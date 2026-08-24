import Foundation
import OSLog
import UIKit

@MainActor
final class FocusSessionCoordinator: ObservableObject {
    @Published var run: FocusRun?
    @Published var proximityState: ProximityState = .initial
    @Published var events: [SessionEvent] = []
    @Published var latestReward: RewardItem?
    @Published var progress: UserProgress
    @Published var rewards: [RewardItem]
    @Published var pingPulseCount = 0
    @Published var ollieMessage = "Ollie is ready when your phone is."
    @Published var backgroundReturnMessage: String?
    @Published var shieldingState: ActiveRunShieldingState = .notRequested
    @Published var sheepSearchState: SheepSearchState
    @Published var latestSheepSearchOutcome: SheepSearchOutcome?
    @Published var farmState: FarmState
    @Published private(set) var lastOnboardingPracticeGrantedSheep = false
    @Published private(set) var emergencyExitChallenge: EmergencyExitChallenge?

    private let persistence: PersistenceService
    private let rewardEngine = RewardEngine()
    let watch: WatchConnectivityManager
    private let ping = PingService()
    private let notifications = PhoneNotificationService.shared
    private let liveActivity: FocusRunLiveActivityService
    private let shielding: QuietTimeShieldingProviding
    let nearby = NearbyInteractionDistanceProvider()
    private var timer: Timer?
    // Screen-Free Morning is an independent journal occurrence, but its
    // boundaries still belong to this phone-authoritative coordinator. This
    // timer keeps deferred and ordinary mornings advancing while the app is
    // foregrounded after the parent Wind Down has ended.
    private var morningOccurrenceTimer: Timer?
    var placementTask: Task<Void, Never>?
    var placementTimeoutTask: Task<Void, Never>?
    var pairedWatchTokenData: Data?
    private var lastLiveActivityPhase: NightWatchPhase?
    var optionalSheepSearchBonusProvider: (() -> Int)?
    var onPhoneAwayValidated: ((FocusRun) -> Void)?
    /// Lets the owning view model advance the saved routine cursor after a
    /// terminal run without making the coordinator own scheduling policy.
    var onRunFinished: ((FocusRun, Bool) -> Void)?
    /// The view model owns notification and usage-monitor dependencies. It is
    /// invoked only after a terminal exit has passed coordinator authorization.
    var onAuthorizedEarlyExit: ((Bool) -> Void)?
    private var emergencyExitChallengeMachine = EmergencyExitChallengeMachine()
#if DEBUG
    let energyLogger = Logger(
        subsystem: "com.ngawangchime.countingsheep",
        category: "Energy.Session"
    )
    private var boundaryTimerScheduleCount = 0
#endif

    init(
        persistence: PersistenceService = .shared,
        liveActivity: FocusRunLiveActivityService? = nil,
        shielding: QuietTimeShieldingProviding? = nil,
        watch: WatchConnectivityManager = .shared
    ) {
        self.persistence = persistence
        self.liveActivity = liveActivity ?? FocusRunLiveActivityService()
        self.shielding = shielding ?? QuietTimeShieldingService()
        self.watch = watch
        self.progress = persistence.progress
        self.rewards = persistence.rewards
        self.farmState = persistence.farmState
        let savedSearchState = persistence.sheepSearchState
        self.sheepSearchState = savedSearchState
        self.latestSheepSearchOutcome = savedSearchState.lastOutcome
        watch.onMessage = { [weak self] message in
            Task { @MainActor in self?.handle(message) }
        }
        watch.currentStateProvider = { [weak self] in
            guard let self else { return nil }
            return WatchMessage(
                type: .focusRunStateUpdate,
                run: self.run,
                proximity: self.proximityState,
                screenFreeMorning: self.currentScreenFreeMorningPresentation()
            )
        }
        restoreActiveRunIfNeeded()
    }

    deinit {
        timer?.invalidate()
        placementTask?.cancel()
        placementTimeoutTask?.cancel()
        nearby.stop()
    }

    var remainingSeconds: TimeInterval {
        guard let run else { return 0 }
        return max(0, run.plannedEndAt.timeIntervalSince(Date()))
    }

    var currentNightWatchPhase: NightWatchPhase? {
        run?.nightWatchPhase()
    }

    var nextNightWatchTransition: Date? {
        guard let run else { return nil }
        return run.nightWatchPlan?.nextTransition(after: Date())
    }

    func start(
        configuration: FocusRunConfiguration,
        focusAccepted: Bool,
        startedAt: Date = Date(),
        autoConfirmPlacement: Bool = false,
        appShieldingRequested: Bool = true,
        liveActivityRequested: Bool = true,
        runID: UUID? = nil
    ) {
        cancelEmergencyExitChallenge()
        guard !persistence.windDownMorningSettlementJournal.morningOccurrences.contains(where: {
            $0.outcome == .active
        }) else { return }
        resetToSetup(clearPersistedRun: false, liveActivityCancellationReason: .replaced)
        let plannedDuration = configuration.nightWatchPlan.map {
            max(FocusRunRules.minimumMeaningfulDurationSeconds, $0.protectedUntil.timeIntervalSince(startedAt))
        } ?? configuration.duration
        let placementRequired = configuration.guardKind.needsPlacementConfirmation
            && !autoConfirmPlacement
        var newRun = FocusRun(
            id: runID ?? UUID(),
            plannedDurationSeconds: plannedDuration,
            startedAt: startedAt,
            state: placementRequired ? .placementGrace : .running,
            guardKind: configuration.guardKind,
            nightWatchPlan: configuration.nightWatchPlan,
            appShieldingRequested: appShieldingRequested,
            liveActivityRequested: liveActivityRequested
        )
        newRun.isPractice = configuration.isPractice
        let isAdditionalQuiet = newRun.nightWatchPlan?.role == .additionalQuiet
        if !configuration.guardKind.needsPlacementConfirmation || autoConfirmPlacement {
            newRun.phoneAwayValidatedAt = startedAt
        }
        if autoConfirmPlacement {
            newRun.placementStatus = .confirmed
            newRun.placementEvidence = PlacementEvidence(
                guardKind: configuration.guardKind,
                confirmedAt: startedAt,
                note: isAdditionalQuiet
                    ? "Automatic quiet-time schedule started"
                    : "Automatic Wind Down schedule started"
            )
        }
        run = newRun
        latestReward = nil
        proximityState = .initial
        ollieMessage = openingMessage(
            for: configuration.guardKind,
            role: newRun.nightWatchPlan?.role ?? .primarySleepBookend
        )
        addEvent(
            isAdditionalQuiet
                ? "Phone Away started."
                : (newRun.isNightWatch ? "Wind Down started." : "Phone-away time started."),
            detail: focusAccepted ? "System Focus was turned on." : nil
        )
        persistActiveRun()
        ensureOrdinaryScreenFreeMorningOccurrence(for: newRun, at: startedAt)
        if let record = newRun.nightWatchRecord(updatedAt: startedAt) {
            persistence.upsertNightWatchRecord(record, now: startedAt)
            recordRitualEvent(
                .sessionStarted,
                for: newRun,
                at: startedAt,
                idempotencyKey: "\(newRun.id.uuidString):session-started",
                payload: ["startMethod": newRun.guardKind.rawValue]
            )
            if autoConfirmPlacement && newRun.guardKind == .nfcTag {
                recordRitualEvent(
                    .placementConfirmed,
                    for: newRun,
                    at: startedAt,
                    idempotencyKey: "\(newRun.id.uuidString):placement-confirmed",
                    payload: ["method": "nfcTag"]
                )
            }
            // The start flow only calls this after the required preflight. For NFC,
            // the tag tap is the barrier-confirming action, so the run and shield are
            // both created together after that tap.
            reconcileShielding(for: newRun, at: Date())
        }
        liveActivity.start(for: newRun)
        if let activeMorning = persistence.windDownMorningSettlementJournal.morningOccurrences.first(where: { $0.outcome == .active }) {
            liveActivity.startScreenFreeMorning(activeMorning)
        }
        lastLiveActivityPhase = newRun.nightWatchPhase(at: Date())
        UIApplication.shared.isIdleTimerDisabled = configuration.guardKind == .watchPlacement
        scheduleNextBoundaryTimer()
        scheduleNextMorningOccurrenceBoundaryTimer()
        watch.send(WatchMessage(
            type: .startFocusRun,
            run: newRun,
            proximity: proximityState,
            screenFreeMorning: currentScreenFreeMorningPresentation()
        ))
        if newRun.phoneAwayValidatedAt != nil {
            onPhoneAwayValidated?(newRun)
        }

        switch configuration.guardKind {
        case .watchPlacement:
            if !autoConfirmPlacement {
                startWatchPlacement()
            }
        case .qrCode:
            if !autoConfirmPlacement {
                addEvent(
                    isAdditionalQuiet ? "Phone-bed code needed." : "Wind Down code needed.",
                    detail: isAdditionalQuiet
                        ? "Scan your phone-bed code to start Phone Away."
                        : "Scan your Wind Down code to start the app-access barrier."
                )
            }
        case .nfcTag:
            let protectionDetail: String
            if isAdditionalQuiet {
                protectionDetail = "Selected apps are limited until \(OllieFormat.time(newRun.plannedEndAt))."
            } else {
                protectionDetail = "Selected apps are limited until \(OllieFormat.time(newRun.plannedEndAt)) or you use the emergency exit."
            }
            addEvent(
                isAdditionalQuiet
                    ? (autoConfirmPlacement
                        ? "Phone Away tag confirmed."
                        : "Phone Away is waiting. Tap the Phone Away tag when it is ready.")
                    : (autoConfirmPlacement
                        ? "Wind Down tag confirmed."
                        : "Wind Down is running. Tap the Wind Down tag when it is ready."),
                detail: autoConfirmPlacement
                        ? protectionDetail
                    : "The session has not started until the registered tag is tapped."
            )
        case .honorTimer:
            break
        }
    }

    func confirmQRCode(_ code: String, expectedCode: String?) -> Bool {
        guard var run, run.guardKind == .qrCode else { return false }
        guard expectedCode == nil || expectedCode == code else {
            ollieMessage = run.nightWatchPlan?.role == .additionalQuiet
                ? "That is not your phone-bed code. Try again."
                : "That is not your Wind Down code. Try again."
            recordRitualEvent(.placementValidationFailed, for: run, payload: ["method": "qrCode"])
            return false
        }
        confirmPlacement(
            &run,
            note: run.nightWatchPlan?.role == .additionalQuiet
                ? "Phone-bed code confirmed"
                : "Wind Down code confirmed"
        )
        recordRitualEvent(
            .placementConfirmed,
            for: run,
            idempotencyKey: "\(run.id.uuidString):placement-confirmed",
            payload: ["method": "qrCode"]
        )
        return true
    }

    func confirmNFCTag(_ fingerprint: String, expectedFingerprint: String?) -> Bool {
        guard var run, run.guardKind == .nfcTag else { return false }
        guard expectedFingerprint == nil || expectedFingerprint == fingerprint else {
            ollieMessage = run.nightWatchPlan?.role == .additionalQuiet
                ? "That is not your Phone Away tag. Try again."
                : "That is not your Wind Down tag. Try again."
            recordRitualEvent(.placementValidationFailed, for: run, payload: ["method": "nfcTag"])
            return false
        }
        confirmPlacement(
            &run,
            note: run.nightWatchPlan?.role == .additionalQuiet
                ? "Phone Away tag tapped"
                : "Wind Down tag tapped"
        )
        recordRitualEvent(
            .placementConfirmed,
            for: run,
            idempotencyKey: "\(run.id.uuidString):placement-confirmed",
            payload: ["method": "nfcTag"]
        )
        return true
    }

    func continueWithoutWatch() {
        guard var run, run.guardKind.needsPlacementConfirmation else { return }
        stopWatchPlacement()
        run.guardKind = .honorTimer
        run.placementStatus = .notRequired
        let isAdditionalQuiet = run.nightWatchPlan?.role == .additionalQuiet
        run.placementEvidence = PlacementEvidence(
            guardKind: .honorTimer,
            confirmedAt: nil,
            note: isAdditionalQuiet ? "Continued without a Phone Away tag" : "Continued without a Wind Down tag"
        )
        run.phoneAwayValidatedAt = Date()
        run.state = .running
        self.run = run
        ollieMessage = "Ollie will keep the quiet while your phone rests away."
        addEvent(isAdditionalQuiet ? "Phone Away continued without a tag check." : "Wind Down continued without a tag check.")
        recordRitualEvent(
            .fallbackSelected,
            for: run,
            idempotencyKey: "\(run.id.uuidString):fallback-selected",
            payload: ["method": "honorTimer"]
        )
        persistActiveRun()
        reconcileShielding(for: run)
        UIApplication.shared.isIdleTimerDisabled = false
        watch.send(WatchMessage(type: .focusRunStateUpdate, run: run, proximity: proximityState))
        onPhoneAwayValidated?(run)
        if Date() >= run.plannedEndAt {
            reconcileSession()
        }
    }

    func requestDistanceCheck() {
        guard run?.guardKind == .watchPlacement, run?.placementStatus == .awaitingConfirmation else { return }
        startWatchPlacement()
    }

    func exitAuthorization(
        for reason: EarlyEndReason,
        source: SessionExitSource = .phone
    ) -> SessionExitAuthorization {
        guard let run else { return .rejected(.invalidAuthentication) }
        return SessionExitAuthorizationPolicy.authorization(
            for: run.guardKind,
            requestedReason: reason,
            source: source
        )
    }

    @discardableResult
    func beginEmergencyExitChallenge() -> Bool {
        guard let run,
              run.guardKind == .nfcTag,
              ![.completed, .endedEarly, .setup].contains(run.state) else { return false }
        emergencyExitChallenge = emergencyExitChallengeMachine.begin(for: run.id)
        return true
    }

    @discardableResult
    func submitEmergencyExitReason(_ reason: String) -> Bool {
        guard let run else { return false }
        let accepted = emergencyExitChallengeMachine.submitReason(reason, for: run.id)
        emergencyExitChallenge = emergencyExitChallengeMachine.challenge
        return accepted
    }

    @discardableResult
    func submitEmergencyExitConfirmation(_ reason: String) -> Bool {
        guard let run else { return false }
        let accepted = emergencyExitChallengeMachine.submitConfirmation(reason, for: run.id)
        emergencyExitChallenge = emergencyExitChallengeMachine.challenge
        return accepted
    }

    /// Compatibility entry point for older views. The challenge itself decides
    /// whether this is the first reason or the reason-again step.
    @discardableResult
    func submitEmergencyExitWord(_ word: String) -> Bool {
        guard let run else { return false }
        let accepted = emergencyExitChallengeMachine.submit(word, for: run.id)
        emergencyExitChallenge = emergencyExitChallengeMachine.challenge
        return accepted
    }

    func cancelEmergencyExitChallenge() {
        emergencyExitChallengeMachine.cancel()
        emergencyExitChallenge = nil
    }

    @discardableResult
    func confirmEmergencyExit() -> Bool {
        guard let run,
              let challenge = emergencyExitChallengeMachine.challenge,
              let reason = challenge.reason,
              challenge.canConfirm,
              emergencyExitChallengeMachine.consumeConfirmation(for: run.id) else {
            emergencyExitChallenge = emergencyExitChallengeMachine.challenge
            return false
        }
        emergencyExitChallenge = nil
        guard let terminalRun = emergencyTerminalRun(for: run) else { return false }
        persistence.saveEmergencyExitReason(reason, for: run.id)
        completeAuthorizedEarlyExit(with: terminalRun)
        return true
    }

    @discardableResult
    func endEarly(
        reason: EarlyEndReason = .userEnded,
        source: SessionExitSource = .phone
    ) -> Bool {
        guard let run else { return false }
        guard let terminalRun = SessionExitTransition.ending(
            run,
            requestedReason: reason,
            source: source
        ) else {
            rejectUnauthorizedExit(for: run, source: source)
            return false
        }
        completeAuthorizedEarlyExit(with: terminalRun)
        return true
    }

    /// This terminal path is intentionally private: only a matching, consumed
    /// challenge in `confirmEmergencyExit()` can create an emergency bypass.
    private func emergencyTerminalRun(for run: FocusRun, at date: Date = Date()) -> FocusRun? {
        guard run.guardKind == .nfcTag,
              ![.completed, .endedEarly, .setup].contains(run.state) else { return nil }
        var terminalRun = run
        terminalRun.state = .endedEarly
        terminalRun.endedAt = date
        terminalRun.actualDurationSeconds = min(
            run.plannedDurationSeconds,
            max(0, date.timeIntervalSince(run.startedAt))
        )
        terminalRun.endedEarlyReason = .emergencyBypass
        return terminalRun
    }

    private func completeAuthorizedEarlyExit(
        with terminalRun: FocusRun,
        preservingShieldForLinkedMorning: Bool = false
    ) {
        // This is the last authorization boundary before any resource cleanup.
        // It keeps rejected scans and Watch requests from lifting app limits.
        onAuthorizedEarlyExit?(preservingShieldForLinkedMorning)
        if !preservingShieldForLinkedMorning {
            shielding.cancelAutomaticSchedule()
            shielding.clear()
        }
        finish(
            run: terminalRun,
            clearShielding: !preservingShieldForLinkedMorning,
            linkedMorningHandoff: preservingShieldForLinkedMorning
        )
    }

    private func rejectUnauthorizedExit(for run: FocusRun, source: SessionExitSource) {
        guard run.guardKind == .nfcTag else { return }
        let isAdditionalQuiet = run.nightWatchPlan?.role == .additionalQuiet
        addEvent(
            isAdditionalQuiet ? "Phone Away tag needed." : "Wind Down tag needed.",
            detail: isAdditionalQuiet
                ? "Use the iPhone and tap the registered tag to end Phone Away, or use the iPhone emergency exit to end without the tag."
                : "Use the iPhone and tap the registered tag to end Wind Down, or use the iPhone emergency exit to end without the tag."
        )
        if source == .watch {
            watch.send(
                WatchMessage(
                    type: .focusRunStateUpdate,
                    run: run,
                    proximity: proximityState
                )
            )
        }
    }

    func pingPhone() {
        ping.pingPhone()
        pingPulseCount += 1
        addEvent("Phone heard the whistle.", severity: .success)
    }

    func applicationDidEnterBackground() {
        cancelMorningOccurrenceBoundaryTimer(reason: "background")
        guard run != nil else { return }
        updateElapsedTime(at: Date())
        cancelBoundaryTimer(reason: "background")
        persistActiveRun()
        UIApplication.shared.isIdleTimerDisabled = false
        if run?.guardKind == .watchPlacement, run?.placementStatus == .awaitingConfirmation {
            stopWatchPlacement()
        }
#if DEBUG
        logResourceState(event: "entered background")
#endif
    }

    func applicationDidBecomeActive() {
        reconcileMorningQuietOccurrences()
        scheduleNextMorningOccurrenceBoundaryTimer()
        guard let currentRun = run,
              ![.completed, .endedEarly, .setup].contains(currentRun.state) else { return }
        backgroundReturnMessage = "Welcome back. Ollie is still on watch."
        if run?.guardKind == .watchPlacement, run?.placementStatus == .awaitingConfirmation {
            ollieMessage = "Ollie can try the Watch check again, or you can continue without it."
        }
        reconcileSession()
#if DEBUG
        logResourceState(event: "became active")
#endif
    }

    func resetToSetup(
        clearPersistedRun: Bool = true,
        liveActivityCancellationReason: FocusRunLiveActivityCancellationReason = .reset
    ) {
        cancelEmergencyExitChallenge()
        cancelBoundaryTimer(reason: "reset")
        cancelMorningOccurrenceBoundaryTimer(reason: "reset")
        stopWatchPlacement()
        UIApplication.shared.isIdleTimerDisabled = false
        run = nil
        latestReward = nil
        proximityState = .initial
        backgroundReturnMessage = nil
        shieldingState = .notRequested
        lastLiveActivityPhase = nil
        ollieMessage = "Ollie is ready when your phone is."
        notifications.cancelRunCompletion()
        let preservedMorning = currentScreenFreeMorningPresentation()
        if preservedMorning?.isActive != true {
            liveActivity.endAll(reason: liveActivityCancellationReason)
            shielding.clear()
        }
        watch.send(WatchMessage(
            type: .focusRunStateUpdate,
            run: nil,
            proximity: proximityState,
            screenFreeMorning: preservedMorning
        ))
        if clearPersistedRun { persistence.lastRun = nil }
#if DEBUG
        logResourceState(event: "reset complete")
#endif
    }

    func resetLiveActivityToFreshInstallDefaults() {
        liveActivity.resetToFreshInstallDefaults()
    }

    func revealDeliveredWindDownBenefit(for runID: UUID, at date: Date = Date()) {
        var journal = persistence.windDownMorningSettlementJournal
        guard journal.markRevealed(runID: runID, at: date) != nil else { return }
        persistence.windDownMorningSettlementJournal = journal
        notifications.reconcileScreenFreeMorningNotifications(
            occurrences: journal.morningOccurrences,
            now: date
        )
    }

    /// Ends only an overnight Wind Down after the same authorization that
    /// governs every other terminal exit. The independent morning occurrence
    /// is durable before cleanup so an NFC cancellation or mismatch cannot
    /// leave a partially committed choice behind.
    @discardableResult
    func transitionToEarlyMorning(
        intent: MorningQuietIntent,
        reason: EarlyEndReason,
        source: SessionExitSource = .phone,
        at date: Date = Date()
    ) -> MorningQuietOccurrence? {
        guard intent != .keepWindDownRunning,
              let currentRun = run,
              MorningQuietIntentEngine.isAvailable(run: currentRun, at: date),
              case .authorized = exitAuthorization(for: reason, source: source),
              let proposedOccurrence = MorningQuietIntentEngine.occurrence(
                  for: intent,
                  run: currentRun,
                  at: date
              ) else { return nil }

        var journal = persistence.windDownMorningSettlementJournal
        let occurrence: MorningQuietOccurrence
        if let existing = journal.morningOccurrences.first(where: {
            $0.linkedWindDownRunID == currentRun.id && $0.outcome == .scheduled
        }) {
            occurrence = MorningQuietOccurrence(
                id: existing.id,
                linkedWindDownRunID: currentRun.id,
                scheduleOccurrenceID: existing.scheduleOccurrenceID,
                scheduledStart: proposedOccurrence.scheduledStart,
                scheduledEnd: proposedOccurrence.scheduledEnd,
                actualStart: proposedOccurrence.actualStart,
                endedAt: proposedOccurrence.endedAt,
                outcome: proposedOccurrence.outcome,
                liveActivityRequested: proposedOccurrence.liveActivityRequested
            )
            guard journal.replaceOccurrence(occurrence) else { return nil }
        } else {
            occurrence = proposedOccurrence
            let count = journal.morningOccurrences.count
            journal.appendOccurrence(occurrence)
            guard journal.morningOccurrences.count == count + 1 else { return nil }
        }
        persistence.windDownMorningSettlementJournal = journal
        notifications.reconcileScreenFreeMorningNotifications(
            occurrences: journal.morningOccurrences,
            now: date
        )

        var terminalRun = currentRun
        terminalRun.endedAt = date
        terminalRun.actualDurationSeconds = min(
            terminalRun.plannedDurationSeconds,
            max(0, date.timeIntervalSince(terminalRun.startedAt))
        )
        let eligible = FocusRunRules.protectedSpanMinutes(for: terminalRun, at: date)
            >= FocusRunRules.minimumProtectedNightSearchSpanMinutes
        terminalRun.state = eligible ? .completed : .endedEarly
        terminalRun.completedSuccessfully = eligible
        terminalRun.endedEarlyReason = eligible ? nil : reason
        completeAuthorizedEarlyExit(
            with: terminalRun,
            preservingShieldForLinkedMorning: occurrence.outcome == .active
        )
        _ = shielding.reconcile(for: occurrence, at: date)
        // Publish/apply the linked Morning first, then tombstone the terminal
        // Wind Down entry so a stale callback cannot clear the new window.
        shielding.clear(occurrenceID: currentRun.id)
        reconcileMorningQuietOccurrences(at: date)
        return occurrence
    }

    @discardableResult
    func finishScreenFreeMorning(
        occurrenceID: UUID,
        at date: Date = Date()
    ) -> MorningQuietOccurrence? {
        var journal = persistence.windDownMorningSettlementJournal
        guard let index = journal.morningOccurrences.firstIndex(where: { $0.id == occurrenceID }) else {
            return nil
        }
        var occurrence = journal.morningOccurrences[index]
        guard occurrence.outcome == .active else { return nil }
        occurrence.endedAt = min(max(date, occurrence.scheduledStart), occurrence.scheduledEnd)
        occurrence.outcome = .finished
        journal.morningOccurrences[index] = occurrence
        settleFinishedMorningOccurrences(&journal, at: occurrence.endedAt ?? date)
        persistence.windDownMorningSettlementJournal = journal
        notifications.reconcileScreenFreeMorningNotifications(
            occurrences: journal.morningOccurrences,
            now: date
        )
        shielding.clear(occurrenceID: occurrence.id)
        liveActivity.finishScreenFreeMorning(occurrence)
        sendWatchState()
        scheduleNextMorningOccurrenceBoundaryTimer()
        return occurrence
    }

    /// Restores a deferred Screen-Free Morning even when the app was absent
    /// for the whole window. This is deliberately separate from `FocusRun` so
    /// its minutes and Sunrise Trail cannot alter Wind Down/Phone Away state.
    func reconcileMorningQuietOccurrences(at date: Date = Date()) {
        var journal = persistence.windDownMorningSettlementJournal
        var changed = false
        var startedOccurrences: [MorningQuietOccurrence] = []
        var finishedOccurrences: [MorningQuietOccurrence] = []
        for index in journal.morningOccurrences.indices {
            var occurrence = journal.morningOccurrences[index]
            if occurrence.outcome == .scheduled, date >= occurrence.scheduledStart {
                occurrence.actualStart = occurrence.scheduledStart
                occurrence.outcome = .active
                journal.morningOccurrences[index] = occurrence
                _ = shielding.reconcile(for: occurrence, at: date)
                changed = true
                if date < occurrence.scheduledEnd {
                    startedOccurrences.append(occurrence)
                }
            }
            if occurrence.outcome == .active, date >= occurrence.scheduledEnd {
                occurrence.endedAt = occurrence.scheduledEnd
                occurrence.outcome = .finished
                journal.morningOccurrences[index] = occurrence
                shielding.clear(occurrenceID: occurrence.id)
                changed = true
                finishedOccurrences.append(occurrence)
            }
        }
        if changed {
            settleFinishedMorningOccurrences(&journal, at: date)
        }
        guard changed else {
            if let active = journal.morningOccurrences.first(where: { $0.outcome == .active }) {
                liveActivity.startScreenFreeMorning(active)
                sendWatchState()
            }
            scheduleNextMorningOccurrenceBoundaryTimer()
            return
        }
        persistence.windDownMorningSettlementJournal = journal
        persistence.sheepSearchState = sheepSearchState
        persistence.farmState = farmState
        notifications.reconcileScreenFreeMorningNotifications(
            occurrences: journal.morningOccurrences,
            now: date
        )
        startedOccurrences.forEach(liveActivity.startScreenFreeMorning)
        finishedOccurrences.forEach(liveActivity.finishScreenFreeMorning)
        sendWatchState()
        scheduleNextMorningOccurrenceBoundaryTimer()
    }

    @discardableResult
    func recordMorningQuietOccurrence(_ occurrence: MorningQuietOccurrence) -> Bool {
        var journal = persistence.windDownMorningSettlementJournal
        let count = journal.morningOccurrences.count
        journal.appendOccurrence(occurrence)
        guard journal.morningOccurrences.count != count else { return false }
        persistence.windDownMorningSettlementJournal = journal
        return true
    }

    private func settleFinishedMorningOccurrences(
        _ journal: inout WindDownMorningSettlementJournal,
        at date: Date
    ) {
        for occurrence in journal.morningOccurrences where occurrence.outcome == .finished {
            let settlement = SunriseTrailSettlementEngine.settle(
                occurrence: occurrence,
                at: occurrence.endedAt ?? date,
                state: journal.sunriseTrail,
                protectedWindDownCount: progress.totalCompletedRuns,
                trackedSheepID: farmState.trackedSheepDefinitionID
            )
            journal.sunriseTrail = settlement.state
            // Commit deterministic Sunrise state before any projection. A
            // crash now reuses the exact fills/outcomes instead of resolving
            // mutable odds or losing a wool/search effect.
            persistence.windDownMorningSettlementJournal = journal
            let fills = journal.sunriseTrail.fills.filter { $0.occurrenceID == occurrence.id }
            for fill in fills {
                let marker = "sunrise:\(occurrence.id.uuidString):fill:\(fill.id.uuidString):projection"
                guard !journal.deliveredEffectIDs.contains(marker) else { continue }
                sheepSearchState.append(fill.outcome)
                farmState.applySunriseTrailFill(fill)
                // Projection stores are independently non-atomic. Persist both
                // before committing this replay marker so a crash retries the
                // same deterministic fill and repairs either missing store.
                persistence.sheepSearchState = sheepSearchState
                persistence.farmState = farmState
                _ = journal.markEffectDelivered(marker)
                persistence.windDownMorningSettlementJournal = journal
            }
            _ = journal.markEffectDelivered("sunrise:\(occurrence.id.uuidString):settled")
            persistence.windDownMorningSettlementJournal = journal
        }
        persistence.sheepSearchState = sheepSearchState
        persistence.farmState = farmState
    }

    private func currentScreenFreeMorningPresentation(
        at date: Date = Date()
    ) -> ScreenFreeMorningPresentation? {
        ScreenFreeMorningPresentationRouting.current(
            occurrences: persistence.windDownMorningSettlementJournal.morningOccurrences,
            at: date
        )
    }

    private func sendWatchState() {
        watch.send(
            WatchMessage(
                type: .focusRunStateUpdate,
                run: run,
                proximity: proximityState,
                screenFreeMorning: currentScreenFreeMorningPresentation()
            )
        )
    }

    private func restoreActiveRunIfNeeded() {
        cancelEmergencyExitChallenge()
        reconcileMorningQuietOccurrences()
        guard var storedRun = persistence.lastRun else { return }
        guard ![.completed, .endedEarly, .setup].contains(storedRun.state) else {
            // A terminal lastRun is deliberately persisted before its Phone
            // Away settlement. If termination happened in that small window,
            // settle it now before returning the receipt to the UI.
            settlePhoneAwayIfNeeded(for: storedRun)
            settleOnboardingPracticeIfNeeded(for: storedRun)
            resolveHiddenWindDownBenefitIfEligible(for: storedRun, at: storedRun.endedAt ?? Date())
            deliverHiddenWindDownBenefitIfNeeded(for: storedRun, at: storedRun.endedAt ?? Date())
            replayTerminalHistory(for: storedRun, at: storedRun.endedAt ?? Date())
            run = storedRun
            return
        }
        // Older builds could leave a timed-out Watch placement run in a waiting state.
        // It is an optional assist, so restore it as a normal timer rather than trapping it.
        if storedRun.guardKind == .watchPlacement,
           storedRun.placementStatus == .unavailable {
            storedRun.state = .running
            persistence.lastRun = storedRun
        }
        run = storedRun
        // Placement evidence is independent from app shielding. Reconcile on every
        // restore so the active screen can explain whether the selected apps are still
        // protected even when the user has not tapped the NFC tag yet.
        reconcileShielding(for: storedRun)
        liveActivity.start(for: storedRun)
        if let activeMorning = persistence.windDownMorningSettlementJournal.morningOccurrences.first(where: { $0.outcome == .active }) {
            liveActivity.startScreenFreeMorning(activeMorning)
        }
        lastLiveActivityPhase = storedRun.nightWatchPhase()
        if Date() >= storedRun.plannedEndAt,
           FocusRunRules.canCompleteSuccessfully(storedRun, demoMode: false) {
            storedRun.state = .completed
            storedRun.completedSuccessfully = true
            storedRun.actualDurationSeconds = storedRun.plannedDurationSeconds
            storedRun.endedAt = Date()
            finish(run: storedRun)
        } else {
            ollieMessage = storedRun.guardKind == .watchPlacement && storedRun.placementStatus == .awaitingConfirmation
                ? "Ollie can try the Watch check again, or you can continue without it."
                : storedRun.isNightWatch ? "Ollie is still keeping the quiet." : "Your phone-away time is still resting."
            scheduleNextBoundaryTimer()
        }
    }

    private func scheduleNextBoundaryTimer() {
        cancelBoundaryTimer(reason: "reschedule")
        guard let run else { return }

        let now = Date()
        let boundary = run.nightWatchPlan?.nextTransition(after: now) ?? run.plannedEndAt
        guard boundary > now else { return }

        let timer = Timer(fire: boundary, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.timer = nil
#if DEBUG
                self?.energyLogger.debug("Boundary timer fired")
#endif
                self?.reconcileSession()
            }
        }
        timer.tolerance = min(1, max(0.1, boundary.timeIntervalSince(now) * 0.01))
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
#if DEBUG
        boundaryTimerScheduleCount += 1
        energyLogger.debug(
            "Boundary timer scheduled count=\(self.boundaryTimerScheduleCount) target=\(boundary, privacy: .public)"
        )
#endif
    }

    private func scheduleNextMorningOccurrenceBoundaryTimer() {
        cancelMorningOccurrenceBoundaryTimer(reason: "reschedule")
        let now = Date()
        let nextBoundary = MorningQuietOccurrenceBoundary.next(
            after: now,
            occurrences: persistence.windDownMorningSettlementJournal.morningOccurrences
        )
        guard let nextBoundary else { return }
        let occurrenceTimer = Timer(fire: nextBoundary, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.morningOccurrenceTimer = nil
                self?.reconcileMorningQuietOccurrences(at: Date())
            }
        }
        occurrenceTimer.tolerance = min(1, max(0.1, nextBoundary.timeIntervalSince(now) * 0.01))
        RunLoop.main.add(occurrenceTimer, forMode: .common)
        morningOccurrenceTimer = occurrenceTimer
    }

    private func cancelBoundaryTimer(reason: String) {
        guard let timer else { return }
        timer.invalidate()
        self.timer = nil
#if DEBUG
        energyLogger.debug("Boundary timer cancelled reason=\(reason, privacy: .public)")
#endif
    }

    private func cancelMorningOccurrenceBoundaryTimer(reason: String) {
        guard let morningOccurrenceTimer else { return }
        morningOccurrenceTimer.invalidate()
        self.morningOccurrenceTimer = nil
    }

    func reconcileSession(at now: Date = Date()) {
        guard var run else { return }
        run.actualDurationSeconds = min(run.plannedDurationSeconds, now.timeIntervalSince(run.startedAt))
        resolveHiddenWindDownBenefitIfEligible(for: run, at: now)
        if now >= run.plannedEndAt,
           FocusRunRules.canCompleteSuccessfully(run, demoMode: false) {
            run.state = .completed
            run.completedSuccessfully = true
            run.actualDurationSeconds = run.plannedDurationSeconds
            run.endedAt = now
            finish(run: run)
            return
        }
        self.run = run
        reconcileShielding(for: run, at: now)
        reconcileOrdinaryScreenFreeMorning(for: run, at: now)
        let phase = run.nightWatchPhase(at: now)
        if let activeMorning = persistence.windDownMorningSettlementJournal.morningOccurrences.first(where: { $0.outcome == .active }) {
            liveActivity.startScreenFreeMorning(activeMorning)
        } else if phase != lastLiveActivityPhase {
            lastLiveActivityPhase = phase
            liveActivity.update(for: run)
        }
        persistActiveRun()
        watch.send(WatchMessage(
            type: .focusRunStateUpdate,
            run: run,
            proximity: proximityState,
            screenFreeMorning: currentScreenFreeMorningPresentation()
        ))
        scheduleNextBoundaryTimer()
    }

    /// Persist the usual Morning at run creation so background termination
    /// cannot manufacture a second occurrence on foreground restore.
    private func ensureOrdinaryScreenFreeMorningOccurrence(for run: FocusRun, at date: Date) {
        guard run.isProgressionEligibleNightWatch, let plan = run.nightWatchPlan else { return }
        var journal = persistence.windDownMorningSettlementJournal
        guard !journal.morningOccurrences.contains(where: {
            $0.linkedWindDownRunID == run.id && $0.scheduledStart == plan.wakeTime
        }) else { return }
        let occurrence = MorningQuietOccurrence(
            id: MorningQuietOccurrenceIdentity.ordinary(for: run.id),
            linkedWindDownRunID: run.id,
            scheduleOccurrenceID: MorningQuietOccurrenceIdentity.ordinary(for: run.id),
            scheduledStart: plan.wakeTime,
            scheduledEnd: plan.protectedUntil,
            outcome: .scheduled,
            liveActivityRequested: run.liveActivityRequested
        )
        let count = journal.morningOccurrences.count
        journal.appendOccurrence(occurrence)
        guard journal.morningOccurrences.count == count + 1 else { return }
        persistence.windDownMorningSettlementJournal = journal
        _ = shielding.reconcile(for: occurrence, at: date)
        notifications.reconcileScreenFreeMorningNotifications(
            occurrences: journal.morningOccurrences,
            now: date
        )
        scheduleNextMorningOccurrenceBoundaryTimer()
    }

    /// The ordinary saved plan still uses the legacy `FocusRun` phase for
    /// timing. The occurrence itself was committed at start; this method only
    /// advances that fixed identity and settles a whole missed window safely.
    private func reconcileOrdinaryScreenFreeMorning(for run: FocusRun, at date: Date) {
        guard run.isProgressionEligibleNightWatch,
              let plan = run.nightWatchPlan,
              date >= plan.wakeTime else { return }
        ensureOrdinaryScreenFreeMorningOccurrence(for: run, at: run.startedAt)
        var journal = persistence.windDownMorningSettlementJournal
        guard let index = journal.morningOccurrences.firstIndex(where: {
            $0.id == MorningQuietOccurrenceIdentity.ordinary(for: run.id)
        }) else { return }
        var occurrence = journal.morningOccurrences[index]
        guard occurrence.outcome == .scheduled || occurrence.outcome == .active else { return }
        if occurrence.outcome == .scheduled {
            occurrence.actualStart = occurrence.scheduledStart
            occurrence.outcome = date >= occurrence.scheduledEnd ? .finished : .active
            occurrence.endedAt = date >= occurrence.scheduledEnd ? occurrence.scheduledEnd : nil
        } else if date >= occurrence.scheduledEnd {
            occurrence.endedAt = occurrence.scheduledEnd
            occurrence.outcome = .finished
        }
        journal.morningOccurrences[index] = occurrence
        if occurrence.outcome == .finished {
            settleFinishedMorningOccurrences(&journal, at: occurrence.endedAt ?? date)
            shielding.clear(occurrenceID: occurrence.id)
        } else {
            _ = shielding.reconcile(for: occurrence, at: date)
        }
        persistence.windDownMorningSettlementJournal = journal
        notifications.reconcileScreenFreeMorningNotifications(
            occurrences: journal.morningOccurrences,
            now: date
        )
        if occurrence.outcome == .active {
            liveActivity.startScreenFreeMorning(occurrence)
        } else {
            liveActivity.finishScreenFreeMorning(occurrence)
        }
        sendWatchState()
        scheduleNextMorningOccurrenceBoundaryTimer()
    }

    /// Materializes an automatic Wind Down that completed while the app was closed.
    /// DeviceActivity can enforce the shield without the app, so the next activation
    /// needs to create the local run and receipt without replaying the full UI flow.
    func reconcileExpiredAutomaticNightWatch(
        plan: NightWatchPlan,
        guardKind: SessionGuardKind,
        startedAt: Date,
        endedAt: Date,
        appShieldingRequested: Bool = true,
        liveActivityRequested: Bool = true,
        runID: UUID? = nil
    ) {
        guard endedAt > startedAt else { return }
        if let run, ![.setup, .completed, .endedEarly].contains(run.state) {
            return
        }
        if run != nil {
            resetToSetup(clearPersistedRun: false, liveActivityCancellationReason: .replaced)
        }
        start(
            configuration: FocusRunConfiguration(
                nightWatchPlan: plan,
                guardKind: guardKind
            ),
            focusAccepted: false,
            startedAt: startedAt,
            autoConfirmPlacement: true,
            appShieldingRequested: appShieldingRequested,
            liveActivityRequested: liveActivityRequested,
            runID: runID
        )
        reconcileSession(at: endedAt)
    }

    private func updateElapsedTime(at date: Date) {
        guard var run else { return }
        run.actualDurationSeconds = min(run.plannedDurationSeconds, date.timeIntervalSince(run.startedAt))
        self.run = run
    }

    private func finish(
        run: FocusRun,
        clearShielding: Bool = true,
        linkedMorningHandoff: Bool = false
    ) {
        // A scene-activation callback, a boundary timer, or a repeated exit can
        // converge on the same terminal run. Persisted rewards and sheep-search
        // outcomes must be settled exactly once.
        guard let currentRun = self.run,
              currentRun.id == run.id,
              ![.completed, .endedEarly, .setup].contains(currentRun.state) else { return }
        cancelEmergencyExitChallenge()
        cancelBoundaryTimer(reason: "finish")
        stopWatchPlacement()
        UIApplication.shared.isIdleTimerDisabled = false
        notifications.cancelRunCompletion()
        // An immediate linked Morning reuses this surface below; ending the
        // Wind Down activity first would race an asynchronous terminal end
        // against the Morning update and can briefly leave both surfaces.
        if !linkedMorningHandoff {
            liveActivity.finish(for: run)
        }
        var finalRun = run
        resolveHiddenWindDownBenefitIfEligible(for: finalRun, at: finalRun.endedAt ?? Date())
        let windDownBenefit = persistence.windDownMorningSettlementJournal.benefit(for: finalRun.id)
        finalRun.briefAccessUseCount = max(
            finalRun.briefAccessUseCount,
            shielding.briefAccessUseCount(for: finalRun)
        )
        let protection = shielding.protectionSummary(
            for: finalRun,
            at: finalRun.endedAt ?? Date()
        )
        if clearShielding { shielding.clear() }
        // The factual early-ending receipt remains early, while a previously
        // entitled Wind Down receives the same settlement exactly once.
        if windDownBenefit != nil {
            // The threshold is factual and monotonic. Once the journal has
            // entitled this run, an authorized terminal path cannot recast it
            // as an early-ended Wind Down in history, receipts, or sharing.
            finalRun.state = .completed
            finalRun.completedSuccessfully = true
            finalRun.endedEarlyReason = nil
        }
        let settlementRun = finalRun
        let reward: RewardItem?
        let nextProgress: UserProgress
        if windDownBenefit != nil {
            var journal = persistence.windDownMorningSettlementJournal
            if journal.benefit(for: finalRun.id)?.deliveredProgress == nil {
                let plannedReward = rewardEngine.generateReward(for: settlementRun, progress: progress)
                let plannedProgress = rewardEngine.updatedProgress(
                    after: settlementRun,
                    current: progress,
                    reward: plannedReward
                )
                _ = journal.persistTerminalProjections(
                    for: finalRun.id,
                    reward: plannedReward,
                    progress: plannedProgress
                )
                persistence.windDownMorningSettlementJournal = journal
            }
            let planned = persistence.windDownMorningSettlementJournal.benefit(for: finalRun.id)
            reward = planned?.deliveredReward
            nextProgress = planned?.deliveredProgress ?? progress
        } else {
            reward = rewardEngine.generateReward(for: settlementRun, progress: progress)
            nextProgress = rewardEngine.updatedProgress(after: settlementRun, current: progress, reward: reward)
        }
        if let reward {
            if !finalRun.earnedRewardIDs.contains(reward.id) {
                finalRun.earnedRewardIDs.append(reward.id)
            }
            if !rewards.contains(where: { $0.id == reward.id }) {
                rewards.insert(reward, at: 0)
            }
            latestReward = reward
        }
        progress = nextProgress
        persistence.progress = progress
        persistence.rewards = rewards
        persistence.lastRun = finalRun
        // Search state is the settlement journal. Write it, including the
        // consumed meter and any outcome, before projecting Farm arrivals.
        // Launch recovery calls the same idempotent helper if termination
        // happened after lastRun but before this write.
        settlePhoneAwayIfNeeded(for: finalRun)
        settleOnboardingPracticeIfNeeded(for: finalRun)
        deliverHiddenWindDownBenefitIfNeeded(for: finalRun, at: finalRun.endedAt ?? Date())
        replayTerminalHistory(for: finalRun, protection: protection, at: finalRun.endedAt ?? Date())
        self.run = finalRun
        if finalRun.nightWatchPlan?.role == .additionalQuiet {
            ollieMessage = finalRun.completedSuccessfully
                ? "Phone Away is complete."
                : "Ollie kept your quiet spot warm."
        } else {
            ollieMessage = finalRun.completedSuccessfully
                ? "Ollie saved your qualifying Wind Down receipt."
                : "Ollie kept your spot warm."
        }
        // A terminal receipt is finite and opened on the phone. Do not expose
        // its still-unread result or reward on Watch transport.
        watch.send(
            WatchMessage(
                type: finalRun.completedSuccessfully ? .rewardEarned : .endFocusRunEarly,
                run: finalRun,
                proximity: proximityState,
                screenFreeMorning: currentScreenFreeMorningPresentation()
            )
        )
        onRunFinished?(finalRun, linkedMorningHandoff)
#if DEBUG
        logResourceState(event: "finish complete")
#endif
    }

    /// `lastRun` is intentionally written before the projections that can
    /// crash independently. Replaying terminal history is idempotent by run
    /// ID/event key, so relaunch repairs that write gap without a second row.
    private func replayTerminalHistory(
        for terminalRun: FocusRun,
        protection: QuietTimeShieldProtectionSummary? = nil,
        at date: Date
    ) {
        let summary = protection ?? shielding.protectionSummary(for: terminalRun, at: date)
        guard let record = terminalRun.nightWatchRecord(
            updatedAt: date,
            shieldedWindDownMinutes: summary.windDownMinutes,
            shieldedMorningQuietMinutes: summary.morningQuietMinutes,
            shieldProtectionEvidence: summary.evidence
        ) else { return }
        persistence.upsertNightWatchRecord(record, now: date)
        recordRitualEvent(
            terminalRun.completedSuccessfully ? .sessionCompleted : .sessionEndedEarly,
            for: terminalRun,
            at: date,
            idempotencyKey: "\(terminalRun.id.uuidString):terminal",
            payload: terminalRun.endedEarlyReason.map { ["reason": $0.rawValue] } ?? [:]
        )
    }

    /// Resolves the deterministic search at the factual 420-minute boundary,
    /// but leaves every visible projection untouched until terminal delivery.
    private func resolveHiddenWindDownBenefitIfEligible(for run: FocusRun, at date: Date) {
        var journal = persistence.windDownMorningSettlementJournal
        guard let settlement = journal.resolveWindDown(run: run, at: date) else { return }
        if settlement.hiddenSearchOutcome == nil {
            let plan = run.nightWatchPlan
            let evidence = SheepSearchEvidence(
                windDownMinutes: run.creditedWindDownMinutes,
                morningQuietMinutes: 0,
                plannedWindDownMinutes: plan?.windDownMinutes ?? run.creditedWindDownMinutes,
                plannedMorningQuietMinutes: 0,
                startedNearSchedule: plan.map {
                    abs(run.startedAt.timeIntervalSince($0.intendedBedtime)) <= 30 * 60
                } ?? false,
                shieldingObserved: false,
                placementConfirmed: run.placementStatus == .confirmed,
                recentProtectedNights: min(12, sheepSearchState.outcomes.suffix(7).filter { $0.result == .found }.count),
                optionalBonusPoints: optionalSheepSearchBonusProvider?() ?? 0,
                trailMapBonusPercentagePoints: 0
            )
            let calculation = SheepSearchEngine.calculate(
                runID: run.id,
                protectedNightNumber: progress.totalCompletedRuns + 1,
                evidence: evidence,
                state: sheepSearchState,
                trackedSheepID: farmState.trackedSheepDefinitionID,
                now: date
            )
            _ = journal.persistHiddenOutcome(calculation.outcome, for: run.id)
        }
        persistence.windDownMorningSettlementJournal = journal
    }

    /// Applies the immutable journal payload after a normal/NFC/emergency
    /// terminal authorization. Replays cannot append another search or Farm
    /// arrival because both the journal marker and projections are idempotent.
    private func deliverHiddenWindDownBenefitIfNeeded(for run: FocusRun, at date: Date) {
        var journal = persistence.windDownMorningSettlementJournal
        guard let settlement = journal.benefit(for: run.id),
              let outcome = settlement.hiddenSearchOutcome else { return }
        if let projectedProgress = settlement.deliveredProgress {
            progress = projectedProgress
            persistence.progress = projectedProgress
        }
        if let projectedReward = settlement.deliveredReward,
           !rewards.contains(where: { $0.id == projectedReward.id }) {
            rewards.insert(projectedReward, at: 0)
            latestReward = projectedReward
            persistence.rewards = rewards
        }
        let marker = "windDown:\(run.id.uuidString):projection"
        if journal.markEffectDelivered(marker) {
            sheepSearchState.append(outcome)
            persistence.sheepSearchState = sheepSearchState
            farmState.recordArrival(outcome)
            persistence.farmState = farmState
            latestSheepSearchOutcome = outcome
        }
        _ = journal.markDelivered(runID: run.id, at: date)
        persistence.windDownMorningSettlementJournal = journal
    }

    private func settlePhoneAwayIfNeeded(for terminalRun: FocusRun) {
        guard let input = PhoneAwaySearchSettlementInput.terminalRun(
            terminalRun,
            protectedWindDownCount: progress.totalCompletedRuns,
            trackedSheepID: farmState.trackedSheepDefinitionID
        ) else { return }

        let settlement = PhoneAwaySearchSettlementEngine.settle(
            input: input,
            state: sheepSearchState
        )
        sheepSearchState = settlement.state
        persistence.sheepSearchState = sheepSearchState

        if let outcome = settlement.outcome {
            farmState.recordArrival(outcome)
            persistence.farmState = farmState
            latestSheepSearchOutcome = outcome
        }
    }

    private func settleOnboardingPracticeIfNeeded(for terminalRun: FocusRun) {
        guard terminalRun.isPractice else { return }
        let result = WelcomeRewardEngine.settlePractice(
            run: terminalRun,
            farm: farmState,
            search: sheepSearchState,
            ledger: persistence.welcomeRewardLedger,
            now: terminalRun.endedAt ?? Date()
        )
        sheepSearchState = result.search
        farmState = result.farm
        persistence.sheepSearchState = result.search
        persistence.farmState = result.farm
        persistence.welcomeRewardLedger = result.ledger
        lastOnboardingPracticeGrantedSheep = result.outcome != nil
        if let outcome = result.outcome {
            latestSheepSearchOutcome = outcome
        }
    }


    func persistActiveRun() {
        persistence.lastRun = run
    }

#if DEBUG
    private func logResourceState(event: String) {
        energyLogger.debug(
            "\(event, privacy: .public) boundaryTimer=\(self.timer != nil) placementTask=\(self.placementTask != nil) placementTimeout=\(self.placementTimeoutTask != nil) nearby=\(self.nearby.isRunning)"
        )
    }
#endif

    func addEvent(_ title: String, detail: String? = nil, severity: EventSeverity = .info) {
        events.insert(SessionEvent(title: title, detail: detail, severity: severity), at: 0)
        events = Array(events.prefix(8))
    }

    private func recordRitualEvent(
        _ kind: RitualEventKind,
        for run: FocusRun,
        at date: Date = Date(),
        idempotencyKey: String? = nil,
        payload: [String: String] = [:]
    ) {
        guard run.isNightWatch else { return }
        persistence.appendRitualEvent(
            RitualEvent(
                runID: run.id,
                occurredAt: date,
                recordedAt: Date(),
                kind: kind,
                source: .observed,
                idempotencyKey: idempotencyKey,
                payload: payload
            )
        )
    }

    private func recordShieldingOutcome(
        _ outcome: QuietTimeShieldingOutcome,
        for run: FocusRun,
        at date: Date = Date()
    ) {
        shieldingState = .from(outcome)
        switch outcome {
        case .disabled:
            break
        case .noSelection:
            recordRitualEvent(
                .shieldActivationFailed,
                for: run,
                at: date,
                idempotencyKey: "\(run.id.uuidString):shield:no-selection",
                payload: ["reason": "noSelection"]
            )
        case .scheduled:
            recordRitualEvent(
                .shieldScheduleRequested,
                for: run,
                at: date,
                idempotencyKey: "\(run.id.uuidString):shield:scheduled"
            )
        case .applied:
            recordRitualEvent(
                .shieldScheduleRequested,
                for: run,
                at: date,
                idempotencyKey: "\(run.id.uuidString):shield:scheduled"
            )
            recordRitualEvent(
                .shieldApplied,
                for: run,
                at: date,
                idempotencyKey: "\(run.id.uuidString):shield:applied:\(run.nightWatchPhase(at: date)?.rawValue ?? "unknown")"
            )
        case .cleared:
            recordRitualEvent(
                .shieldCleared,
                for: run,
                at: date,
                idempotencyKey: "\(run.id.uuidString):shield:cleared:\(run.nightWatchPhase(at: date)?.rawValue ?? "terminal")"
            )
        case .failed(let reason):
            recordRitualEvent(
                .shieldActivationFailed,
                for: run,
                at: date,
                idempotencyKey: "\(run.id.uuidString):shield:failed:\(reason)",
                payload: ["reason": reason]
            )
        }
    }

    func reconcileShielding(for run: FocusRun, at date: Date = Date()) {
        recordShieldingOutcome(
            shielding.reconcile(for: run, at: date),
            for: run,
            at: date
        )
        var reconciledRun = run
        reconciledRun.briefAccessUseCount = max(
            reconciledRun.briefAccessUseCount,
            shielding.briefAccessUseCount(for: reconciledRun)
        )
        if reconciledRun.briefAccessUseCount != run.briefAccessUseCount {
            self.run = reconciledRun
            persistence.lastRun = reconciledRun
        }
        let protection = shielding.protectionSummary(for: run, at: date)
        if let record = reconciledRun.nightWatchRecord(
            updatedAt: date,
            shieldedWindDownMinutes: protection.windDownMinutes,
            shieldedMorningQuietMinutes: protection.morningQuietMinutes,
            shieldProtectionEvidence: protection.evidence,
            briefAccessUseCount: reconciledRun.briefAccessUseCount
        ) {
            persistence.upsertNightWatchRecord(record, now: date)
        }
    }

    func reconcileShieldingNow(for run: FocusRun) {
        reconcileShielding(for: run, at: Date())
    }

    func setLiveActivityEnabled(_ enabled: Bool) {
        liveActivity.setEnabled(enabled)
    }

    private func openingMessage(
        for guardKind: SessionGuardKind,
        role: WindDownOccurrenceRole
    ) -> String {
        if role == .additionalQuiet {
            switch guardKind {
            case .honorTimer: return "Carry the phone to its resting place. Ollie will keep the quiet."
            case .watchPlacement: return "Carry the phone away. Ollie will make one short Watch check."
            case .qrCode: return "Scan your phone-bed code to set the app limits."
            case .nfcTag: return "Tap your Phone Away tag to start Phone Away."
            }
        }
        switch guardKind {
        case .honorTimer: return "Carry the phone to its resting place. Ollie will keep the quiet."
        case .watchPlacement: return "Carry the phone away. Ollie will make one short Watch check."
        case .qrCode: return "Scan your Wind Down code to set the app-access barrier."
        case .nfcTag: return "Tap your Wind Down tag to set the app-access barrier."
        }
    }

    private func handle(_ message: WatchMessage) {
        switch message.type {
        case .nearbyDiscoveryToken:
            receiveNearbyToken(message.tokenData)
        case .watchDistanceReading:
            guard let distance = message.distanceMeters else { return }
            processPlacementReading(ProximityReading(distanceMeters: distance, timestamp: message.sentAt, source: .nearbyInteraction, confidence: .high))
        case .pingPhone:
            pingPhone()
        case .endFocusRunEarly:
            endEarly(source: .watch)
        default:
            break
        }
    }
}
