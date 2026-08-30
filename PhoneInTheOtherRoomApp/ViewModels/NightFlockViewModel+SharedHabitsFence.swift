import Foundation

extension NightFlockViewModel {
    var hasPendingSharedHabitsPrivacyAction: Bool {
        !sharedHabitsPrivacyFences.isEmpty
    }

    var sharedHabitsPrivacyNotice: String? {
        guard let fence = sharedHabitsPrivacyFences.first else { return nil }
        switch fence.action {
        case .leave:
            return "Leaving this party is waiting for a connection. New sharing is paused on this iPhone."
        case .withdrawHistory:
            return "Removing your shared history is waiting for a connection. New sharing is paused on this iPhone."
        case .dissolveAndLeave:
            return "Dissolving this party is waiting for a connection. New sharing is paused on this iPhone."
        }
    }

    func isSharedHabitsPartySuppressed(_ partyID: UUID) -> Bool {
        !NightFlockSharedHabitsFencePolicy.permitsPartyReadOrPublication(
            partyID: partyID,
            fences: sharedHabitsPrivacyFences
        )
    }

    func mayPublishWhileSharedHabitsFenceIsOpen() -> Bool {
        NightFlockSharedHabitsFencePolicy.permitsAnyPublication(
            fences: sharedHabitsPrivacyFences
        )
    }

    /// The durable write precedes any transport. A server response can prove a
    /// leave, but a local privacy stop takes effect before that response exists.
    func beginSharedHabitsPrivacyFence(
        partyID: UUID,
        action: NightFlockSharedHabitsPrivacyFence.Action,
        onFenced: @escaping (NightFlockSharedHabitsPrivacyFence) -> Void = { _ in }
    ) {
        guard featureEnabled,
              accountState == .linked,
              !isSharedHabitsPartySuppressed(partyID),
              let outbox
        else { return }
        let fence = NightFlockSharedHabitsPrivacyFence(partyID: partyID, action: action)
        let generation = localSocialGeneration
        Task { [weak self] in
            guard let self,
                  await outbox.stageSharedHabitsPrivacyFence(fence, epoch: generation),
                  await outbox.dropSharedHabits(for: partyID, epoch: generation),
                  self.isCurrentLocalSocialGeneration(generation)
            else {
                guard let self else { return }
                self.phase = .offline
                self.warmNotice = "Sharing is paused on this iPhone while Ollie keeps this privacy change safe."
                return
            }
            // Do not acknowledge or suppress the party until the local
            // privacy fence has survived a process termination/relaunch.
            self.sharedHabitsPrivacyFences = NightFlockSharedHabitsFencePolicy.replacing(
                self.sharedHabitsPrivacyFences,
                with: fence
            )
            self.sharedHabitsFenceGeneration &+= 1
            self.onSharedHabitsAuthorityInvalidated?()
            self.suppressSharedHabitsPartyPresentation(partyID)
            onFenced(fence)
        }
    }

    func clearSharedHabitsPrivacyFenceAfterAuthoritativeConfirmation(partyID: UUID) {
        guard let outbox else { return }
        let generation = localSocialGeneration
        Task { [weak self] in
            guard let self,
                  await outbox.removeSharedHabitsPrivacyFence(partyID: partyID, epoch: generation),
                  self.isCurrentLocalSocialGeneration(generation)
            else { return }
            self.sharedHabitsPrivacyFences.removeAll { $0.partyID == partyID }
            self.sharedHabitsFenceGeneration &+= 1
            self.refreshSharedHabitsFormerParties()
        }
    }

    func reconcileSharedHabitsLeaveFences(
        with canonicalParties: [NightFlockV4PartySummary]
    ) {
        let absentPartyIDs = sharedHabitsPrivacyFences.compactMap { fence -> UUID? in
            guard fence.action == .leave || fence.action == .dissolveAndLeave || fence.action == .withdrawHistory,
                  !canonicalParties.contains(where: { $0.partyID == fence.partyID })
            else { return nil }
            return fence.partyID
        }
        for partyID in absentPartyIDs {
            guard let fence = sharedHabitsPrivacyFences.first(where: { $0.partyID == partyID }) else { continue }
            if fence.action == .withdrawHistory {
                deleteSharedHabitsHistoryAfterConfirmedLeave(partyID: partyID, fence: fence)
            } else {
                if fence.action == .leave, let outbox {
                    let generation = localSocialGeneration
                    Task { await outbox.recordSharedHabitsFormerParty(partyID, epoch: generation) }
                }
                clearSharedHabitsPrivacyFenceAfterAuthoritativeConfirmation(partyID: partyID)
            }
        }
    }

    func withdrawSharedHabitsAndLeave(_ partyID: UUID) {
        guard NightFlockSharedHabitsFencePolicy.archiveDeletionDisposition(
            supportsSharedHabits: supportsSharedHabits,
            fence: sharedHabitsPrivacyFences.first(where: { $0.partyID == partyID })
        ) == .send else { return }
        beginSharedHabitsPrivacyFence(partyID: partyID, action: .withdrawHistory) { [weak self] fence in
            guard let self else { return }
            self.performV4(.leaveParty(
                partyID: partyID,
                idempotencyKey: self.fenceIdempotencyKey(fence, action: "leave-and-delete-shared-habits")
            ))
        }
    }

    func retrySharedHabitsPrivacyAction() {
        guard let fence = sharedHabitsPrivacyFences.first else { return }
        let retry = { [weak self] in
            guard let self else { return }
            switch fence.action {
            case .leave:
                self.performV4(.leaveParty(partyID: fence.partyID, idempotencyKey: self.fenceIdempotencyKey(fence, action: "leave-party")))
            case .dissolveAndLeave:
                self.performV4(.deleteParty(partyID: fence.partyID, idempotencyKey: self.fenceIdempotencyKey(fence, action: "dissolve-party")))
            case .withdrawHistory:
                guard let shouldDelete = NightFlockSharedHabitsFencePolicy.withdrawalRetryRequiresRemoteDelete(
                    canonicalSnapshotLoaded: self.hasCanonicalV4PartySnapshot,
                    partyIsStillPresent: self.canonicalV4PartyIDs.contains(fence.partyID)
                ) else {
                    self.warmNotice = "Your shared-history deletion is waiting for a connection. New sharing remains paused on this iPhone."
                    return
                }
                if shouldDelete {
                    self.deleteSharedHabitsHistoryAfterConfirmedLeave(partyID: fence.partyID, fence: fence)
                } else {
                    self.performV4(.leaveParty(partyID: fence.partyID, idempotencyKey: self.fenceIdempotencyKey(fence, action: "leave-and-delete-shared-habits")))
                }
            }
        }
        if !hasCanonicalV4PartySnapshot {
            Task { [weak self] in
                guard let self else { return }
                guard await self.refreshState(showLoading: false) else {
                    self.warmNotice = "This privacy change is waiting for a connection. New sharing remains paused on this iPhone."
                    return
                }
                retry()
            }
        } else {
            retry()
        }
    }

    func fenceIdempotencyKey(
        _ fence: NightFlockSharedHabitsPrivacyFence,
        action: String
    ) -> String {
        NightFlockV4Idempotency.command(action, seed: fence.commandID ?? fence.id)
    }

    private func deleteSharedHabitsHistoryAfterConfirmedLeave(
        partyID: UUID,
        fence: NightFlockSharedHabitsPrivacyFence
    ) {
        switch NightFlockSharedHabitsFencePolicy.archiveDeletionDisposition(
            supportsSharedHabits: supportsSharedHabits,
            fence: fence
        ) {
        case .send:
            break
        case .preservePendingFence:
            warmNotice = "Your shared-history deletion is still pending until this Slumber Party can confirm shared habits again. New sharing remains paused on this iPhone."
            return
        case .unavailable:
            return
        }
        guard accountState == .linked,
              permitsNightFlockNetwork,
              !sharedHabitsDestructiveCommandPartyIDs.contains(partyID),
              let service,
              let outbox
        else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        let idempotencyKey = fenceIdempotencyKey(fence, action: "delete-shared-habits-history")
        sharedHabitsDestructiveCommandPartyIDs.insert(partyID)
        Task { [weak self] in
            defer { self?.sharedHabitsDestructiveCommandPartyIDs.remove(partyID) }
            do {
                guard let self,
                      self.isCurrentLocalSocialGeneration(generation),
                      self.isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      self.accountState == .linked,
                      self.permitsNightFlockNetwork,
                      self.supportsSharedHabits,
                      self.sharedHabitsPrivacyFences.contains(where: {
                          $0.id == fence.id
                              && $0.partyID == partyID
                              && $0.action == .withdrawHistory
                      })
                else { return }
                let acknowledgement = try await service.sendSharedHabits(.deleteAll(
                    partyID: partyID,
                    idempotencyKey: idempotencyKey
                ))
                guard acknowledgement.accepted,
                      self.isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      self.accountState == .linked,
                      self.permitsNightFlockNetwork,
                      self.supportsSharedHabits
                else { return }
                await outbox.removeSharedHabitsFormerParty(partyID, epoch: generation)
                self.clearSharedHabitsPrivacyFenceAfterAuthoritativeConfirmation(partyID: partyID)
                Task { await self.refreshState(showLoading: false) }
            } catch {
                guard let self,
                      self.isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      self.accountState == .linked,
                      self.permitsNightFlockNetwork,
                      self.supportsSharedHabits
                else { return }
                self.presentNightFlockError(
                    error,
                    lane: .directCommand(schema: NightFlockV4Rules.schemaVersion)
                )
                guard self.pendingAuthenticationRecovery == .none else { return }
                self.phase = .offline
                self.warmNotice = "Your shared-history deletion is waiting for a connection. New sharing remains paused on this iPhone."
            }
        }
    }

    func refreshSharedHabitsFormerParties() {
        guard let outbox else { return }
        Task { [weak self] in
            let parties = await outbox.sharedHabitsFormerParties()
            guard let self else { return }
            self.sharedHabitsFormerParties = parties
        }
    }

    func deleteRetainedSharedHabitsHistory(partyID: UUID) {
        guard NightFlockSharedHabitsFencePolicy.archiveDeletionDisposition(
            supportsSharedHabits: supportsSharedHabits,
            fence: sharedHabitsPrivacyFences.first(where: { $0.partyID == partyID })
        ) == .send else { return }
        beginSharedHabitsPrivacyFence(partyID: partyID, action: .withdrawHistory) { [weak self] fence in
            self?.deleteSharedHabitsHistoryAfterConfirmedLeave(partyID: partyID, fence: fence)
        }
    }

    private func suppressSharedHabitsPartyPresentation(_ partyID: UUID) {
        v4ListState?.parties.removeAll { $0.partyID == partyID }
        v4InviteCodes.removeValue(forKey: partyID)
        v4ObservedPartyDetails.removeValue(forKey: partyID)
        v4ObservedPartyRefreshDates.removeValue(forKey: partyID)
        v4ObservedPartyObservationStates.removeValue(forKey: partyID)
        sharedHabitsStates.removeValue(forKey: partyID)
        sharedHabitsLoadingPartyIDs.remove(partyID)
        sharedHabitsAgreementSavingPartyIDs.remove(partyID)
        sharedHabitsAgreementErrors.removeValue(forKey: partyID)
        sharedHabitsAgreementAttemptIDs.removeValue(forKey: partyID)
        v4AcceptedPartyDetailRequestSequences.removeValue(forKey: partyID)
        v4RefreshingPartyIDs.remove(partyID)
        v4SelectedPartyRefreshAttemptIDs.removeValue(forKey: partyID)
        v4PartyObservationNeedsRefresh.remove(partyID)
        v4RealtimeRefreshTasks.removeValue(forKey: partyID)?.cancel()
        v4RealtimeSetupTasks.removeValue(forKey: partyID)?.cancel()
        v4PartyObservationTasks.removeValue(forKey: partyID)?.cancel()
        v4RealtimeRefreshAttemptIDs.removeValue(forKey: partyID)
        v4RealtimeSetupAttemptIDs.removeValue(forKey: partyID)
        v4PartyObservationAttemptIDs.removeValue(forKey: partyID)
        v4RealtimePartyIDs.remove(partyID)
        v4RealtimeConnectedPartyIDs.remove(partyID)
        v4CheerSendStates = v4CheerSendStates.filter { $0.key.partyID != partyID }
        if selectedV4Party?.summary.partyID == partyID {
            selectedV4Party = nil
        }
        Task { [service] in await service?.stopV4Realtime(partyID: partyID) }
    }
}
