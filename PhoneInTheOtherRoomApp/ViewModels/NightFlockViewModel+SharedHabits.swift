import Foundation

@MainActor
extension NightFlockViewModel {
    var outboxForSharedHabitsReconciliation: NightFlockOutboxService? { outbox }

    func sharedNightPlanBinding(partyID: UUID, memberEpochID: UUID, nightEndingDate: NightFlockLocalDate) async -> SharedNightPlan? {
        await outbox?.sharedNightPlanBinding(partyID: partyID, memberEpochID: memberEpochID, nightEndingDate: nightEndingDate)
    }

    var supportsSharedHabits: Bool {
        v4ListState?.supportsSharedHabits == true
    }

    var supportsSharedNightPlans: Bool {
        v4ListState?.supportsSharedNightPlans == true
    }

    func requiresSharedNightPlanAgreement(partyID: UUID) -> Bool {
        supportsSharedNightPlans && (sharedHabitsStates[partyID]?.agreement?.agreementVersion ?? 0) < 2
    }

    /// The earliest active agreement in each contributor timezone bounds one
    /// batched local Health query. Each later party is still checked again at
    /// publication, so a result never crosses its own consent cutoff.
    /// Server metadata is the recovery-safe deletion discovery path. The local
    /// pointer remains only for older services that cannot list retained rows.
    var retainedSharedHabitParties: [NightFlockRetainedSharedHabitParty] {
        guard supportsSharedHabits else { return [] }
        return v4ListState?.retainedSharedHabitParties ?? []
    }

    var sharedHabitsEarliestAcceptanceByTimeZone: [String: Date] {
        Dictionary(grouping: sharedHabitsStates.values.compactMap { state -> NightFlockSharedHabitsAgreementReceipt? in
            state.agreement
        }, by: \.timeZoneIdentifier).compactMapValues { receipts in
            receipts.map(\.acceptedAt).min()
        }
    }

    func isSharedHabitsJoinAgreementReceiptPending(partyID: UUID) -> Bool {
        sharedHabitsStagedJoinPartyIDs.contains(partyID)
    }

    func refreshSharedHabitsReceiptsForCurrentParties() {
        guard supportsSharedHabits else { return }
        for party in slumberParties where sharedHabitsStates[party.partyID] == nil {
            refreshSharedHabits(partyID: party.partyID)
        }
    }

    func sharedHabitsState(for partyID: UUID) -> NightFlockSharedHabitsStateResponse? {
        guard supportsSharedHabits, !isSharedHabitsPartySuppressed(partyID) else { return nil }
        return sharedHabitsStates[partyID]
    }

    func refreshSharedHabits(partyID: UUID, cursor: String? = nil) {
        guard accountState == .linked,
              permitsNightFlockNetwork,
              supportsSharedHabits,
              slumberParties.contains(where: { $0.partyID == partyID }),
              !isSharedHabitsPartySuppressed(partyID),
              !sharedHabitsLoadingPartyIDs.contains(partyID),
              !sharedHabitsAgreementSavingPartyIDs.contains(partyID),
              let service
        else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        let fenceGeneration = sharedHabitsFenceGeneration
        let agreementAttemptID = sharedHabitsAgreementAttemptIDs[partyID]
        sharedHabitsLoadingPartyIDs.insert(partyID)
        var restartWithoutCursor = false
        Task { [weak self] in
            defer {
                self?.sharedHabitsLoadingPartyIDs.remove(partyID)
                if restartWithoutCursor {
                    self?.refreshSharedHabits(partyID: partyID)
                }
            }
            do {
                guard let self,
                      self.isCurrentLocalSocialGeneration(generation),
                      self.isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      self.accountState == .linked,
                      self.permitsNightFlockNetwork,
                      self.supportsSharedHabits,
                      self.sharedHabitsFenceGeneration == fenceGeneration,
                      !self.isSharedHabitsPartySuppressed(partyID)
                else { return }
                let response = try await service.stateSharedHabits(partyID: partyID, cursor: cursor)
                guard self.isCurrentLocalSocialGeneration(generation),
                  self.isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      self.accountState == .linked,
                      self.permitsNightFlockNetwork,
                      self.supportsSharedHabits,
                      self.sharedHabitsFenceGeneration == fenceGeneration,
                      !self.isSharedHabitsPartySuppressed(partyID)
                else { return }
                // A response started before confirmation must not overwrite its receipt.
                guard self.sharedHabitsAgreementAttemptIDs[partyID] == agreementAttemptID,
                      !self.sharedHabitsAgreementSavingPartyIDs.contains(partyID)
                else {
                    restartWithoutCursor = true
                    return
                }
                self.sharedHabitsAgreementErrors.removeValue(forKey: partyID)
                let previousAgreement = self.sharedHabitsStates[partyID]?.agreement
                if cursor != nil, let existing = self.sharedHabitsStates[partyID] {
                    var merged = response
                    let known = Set(existing.records.map(\.recordID))
                    merged.records = existing.records + response.records.filter { !known.contains($0.recordID) }
                    self.sharedHabitsStates[partyID] = merged
                } else {
                    self.sharedHabitsStates[partyID] = response
                }
                if let receipt = self.sharedHabitsStates[partyID]?.agreement {
                    self.migrateSharedHabitsIfNeeded(partyID: partyID, agreementID: receipt.agreementID)
                    if receipt.agreementVersion >= 2 {
                        self.refreshSharedNights(partyID: partyID)
                    }
                    if cursor == nil || previousAgreement?.agreementID != receipt.agreementID
                        || previousAgreement?.memberEpochID != receipt.memberEpochID {
                        self.onSharedHabitsAgreementAvailable?()
                    }
                }
                await self.reconcilePendingSharedHabits(for: partyID, epoch: generation)
            } catch {
                guard let self,
                      self.isCurrentLocalSocialGeneration(generation),
                      self.isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      self.accountState == .linked,
                      self.permitsNightFlockNetwork,
                      self.supportsSharedHabits,
                      self.sharedHabitsFenceGeneration == fenceGeneration,
                      !self.isSharedHabitsPartySuppressed(partyID)
                else { return }
                // A cursor rejection denotes a changed immutable snapshot.
                // Refetch its first page rather than guessing an offset.
                if cursor != nil {
                    self.sharedHabitsStates.removeValue(forKey: partyID)
                    // Restart only after this task releases its loading marker.
                    // Otherwise this request's defer can clear the replacement
                    // request and allow duplicate loads.
                    restartWithoutCursor = true
                    return
                }
                guard self.sharedHabitsAgreementAttemptIDs[partyID] == agreementAttemptID,
                      !self.sharedHabitsAgreementSavingPartyIDs.contains(partyID)
                else {
                    restartWithoutCursor = true
                    return
                }
                if self.sharedHabitsStates[partyID]?.agreement == nil {
                    self.presentSharedHabitsAgreementError(error, partyID: partyID,
                        lane: .snapshot(schema: NightFlockV4Rules.schemaVersion), isReceiptLookup: true)
                } else {
                    self.presentNightFlockError(error, lane: .snapshot(schema: NightFlockV4Rules.schemaVersion))
                }
            }
        }
    }

    func loadMoreSharedHabits(partyID: UUID) {
        guard let cursor = sharedHabitsState(for: partyID)?.nextCursor else { return }
        refreshSharedHabits(partyID: partyID, cursor: cursor)
    }

    func loadMoreSharedNights(partyID: UUID) {
        guard let cursor = sharedHabitsState(for: partyID)?.sharedNightsNextCursor else { return }
        refreshSharedNights(partyID: partyID, cursor: cursor)
    }

    private func refreshSharedNights(partyID: UUID, cursor: String? = nil) {
        guard supportsSharedNightPlans,
              accountState == .linked,
              permitsNightFlockNetwork,
              !isSharedHabitsPartySuppressed(partyID),
              !sharedNightsLoadingPartyIDs.contains(partyID),
              let service
        else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        let fenceGeneration = sharedHabitsFenceGeneration
        sharedNightsLoadingPartyIDs.insert(partyID)
        var restartWithoutCursor = false
        Task { [weak self] in
            defer {
                self?.sharedNightsLoadingPartyIDs.remove(partyID)
                if restartWithoutCursor { self?.refreshSharedNights(partyID: partyID) }
            }
            do {
                let response = try await service.stateSharedNights(partyID: partyID, cursor: cursor)
                guard let self,
                      self.isCurrentLocalSocialGeneration(generation),
                      self.isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      self.sharedHabitsFenceGeneration == fenceGeneration,
                      !self.isSharedHabitsPartySuppressed(partyID),
                      var existing = self.sharedHabitsStates[partyID]
                else { return }
                if cursor != nil {
                    let knownPlans = Set(existing.sharedNightPlans.map(\.planID))
                    let knownReceipts = Set(existing.sharedNightReceipts.map(\.receiptID))
                    existing.sharedNightPlans += response.sharedNightPlans.filter { !knownPlans.contains($0.planID) }
                    existing.sharedNightReceipts += response.sharedNightReceipts.filter { !knownReceipts.contains($0.receiptID) }
                    existing.sharedNightsNextCursor = response.sharedNightsNextCursor
                    existing.sharedNightsSnapshotRevision = response.sharedNightsSnapshotRevision
                } else {
                    existing.sharedNightPlans = response.sharedNightPlans
                    existing.sharedNightReceipts = response.sharedNightReceipts
                    existing.sharedNightsNextCursor = response.sharedNightsNextCursor
                    existing.sharedNightsSnapshotRevision = response.sharedNightsSnapshotRevision
                }
                self.sharedHabitsStates[partyID] = existing
            } catch {
                // A stale v2 cursor represents a changed archive snapshot. A first-page
                // refresh is the only safe continuation; never infer an offset locally.
                if cursor != nil { restartWithoutCursor = true }
            }
        }
    }

    func stageSharedHabitsJoinAgreement(
        commandID: UUID,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        then action: @escaping () -> Void
    ) {
        guard supportsSharedHabits, let outbox else {
            action()
            return
        }
        let generation = localSocialGeneration
        Task { [weak self] in
            guard let self,
                  await outbox.stageSharedHabitsJoinAgreementIntent(commandID: commandID, timeZoneIdentifier: timeZoneIdentifier, epoch: generation),
                  self.isCurrentLocalSocialGeneration(generation)
            else { return }
            action()
        }
    }

    func acceptStagedSharedHabitsAgreementAfterJoining(partyID: UUID, commandID: UUID) {
        guard supportsSharedHabits, let outbox else { return }
        let generation = localSocialGeneration
        Task { [weak self] in
            guard let self,
                  let intent = await outbox.resolveSharedHabitsJoinAgreementIntent(commandID: commandID, partyID: partyID, epoch: generation),
                  self.isCurrentLocalSocialGeneration(generation),
                  self.slumberParties.contains(where: { $0.partyID == partyID })
            else { return }
            self.sharedHabitsStagedJoinPartyIDs.insert(partyID)
            self.acceptSharedHabitsAgreement(partyID: partyID, timeZoneIdentifier: intent.timeZoneIdentifier)
        }
    }

    internal func persistResolvedSharedHabitsJoinAgreementIntent(
        partyID: UUID,
        commandID: UUID,
        epoch: UInt64
    ) async {
        guard supportsSharedHabits, let outbox else { return }
        if await outbox.resolveSharedHabitsJoinAgreementIntent(
            commandID: commandID,
            partyID: partyID,
            epoch: epoch
        ) != nil {
            // Reserve this exact party while its canonical detail arrives;
            // the post-detail callback then performs the one receipt request.
            sharedHabitsStagedJoinPartyIDs.insert(partyID)
        }
    }

    /// A command acknowledgement may arrive before its canonical detail. The
    /// resolved intent survives that gap and a relaunch, but only resumes for
    /// its exact party after the current membership detail is available.
    func resumeResolvedSharedHabitsJoinAgreementIfPossible(partyID: UUID) {
        guard supportsSharedHabits,
              !sharedHabitsStagedJoinPartyIDs.contains(partyID),
              let outbox
        else { return }
        let generation = localSocialGeneration
        Task { [weak self] in
            guard let self,
                  let intent = await outbox.sharedHabitsJoinAgreementIntent(epoch: generation),
                  self.isCurrentLocalSocialGeneration(generation),
                  NightFlockSharedHabitsJoinAgreementIntentPolicy.permitsResume(
                    intent,
                    partyID: partyID,
                    isCurrentMember: self.slumberParties.contains(where: { $0.partyID == partyID }),
                    hasCurrentMemberDetail: self.v4ObservedPartyDetail(for: partyID)?.myMemberID != nil,
                    agreementIsMissing: self.sharedHabitsStates[partyID]?.agreement == nil
                  )
            else { return }
            self.sharedHabitsStagedJoinPartyIDs.insert(partyID)
            self.acceptSharedHabitsAgreement(partyID: partyID, timeZoneIdentifier: intent.timeZoneIdentifier)
        }
    }

    /// Queues a derived local value only after this party has supplied an
    /// explicit receipt. A missing receipt causes a focused state refresh; it
    /// never turns old local history into a pre-join upload.
    func publishSharedHabitProjection(
        _ projection: NightFlockSharedHabitProjection,
        startedAt: Date? = nil,
        sleepEligibleAfter: Date? = nil
    ) {
        guard supportsSharedHabits,
              mayPublishWhileSharedHabitsFenceIsOpen(),
              let outbox
        else { return }
        let generation = localSocialGeneration
        let parties = slumberParties.filter { !isSharedHabitsPartySuppressed($0.partyID) }
        Task { [weak self] in
            guard let self else { return }
            for party in parties {
                guard self.isCurrentLocalSocialGeneration(generation),
                      self.supportsSharedHabits,
                      self.mayPublishWhileSharedHabitsFenceIsOpen()
                else { return }
                if projection.kind == .sleep {
                    guard let receipt = self.sharedHabitsStates[party.partyID]?.agreement,
                          NightFlockSharedHabitSleepReconciliationPolicy.permitsPartySleepPublication(
                            projectionTimeZoneIdentifier: projection.timeZoneIdentifier,
                            receiptTimeZoneIdentifier: receipt.timeZoneIdentifier
                          )
                    else {
                        // Sleep windows are contributor-local. Until this
                        // exact party receipt is known, a later bounded Health
                        // reconciliation reoffers the correct timezone.
                        self.refreshSharedHabits(partyID: party.partyID)
                        continue
                    }
                }
                if self.sharedHabitsStates[party.partyID] == nil {
                    let stored = await outbox.enqueueSharedHabitsPending(
                        NightFlockSharedHabitsPendingProjection(
                            id: UUID(), partyID: party.partyID, projection: projection,
                            startedAt: startedAt ?? .distantPast,
                            sleepEligibleAfter: sleepEligibleAfter
                        ), epoch: generation
                    )
                    guard stored else {
                        self.warmNotice = "Shared habits could not be queued because the local sharing queue is full. Try again after existing updates travel."
                        continue
                    }
                    self.refreshSharedHabits(partyID: party.partyID)
                    continue
                }
                switch await self.admitSharedHabitProjection(
                    projection,
                    partyID: party.partyID,
                    startedAt: startedAt,
                    sleepEligibleAfter: sleepEligibleAfter,
                    epoch: generation
                ) {
                case .queued:
                    continue
                case .notReady:
                    let stored = await outbox.enqueueSharedHabitsPending(
                        NightFlockSharedHabitsPendingProjection(
                            id: UUID(), partyID: party.partyID, projection: projection,
                            startedAt: startedAt ?? .distantPast,
                            sleepEligibleAfter: sleepEligibleAfter
                        ), epoch: generation
                    )
                    if stored { self.refreshSharedHabits(partyID: party.partyID) }
                case .prohibited:
                    continue
                case .full:
                    self.warmNotice = "Shared habits could not be queued because the local sharing queue is full. Try again after existing updates travel."
                    return
                }
            }
            await self.flushSharedHabitsOutbox()
        }
    }

    func publishSharedNight(_ payload: NightFlockSharedNightOutboxPayload, originRunID: UUID? = nil) {
        guard supportsSharedNightPlans, mayPublishWhileSharedHabitsFenceIsOpen(), let outbox else { return }
        let generation = localSocialGeneration
        let partyID: UUID; let agreementID: UUID; let epochID: UUID; let seed: UUID; let label: String
        switch payload {
        case let .plan(plan): partyID = plan.partyID; agreementID = plan.agreementID; epochID = plan.memberEpochID; seed = plan.planID; label = "shared-night-plan-\(plan.revision)"
        case let .cancellation(cancellation): partyID = cancellation.partyID; agreementID = cancellation.agreementID; epochID = cancellation.memberEpochID; seed = SharedNightPlanRules.stablePlanID(partyID: partyID, memberEpochID: epochID, nightEndingDate: cancellation.nightEndingDate); label = "shared-night-cancellation-\(cancellation.revision)"
        case let .receipt(receipt): partyID = receipt.partyID; agreementID = receipt.agreementID; epochID = receipt.memberEpochID; seed = receipt.sourceID ?? receipt.receiptID; label = "shared-night-receipt-\(receipt.revision)"
        }
        guard let receipt = sharedHabitsStates[partyID]?.agreement,
              receipt.agreementVersion >= 2, receipt.agreementID == agreementID, receipt.memberEpochID == epochID,
              !isSharedHabitsPartySuppressed(partyID)
        else { return }
        Task { [weak self] in
            guard let self, await outbox.enqueueSharedNight(.init(id: UUID(), payload: payload, partyID: partyID, agreementID: agreementID, memberEpochID: epochID, idempotencyKey: NightFlockV4Idempotency.command(label, seed: seed), attemptCount: 0, createdAt: Date(), originRunID: originRunID), epoch: generation), self.isCurrentLocalSocialGeneration(generation) else { return }
            await self.flushSharedNightOutbox()
        }
    }

    /// Queues a durable, revision-fenced cancellation. Privacy cancellations
    /// additionally persist a local fence; schedule reconciliation uses the
    /// same transport tombstone without changing the user's privacy choice.
    func cancelSharedNightPlan(
        _ cancellation: SharedNightPlanCancellation,
        persistPrivacyFence: Bool = true
    ) {
        guard supportsSharedNightPlans,
              mayPublishWhileSharedHabitsFenceIsOpen(),
              let outbox,
              let agreement = sharedHabitsStates[cancellation.partyID]?.agreement,
              agreement.agreementVersion >= 2,
              agreement.agreementID == cancellation.agreementID,
              agreement.memberEpochID == cancellation.memberEpochID,
              !isSharedHabitsPartySuppressed(cancellation.partyID)
        else { return }
        let generation = localSocialGeneration
        let planID = SharedNightPlanRules.stablePlanID(
            partyID: cancellation.partyID,
            memberEpochID: cancellation.memberEpochID,
            nightEndingDate: cancellation.nightEndingDate
        )
        let record = NightFlockSharedNightOutboxRecord(
            id: UUID(),
            payload: .cancellation(cancellation),
            partyID: cancellation.partyID,
            agreementID: cancellation.agreementID,
            memberEpochID: cancellation.memberEpochID,
            idempotencyKey: NightFlockV4Idempotency.command(
                "shared-night-cancellation-\(cancellation.revision)",
                seed: planID
            ),
            attemptCount: 0,
            createdAt: Date()
        )
        Task { [weak self] in
            guard let self else { return }
            if persistPrivacyFence {
                // The fence is intentionally persisted before a cancellation
                // can affect UI or replay. A later crash therefore fails
                // closed even if transport never starts.
                await outbox.recordSharedNightPlanPrivacyFence(cancellation, epoch: generation)
            }
            guard self.isCurrentLocalSocialGeneration(generation) else { return }
            guard await outbox.enqueueSharedNightCancellationAndClearBinding(record, epoch: generation) else { return }
            guard self.isCurrentLocalSocialGeneration(generation) else { return }
            await self.flushSharedNightOutbox()
        }
    }

    func cancelSharedNightPlansForPrivatePrimaryRun(_ run: FocusRun) {
        guard supportsSharedNightPlans,
              mayPublishWhileSharedHabitsFenceIsOpen(),
              let plan = run.nightWatchPlan
        else { return }
        cancelSharedNightPlansForPrivatePrimaryPlan(plan)
    }

    /// A persisted primary-run decision can outlive the in-memory `FocusRun`
    /// after a termination. Its plan is enough to reassert the one-night
    /// privacy fence once party authority is available again.
    func cancelSharedNightPlansForPrivatePrimaryPlan(_ plan: NightWatchPlan) {
        guard supportsSharedNightPlans,
              mayPublishWhileSharedHabitsFenceIsOpen(),
              let outbox
        else { return }
        let generation = localSocialGeneration
        for party in slumberParties {
            guard let agreement = sharedHabitsState(for: party.partyID)?.agreement,
                  agreement.agreementVersion >= 2,
                  let zone = TimeZone(identifier: agreement.timeZoneIdentifier)
            else { continue }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            guard let anchor = NightFlockLocalDate(
                date: plan.wakeTime,
                timeZoneIdentifier: agreement.timeZoneIdentifier,
                calendar: calendar
            ) else { continue }
            let observed = sharedHabitsState(for: party.partyID)?.sharedNightPlans
                .filter { $0.memberEpochID == agreement.memberEpochID && $0.nightEndingDate == anchor }
                .map(\.revision)
                .max() ?? 0
            Task { [weak self] in
                guard let self,
                      let revision = await outbox.nextSharedNightPlanRevision(
                        partyID: party.partyID,
                        memberEpochID: agreement.memberEpochID,
                        nightEndingDate: anchor,
                        observedRevision: observed,
                        epoch: generation
                      ),
                      self.isCurrentLocalSocialGeneration(generation)
                else { return }
                self.cancelSharedNightPlan(.init(
                    partyID: party.partyID,
                    memberEpochID: agreement.memberEpochID,
                    agreementID: agreement.agreementID,
                    nightEndingDate: anchor,
                    timeZoneIdentifier: agreement.timeZoneIdentifier,
                    revision: revision
                ))
            }
        }
    }

    func flushSharedNightOutbox() async {
        guard supportsSharedNightPlans, accountState == .linked, permitsNightFlockNetwork, mayPublishWhileSharedHabitsFenceIsOpen(), let outbox, let service else { return }
        let generation = localSocialGeneration; let transportEpoch = transportRecoveryEpoch
        let privacyFences = await outbox.sharedNightPlanPrivacyFences()
        for queued in await outbox.sharedNightRecords() {
            let isCancelledNight: Bool
            switch queued.payload {
            case let .plan(plan):
                isCancelledNight = privacyFences.contains { $0.partyID == plan.partyID && $0.memberEpochID == plan.memberEpochID && $0.nightEndingDate == plan.nightEndingDate }
            case .cancellation:
                isCancelledNight = false
            case let .receipt(receipt):
                isCancelledNight = privacyFences.contains { $0.partyID == receipt.partyID && $0.memberEpochID == receipt.memberEpochID && $0.nightEndingDate == receipt.nightEndingDate }
            }
            if isCancelledNight {
                await outbox.removeSharedNight(queued, epoch: generation)
                continue
            }
            if case .receipt = queued.payload,
               !maySharePrimaryRun(runID: queued.originRunID ?? UUID(), startedAt: queued.createdAt) {
                await outbox.removeSharedNight(queued, epoch: generation)
                continue
            }
            guard await outbox.permitsSharedHabitsPublication(), isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                  let agreement = sharedHabitsStates[queued.partyID]?.agreement, agreement.agreementVersion >= 2,
                  agreement.agreementID == queued.agreementID, agreement.memberEpochID == queued.memberEpochID,
                  !isSharedHabitsPartySuppressed(queued.partyID) else { continue }
            do {
                let command: NightFlockSharedHabitsCommand
                switch queued.payload {
                case let .plan(plan): command = .publishNightPlan(plan, idempotencyKey: queued.idempotencyKey)
                case let .cancellation(cancellation): command = .cancelNightPlan(cancellation, idempotencyKey: queued.idempotencyKey)
                case let .receipt(receipt): command = .publishNightReceipt(receipt, idempotencyKey: queued.idempotencyKey)
                }
                let response = try await service.sendSharedHabits(command)
                if case let .plan(plan) = queued.payload {
                    await outbox.acknowledgeSharedNightPlan(
                        queued,
                        plan: plan,
                        acknowledgement: SharedNightPlanBindingPolicy.acknowledgement(
                            accepted: response.accepted,
                            staleRevision: response.staleRevision
                        ),
                        epoch: generation
                    )
                } else {
                    await outbox.removeSharedNight(queued, epoch: generation)
                }
                refreshSharedHabits(partyID: queued.partyID)
            } catch {
                if isPermanentSharedNightPublicationFailure(error) {
                    await outbox.removeSharedNight(queued, epoch: generation)
                    refreshSharedHabits(partyID: queued.partyID)
                    continue
                }
                await outbox.markSharedNightAttempt(queued, epoch: generation)
                return
            }
        }
    }

    private func isPermanentSharedNightPublicationFailure(_ error: Error) -> Bool {
        switch Self.remoteError(from: error)?.code {
        case .sharedHistoryDeleted, .publicationBeforeAgreement, .agreementTimezoneMismatch,
             .publicationOutsidePlanWindow, .publicationOutsideReceiptWindow,
             .invalidSharedNightPayload, .invalidPlanChronology, .invalidReceiptChronology,
             .invalidPlanBinding, .invalidReceiptSource, .receiptPlanMismatch, .sharedNightPlanFrozen,
             .sharedNightPlanCancelled, .receiptActualStartRequired:
            return true
        default:
            break
        }
        let description = String(describing: error).lowercased()
        let codes = [
            "publication_outside_plan_window", "publication_outside_receipt_window",
            "publication_before_agreement", "agreement_timezone_mismatch",
            "invalid_shared_night_payload", "invalid_plan_chronology",
            "invalid_receipt_chronology", "invalid_plan_binding", "invalid_receipt_source",
            "receipt_plan_mismatch", "shared_night_plan_frozen", "shared_night_plan_cancelled", "receipt_actual_start_required", "shared_history_deleted", "stale_revision"
        ]
        return codes.contains { description.contains($0) }
    }

    private enum SharedHabitProjectionAdmission {
        case queued
        case notReady
        case prohibited
        case full
    }

    /// Admission is party-scoped: callers retain their durable pending source
    /// until this exact receipt and membership epoch have accepted it.
    private func admitSharedHabitProjection(
        _ projection: NightFlockSharedHabitProjection,
        partyID: UUID,
        startedAt: Date?,
        sleepEligibleAfter: Date?,
        epoch: UInt64
    ) async -> SharedHabitProjectionAdmission {
        guard isCurrentLocalSocialGeneration(epoch),
              supportsSharedHabits,
              !isSharedHabitsPartySuppressed(partyID),
              let outbox,
              let state = sharedHabitsStates[partyID],
              let receipt = state.agreement,
              let memberID = v4ObservedPartyDetail(for: partyID)?.myMemberID,
              let localDate = projection.localDate
        else { return .notReady }
        guard let startedAt, startedAt >= receipt.acceptedAt else { return .prohibited }
        if projection.kind == .sleep {
            guard NightFlockSharedHabitSleepReconciliationPolicy.permitsPartySleepPublication(
                projectionTimeZoneIdentifier: projection.timeZoneIdentifier,
                receiptTimeZoneIdentifier: receipt.timeZoneIdentifier
            ) else { return .prohibited }
            guard let sleepEligibleAfter, sleepEligibleAfter >= receipt.acceptedAt else { return .prohibited }
            if let firstNight = receipt.firstEligibleSleepNight, localDate < firstNight {
                return .prohibited
            }
            if await outbox.hasSharedHabitsSleepDelivery(
                sourceID: projection.sourceID,
                revision: projection.revision,
                partyID: partyID,
                agreementID: receipt.agreementID,
                memberEpochID: receipt.memberEpochID,
                epoch: epoch
            ) {
                return .queued
            }
        }
        let record = NightFlockSharedHabitRecord(
            recordID: UUID(), partyID: partyID, memberID: memberID,
            sourceID: projection.sourceID, revision: projection.revision,
            kind: projection.kind, localDate: localDate,
            timeZoneIdentifier: projection.timeZoneIdentifier,
            minutes: projection.minutes, outcome: projection.outcome,
            protectionMinutes: projection.protectionMinutes,
            evidence: projection.evidence,
            profileSnapshot: NightFlockSharedHabitProfileSnapshot(
                displayName: PersistenceService.shared.userProfile.displayName,
                avatarID: PersistenceService.shared.userProfile.presentation.avatarID
            ), isFormerMember: false, migratedAt: nil
        )
        let queued = NightFlockSharedHabitsOutboxRecord(
            record: record, agreementID: receipt.agreementID,
            memberEpochID: receipt.memberEpochID,
            idempotencyKey: NightFlockV4Idempotency.command(
                "shared-habit-\(partyID.uuidString)-\(receipt.agreementID.uuidString)-\(receipt.memberEpochID.uuidString)-\(projection.kind.rawValue)-\(projection.revision)",
                seed: projection.sourceID
            )
        )
        return await outbox.enqueueSharedHabits(queued, epoch: epoch) ? .queued : .full
    }

    private func migrateSharedHabitsIfNeeded(partyID: UUID, agreementID: UUID) {
        guard supportsSharedHabits, accountState == .linked, permitsNightFlockNetwork,
              let outbox, let service else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        Task { [weak self] in
            guard let self,
                  !(await outbox.hasMigratedSharedHabits(agreementID: agreementID)),
                  self.isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                  self.accountState == .linked,
                  self.permitsNightFlockNetwork,
                  self.supportsSharedHabits,
                  self.sharedHabitsStates[partyID]?.agreement?.agreementID == agreementID
            else { return }
            do {
                let response = try await service.sendSharedHabits(.migrate(
                    partyID: partyID, agreementID: agreementID,
                    idempotencyKey: NightFlockV4Idempotency.command("migrate-shared-habits-\(partyID.uuidString)-\(agreementID.uuidString)", seed: agreementID)
                ))
                guard response.accepted,
                      self.isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      self.accountState == .linked,
                      self.permitsNightFlockNetwork,
                      self.supportsSharedHabits
                else { return }
                await outbox.markSharedHabitsMigrated(agreementID: agreementID, epoch: generation)
                self.refreshSharedHabits(partyID: partyID)
            } catch {
                guard self.isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      self.accountState == .linked,
                      self.permitsNightFlockNetwork,
                      self.supportsSharedHabits
                else { return }
                self.presentNightFlockError(
                    error,
                    lane: .directCommand(schema: NightFlockV4Rules.schemaVersion)
                )
                guard self.pendingAuthenticationRecovery == .none else { return }
                self.warmNotice = "Earlier agreed group summaries will refresh when this Slumber Party can connect."
            }
        }
    }

    private func reconcilePendingSharedHabits(for partyID: UUID, epoch: UInt64) async {
        guard let outbox,
              isCurrentLocalSocialGeneration(epoch),
              !isSharedHabitsPartySuppressed(partyID),
              let receipt = sharedHabitsStates[partyID]?.agreement
        else { return }
        // Keep the staged intent and retry key until the canonical receipt is readable.
        // A successful POST alone must not send a new joiner back to affirmation.
        sharedHabitsStagedJoinPartyIDs.remove(partyID)
        if let memberID = v4ObservedPartyDetail(for: partyID)?.myMemberID {
            await outbox.clearSharedHabitsAgreementAttempt(partyID: partyID, memberID: memberID, epoch: epoch)
        }
        await outbox.clearSharedHabitsJoinAgreementIntent(partyID: partyID, epoch: epoch)
        for pending in await outbox.sharedHabitsPendingProjections().filter({ $0.partyID == partyID }) {
            if pending.projection.kind == .sleep,
               !NightFlockSharedHabitSleepReconciliationPolicy.permitsPartySleepPublication(
                projectionTimeZoneIdentifier: pending.projection.timeZoneIdentifier,
                receiptTimeZoneIdentifier: receipt.timeZoneIdentifier
               ) {
                await outbox.removeSharedHabitsPending(pending, epoch: epoch)
                continue
            }
            guard pending.startedAt >= receipt.acceptedAt,
                  pending.projection.kind != .sleep || (pending.sleepEligibleAfter ?? .distantPast) >= receipt.acceptedAt
            else {
                await outbox.removeSharedHabitsPending(pending, epoch: epoch)
                continue
            }
            let admission = await admitSharedHabitProjection(
                pending.projection,
                partyID: partyID,
                startedAt: pending.startedAt,
                sleepEligibleAfter: pending.sleepEligibleAfter,
                epoch: epoch
            )
            switch admission {
            case .queued, .prohibited:
                // The source stays durable until the exact party authority
                // accepts it into the outbox or its consent floor rejects it.
                await outbox.removeSharedHabitsPending(pending, epoch: epoch)
            case .notReady:
                continue
            case .full:
                warmNotice = "Shared habits are waiting for room in the local sharing queue."
            }
        }
    }

    func publishSharedSleep(
        minutes: Int,
        window: NightFlockSharedSleepWindow,
        earliestContributingIntervalStart: Date?
    ) {
        guard supportsSharedHabits, let outbox else { return }
        let generation = localSocialGeneration
        Task { [weak self] in
            guard let self,
                  let ledger = await outbox.sharedHabitsSleepPublication(
                    nightEndingDate: window.nightEndingDate,
                    timeZoneIdentifier: window.timeZoneIdentifier,
                    minutes: minutes,
                    epoch: generation
                  ),
                  self.isCurrentLocalSocialGeneration(generation)
            else { return }
            self.publishSharedHabitProjection(
                NightFlockSharedHabitProjection(
                    sourceID: ledger.sourceID, revision: ledger.revision, kind: .sleep,
                    localDate: window.nightEndingDate, timeZoneIdentifier: window.timeZoneIdentifier,
                    minutes: ledger.minutes
                ),
                startedAt: window.interval.start,
                sleepEligibleAfter: earliestContributingIntervalStart
            )
        }
    }

    func flushSharedHabitsOutbox() async {
        guard supportsSharedHabits, accountState == .linked,
              permitsNightFlockNetwork, mayPublishWhileSharedHabitsFenceIsOpen(),
              let outbox, let service
        else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        guard await outbox.permitsSharedHabitsPublication() else { return }
        for queued in await outbox.sharedHabitsRecords() {
            if queued.record.kind == .windDown,
               let sourceID = queued.record.sourceID,
               !maySharePrimaryRun(runID: sourceID, startedAt: queued.createdAt) {
                await outbox.removeSharedHabits(queued, epoch: generation)
                continue
            }
            guard await outbox.permitsSharedHabitsPublication(),
                  isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                  accountState == .linked,
                  permitsNightFlockNetwork,
                  supportsSharedHabits,
                  !isSharedHabitsPartySuppressed(queued.record.partyID),
                  let receipt = sharedHabitsStates[queued.record.partyID]?.agreement,
                  receipt.agreementID == queued.agreementID,
                  receipt.memberEpochID == queued.memberEpochID
            else { continue }
            do {
                let response = try await service.sendSharedHabits(.publish(
                    record: queued.record, agreementID: queued.agreementID,
                    memberEpochID: queued.memberEpochID, idempotencyKey: queued.idempotencyKey
                ))
                guard response.accepted,
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      accountState == .linked,
                      permitsNightFlockNetwork,
                      supportsSharedHabits,
                      !isSharedHabitsPartySuppressed(queued.record.partyID)
                else { return }
                await outbox.removeSharedHabits(queued, epoch: generation)
                if queued.record.kind == .sleep, let sourceID = queued.record.sourceID {
                    await outbox.markSharedHabitsSleepDelivery(
                        sourceID: sourceID,
                        revision: queued.record.revision,
                        partyID: queued.record.partyID,
                        agreementID: queued.agreementID,
                        memberEpochID: queued.memberEpochID,
                        epoch: generation
                    )
                }
                refreshSharedHabits(partyID: queued.record.partyID)
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      accountState == .linked,
                      permitsNightFlockNetwork,
                      supportsSharedHabits
                else { return }
                switch NightFlockSharedHabitsOutboxFailurePolicy.disposition(
                    for: Self.remoteError(from: error)?.code,
                    detail: String(describing: error)
                ) {
                case .dropSourceAndReconcile:
                    await outbox.dropSharedHabitsSource(
                        queued.record.sourceID,
                        recordID: queued.record.recordID,
                        partyID: queued.record.partyID,
                        epoch: generation
                    )
                    refreshSharedHabits(partyID: queued.record.partyID)
                    continue
                case .dropRecordAndReconcile:
                    await outbox.removeSharedHabits(queued, epoch: generation)
                    refreshSharedHabits(partyID: queued.record.partyID)
                    continue
                case .retry:
                    break
                }
                await outbox.markSharedHabitsAttempt(queued, epoch: generation)
                handleOutboxFailure(error, lane: .outbox(schema: NightFlockV4Rules.schemaVersion))
                return
            }
        }
    }
}
