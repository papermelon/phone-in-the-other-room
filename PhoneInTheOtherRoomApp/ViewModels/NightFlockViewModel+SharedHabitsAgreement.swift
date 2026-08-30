import Foundation

@MainActor
extension NightFlockViewModel {
    func acceptSharedHabitsAgreement(
        partyID: UUID,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) {
        guard supportsSharedHabits,
              accountState == .linked,
              permitsNightFlockNetwork,
              !isSharedHabitsPartySuppressed(partyID),
              !sharedHabitsAgreementSavingPartyIDs.contains(partyID),
              let service,
              let memberID = v4ObservedPartyDetail(for: partyID)?.myMemberID,
              let outbox
        else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        let attemptID = UUID()
        sharedHabitsAgreementAttemptIDs[partyID] = attemptID
        sharedHabitsAgreementSavingPartyIDs.insert(partyID)
        sharedHabitsAgreementErrors.removeValue(forKey: partyID)
        Task { [weak self] in
            var shouldRefreshReceipt = false
            defer {
                // Release only this attempt, before starting the receipt request.
                // The old shared loading flag let a defer clear its successor.
                if let self, self.sharedHabitsAgreementAttemptIDs[partyID] == attemptID {
                    self.sharedHabitsAgreementSavingPartyIDs.remove(partyID)
                    if shouldRefreshReceipt {
                        self.refreshSharedHabits(partyID: partyID)
                    }
                }
            }
            let joinIntent = await outbox.sharedHabitsJoinAgreementIntent(epoch: generation)
            let contributorTimeZone = joinIntent?.partyID == partyID
                ? (joinIntent?.timeZoneIdentifier ?? timeZoneIdentifier)
                : timeZoneIdentifier
            guard let seed = await outbox.sharedHabitsAgreementAttempt(
                partyID: partyID, memberID: memberID,
                timeZoneIdentifier: contributorTimeZone, epoch: generation
            ) else { return }
            guard let self,
                  self.isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                  self.sharedHabitsAgreementAttemptIDs[partyID] == attemptID,
                  self.accountState == .linked,
                  self.permitsNightFlockNetwork,
                  self.supportsSharedHabits,
                  !self.isSharedHabitsPartySuppressed(partyID)
            else { return }
            let command = NightFlockSharedHabitsCommand.acceptAgreement(
                partyID: partyID,
                agreementVersion: self.supportsSharedNightPlans ? 2 : 1,
                timeZoneIdentifier: contributorTimeZone,
                idempotencyKey: NightFlockV4Idempotency.command("shared-habits-agreement-\(partyID.uuidString)-\(memberID.uuidString)-\(contributorTimeZone)", seed: seed)
            )
            do {
                let acknowledgement = try await service.sendSharedHabits(command)
                guard acknowledgement.accepted,
                      self.isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      self.sharedHabitsAgreementAttemptIDs[partyID] == attemptID,
                      self.accountState == .linked,
                      self.permitsNightFlockNetwork,
                      self.supportsSharedHabits,
                      !self.isSharedHabitsPartySuppressed(partyID),
                      self.slumberParties.contains(where: { $0.partyID == partyID })
                else { return }
                shouldRefreshReceipt = true
            } catch {
                guard self.isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      self.sharedHabitsAgreementAttemptIDs[partyID] == attemptID,
                      self.accountState == .linked,
                      self.permitsNightFlockNetwork,
                      self.supportsSharedHabits
                else { return }
                self.presentSharedHabitsAgreementError(error, partyID: partyID,
                    lane: .directCommand(schema: NightFlockV4Rules.schemaVersion))
            }
        }
    }


    /// Agreement transport failures belong to this card. Only owned account
    /// recovery may replace the global social presentation.
    func presentSharedHabitsAgreementError(
        _ error: Error, partyID: UUID, lane: NightFlockRecoveryLane,
        isReceiptLookup: Bool = false
    ) {
        if isReceiptLookup {
            sharedHabitsAgreementErrors[partyID] = "We couldn’t load your group confirmation. Please try again."
        } else if case let .error(message) = Self.phase(for: error) {
            sharedHabitsAgreementErrors[partyID] = message
        } else {
            sharedHabitsAgreementErrors[partyID] = "We couldn’t confirm your agreement. Please try again."
        }
        if let remote = Self.remoteError(from: error) {
            let presentation = configureAuthenticationRecovery(remote, lane: lane)
            if presentation.action != .none {
                presentNightFlockError(error, lane: lane)
            }
        }
    }
}
