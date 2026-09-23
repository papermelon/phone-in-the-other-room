import Foundation

@MainActor
extension NightFlockViewModel {
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
            return result
        } catch {
            guard isCurrentTransportTask(generation: generation, epoch: epoch) else { return nil }
            partyConnectionsError = (error as? SlumberPartyConnectionError)?.errorDescription
                ?? SlumberPartyConnectionError.offline.errorDescription
            return nil
        }
    }

    func acceptPartyInvitation(_ invitation: SlumberPartyInvitation) {
        guard supportsDirectInvitations, !partyConnectionsBusy, accountState == .linked, permitsNightFlockNetwork,
              let commandID = v4Acquisition.begin(.invitation(invitation.id)) else { return }
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
                    if self.isCurrentTransportTask(generation: generation, epoch: epoch) { self.v4Acquisition.finish() }
                    return
                }
                self.v4Acquisition.finish(partyID: partyID)
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
