import Foundation

@MainActor
extension NightFlockViewModel {
    func beginPartyAcquisition(_ intent: SlumberPartyAcquisition.Intent) -> UUID? {
        guard restoreCampfireVisibility() else { return nil }
        if !v4Acquisition.isBusy, var saved = campfireDocument.partyAcquisition {
            saved.finish()
            v4Acquisition = saved
        }
        if let unresolved = v4Acquisition.intent, unresolved != intent {
            partyConnectionsError = "Check the previous party request before starting another."
            return nil
        }
        guard let id = v4Acquisition.begin(intent) else { return nil }
        var document = campfireDocument
        document.partyAcquisition = v4Acquisition
        guard saveCampfireDocument(document) else { v4Acquisition.finish(); return nil }
        return id
    }

    func finishPartyAcquisition(partyID: UUID? = nil, rejected: Bool = false) {
        if partyID != nil { UserDefaults.standard.removeObject(forKey: SlumberPartyLink.pendingCodeKey) }
        v4Acquisition.finish(partyID: partyID, rejected: rejected)
        guard campfireDocumentOwner == pastureOwner else { return }
        var document = campfireDocument
        document.partyAcquisition = v4Acquisition.intent == nil ? nil : v4Acquisition
        _ = saveCampfireDocument(document)
    }

    func rejectPartyAcquisitionIfConfirmed(_ error: Error) {
        // An explicit rejection allows a different invitation; uncertain
        // transport or snapshot failures must keep the original identity.
        let code = Self.remoteError(from: error)?.code
        let rejected = code == .invalidRequest || code == .flockFull || code == .blockedMembership || code == .inviteUnavailable
        finishPartyAcquisition(rejected: rejected)
    }

    func recoverPartyAcquisition() {
        guard restoreCampfireVisibility(), let intent = campfireDocument.partyAcquisition?.intent else { return }
        switch intent {
        case let .create(name, zone): createSlumberParty(named: name, timeZoneIdentifier: zone)
        case let .join(code): redeemSlumberPartyInvite(code: code)
        case let .invitation(id):
            if let invitation = partyConnections?.invitations.first(where: { $0.id == id }) { acceptPartyInvitation(invitation) }
            else {
                // The server might already have accepted it. Reconcile its exact
                // UUID before allowing another acquisition, without another join.
                guard let commandID = beginPartyAcquisition(.invitation(id)) else { return }
                let generation = localSocialGeneration, epoch = transportRecoveryEpoch
                Task {
                    guard let result = await updatePartyConnections(.init(action: "accept", invitationID: id)),
                          let party = result.acceptedPartyID else {
                        if isCurrentTransportTask(generation: generation, epoch: epoch) { finishPartyAcquisition() }
                        return
                    }
                    finishPartyAcquisition(partyID: party)
                    await persistResolvedSharedHabitsJoinAgreementIntent(partyID: party, commandID: commandID, epoch: generation)
                    guard isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                    try? await refreshV4List()
                    guard isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                    selectSlumberParty(party)
                    acceptStagedSharedHabitsAgreementAfterJoining(partyID: party, commandID: commandID)
                }
            }
        }
    }

    func searchPartyConnection(partyID: UUID, query: String) async -> SlumberPartyPerson? {
        guard supportsDirectInvitations, !partySearchBusy, accountState == .linked,
              permitsNightFlockNetwork, let service else { return nil }
        let generation = localSocialGeneration, epoch = transportRecoveryEpoch
        partySearchBusy = true; partySearchError = nil
        defer { if isCurrentTransportTask(generation: generation, epoch: epoch) { partySearchBusy = false } }
        do {
            let result = try await service.partyConnections(.init(action: "search", partyID: partyID, query: query))
            guard isCurrentTransportTask(generation: generation, epoch: epoch) else { return nil }
            return result.person
        } catch {
            guard isCurrentTransportTask(generation: generation, epoch: epoch) else { return nil }
            partySearchError = (error as? SlumberPartyConnectionError)?.errorDescription ?? SlumberPartyConnectionError.offline.errorDescription
            return nil
        }
    }
    func performSlumberPartyInvitation(_ command: NightFlockV4Command, partyID: UUID) {
        guard accountState == .linked, permitsNightFlockNetwork, service != nil,
              !v4InvitationLoadingPartyIDs.contains(partyID) else { return }
        v4InvitationLoadingPartyIDs.insert(partyID)
        v4InvitationErrors.removeValue(forKey: partyID)
        performV4(command, onSettled: { [weak self] result in
            guard let self else { return }
            self.v4InvitationLoadingPartyIDs.remove(partyID)
            if case let .failure(error) = result { self.v4InvitationErrors[partyID] = self.refreshFailure(for: error) }
        })
    }

    var supportsDirectInvitations: Bool { v4ListState?.directInvitationsVersion == 1 }

    @discardableResult
    func updatePartyConnections(_ request: SlumberPartyConnectionsRequest) async -> SlumberPartyConnections? {
        guard supportsDirectInvitations, accountState == .linked, permitsNightFlockNetwork,
              !partyConnectionsBusy, let service else { return nil }
        let generation = localSocialGeneration
        let epoch = transportRecoveryEpoch
        let attemptID = UUID()
        partyConnectionsAttemptID = attemptID
        partyConnectionsBusy = true
        partyConnectionsError = nil
        defer {
            if partyConnectionsAttemptID == attemptID {
                partyConnectionsBusy = false
                partyConnectionsAttemptID = nil
            }
        }
        do {
            let result = try await service.partyConnections(request)
            guard request.action != "invite" || result.invitations.contains(where: {
                $0.partyID == request.partyID && $0.recipientID == request.userID && !$0.isIncoming
            }) else { throw NightFlockServiceError.unsupportedResponse }
            guard isCurrentTransportTask(generation: generation, epoch: epoch), permitsNightFlockNetwork else { return nil }
            partyConnections = result
            if request.action != "state" { await refreshSocialInbox(summary: true) }
            return result
        } catch {
            guard isCurrentTransportTask(generation: generation, epoch: epoch) else { return nil }
            if request.action == "accept", let error = error as? SlumberPartyConnectionError {
                switch error {
                case .unavailable, .full, .limit, .invalid: finishPartyAcquisition(rejected: true)
                default: break
                }
            }
            partyConnectionsError = (error as? SlumberPartyConnectionError)?.errorDescription
                ?? SlumberPartyConnectionError.offline.errorDescription
            return nil
        }
    }

    func acceptPartyInvitation(_ invitation: SlumberPartyInvitation) {
        guard supportsDirectInvitations, !partyConnectionsBusy, accountState == .linked, permitsNightFlockNetwork,
              let commandID = beginPartyAcquisition(.invitation(invitation.id)) else { return }
        warmNotice = nil
        stageSharedHabitsJoinAgreement(commandID: commandID) { [weak self] in
            guard let self else { return }
            let generation = self.localSocialGeneration
            let epoch = self.transportRecoveryEpoch
            self.v4CommandAttempts.insert(commandID)
            Task {
                defer { self.v4CommandAttempts.remove(commandID) }
                guard let response = await self.updatePartyConnections(.init(action: "accept", invitationID: invitation.id)),
                      let partyID = response.acceptedPartyID, partyID == invitation.partyID else {
                    if self.isCurrentTransportTask(generation: generation, epoch: epoch) { self.finishPartyAcquisition() }
                    return
                }
                self.finishPartyAcquisition(partyID: partyID)
                await self.persistResolvedSharedHabitsJoinAgreementIntent(partyID: partyID, commandID: commandID, epoch: generation)
                guard self.isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                do {
                    try await self.refreshV4List()
                    guard self.isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                    self.selectSlumberParty(partyID)
                    self.acceptStagedSharedHabitsAgreementAfterJoining(partyID: partyID, commandID: commandID)
                } catch {
                    guard self.isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                    self.partyConnectionsError = "You joined the party. Refresh your parties to open it."
                }
            }
        }
    }
}
