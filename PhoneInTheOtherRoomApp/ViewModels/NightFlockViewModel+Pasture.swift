import Foundation

extension NightFlockViewModel {
    var pastureOwner: UUID? {
        NightFlockExpectedIdentityBinding.classify(defaults.string(forKey: NightFlockAccountService.expectedLinkedUserIDKey)).validUserID
    }

    var visitingSheepIDs: Set<UUID> {
        guard permitsFarmOwnerScopedSocialEffects else { return [] }
        let eligible = Set(slumberParties.map(\.partyID)).filter { !isSharedHabitsPartySuppressed($0) }
        return eligible.reduce(into: Set<UUID>()) { result, partyID in
            result.formUnion(cachedPastureVisits[partyID] ?? [])
            result.formUnion(v4ObservedPartyDetails[partyID]?.pasture?.visits.compactMap(\.ownedSheepID) ?? [])
        }
    }

    func restorePastureVisitIndex(eligiblePartyIDs: Set<UUID>) {
        guard let owner = pastureOwner else { return }
        do {
            cachedPastureVisits = try pastureOutbox.visitIndex(owner: owner).filter { eligiblePartyIDs.contains($0.key) }
            try pastureOutbox.saveVisitIndex(cachedPastureVisits, owner: owner)
        } catch { /* Canonical refresh repairs the small derived visit index. */ }
    }

    func recordPastureVisits(_ party: NightFlockV4PartyDetail) {
        guard let owner = pastureOwner, let pasture = party.pasture, pasture.isSupported else { return }
        cachedPastureVisits[party.summary.partyID] = Set(pasture.visits.compactMap(\.ownedSheepID))
        do { try pastureOutbox.saveVisitIndex(cachedPastureVisits, owner: owner) }
        catch { pastureMessages[party.summary.partyID] = "The shared pasture is current. This phone couldn’t keep a local copy of your visits." }
    }

    func movePasture(partyID: UUID, arrangement: SharedMeadowArrangement) {
        guard let state = v4ObservedPartyDetail(for: partyID)?.pasture, state.isSupported else { return }
        for entity in SharedPastureRules.changedEntities(in: arrangement, from: state) {
            var command = SharedPastureCommand(command: "movePastureEntity", partyID: partyID, memberEpochID: state.memberEpochID)
            command.entityID = entity.id; command.expectedRevision = entity.revision; command.x = entity.x; command.y = entity.y
            enqueuePasture(command)
        }
    }

    func contributeSheep(_ sheepID: UUID, partyID: UUID) {
        guard let state = v4ObservedPartyDetail(for: partyID)?.pasture, state.isSupported else { return }
        var command = SharedPastureCommand(command: "contributePastureSheep", partyID: partyID, memberEpochID: state.memberEpochID)
        command.sheepID = sheepID; command.consentVersion = 1
        enqueuePasture(command)
    }

    func recallSheep(_ visitID: UUID, partyID: UUID) {
        guard let state = v4ObservedPartyDetail(for: partyID)?.pasture, state.isSupported else { return }
        var command = SharedPastureCommand(command: "recallPastureSheep", partyID: partyID, memberEpochID: state.memberEpochID)
        command.visitID = visitID
        enqueuePasture(command)
    }

    private func enqueuePasture(_ command: SharedPastureCommand) {
        guard let owner = pastureOwner, permitsNightFlockNetwork, accountState == .linked,
              !isSharedHabitsPartySuppressed(command.partyID), !pastureSending.contains(command.partyID) else { return }
        do {
            let pending = try pastureOutbox.commands(owner: owner)
            if pending.contains(where: { $0.partyID == command.partyID && $0.command == command.command && $0.sheepID == command.sheepID && $0.visitID == command.visitID && $0.entityID == command.entityID }) {
                recoverPasture(partyID: command.partyID, retry: true)
                return
            }
            try pastureOutbox.enqueue(command, owner: owner)
            recoverPasture(partyID: command.partyID, retry: true)
        } catch { pastureMessages[command.partyID] = "Couldn’t save that change. Try again." }
    }

    func recoverPasture(partyID: UUID, retry: Bool = false) {
        guard let owner = pastureOwner, permitsNightFlockNetwork, accountState == .linked, let service,
              !isSharedHabitsPartySuppressed(partyID), !pastureSending.contains(partyID),
              let state = v4ObservedPartyDetail(for: partyID)?.pasture, state.isSupported else { return }
        let commands: [SharedPastureCommand]
        do { commands = try pastureOutbox.commands(owner: owner).filter { $0.partyID == partyID } }
        catch { pastureMessages[partyID] = "Saved changes couldn’t be read. Your shared arrangement is still safe."; return }
        guard commands.contains(where: { retry || !pastureAttempts.contains("\(localSocialGeneration):\($0.id)") }) else { return }
        let generation = localSocialGeneration
        let transport = transportRecoveryEpoch
        let fence = sharedHabitsFenceGeneration
        pastureSending.insert(partyID)
        pastureMessages[partyID] = "Saving to the shared pasture…"
        Task {
            defer { if generation == localSocialGeneration { pastureSending.remove(partyID) } }
            for command in commands {
                guard permitsNightFlockNetwork, pastureOwner == owner,
                      isCurrentTransportTask(generation: generation, epoch: transport),
                      fence == sharedHabitsFenceGeneration, !isSharedHabitsPartySuppressed(partyID) else { return }
                guard command.memberEpochID == state.memberEpochID else {
                    try? pastureOutbox.remove(command.id, owner: owner); continue
                }
                let attempt = "\(generation):\(command.id)"
                if !retry && pastureAttempts.contains(attempt) { continue }
                pastureAttempts.insert(attempt)
                do {
                    let result = try await service.sendPasture(command)
                    guard permitsNightFlockNetwork, pastureOwner == owner,
                          isCurrentTransportTask(generation: generation, epoch: transport),
                          fence == sharedHabitsFenceGeneration, !isSharedHabitsPartySuppressed(partyID) else { return }
                    guard result.accepted else { throw NightFlockServiceError.unsupportedResponse }
                    try pastureOutbox.remove(command.id, owner: owner)
                    pastureMessages[partyID] = result.conflict == true
                        ? "Someone placed this first. Showing the shared arrangement."
                        : "Saved to the shared pasture"
                    pastureRefreshTokens[partyID, default: 0] += 1
                    selectSlumberParty(partyID)
                } catch {
                    guard generation == localSocialGeneration, pastureOwner == owner else { return }
                    if let remote = error as? NightFlockRemoteError, !remote.retryable,
                       remote.code != .unauthorized && remote.code != .linkedAccountRequired {
                        try? pastureOutbox.remove(command.id, owner: owner)
                        pastureMessages[partyID] = [NightFlockRemoteErrorCode.pastureSheepNotOwned, .pastureSheepAlreadyVisiting].contains(remote.code)
                            ? remote.errorDescription : "That change is no longer available. Refresh the party before trying again."
                        pastureRefreshTokens[partyID, default: 0] += 1
                        selectSlumberParty(partyID)
                    } else {
                        pastureMessages[partyID] = "That change hasn’t been saved. Refresh, then retry."
                    }
                    return
                }
            }
        }
    }
}
