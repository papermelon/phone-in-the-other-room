import Foundation

@MainActor
extension FocusRunViewModel {
    func publishNextSharedNightPlansAfterExplicitSave() {
        reconcileSharedNightPlans()
    }

    func reconcileSharedNightPlans() {
        guard nightFlockViewModel.supportsSharedNightPlans else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.reconcileSharedNightPlansAfterAuthorityCheck()
        }
    }

    /// Privacy decisions are persisted before a primary run is admitted, but
    /// a process can still end before its remote plan cancellation drains.
    /// Rebuild the cancellation intent from local run history whenever either
    /// the decisions or the party agreement authority becomes available.
    func reconcileRestoredPrivatePrimaryPlanFences() {
        guard nightFlockViewModel.supportsSharedNightPlans else { return }
        var privatePlans: [UUID: NightWatchPlan] = [:]
        if let activeRun,
           activeRun.nightWatchPlan?.role == .primarySleepBookend,
           nightFlockViewModel.primaryRunSharingDecisions[activeRun.id]?.allowsSharing == false,
           let plan = activeRun.nightWatchPlan {
            privatePlans[activeRun.id] = plan
        }
        for record in NightFlockPrimaryRunPrivacyRecoveryRules.recordsNeedingPlanFence(
            from: persistence.nightWatchHistory.records,
            decisions: nightFlockViewModel.primaryRunSharingDecisions
        ) {
            privatePlans[record.id] = record.plan
        }
        for plan in privatePlans.values {
            nightFlockViewModel.cancelSharedNightPlansForPrivatePrimaryPlan(plan)
        }
    }

    private func reconcileSharedNightPlansAfterAuthorityCheck() async {
        guard let outbox = nightFlockViewModel.outboxForSharedHabitsReconciliation else { return }
        let now = nowProvider()
        let generation = nightFlockViewModel.localSocialGeneration
        let queued = await outbox.sharedNightRecords()
        let privacyFences = await outbox.sharedNightPlanPrivacyFences()
        for party in nightFlockViewModel.slumberParties {
            guard let agreement = nightFlockViewModel.sharedHabitsState(for: party.partyID)?.agreement,
                  agreement.agreementVersion >= 2,
                  let memberID = nightFlockViewModel.v4ObservedPartyDetail(for: party.partyID)?.myMemberID
            else { continue }
            guard let agreementTimeZone = TimeZone(identifier: agreement.timeZoneIdentifier) else { continue }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = agreementTimeZone
            guard let today = NightFlockLocalDate(date: now, timeZoneIdentifier: agreement.timeZoneIdentifier, calendar: calendar) else { continue }
            guard let firstEligible = calendar.date(byAdding: .day, value: 1, to: today.date(in: agreement.timeZoneIdentifier) ?? now).flatMap({ NightFlockLocalDate(date: $0, timeZoneIdentifier: agreement.timeZoneIdentifier, calendar: calendar) }),
                  let lastEligible = calendar.date(byAdding: .day, value: 7, to: today.date(in: agreement.timeZoneIdentifier) ?? now).flatMap({ NightFlockLocalDate(date: $0, timeZoneIdentifier: agreement.timeZoneIdentifier, calendar: calendar) })
            else { continue }
            let primaryOccurrences = WindDownScheduleEngine.futureOccurrences(
                in: windDownSchedule,
                after: now,
                calendar: calendar,
                primaryExtensionMinutes: nightWatchPreferences.morningQuietMinutes,
                limit: 64
            ).filter { $0.occurrence.role == .primarySleepBookend }
            var desiredNightEndingDates = Set<NightFlockLocalDate>()
            for occurrence in primaryOccurrences {
                let plan = WindDownScheduleEngine.plan(
                    for: occurrence,
                    preferences: nightWatchPreferences,
                    startedAt: occurrence.occurrence.interval.start,
                    calendar: calendar
                )
                guard let anchor = plan.localDateAnchor else { continue }
                guard anchor.nightEndingDate >= firstEligible && anchor.nightEndingDate <= lastEligible else { continue }
                let locallyCancelled = privacyFences.contains {
                    $0.partyID == party.partyID
                        && $0.memberEpochID == agreement.memberEpochID
                        && $0.nightEndingDate == anchor.nightEndingDate
                } || queued.contains { record in
                    guard record.partyID == party.partyID,
                          record.memberEpochID == agreement.memberEpochID,
                          case let .cancellation(cancellation) = record.payload
                    else { return false }
                    return cancellation.nightEndingDate == anchor.nightEndingDate
                }
                guard !locallyCancelled else { continue }
                let candidate = SharedNightPlan(
                    planID: SharedNightPlanRules.stablePlanID(partyID: party.partyID, memberEpochID: agreement.memberEpochID, nightEndingDate: anchor.nightEndingDate),
                    partyID: party.partyID, memberID: memberID, memberEpochID: agreement.memberEpochID, agreementID: agreement.agreementID,
                    revision: 0, nightEndingDate: anchor.nightEndingDate, timeZoneIdentifier: agreement.timeZoneIdentifier,
                    plannedWindDownStart: plan.intendedBedtime.addingTimeInterval(TimeInterval(-plan.windDownMinutes * 60)), intendedBedtime: plan.intendedBedtime,
                    intendedWakeTime: plan.wakeTime, morningQuietEnd: plan.protectedUntil, beforeBedMinutes: plan.windDownMinutes,
                    afterWakingMinutes: plan.morningQuietMinutes, eveningSuggestionIDs: plan.eveningRoutine.compactMap { $0.activity?.rawValue },
                    morningSuggestionIDs: plan.morningRoutine.compactMap { $0.activity?.rawValue }
                )
                guard SharedNightPlanRules.isFuturePublicationCandidate(candidate, now: now) else { continue }
                desiredNightEndingDates.insert(anchor.nightEndingDate)
                let published = nightFlockViewModel.sharedHabitsState(for: party.partyID)?.sharedNightPlans.filter {
                    $0.memberEpochID == agreement.memberEpochID && $0.nightEndingDate == anchor.nightEndingDate
                } ?? []
                let pending = queued.compactMap { record -> SharedNightPlan? in
                    guard record.partyID == party.partyID, record.memberEpochID == agreement.memberEpochID,
                          case let .plan(plan) = record.payload, plan.nightEndingDate == anchor.nightEndingDate
                    else { return nil }
                    return plan
                }
                let latest = (published + pending).max { $0.revision < $1.revision }
                guard latest.map({ !SharedNightPlanRules.hasSamePublishedContent($0, candidate) }) != false else { continue }
                let observedRevision = latest?.revision ?? 0
                guard let revision = await outbox.nextSharedNightPlanRevision(
                    partyID: party.partyID, memberEpochID: agreement.memberEpochID,
                    nightEndingDate: anchor.nightEndingDate, observedRevision: observedRevision, epoch: generation
                ), nightFlockViewModel.localSocialGeneration == generation
                else { return }
                var versioned = candidate
                versioned.revision = revision
                versioned.planID = SharedNightPlanRules.versionedPlanID(
                    partyID: party.partyID, memberEpochID: agreement.memberEpochID,
                    nightEndingDate: anchor.nightEndingDate, revision: revision
                )
                nightFlockViewModel.publishSharedNight(.plan(versioned))
            }

            // A routine edit, disabled occurrence, or one-time override can
            // move an already-published future night. Retract only this
            // contributor's still-unfrozen plans in the same bounded window;
            // historical versions remain for receipt correlation.
            let remotePlans = nightFlockViewModel.sharedHabitsState(for: party.partyID)?.sharedNightPlans.filter {
                $0.memberID == memberID
                    && $0.memberEpochID == agreement.memberEpochID
                    && $0.nightEndingDate >= firstEligible
                    && $0.nightEndingDate <= lastEligible
            } ?? []
            let pendingPlans = queued.compactMap { record -> SharedNightPlan? in
                guard record.partyID == party.partyID,
                      record.memberEpochID == agreement.memberEpochID,
                      case let .plan(plan) = record.payload,
                      plan.memberID == memberID,
                      plan.nightEndingDate >= firstEligible,
                      plan.nightEndingDate <= lastEligible
                else { return nil }
                return plan
            }
            let queuedCancellations = queued.compactMap { record -> SharedNightPlanCancellation? in
                guard record.partyID == party.partyID,
                      record.memberEpochID == agreement.memberEpochID,
                      case let .cancellation(cancellation) = record.payload
                else { return nil }
                return cancellation
            }
            for stale in SharedNightPlanRules.staleFuturePlans(
                remotePlans + pendingPlans,
                desiredNightEndingDates: desiredNightEndingDates,
                now: now
            ) where !privacyFences.contains(where: {
                $0.partyID == party.partyID
                    && $0.memberEpochID == agreement.memberEpochID
                    && $0.nightEndingDate == stale.nightEndingDate
            }) && !queuedCancellations.contains(where: { $0.nightEndingDate == stale.nightEndingDate }) {
                let observedRevision = (remotePlans + pendingPlans)
                    .filter { $0.nightEndingDate == stale.nightEndingDate }
                    .map(\.revision)
                    .max() ?? stale.revision
                guard let revision = await outbox.nextSharedNightPlanRevision(
                    partyID: party.partyID,
                    memberEpochID: agreement.memberEpochID,
                    nightEndingDate: stale.nightEndingDate,
                    observedRevision: observedRevision,
                    epoch: generation
                ), nightFlockViewModel.localSocialGeneration == generation
                else { return }
                nightFlockViewModel.cancelSharedNightPlan(.init(
                    partyID: party.partyID,
                    memberEpochID: agreement.memberEpochID,
                    agreementID: agreement.agreementID,
                    nightEndingDate: stale.nightEndingDate,
                    timeZoneIdentifier: agreement.timeZoneIdentifier,
                    revision: revision,
                    authority: .schedule
                ), persistPrivacyFence: false)
            }
        }
    }
    /// A borrowed item is only a bundled activity identifier. It is copied
    /// into this person's private draft and never records anything about the
    /// member who originally shared the plan.
    @discardableResult
    func borrowSharedRoutineIdea(
        _ suggestionID: String,
        phase: WindDownRoutinePhase
    ) -> WindDownGuidanceRoutineAddResult {
        guard nightWatchPreferences.isConfigured,
              let activity = PhoneFreeActivity(rawValue: suggestionID)
        else { return .unavailable }
        var preferences = nightWatchPreferences
        var steps = phase == .evening ? preferences.eveningRoutine : preferences.morningRoutine
        guard !steps.contains(where: { $0.activity == activity }) else { return .alreadyAdded }
        let maximum = phase == .evening ? WindDownRoutineStep.maximumEveningCount : WindDownRoutineStep.maximumMorningCount
        guard steps.count < maximum else { return .needsReplacement(phase: phase, stepIDs: steps.map(\.id)) }
        steps.append(.suggested(activity, phase: phase))
        if phase == .evening { preferences.eveningRoutine = steps } else { preferences.morningRoutine = steps }
        nightWatchPreferences = preferences
        saveNightWatchPreferences()
        return .added
    }

    func invalidateSharedHabitSleepReconciliation() {
        sharedHabitSleepReconcileGeneration &+= 1
        sharedHabitSleepReconcileTask?.cancel()
        sharedHabitSleepReconcileTask = nil
        sharedHabitSleepReconcileTaskID = nil
    }

    private var sharedHabitSleepReconciliationAuthority: NightFlockSharedHabitSleepReconciliationAuthority {
        NightFlockSharedHabitSleepReconciliationAuthority(
            socialGeneration: nightFlockViewModel.localSocialGeneration,
            fenceGeneration: nightFlockViewModel.sharedHabitsFenceGeneration,
            reconcileGeneration: sharedHabitSleepReconcileGeneration,
            accountIsLinked: nightFlockViewModel.accountState == .linked,
            supportsSharedHabits: nightFlockViewModel.supportsSharedHabits
        )
    }

    /// Shared-habits publication is independent of the existing round/activity
    /// stream. Derived values are offered only after the local terminal record
    /// exists and a party receipt has been loaded.
    func publishSharedHabitsOutcome(for run: FocusRun) {
        let isPrimaryWindDown = run.nightWatchPlan?.role != .additionalQuiet
        guard !isPrimaryWindDown || nightFlockViewModel.maySharePrimaryRun(run) else { return }
        let history = persistence.nightWatchHistory.records
        let projections: [NightFlockSharedHabitProjection]
        if run.nightWatchPlan?.role == .additionalQuiet {
            projections = NightFlockSharedHabitProjectionRules.phoneAwayProjections(from: history)
        } else {
            projections = NightFlockSharedHabitProjectionRules.windDownProjections(from: history)
        }
        projections.filter { $0.sourceID == run.id }.forEach {
            nightFlockViewModel.publishSharedHabitProjection($0, startedAt: run.startedAt)
        }
        guard run.nightWatchPlan?.role != .additionalQuiet,
              let terminalRecord = history.first(where: { $0.id == run.id }),
              let anchor = terminalRecord.plan.localDateAnchor
        else { return }
        for party in nightFlockViewModel.slumberParties {
            guard let agreement = nightFlockViewModel.sharedHabitsState(for: party.partyID)?.agreement,
                  agreement.agreementVersion >= 2,
                  let memberID = nightFlockViewModel.v4ObservedPartyDetail(for: party.partyID)?.myMemberID,
                  anchor.timeZoneIdentifier == agreement.timeZoneIdentifier,
                  let record = SharedNightReceiptRules.winner(
                    from: history,
                    nightEndingDate: anchor.nightEndingDate,
                    timeZoneIdentifier: anchor.timeZoneIdentifier
                  ),
                  SharedNightReceiptPublicationRules.permits(
                    actualStart: record.startedAt,
                    acceptedAt: agreement.acceptedAt
                  )
            else { continue }
            let serverPlan = nightFlockViewModel.sharedHabitsState(for: party.partyID)?.sharedNightPlans
                .filter { $0.memberEpochID == agreement.memberEpochID && $0.nightEndingDate == anchor.nightEndingDate }
                .max { $0.revision < $1.revision }
            let sourceID = SharedNightPlanRules.stableReceiptSourceID(
                partyID: party.partyID,
                memberEpochID: agreement.memberEpochID,
                nightEndingDate: anchor.nightEndingDate
            )
            let existingReceipts = nightFlockViewModel.sharedHabitsState(for: party.partyID)?.sharedNightReceipts
                .filter { $0.memberEpochID == agreement.memberEpochID && $0.nightEndingDate == anchor.nightEndingDate }
                ?? []
            let evidence: SharedNightProtectionEvidence
            switch record.shieldProtectionEvidence { case .observed: evidence = .observed; case .partial: evidence = .partial; case .unavailable, .notRequested: evidence = .unavailable }
            let emergencyExitUsed = record.id == run.id
                ? SharedNightEmergencyExitPresentationRules.emergencyExitUsed(
                    completedSuccessfully: run.completedSuccessfully,
                    endedEarlyReason: run.endedEarlyReason
                )
                : nil
            let existingReceipt = existingReceipts
                .filter { $0.sourceID == sourceID }
                .max { $0.revision < $1.revision }
            guard SharedNightReceiptReplayRules.needsPublication(
                record: record,
                evidence: evidence,
                emergencyExitUsed: emergencyExitUsed,
                existing: existingReceipt
            ), let receiptRevision = NightFlockSharedHabitProjectionRules.nextRevision(
                for: record,
                after: existingReceipts.map(\.revision).max()
            ) else { continue }
            func publishReceipt(for plan: SharedNightPlan?) {
                nightFlockViewModel.publishSharedNight(.receipt(.init(
                    receiptID: UUID(), partyID: party.partyID, memberID: memberID, memberEpochID: agreement.memberEpochID, agreementID: agreement.agreementID,
                    planID: plan?.planID, planRevision: plan?.revision, sourceID: sourceID, revision: receiptRevision,
                    nightEndingDate: anchor.nightEndingDate, timeZoneIdentifier: anchor.timeZoneIdentifier, actualStart: record.startedAt, terminalAt: record.endedAt,
                    outcome: record.outcome == .completed ? .completed : .partlyCompleted, windDownMinutes: record.creditedWindDownMinutes,
                    protectionMinutes: record.shieldedWindDownMinutes, protectionEvidence: evidence,
                    emergencyExitUsed: emergencyExitUsed,
                    profileSnapshot: .init(displayName: "", avatarID: nil)
                )), originRunID: record.id)
            }
            if let serverPlan {
                publishReceipt(for: serverPlan)
            } else {
                Task { [weak self] in
                    guard let self else { return }
                    let binding = await self.nightFlockViewModel.sharedNightPlanBinding(partyID: party.partyID, memberEpochID: agreement.memberEpochID, nightEndingDate: anchor.nightEndingDate)
                    publishReceipt(for: binding)
                }
            }
        }

    }
}

@MainActor
extension FocusRunViewModel {
    /// A foreground pass uses one bounded 30-night Health query per
    /// contributor timezone, never one query per party. Each party still
    /// checks its own agreement cutoff before publication.
    func reconcileSharedHabitSleepAfterForeground() {
        guard activeRun == nil,
              sharedHabitSleepReconcileTask == nil,
              nightFlockViewModel.supportsSharedHabits,
              sleepAuthorization == .requested
        else { return }
        let receipts = nightFlockViewModel.sharedHabitsEarliestAcceptanceByTimeZone
        guard !receipts.isEmpty else { return }
        let now = nowProvider()
        let authority = sharedHabitSleepReconciliationAuthority
        let taskID = UUID()
        sharedHabitSleepReconcileTaskID = taskID
        sharedHabitSleepReconcileTask = Task { [weak self] in
            defer {
                if self?.sharedHabitSleepReconcileTaskID == taskID {
                    self?.sharedHabitSleepReconcileTask = nil
                    self?.sharedHabitSleepReconcileTaskID = nil
                }
            }
            guard let self,
                  NightFlockSharedHabitSleepReconciliationPolicy.permitsResult(
                    captured: authority,
                    current: self.sharedHabitSleepReconciliationAuthority,
                    taskIsCancelled: Task.isCancelled,
                    hasActiveRun: self.activeRun != nil
                  )
            else { return }
            for (timeZoneIdentifier, acceptedAt) in receipts {
                var calendar = Calendar(identifier: .gregorian)
                guard let currentDay = NightFlockLocalDate(date: now, timeZoneIdentifier: timeZoneIdentifier, calendar: calendar) else { continue }
                calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
                let windows = (0..<31).compactMap { offset -> NightFlockSharedSleepWindow? in
                    guard let date = currentDay.date(in: timeZoneIdentifier, calendar: calendar),
                          let earlier = calendar.date(byAdding: .day, value: -offset, to: date),
                          let localDay = NightFlockLocalDate(date: earlier, timeZoneIdentifier: timeZoneIdentifier, calendar: calendar)
                    else { return nil }
                    return NightFlockSharedSleepWindow(nightEndingDate: localDay, timeZoneIdentifier: timeZoneIdentifier)
                }
                let results = await self.healthSleepService.sharedHabitSleepQueries(
                    in: windows, acceptedAt: acceptedAt, now: now
                )
                guard NightFlockSharedHabitSleepReconciliationPolicy.permitsResult(
                    captured: authority,
                    current: self.sharedHabitSleepReconciliationAuthority,
                    taskIsCancelled: Task.isCancelled,
                    hasActiveRun: self.activeRun != nil
                ) else { return }
                let primaryNightSharing = self.persistence.nightWatchHistory.records.compactMap { record -> NightFlockPrimaryNightSharingEvidence? in
                    guard record.role == .primarySleepBookend,
                          let anchor = record.plan.localDateAnchor
                    else { return nil }
                    return .init(
                        nightEndingDate: anchor.nightEndingDate,
                        timeZoneIdentifier: anchor.timeZoneIdentifier,
                        mayShare: self.nightFlockViewModel.maySharePrimaryRun(
                            runID: record.id,
                            startedAt: record.startedAt
                        )
                    )
                }
                for result in results {
                    guard case let .data(minutes) = result.state,
                          result.isEligibleForFirstPublication(acceptedAt: acceptedAt),
                          NightFlockSharedHabitSleepReconciliationPolicy.permitsSleepWindow(
                            nightEndingDate: result.window.nightEndingDate,
                            timeZoneIdentifier: result.window.timeZoneIdentifier,
                            primaryRuns: primaryNightSharing
                          ),
                          NightFlockSharedHabitSleepReconciliationPolicy.permitsResult(
                            captured: authority,
                            current: self.sharedHabitSleepReconciliationAuthority,
                            taskIsCancelled: Task.isCancelled,
                            hasActiveRun: self.activeRun != nil
                          )
                    else { continue }
                    self.nightFlockViewModel.publishSharedSleep(
                        minutes: minutes,
                        window: result.window,
                        earliestContributingIntervalStart: result.earliestContributingIntervalStart
                    )
                }
            }
        }
    }
}
