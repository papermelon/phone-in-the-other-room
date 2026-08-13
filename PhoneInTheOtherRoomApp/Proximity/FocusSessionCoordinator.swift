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

    private let persistence: PersistenceService
    private let rewardEngine = RewardEngine()
    let watch: WatchConnectivityManager
    private let ping = PingService()
    private let notifications = PhoneNotificationService.shared
    private let liveActivity: FocusRunLiveActivityService
    private let shielding: QuietTimeShieldingProviding
    let nearby = NearbyInteractionDistanceProvider()
    private var timer: Timer?
    var placementTask: Task<Void, Never>?
    var placementTimeoutTask: Task<Void, Never>?
    var pairedWatchTokenData: Data?
    private var lastLiveActivityPhase: NightWatchPhase?
    var optionalSheepSearchBonusProvider: (() -> Int)?
    var onPhoneAwayValidated: ((FocusRun) -> Void)?
    /// Lets the owning view model advance the saved routine cursor after a
    /// terminal run without making the coordinator own scheduling policy.
    var onRunFinished: (() -> Void)?
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
        let savedSearchState = persistence.sheepSearchState
        self.sheepSearchState = savedSearchState
        self.latestSheepSearchOutcome = savedSearchState.lastOutcome
        self.farmState = persistence.farmState
        watch.onMessage = { [weak self] message in
            Task { @MainActor in self?.handle(message) }
        }
        watch.currentStateProvider = { [weak self] in
            guard let self else { return nil }
            return WatchMessage(type: .focusRunStateUpdate, run: self.run, proximity: self.proximityState, reward: self.latestReward)
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
                ? "Phone Break started."
                : (newRun.isNightWatch ? "Wind Down started." : "Phone-away time started."),
            detail: focusAccepted ? "System Focus was turned on." : nil
        )
        persistActiveRun()
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
        lastLiveActivityPhase = newRun.nightWatchPhase(at: Date())
        UIApplication.shared.isIdleTimerDisabled = configuration.guardKind == .watchPlacement
        scheduleNextBoundaryTimer()
        watch.send(WatchMessage(type: .startFocusRun, run: newRun, proximity: proximityState))
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
                        ? "Scan your phone-bed code to start Phone Break."
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
                        ? "Phone-bed tag confirmed."
                        : "Phone Break is waiting. Tap the phone-bed tag when it is ready.")
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
                ? "That is not your phone-bed tag. Try again."
                : "That is not your Wind Down tag. Try again."
            recordRitualEvent(.placementValidationFailed, for: run, payload: ["method": "nfcTag"])
            return false
        }
        confirmPlacement(
            &run,
            note: run.nightWatchPlan?.role == .additionalQuiet
                ? "Phone-bed tag tapped"
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
            note: isAdditionalQuiet ? "Continued without a phone-bed tag" : "Continued without a Wind Down tag"
        )
        run.phoneAwayValidatedAt = Date()
        run.state = .running
        self.run = run
        ollieMessage = "Ollie will keep the quiet while your phone rests away."
        addEvent(isAdditionalQuiet ? "Phone Break continued without a tag check." : "Wind Down continued without a tag check.")
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

    func endEarly(reason: EarlyEndReason = .userEnded) {
        guard var run,
              ![.completed, .endedEarly, .setup].contains(run.state) else { return }
        run.state = .endedEarly
        run.endedAt = Date()
        run.actualDurationSeconds = min(run.plannedDurationSeconds, Date().timeIntervalSince(run.startedAt))
        run.endedEarlyReason = reason
        shielding.clear()
        finish(run: run)
    }

    func pingPhone() {
        ping.pingPhone()
        pingPulseCount += 1
        addEvent("Phone heard the whistle.", severity: .success)
    }

    func applicationDidEnterBackground() {
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
        cancelBoundaryTimer(reason: "reset")
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
        liveActivity.endAll(reason: liveActivityCancellationReason)
        shielding.clear()
        watch.send(WatchMessage(type: .focusRunStateUpdate, run: nil, proximity: proximityState))
        if clearPersistedRun { persistence.lastRun = nil }
#if DEBUG
        logResourceState(event: "reset complete")
#endif
    }

    func resetLiveActivityToFreshInstallDefaults() {
        liveActivity.resetToFreshInstallDefaults()
    }

    private func restoreActiveRunIfNeeded() {
        guard var storedRun = persistence.lastRun else { return }
        guard ![.completed, .endedEarly, .setup].contains(storedRun.state) else {
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

    private func cancelBoundaryTimer(reason: String) {
        guard let timer else { return }
        timer.invalidate()
        self.timer = nil
#if DEBUG
        energyLogger.debug("Boundary timer cancelled reason=\(reason, privacy: .public)")
#endif
    }

    func reconcileSession(at now: Date = Date()) {
        guard var run else { return }
        run.actualDurationSeconds = min(run.plannedDurationSeconds, now.timeIntervalSince(run.startedAt))
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
        let phase = run.nightWatchPhase(at: now)
        if phase != lastLiveActivityPhase {
            lastLiveActivityPhase = phase
            liveActivity.update(for: run)
        }
        persistActiveRun()
        watch.send(WatchMessage(type: .focusRunStateUpdate, run: run, proximity: proximityState))
        scheduleNextBoundaryTimer()
    }

    /// Materializes an automatic Wind Down that completed while the app was closed.
    /// DeviceActivity can enforce the shield without the app, so the next activation
    /// needs to create the local run and receipt without replaying the full UI flow.
    func reconcileExpiredAutomaticNightWatch(
        plan: NightWatchPlan,
        guardKind: SessionGuardKind,
        startedAt: Date,
        endedAt: Date,
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

    private func finish(run: FocusRun) {
        // A scene-activation callback, a boundary timer, or a repeated exit can
        // converge on the same terminal run. Persisted rewards and sheep-search
        // outcomes must be settled exactly once.
        guard let currentRun = self.run,
              currentRun.id == run.id,
              ![.completed, .endedEarly, .setup].contains(currentRun.state) else { return }
        cancelBoundaryTimer(reason: "finish")
        stopWatchPlacement()
        UIApplication.shared.isIdleTimerDisabled = false
        notifications.cancelRunCompletion()
        liveActivity.finish(for: run)
        var finalRun = run
        finalRun.briefAccessUseCount = max(
            finalRun.briefAccessUseCount,
            shielding.briefAccessUseCount(for: finalRun)
        )
        let protection = shielding.protectionSummary(
            for: finalRun,
            at: finalRun.endedAt ?? Date()
        )
        shielding.clear()
        let reward = rewardEngine.generateReward(for: finalRun, progress: progress)
        if let reward {
            finalRun.earnedRewardIDs.append(reward.id)
            rewards.insert(reward, at: 0)
            latestReward = reward
        }
        progress = rewardEngine.updatedProgress(after: finalRun, current: progress, reward: reward)
        persistence.progress = progress
        persistence.rewards = rewards
        persistence.lastRun = finalRun
        if finalRun.completedSuccessfully,
           finalRun.nightWatchPlan?.role == .additionalQuiet,
           finalRun.creditedQuietMinutes >= 15 {
            let phoneBreakSearchUnlocked = progress.totalCompletedRuns >= SheepSearchEngine.starterGuaranteeRuns
            sheepSearchState.trailMap.credit(
                runID: finalRun.id,
                minutes: min(75, finalRun.creditedQuietMinutes),
                pendingCap: phoneBreakSearchUnlocked
                    ? SheepTrailMapState.maximumPendingMinutes
                    : SheepTrailMapState.maximumMappedMinutes
            )

            // Phone Breaks bank their own trail meter. Once three protected
            // Wind Downs exist, the next completed Phone Break that fills the
            // meter resolves one separate, deterministic bonus search.
            if phoneBreakSearchUnlocked,
               sheepSearchState.trailMap.isReadyForBonusSearch,
               sheepSearchState.phoneBreakOutcome(for: finalRun.id) == nil {
                sheepSearchState.trailMap.consumeBonusSearchMeter()
                let calculation = SheepSearchEngine.calculatePhoneBreak(
                    runID: finalRun.id,
                    protectedNightNumber: progress.totalCompletedRuns,
                    state: sheepSearchState,
                    trackedSheepID: farmState.trackedSheepDefinitionID,
                    now: finalRun.endedAt ?? Date()
                )
                sheepSearchState.append(calculation.outcome)
                farmState.recordArrival(calculation.outcome)
                persistence.farmState = farmState
                latestSheepSearchOutcome = calculation.outcome
            }
            persistence.sheepSearchState = sheepSearchState
        }
        if finalRun.completedSuccessfully && finalRun.isProgressionEligibleNightWatch {
            let plan = finalRun.nightWatchPlan
            let evidence = SheepSearchEvidence(
                windDownMinutes: finalRun.creditedWindDownMinutes,
                morningQuietMinutes: finalRun.creditedMorningQuietMinutes,
                plannedWindDownMinutes: plan?.windDownMinutes ?? finalRun.creditedWindDownMinutes,
                plannedMorningQuietMinutes: plan?.morningQuietMinutes ?? finalRun.creditedMorningQuietMinutes,
                startedNearSchedule: plan.map {
                    abs(finalRun.startedAt.timeIntervalSince($0.intendedBedtime)) <= 30 * 60
                } ?? false,
                shieldingObserved: protection.evidence == .observed,
                placementConfirmed: finalRun.placementStatus == .confirmed,
                recentProtectedNights: min(12, sheepSearchState.outcomes.suffix(7).filter { $0.result == .found }.count),
                optionalBonusPoints: optionalSheepSearchBonusProvider?() ?? 0,
                // Retained in the Codable evidence contract for old notes only.
                // New Wind Down searches never borrow Phone Break meter progress.
                trailMapBonusPercentagePoints: 0
            )
            let calculation = SheepSearchEngine.calculate(
                runID: finalRun.id,
                protectedNightNumber: progress.totalCompletedRuns,
                evidence: evidence,
                state: sheepSearchState,
                trackedSheepID: farmState.trackedSheepDefinitionID,
                now: finalRun.endedAt ?? Date()
            )
            sheepSearchState.append(calculation.outcome)
            persistence.sheepSearchState = sheepSearchState
            farmState.recordArrival(calculation.outcome)
            persistence.farmState = farmState
            latestSheepSearchOutcome = calculation.outcome
        }
        if let record = finalRun.nightWatchRecord(
            updatedAt: finalRun.endedAt ?? Date(),
            shieldedWindDownMinutes: protection.windDownMinutes,
            shieldedMorningQuietMinutes: protection.morningQuietMinutes,
            shieldProtectionEvidence: protection.evidence
        ) {
            persistence.upsertNightWatchRecord(record, now: finalRun.endedAt ?? Date())
            recordRitualEvent(
                finalRun.completedSuccessfully ? .sessionCompleted : .sessionEndedEarly,
                for: finalRun,
                at: finalRun.endedAt ?? Date(),
                idempotencyKey: "\(finalRun.id.uuidString):terminal",
                payload: finalRun.endedEarlyReason.map { ["reason": $0.rawValue] } ?? [:]
            )
        }
        self.run = finalRun
        if finalRun.nightWatchPlan?.role == .additionalQuiet {
            ollieMessage = finalRun.completedSuccessfully
                ? "Phone Break is complete."
                : "Ollie kept your quiet spot warm."
        } else {
            ollieMessage = finalRun.completedSuccessfully
                ? "The phone slept away while both edges of the night stayed quiet."
                : "Ollie kept your spot warm."
        }
        watch.send(WatchMessage(type: finalRun.completedSuccessfully ? .rewardEarned : .endFocusRunEarly, run: finalRun, proximity: proximityState, reward: reward))
        onRunFinished?()
#if DEBUG
        logResourceState(event: "finish complete")
#endif
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
            case .nfcTag: return "Tap your phone-bed tag to start Phone Break."
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
            guard run?.guardKind != .nfcTag else {
                addEvent(
                    run?.nightWatchPlan?.role == .additionalQuiet ? "Phone-bed tag needed." : "Wind Down tag needed.",
                    detail: run?.nightWatchPlan?.role == .additionalQuiet
                        ? "Use the iPhone and tap the registered tag to end Phone Break."
                        : "Use the iPhone and tap the registered tag to end Wind Down."
                )
                if let run {
                    watch.send(
                        WatchMessage(
                            type: .focusRunStateUpdate,
                            run: run,
                            proximity: proximityState
                        )
                    )
                }
                return
            }
            endEarly()
        default:
            break
        }
    }
}
