import Foundation

extension NightFlockViewModel {
    func refreshGlobalCampfire(gathering: String? = nil, cursor: UUID? = nil) {
        guard restoreCampfireVisibility(), permitsNightFlockNetwork, let service, let owner = pastureOwner else { return }
        if let gathering, gathering != globalCampfireGathering {
            globalCampfireGathering = gathering; globalCampfireState = nil
        }
        let requestedGathering = globalCampfireGathering
        let attempt = UUID(), generation = localSocialGeneration, epoch = transportRecoveryEpoch
        globalCampfireRequestID = attempt; globalCampfireLoading = true
        Task {
            defer { if globalCampfireRequestID == attempt { globalCampfireLoading = false } }
            do {
                let response = try await service.globalCampfireState(gathering: requestedGathering, cursor: cursor)
                guard globalCampfireRequestID == attempt, pastureOwner == owner, permitsNightFlockNetwork,
                      isCurrentTransportTask(generation: generation, epoch: epoch), let state = response.state, state.version == 1 else { return }
                var filtered = state
                let blocked = Set(campfireDocument.commands.filter { $0.command == "block" }.compactMap(\.targetID))
                filtered.participants.removeAll { blocked.contains($0.profileID) }
                globalCampfireState = filtered; globalCampfireFailure = nil
                var document = campfireDocument
                document.publicAgreement = state.agreement
                if let name = state.publicName { document.publicName = name }
                if let appearance = state.appearance { document.appearance = appearance }
                if saveCampfireDocument(document) {
                    drainGlobalCampfireCommands()
                    onCampfireAuthorityAvailable?()
                }
            } catch {
                guard globalCampfireRequestID == attempt, pastureOwner == owner,
                      isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                globalCampfireFailure = "Global Campfire couldn’t be reached. Refresh to try again."
                // An old snapshot is no longer evidence of current presence.
                globalCampfireState = nil
            }
        }
    }

    func enqueueGlobalCampfire(_ command: GlobalCampfireCommand) {
        guard restoreCampfireVisibility(), permitsNightFlockNetwork else { return }
        var document = campfireDocument
        guard document.enqueue(command) else {
            campfireVisibilityMessage = "Your changes are waiting to sync. Retry before sending more."; return
        }
        guard saveCampfireDocument(document) else { return }
        drainGlobalCampfireCommands()
    }

    func drainGlobalCampfireCommands(retry: Bool = false) {
        guard restoreCampfireVisibility(), globalCampfireSendID == nil, permitsNightFlockNetwork,
              let owner = pastureOwner, let service else { return }
        if retry { globalCampfireAttempted = [] }
        let commands = campfireDocument.commands.filter { !globalCampfireAttempted.contains($0.id) }
        guard !commands.isEmpty else { return }
        let generation = localSocialGeneration, epoch = transportRecoveryEpoch
        let sendID = UUID()
        globalCampfireSendID = sendID
        Task {
            defer {
                if globalCampfireSendID == sendID {
                    globalCampfireSendID = nil
                    if pastureOwner == owner && isCurrentTransportTask(generation: generation, epoch: epoch) { drainGlobalCampfireCommands() }
                }
            }
            for command in commands {
                guard pastureOwner == owner, permitsNightFlockNetwork,
                      isCurrentTransportTask(generation: generation, epoch: epoch),
                      campfireDocumentOwner == owner else { return }
                guard campfireDocument.commands.contains(where: { $0.id == command.id }) else { continue }
                globalCampfireAttempted.insert(command.id)
                do {
                    let response = try await service.sendGlobalCampfire(command, ownerID: owner)
                    guard pastureOwner == owner, permitsNightFlockNetwork,
                          isCurrentTransportTask(generation: generation, epoch: epoch), campfireDocumentOwner == owner else { return }
                    if !response.accepted, response.retryable == false, command.command != "agreement" {
                        var document = campfireDocument
                        document.commands.removeAll { $0.id == command.id }
                        guard saveCampfireDocument(document) else { return }
                        campfireVisibilityMessage = "That session or action is no longer available. Refresh the fire to see what’s current."
                        refreshGlobalCampfire()
                        continue
                    }
                    guard response.accepted else { throw NightFlockServiceError.unsupportedResponse }
                    var document = campfireDocument
                    document.commands.removeAll { $0.id == command.id }
                    if let agreement = response.agreement { document.publicAgreement = agreement }
                    if let agreement = response.agreement, response.conflict != true, command.enabled == true {
                        document.bindPublicAgreement(commandID: command.id, agreement: agreement)
                    }
                    guard saveCampfireDocument(document) else { return }
                    campfireVisibilityMessage = response.conflict == true
                        ? "Sharing changed on another device. Review visibility before sharing again." : nil
                    if response.conflict == true { globalCampfireState = nil }
                    refreshGlobalCampfire()
                } catch {
                    guard pastureOwner == owner, isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                    campfireVisibilityMessage = command.command == "agreement" && command.enabled == false
                        ? "Removal is waiting to sync. The last shared session may remain until it expires."
                        : "Your Campfire change is waiting to sync. Your timer keeps running."
                    return
                }
            }
        }
    }

    func publishGlobalCampfireSession(_ run: FocusRun, ended: Bool) {
        guard restoreCampfireVisibility(), permitsNightFlockNetwork,
              CampfireRules.permitsOwner(captured: run.nightWatchPlan?.campfireOwnerID, current: pastureOwner),
              let plan = run.nightWatchPlan, let expires = CampfireRules.end(for: run),
              let agreement = campfireDocument.publicAgreement else { return }
        let selection = campfireSelection(for: run)
        let explicitlyChanged = campfireDocument.runSelections[run.id] != nil
        let receipt = explicitlyChanged ? selection.publicAgreementID : plan.publicCampfireAgreementID
        guard CampfireVisibilityRules.permitsPublicPublication(visibility: selection.visibility, capturedAgreement: receipt, current: agreement),
              !campfireDocument.commands.contains(where: { $0.command == "agreement" }) else { return }
        let start = explicitlyChanged ? selection.publicStartedAt ?? expires : CampfireVisibilityRules.sharingStart(requested: run.startedAt, acceptedAt: agreement.acceptedAt)
        guard start >= agreement.acceptedAt, start < expires, expires > Date() || ended else { return }
        if !ended, globalCampfireState?.ownSourceID == run.id { return }
        var command = GlobalCampfireCommand(command: "publish")
        command.id = NightFlockV4Idempotency.command("global-campfire-\(agreement.id)-\(ended)", seed: run.id)
        command.agreementID = agreement.id; command.sourceID = run.id
        command.kind = plan.role == .primarySleepBookend ? .windDown : .phoneAway
        command.activity = plan.role == .additionalQuiet ? plan.campfireActivity ?? .phoneAway : nil
        command.startedAt = start; command.expiresAt = expires; command.ended = ended
        enqueueGlobalCampfire(command)
    }

    func globalCampfireAction(_ action: String, participant: GlobalCampfireParticipant, reason: String? = nil) {
        guard globalCampfireState?.isSupported == true, !participant.isMe else { return }
        var command = GlobalCampfireCommand(command: action)
        command.targetID = action == "encourage" ? participant.id : participant.profileID
        command.reason = reason
        enqueueGlobalCampfire(command)
        if action == "block" {
            globalCampfireState?.participants.removeAll { $0.profileID == participant.profileID }
        }
    }
}
