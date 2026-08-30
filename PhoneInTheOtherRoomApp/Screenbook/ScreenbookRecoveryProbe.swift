#if DEBUG
import Foundation

/// Launch-only recovery coverage for the terminal Morning crash boundaries.
/// It deliberately uses the real coordinator with isolated defaults and a
/// shielding spy; it never touches Screen Time, notification, network, or
/// live-activity services.
@MainActor
enum ScreenbookRecoveryProbe {
    private static let argument = "-screenbook-recovery-probe"
    private static let suitePrefix = "com.ngawangchime.countingsheep.screenbook-recovery-probe"

    static var isRequested: Bool {
        value(after: argument) == "YES"
    }

    static func runIfRequested() throws -> Bool? {
        guard isRequested else { return nil }
        let report = run()
        try write(report)
        return report.passed
    }

    private static func run() -> Report {
        let now = Date()
        return Report(
            schemaVersion: 1,
            generatedAt: now,
            cases: [
                ordinaryPreWakeIntentOnly(now: now),
                ordinaryPartialMorningReplay(now: now),
                consumedDecisionDoesNotResurrect(now: now),
                explicitActiveHandoff(now: now),
                explicitDeferredExpiry(now: now),
                unauthorizedNFCExitCreatesNoDecision(now: now),
                manualStartWithoutAutomaticScheduleKeepsNewShield(now: now),
                manualStartReplacesPriorAutomaticScheduleBeforeNewShield(now: now),
                rejectedManualStartPreservesPriorAutomaticSchedule(now: now),
                manualStartPurposeCueReloadsFromIsolatedRegistry(now: now),
                shortPrimaryTerminalProjectionReplaysExactlyOnce(now: now),
                shieldingInstallRollbackUsesProductionRegistry(),
                explicitMorningShieldingFailureRoutesRepair(now: now),
                unrelatedMorningSuccessDoesNotClearRunFailure(now: now),
                coldActiveMorningRestoreRepublishesShieldingFailure(now: now)
            ]
        )
    }

    private static func ordinaryPreWakeIntentOnly(now: Date) -> CaseResult {
        let wake = now.addingTimeInterval(10 * 60)
        let terminalAt = now.addingTimeInterval(-5 * 60)
        let fixture = pendingTerminal(
            wake: wake,
            terminalAt: terminalAt,
            disposition: .finalizeOrdinary,
            occurrenceOutcome: .scheduled
        )
        let restored = restore(fixture)
        let occurrence = restored.persistence.windDownMorningSettlementJournal.morningOccurrences.first
        return evaluate("ordinary-prewake-intent-only", [
            check(restored.coordinator.run?.id == fixture.terminal.id, "terminal run was not restored"),
            check(occurrence?.outcome == .skipped, "ordinary Morning was not skipped before wake"),
            check(restored.shielding.clearAllCount > 0, "parent shielding was not cleared"),
            check(restored.shielding.clearedOccurrenceIDs.contains(fixture.occurrence.id), "ordinary Morning registry was not cleared"),
            check(restored.persistence.windDownMorningSettlementJournal.pendingAuthorizedTerminalMorningDecisions.isEmpty, "decision remained pending"),
            check(!restored.coordinator.rewards.isEmpty, "terminal reward projection was not replayed")
        ])
    }

    private static func ordinaryPartialMorningReplay(now: Date) -> CaseResult {
        let wake = now.addingTimeInterval(-30 * 60)
        let terminalAt = wake.addingTimeInterval(10 * 60)
        let fixture = pendingTerminal(
            wake: wake,
            terminalAt: terminalAt,
            disposition: .finalizeOrdinary,
            occurrenceOutcome: .scheduled,
            storesTerminalRun: true
        )
        let restored = restore(fixture)
        let first = restored.persistence.windDownMorningSettlementJournal.morningOccurrences.first
        let firstMinutes = first?.eligibleElapsedMinutes(at: terminalAt)
        let rewardCount = restored.coordinator.rewards.count
        let sunriseBeforeReplay = restored.persistence.windDownMorningSettlementJournal.sunriseTrail
        let searchBeforeReplay = restored.persistence.sheepSearchState
        let farmBeforeReplay = restored.persistence.farmState
        let replay = FocusSessionCoordinator(
            persistence: restored.persistence,
            liveActivity: FocusRunLiveActivityService(installationID: UUID(), enabled: false),
            shielding: restored.shielding,
            watch: .inactiveForDeterministicCapture(),
            notificationEffectsEnabled: false
        )
        return evaluate("ordinary-partial-morning-replay", [
            check(first?.outcome == .finished, "ordinary Morning did not finish"),
            check(firstMinutes == 10, "ordinary Morning credited \(firstMinutes ?? -1) instead of 10 minutes"),
            check(replay.rewards.count == rewardCount, "terminal replay duplicated reward projection"),
            check(restored.persistence.windDownMorningSettlementJournal.sunriseTrail == sunriseBeforeReplay, "terminal replay changed Sunrise Trail"),
            check(restored.persistence.sheepSearchState == searchBeforeReplay, "terminal replay changed sheep-search state"),
            check(restored.persistence.farmState == farmBeforeReplay, "terminal replay changed Farm state"),
            check(restored.persistence.windDownMorningSettlementJournal.pendingAuthorizedTerminalMorningDecisions.isEmpty, "decision remained pending after replay")
        ])
    }

    private static func consumedDecisionDoesNotResurrect(now: Date) -> CaseResult {
        let fixture = pendingTerminal(
            wake: now.addingTimeInterval(60 * 60),
            terminalAt: now,
            disposition: .finalizeOrdinary,
            occurrenceOutcome: .scheduled
        )
        var journal = fixture.persistence.windDownMorningSettlementJournal
        _ = journal.markAuthorizedTerminalMorningDecisionCompleted(for: fixture.terminal.id, at: now)
        fixture.persistence.windDownMorningSettlementJournal = journal
        fixture.persistence.lastRun = nil
        let restored = restore(fixture)
        return evaluate("consumed-decision-no-resurrection", [
            check(restored.coordinator.run == nil, "consumed terminal decision resurrected a run"),
            check(restored.shielding.clearAllCount == 0, "consumed decision replayed shielding cleanup"),
            check(restored.persistence.windDownMorningSettlementJournal.pendingAuthorizedTerminalMorningDecisions.isEmpty, "consumed decision became pending")
        ])
    }

    private static func explicitActiveHandoff(now: Date) -> CaseResult {
        let terminalAt = now.addingTimeInterval(-60)
        let fixture = pendingTerminal(
            wake: terminalAt,
            terminalAt: terminalAt,
            disposition: .preserveExplicitIntent,
            occurrenceOutcome: .active,
            occurrenceEnd: now.addingTimeInterval(20 * 60)
        )
        let restored = restore(fixture)
        let occurrence = restored.persistence.windDownMorningSettlementJournal.morningOccurrences.first
        return evaluate("explicit-active-handoff", [
            check(occurrence?.outcome == .active, "explicit active Morning was not retained"),
            check(restored.shielding.reconciledOccurrenceIDs.contains(fixture.occurrence.id), "chosen Morning was not reconciled"),
            check(restored.shielding.clearedOccurrenceIDs.contains(fixture.terminal.id), "parent registry was not tombstoned"),
            check(restored.shielding.clearAllCount == 0, "active Morning handoff cleared all shielding"),
            check(restored.persistence.windDownMorningSettlementJournal.pendingAuthorizedTerminalMorningDecisions.isEmpty, "handoff decision remained pending")
        ])
    }

    /// An expired explicit defer must settle its factual window without
    /// re-registering a Screen Time barrier during restore.
    private static func explicitDeferredExpiry(now: Date) -> CaseResult {
        let terminalAt = now.addingTimeInterval(-2 * 60 * 60)
        let fixture = pendingTerminal(
            wake: terminalAt.addingTimeInterval(30 * 60),
            terminalAt: terminalAt,
            disposition: .preserveExplicitIntent,
            occurrenceOutcome: .scheduled,
            occurrenceEnd: now.addingTimeInterval(-30 * 60)
        )
        let restored = restore(fixture)
        let occurrence = restored.persistence.windDownMorningSettlementJournal.morningOccurrences.first
        let sunriseBeforeReplay = restored.persistence.windDownMorningSettlementJournal.sunriseTrail
        let searchBeforeReplay = restored.persistence.sheepSearchState
        let farmBeforeReplay = restored.persistence.farmState
        _ = FocusSessionCoordinator(
            persistence: restored.persistence,
            liveActivity: FocusRunLiveActivityService(installationID: UUID(), enabled: false),
            shielding: restored.shielding,
            watch: .inactiveForDeterministicCapture(),
            notificationEffectsEnabled: false
        )
        return evaluate("explicit-defer-expired-window", [
            check(occurrence?.outcome == .finished, "expired deferred Morning was not factually settled"),
            check(!restored.shielding.reconciledOccurrenceIDs.contains(fixture.occurrence.id), "expired deferred Morning was re-projected to shielding"),
            check(!restored.shielding.failedOccurrenceIDs.contains(fixture.occurrence.id), "expired deferred Morning reported a shielding failure"),
            check(restored.shielding.clearedOccurrenceIDs.contains(fixture.terminal.id), "expired defer did not tombstone the parent registry"),
            check(restored.persistence.windDownMorningSettlementJournal.pendingAuthorizedTerminalMorningDecisions.isEmpty, "expired defer left its decision pending"),
            check(restored.persistence.windDownMorningSettlementJournal.sunriseTrail == sunriseBeforeReplay, "expired defer replay changed Sunrise Trail"),
            check(restored.persistence.sheepSearchState == searchBeforeReplay, "expired defer replay changed sheep-search state"),
            check(restored.persistence.farmState == farmBeforeReplay, "expired defer replay changed Farm state")
        ])
    }

    private static func unauthorizedNFCExitCreatesNoDecision(now: Date) -> CaseResult {
        let persistence = isolatedPersistence()
        let shielding = ShieldingSpy()
        let coordinator = FocusSessionCoordinator(
            persistence: persistence,
            liveActivity: FocusRunLiveActivityService(installationID: UUID(), enabled: false),
            shielding: shielding,
            watch: .inactiveForDeterministicCapture(),
            notificationEffectsEnabled: false
        )
        let run = makeRun(wake: now.addingTimeInterval(2 * 60 * 60))
        let result = coordinator.start(
            configuration: FocusRunConfiguration(nightWatchPlan: run.nightWatchPlan!, guardKind: .nfcTag),
            focusAccepted: false,
            startedAt: run.startedAt,
            autoConfirmPlacement: false,
            appShieldingRequested: false,
            liveActivityRequested: false,
            runID: run.id
        )
        let ended = coordinator.endEarly(reason: .userEnded)
        return evaluate("unauthorized-nfc-has-no-terminal-decision", [
            check({ if case .started = result { return true }; return false }(), "NFC fixture did not start"),
            check(!ended, "unauthorized NFC exit ended the run"),
            check(persistence.windDownMorningSettlementJournal.pendingAuthorizedTerminalMorningDecisions.isEmpty, "unauthorized NFC exit wrote a terminal decision")
        ])
    }

    private static func explicitMorningShieldingFailureRoutesRepair(now: Date) -> CaseResult {
        let terminalAt = now.addingTimeInterval(-60)
        let fixture = pendingTerminal(
            wake: terminalAt,
            terminalAt: terminalAt,
            disposition: .preserveExplicitIntent,
            occurrenceOutcome: .active,
            occurrenceEnd: now.addingTimeInterval(20 * 60)
        )
        let sunriseBefore = fixture.persistence.windDownMorningSettlementJournal.sunriseTrail
        let shielding = ShieldingSpy()
        shielding.occurrenceOutcomes[fixture.occurrence.id] = .failed("probe-install")
        let coordinator = FocusSessionCoordinator(
            persistence: fixture.persistence,
            liveActivity: FocusRunLiveActivityService(installationID: UUID(), enabled: false),
            shielding: shielding,
            watch: .inactiveForDeterministicCapture(),
            notificationEffectsEnabled: false
        )
        let viewModel = FocusRunViewModel(
            coordinator: coordinator,
            persistence: fixture.persistence,
            startsExternalServices: false,
            quietTimeShielding: shielding
        )
        viewModel.enableScreenbookStartReadiness(keepsShielding: true)
        let occurrenceAfterFailure = fixture.persistence.windDownMorningSettlementJournal.morningOccurrences.first
        let failureIsPublished = coordinator.hasActiveShieldingFailure
            && viewModel.shieldingReadiness == .runtimeFailure
        coordinator.resetToSetup(clearPersistedRun: false)
        let failureSurvivedReset = coordinator.hasActiveShieldingFailure
            && viewModel.shieldingReadiness == .runtimeFailure
        shielding.occurrenceOutcomes[fixture.occurrence.id] = .scheduled
        viewModel.retryShielding()
        return evaluate("explicit-morning-shielding-failure", [
            check(occurrenceAfterFailure?.outcome == .active, "failed explicit Morning did not remain active"),
            check(occurrenceAfterFailure?.scheduledStart == fixture.occurrence.scheduledStart && occurrenceAfterFailure?.scheduledEnd == fixture.occurrence.scheduledEnd, "failed explicit Morning changed factual timing"),
            check(fixture.persistence.windDownMorningSettlementJournal.sunriseTrail == sunriseBefore, "failed explicit Morning changed Sunrise Trail"),
            check(failureIsPublished, "active Morning shielding failure was not exposed as repair-required"),
            check(failureSurvivedReset, "terminal reset cleared active Morning repair state"),
            check(!coordinator.hasActiveShieldingFailure && viewModel.shieldingReadiness == .ready, "retry did not repair the failed active Morning")
        ])
    }

    private static func coldActiveMorningRestoreRepublishesShieldingFailure(now: Date) -> CaseResult {
        let persistence = isolatedPersistence()
        var terminal = makeRun(wake: now)
        terminal.state = .completed
        terminal.completedSuccessfully = true
        terminal.endedAt = now.addingTimeInterval(-5 * 60)
        let occurrence = MorningQuietOccurrence(
            linkedWindDownRunID: terminal.id,
            scheduledStart: now.addingTimeInterval(-5 * 60),
            scheduledEnd: now.addingTimeInterval(20 * 60),
            actualStart: now.addingTimeInterval(-5 * 60),
            outcome: .active
        )
        var journal = persistence.windDownMorningSettlementJournal
        journal.appendOccurrence(occurrence)
        persistence.windDownMorningSettlementJournal = journal
        persistence.lastRun = terminal
        let shielding = ShieldingSpy()
        shielding.occurrenceOutcomes[occurrence.id] = .failed("probe-cold-restore")
        let coordinator = FocusSessionCoordinator(
            persistence: persistence,
            liveActivity: FocusRunLiveActivityService(installationID: UUID(), enabled: false),
            shielding: shielding,
            watch: .inactiveForDeterministicCapture(),
            notificationEffectsEnabled: false
        )
        let viewModel = FocusRunViewModel(
            coordinator: coordinator,
            persistence: persistence,
            startsExternalServices: false,
            quietTimeShielding: shielding
        )
        viewModel.enableScreenbookStartReadiness(keepsShielding: true)
        return evaluate("cold-active-morning-republishes-shielding-failure", [
            check(shielding.reconciledOccurrenceIDs.contains(occurrence.id), "cold restore did not reconcile the active Morning"),
            check(persistence.windDownMorningSettlementJournal.morningOccurrences.first?.outcome == .active, "cold restore changed active Morning outcome"),
            check(coordinator.hasActiveShieldingFailure && viewModel.shieldingReadiness == .runtimeFailure, "cold restore did not republish active Morning repair state")
        ])
    }

    private static func unrelatedMorningSuccessDoesNotClearRunFailure(now: Date) -> CaseResult {
        let persistence = isolatedPersistence()
        let shielding = ShieldingSpy()
        let coordinator = FocusSessionCoordinator(
            persistence: persistence,
            liveActivity: FocusRunLiveActivityService(installationID: UUID(), enabled: false),
            shielding: shielding,
            watch: .inactiveForDeterministicCapture(),
            notificationEffectsEnabled: false
        )
        let run = makeRun(wake: now.addingTimeInterval(2 * 60 * 60))
        shielding.runOutcomes[run.id] = .failed("probe-run-install")
        _ = coordinator.start(
            configuration: FocusRunConfiguration(nightWatchPlan: run.nightWatchPlan!, guardKind: .honorTimer),
            focusAccepted: false,
            startedAt: run.startedAt,
            autoConfirmPlacement: true,
            appShieldingRequested: true,
            liveActivityRequested: false,
            runID: run.id
        )
        let unrelated = MorningQuietOccurrence(
            scheduledStart: now.addingTimeInterval(-60),
            scheduledEnd: now.addingTimeInterval(20 * 60),
            actualStart: now.addingTimeInterval(-60),
            outcome: .active
        )
        coordinator.reconcileShieldingNow(for: unrelated)
        return evaluate("unrelated-morning-success-keeps-run-failure", [
            check(coordinator.hasActiveShieldingFailure, "unrelated Morning success cleared active run failure"),
            check({ if case .failed = coordinator.shieldingState { return true }; return false }(), "run shielding failure was no longer published")
        ])
    }

    private static func shieldingInstallRollbackUsesProductionRegistry() -> CaseResult {
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
        evaluate("shielding-install-rollback", [
            check(QuietTimeShieldingService.debugRollbackProbe(), "production shielding rollback did not preserve unrelated authority")
        ])
#else
        // This probe is a release-safety gate. A target without the required
        // Screen Time capability must not be reported as verified.
        CaseResult(
            name: "shielding-install-rollback",
            passed: false,
            failures: ["required Screen Time capability is unavailable"]
        )
#endif
    }

    private static func manualStartWithoutAutomaticScheduleKeepsNewShield(now: Date) -> CaseResult {
        let fixture = manualStartFixture(now: now, hasAutomaticSchedule: false)
        let presented = fixture.viewModel.requestStartNightWatch(sourceID: fixture.period.id)
        fixture.viewModel.confirmNightWatchStart()
        return evaluate("manual-start-no-prior-automatic", [
            check(presented, "manual start preflight was not presented"),
            check(fixture.viewModel.isRunning, "manual start was not admitted"),
            check(!fixture.shielding.events.contains("cancelAutomatic"), "new shield was cancelled without a prior automatic schedule"),
            check(fixture.shielding.events.contains(where: { $0.hasPrefix("reconcileRun:") }), "new run did not reconcile shielding")
        ])
    }

    private static func manualStartReplacesPriorAutomaticScheduleBeforeNewShield(now: Date) -> CaseResult {
        let fixture = manualStartFixture(now: now, hasAutomaticSchedule: true)
        let presented = fixture.viewModel.requestStartNightWatch(sourceID: fixture.period.id)
        fixture.viewModel.confirmNightWatchStart()
        let cancellationIndex = fixture.shielding.events.firstIndex(of: "cancelAutomatic")
        let reconcileIndex = fixture.shielding.events.firstIndex(where: { $0.hasPrefix("reconcileRun:") })
        return evaluate("manual-start-replaces-prior-automatic", [
            check(presented && fixture.viewModel.isRunning, "manual start was not admitted"),
            check(fixture.persistence.automaticWindDownSchedule == nil, "prior automatic schedule was not cleared after admission"),
            check(cancellationIndex != nil, "prior automatic monitor was not cancelled"),
            check(fixture.shielding.events.filter { $0 == "cancelAutomatic" }.count == 1, "manual admission cancelled shielding more than once"),
            check(cancellationIndex != nil && reconcileIndex != nil && cancellationIndex! < reconcileIndex!, "prior automatic monitor was not cancelled before new shielding")
        ])
    }

    private static func rejectedManualStartPreservesPriorAutomaticSchedule(now: Date) -> CaseResult {
        let fixture = manualStartFixture(now: now, hasAutomaticSchedule: true)
        guard fixture.viewModel.requestStartNightWatch(sourceID: fixture.period.id) else {
            return CaseResult(name: "rejected-manual-start-preserves-prior-automatic", passed: false, failures: ["manual preflight was not presented"])
        }
        let competing = makeRun(wake: now.addingTimeInterval(2 * 60 * 60))
        _ = fixture.coordinator.start(
            configuration: FocusRunConfiguration(nightWatchPlan: competing.nightWatchPlan!, guardKind: .honorTimer),
            focusAccepted: false,
            startedAt: competing.startedAt,
            autoConfirmPlacement: true,
            appShieldingRequested: true,
            liveActivityRequested: false,
            runID: competing.id
        )
        fixture.shielding.events.removeAll()
        fixture.viewModel.confirmNightWatchStart()
        return evaluate("rejected-manual-start-preserves-prior-automatic", [
            check(fixture.persistence.automaticWindDownSchedule != nil, "rejected start cleared the prior automatic schedule"),
            check(!fixture.shielding.events.contains("cancelAutomatic"), "rejected start cancelled the prior automatic monitor")
        ])
    }


    private static func manualStartPurposeCueReloadsFromIsolatedRegistry(now: Date) -> CaseResult {
        let fixture = manualStartFixture(now: now, hasAutomaticSchedule: false)
        let presented = fixture.viewModel.requestStartNightWatch(sourceID: fixture.period.id)
        fixture.viewModel.confirmNightWatchStart()
        guard let run = fixture.viewModel.activeRun else {
            return CaseResult(name: "manual-start-purpose-cue", passed: false, failures: ["manual start was not admitted"])
        }
        var registry = QuietTimeShieldScheduleRegistryStorage.load(from: fixture.purposeDefaults)
        _ = registry.upsert(
            occurrenceID: run.id,
            interval: DateInterval(start: now, end: now.addingTimeInterval(20 * 60)),
            role: .additionalQuiet,
            at: now
        )
        QuietTimeShieldScheduleRegistryStorage.save(registry, to: fixture.purposeDefaults)
        fixture.viewModel.setCurrentPurposeCue(.read)
        let immediatelyPublished = fixture.viewModel.currentPurposeCue == .read
        fixture.viewModel.reloadCurrentPurposeCue()
        return evaluate("manual-start-purpose-cue", [
            check(presented, "manual start preflight was not presented"),
            check(immediatelyPublished, "purpose cue was not published immediately"),
            check(fixture.viewModel.currentPurposeCue == .read, "purpose cue did not survive an immediate reload"),
            check(QuietPurposeCueState.load(from: fixture.purposeDefaults)?.cue == .read, "purpose cue was not stored in the injected registry defaults")
        ])
    }

    /// Models the crash after terminal progress/rewards have been persisted
    /// but before the terminal decision receives its completed marker.
    private static func shortPrimaryTerminalProjectionReplaysExactlyOnce(now: Date) -> CaseResult {
        let persistence = isolatedPersistence()
        let wake = now.addingTimeInterval(20 * 60)
        let active = makeRun(wake: wake)
        let terminalAt = active.startedAt.addingTimeInterval(400 * 60)
        var terminal = active
        terminal.state = .endedEarly
        terminal.completedSuccessfully = false
        terminal.endedEarlyReason = .userEnded
        terminal.endedAt = terminalAt
        terminal.actualDurationSeconds = terminalAt.timeIntervalSince(active.startedAt)
        let reward = RewardItem(
            id: UUID(), type: .muddyPaw, rarity: .consolation,
            title: "A small paw print", description: "Saved before the crash.",
            earnedAt: terminalAt, runDurationMinutes: 400, isDemoReward: false
        )
        var projectedProgress = UserProgress.empty
        projectedProgress.rewardsCollected = 1
        var journal = persistence.windDownMorningSettlementJournal
        guard journal.recordAuthorizedTerminalMorningDecision(
            for: terminal,
            disposition: .finalizeOrdinary,
            at: terminalAt
        ) != nil else {
            return CaseResult(name: "short-primary-terminal-projection", passed: false, failures: ["short primary terminal was not journalled"])
        }
        _ = journal.persistTerminalProjection(for: terminal.id, reward: reward, progress: projectedProgress)
        persistence.windDownMorningSettlementJournal = journal
        // These are the writes that survived the simulated crash.
        persistence.progress = projectedProgress
        persistence.rewards = [reward]
        persistence.lastRun = terminal

        let first = restore(PendingFixture(persistence: persistence, terminal: terminal, occurrence: MorningQuietOccurrence(
            linkedWindDownRunID: terminal.id,
            scheduledStart: wake,
            scheduledEnd: wake.addingTimeInterval(30 * 60),
            outcome: .scheduled
        )))
        let rewardsAfterFirst = first.persistence.rewards
        let progressAfterFirst = first.persistence.progress
        let second = FocusSessionCoordinator(
            persistence: first.persistence,
            liveActivity: FocusRunLiveActivityService(installationID: UUID(), enabled: false),
            shielding: first.shielding,
            watch: .inactiveForDeterministicCapture(),
            notificationEffectsEnabled: false
        )
        return evaluate("short-primary-terminal-projection", [
            check(first.persistence.rewards == [reward], "short primary recovery changed the saved reward projection"),
            check(first.persistence.progress == projectedProgress, "short primary recovery changed rewards/progress projection"),
            check(first.persistence.windDownMorningSettlementJournal.pendingAuthorizedTerminalMorningDecisions.isEmpty, "short primary decision remained pending"),
            check(second.rewards == rewardsAfterFirst, "second short primary recovery duplicated reward"),
            check(second.progress == progressAfterFirst, "second short primary recovery changed progress"),
            check(second.progress.rewardsCollected == 1, "short primary replay changed rewardsCollected")
        ])
    }

    private static func manualStartFixture(now: Date, hasAutomaticSchedule: Bool) -> ManualStartFixture {
        let persistence = isolatedPersistence()
        let period = WindDownOneTimePeriod(
            title: "Probe Phone Away",
            role: .additionalQuiet,
            interval: DateInterval(start: now.addingTimeInterval(-60), end: now.addingTimeInterval(25 * 60))
        )
        persistence.nightWatchPreferences = NightWatchPreferences(
            bedtimeHour: 23, bedtimeMinute: 0, wakeHour: 7, wakeMinute: 0,
            windDownMinutes: 30, morningQuietMinutes: 30,
            eveningActivity: .read, morningActivity: .openCurtains,
            guardKind: .honorTimer, isConfigured: true
        )
        persistence.windDownSchedule = WindDownScheduleState(oneTimePeriods: [period])
        if hasAutomaticSchedule {
            let automaticStart = now.addingTimeInterval(60 * 60)
            persistence.automaticWindDownSchedule = AutomaticWindDownSchedule(
                startedAt: automaticStart,
                plan: NightWatchPlan.additionalQuiet(start: automaticStart, end: automaticStart.addingTimeInterval(30 * 60))
            )
        }
        let shielding = ShieldingSpy()
        let purposeSuite = "\(suitePrefix).purpose.\(UUID().uuidString)"
        guard let purposeDefaults = UserDefaults(suiteName: purposeSuite) else {
            preconditionFailure("Could not create isolated purpose defaults")
        }
        purposeDefaults.removePersistentDomain(forName: purposeSuite)
        let coordinator = FocusSessionCoordinator(
            persistence: persistence,
            liveActivity: FocusRunLiveActivityService(installationID: UUID(), enabled: false),
            shielding: shielding,
            watch: .inactiveForDeterministicCapture(),
            notificationEffectsEnabled: false
        )
        let viewModel = FocusRunViewModel(
            coordinator: coordinator,
            persistence: persistence,
            nowProvider: { now },
            startsExternalServices: false,
            quietTimeShielding: shielding,
            purposeCueDefaults: purposeDefaults
        )
        viewModel.enableScreenbookStartReadiness(keepsShielding: true)
        return ManualStartFixture(
            persistence: persistence,
            coordinator: coordinator,
            viewModel: viewModel,
            shielding: shielding,
            purposeDefaults: purposeDefaults,
            period: period
        )
    }

    private static func pendingTerminal(
        wake: Date,
        terminalAt: Date,
        disposition: AuthorizedTerminalMorningDisposition,
        occurrenceOutcome: MorningQuietOccurrenceOutcome,
        occurrenceEnd: Date? = nil,
        storesTerminalRun: Bool = false
    ) -> PendingFixture {
        let persistence = isolatedPersistence()
        let active = makeRun(wake: wake)
        var terminal = active
        terminal.state = .completed
        terminal.completedSuccessfully = true
        terminal.actualDurationSeconds = terminalAt.timeIntervalSince(active.startedAt)
        terminal.endedAt = terminalAt
        let end = occurrenceEnd ?? wake.addingTimeInterval(30 * 60)
        let occurrence = MorningQuietOccurrence(
            id: UUID(),
            linkedWindDownRunID: active.id,
            scheduleOccurrenceID: UUID(),
            scheduledStart: wake,
            scheduledEnd: end,
            actualStart: occurrenceOutcome == .active ? wake : nil,
            outcome: occurrenceOutcome,
            liveActivityRequested: false
        )
        var journal = WindDownMorningSettlementJournal()
        journal.appendOccurrence(occurrence)
        _ = journal.recordAuthorizedTerminalMorningDecision(for: terminal, disposition: disposition, at: terminalAt)
        persistence.windDownMorningSettlementJournal = journal
        // Ordinary coordinator recovery must handle both crash windows: the
        // decision-only gap and the later terminal-lastRun-before-finalization
        // gap.
        persistence.lastRun = storesTerminalRun ? terminal : active
        return PendingFixture(persistence: persistence, terminal: terminal, occurrence: occurrence)
    }

    private static func restore(_ fixture: PendingFixture) -> RestoredFixture {
        let shielding = ShieldingSpy()
        let coordinator = FocusSessionCoordinator(
            persistence: fixture.persistence,
            liveActivity: FocusRunLiveActivityService(installationID: UUID(), enabled: false),
            shielding: shielding,
            watch: .inactiveForDeterministicCapture(),
            notificationEffectsEnabled: false
        )
        return RestoredFixture(persistence: fixture.persistence, coordinator: coordinator, shielding: shielding)
    }

    private static func makeRun(wake: Date) -> FocusRun {
        let startedAt = wake.addingTimeInterval(-8 * 60 * 60)
        let protectedUntil = wake.addingTimeInterval(30 * 60)
        let plan = NightWatchPlan(
            intendedBedtime: startedAt.addingTimeInterval(30 * 60),
            wakeTime: wake,
            protectedUntil: protectedUntil,
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        var run = FocusRun(
            plannedDurationSeconds: protectedUntil.timeIntervalSince(startedAt),
            startedAt: startedAt,
            state: .running,
            guardKind: .honorTimer,
            nightWatchPlan: plan,
            appShieldingRequested: true,
            liveActivityRequested: false
        )
        run.phoneAwayValidatedAt = startedAt
        return run
    }

    private static func isolatedPersistence() -> PersistenceService {
        let suite = "\(suitePrefix).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            preconditionFailure("Could not create isolated recovery-probe defaults")
        }
        defaults.removePersistentDomain(forName: suite)
        return PersistenceService(defaults: defaults)
    }

    private static func evaluate(_ name: String, _ checks: [Check]) -> CaseResult {
        CaseResult(name: name, passed: checks.allSatisfy(\.passed), failures: checks.filter { !$0.passed }.map(\.message))
    }

    private static func check(_ passed: Bool, _ message: String) -> Check {
        Check(passed: passed, message: message)
    }

    private static func value(after argument: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: argument), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func write(_ report: Report) throws {
        let documents = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let directory = documents.appendingPathComponent("screenbook", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(report).write(to: directory.appendingPathComponent("recovery-probe.json"), options: .atomic)
    }

    private struct PendingFixture {
        let persistence: PersistenceService
        let terminal: FocusRun
        let occurrence: MorningQuietOccurrence
    }

    private struct RestoredFixture {
        let persistence: PersistenceService
        let coordinator: FocusSessionCoordinator
        let shielding: ShieldingSpy
    }

    private struct ManualStartFixture {
        let persistence: PersistenceService
        let coordinator: FocusSessionCoordinator
        let viewModel: FocusRunViewModel
        let shielding: ShieldingSpy
        let purposeDefaults: UserDefaults
        let period: WindDownOneTimePeriod
    }

    private struct Check {
        let passed: Bool
        let message: String
    }

    private struct Report: Codable {
        let schemaVersion: Int
        let generatedAt: Date
        let cases: [CaseResult]
        var passed: Bool { cases.allSatisfy(\.passed) }
    }

    private struct CaseResult: Codable {
        let name: String
        let passed: Bool
        let failures: [String]
    }

    private final class ShieldingSpy: QuietTimeShieldingProviding {
        var events: [String] = []
        var runOutcomes: [UUID: QuietTimeShieldingOutcome] = [:]
        var occurrenceOutcomes: [UUID: QuietTimeShieldingOutcome] = [:]
        var reconciledOccurrenceIDs: [UUID] = []
        var failedOccurrenceIDs: [UUID] = []
        var clearedOccurrenceIDs: [UUID] = []
        var clearAllCount = 0

        func reconcile(for run: FocusRun?, at date: Date) -> QuietTimeShieldingOutcome {
            guard let run else { return .cleared }
            events.append("reconcileRun:\(run.id.uuidString)")
            return runOutcomes[run.id] ?? .scheduled
        }

        func reconcile(for occurrence: MorningQuietOccurrence, at date: Date) -> QuietTimeShieldingOutcome {
            reconciledOccurrenceIDs.append(occurrence.id)
            events.append("reconcileOccurrence:\(occurrence.id.uuidString)")
            if let configured = occurrenceOutcomes[occurrence.id] {
                if case .failed = configured { failedOccurrenceIDs.append(occurrence.id) }
                return configured
            }
            if date >= occurrence.scheduledEnd {
                failedOccurrenceIDs.append(occurrence.id)
                return .failed("expired-probe-window")
            }
            return .scheduled
        }

        func clear() { clearAllCount += 1 }
        func clear(occurrenceID: UUID) { clearedOccurrenceIDs.append(occurrenceID) }
        func scheduleAutomatic(for schedule: AutomaticWindDownSchedule, at date: Date) -> QuietTimeShieldingOutcome {
            events.append("scheduleAutomatic")
            return .scheduled
        }
        func cancelAutomaticSchedule() { events.append("cancelAutomatic") }
        func resetLocalState() { events.append("resetLocalState") }
        func protectionSummary(for run: FocusRun, at date: Date) -> QuietTimeShieldProtectionSummary { .none }
        func briefAccessUseCount(for run: FocusRun) -> Int { 0 }
        func briefAccessTrackerSummary(for run: FocusRun) -> QuietTimeBriefAccessTrackerSummary { .init() }
        func briefAccessTrackerSummary(forOccurrenceID occurrenceID: UUID) -> QuietTimeBriefAccessTrackerSummary { .init() }
    }
}
#endif
