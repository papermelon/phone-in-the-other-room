import Foundation
import UIKit

private enum DistanceCheckReason: Equatable {
    case startup
    case scheduled
    case manual
    case remoteManual

    var isUserRequested: Bool {
        self == .manual || self == .remoteManual
    }

    var title: String {
        switch self {
        case .startup: return "Starting distance link."
        case .scheduled: return "Ollie is checking the trail."
        case .manual, .remoteManual: return "Checking phone distance."
        }
    }
}

@MainActor
final class ProximitySessionCoordinator: ObservableObject {
    @Published var run: FocusRun?
    @Published var proximityState: ProximityState = .initial
    @Published var events: [SessionEvent] = []
    @Published var latestReward: RewardItem?
    @Published var progress: UserProgress
    @Published var rewards: [RewardItem]
    @Published var pingPulseCount = 0
    @Published var ollieMessage = "Open the Watch app before sending Ollie out."

    private var thresholds: ThresholdProfile
    private let persistence: PersistenceService
    private let classifier: ProximityClassifier
    private let rewardEngine = RewardEngine()
    private let watch = WatchConnectivityManager.shared
    private let ping = PingService()
    private let nearby = NearbyInteractionDistanceProvider()
    private var timer: Timer?
    private var distanceTask: Task<Void, Never>?
    private var distanceCheckWindowTask: Task<Void, Never>?
    private var sampledDistanceCheckTask: Task<Void, Never>?
    private var nearbyTokenRetryTask: Task<Void, Never>?
    private var pairedWatchTokenData: Data?
    private var sentNearbyTokenData: Data?
    private var sentNearbyTokenAcknowledged = false
    private var activeDistanceCheckID: UUID?
    private var activeDistanceCheckReason: DistanceCheckReason?
    private var activeDistanceCheckHasResult = false
    private var activeDistanceCheckWarned = false
    private var activeCloseSampleCount = 0
    private var demoMode = false
    private let nearbyTokenRetrySeconds: TimeInterval = 2
    private let nearbyTokenRetryLimit = 6

    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence
        self.thresholds = persistence.thresholds
        self.classifier = ProximityClassifier(thresholds: persistence.thresholds)
        self.progress = persistence.progress
        self.rewards = persistence.rewards
        watch.onMessage = { [weak self] message in
            Task { @MainActor in self?.handle(message) }
        }
        watch.currentStateProvider = { [weak self] in
            guard let self else { return nil }
            return WatchMessage(type: .focusRunStateUpdate, run: self.run, proximity: self.proximityState, reward: self.latestReward)
        }
    }

    var remainingSeconds: TimeInterval {
        guard let run else { return 0 }
        return max(0, run.plannedEndAt.timeIntervalSince(Date()))
    }

    var elapsedSeconds: TimeInterval {
        guard let run else { return 0 }
        return Date().timeIntervalSince(run.startedAt)
    }

    func start(duration: TimeInterval, demoMode: Bool, focusAccepted: Bool) {
        self.demoMode = demoMode
        let started = Date()
        var run = FocusRun(plannedDurationSeconds: duration, startedAt: started, state: .placementGrace)
        run.actualDurationSeconds = 0
        self.run = run
        latestReward = nil
        proximityState = demoMode ? ProximityState(bucket: .demo, distanceMeters: 1.0, confidence: .medium, source: .demo, lastUpdated: started, statusText: ProximityBucket.demo.label, detailText: "Use the slider to send Ollie toward the focus pasture.") : .initial
        ollieMessage = demoMode ? "Use the slider to practice a Focus Run." : "Ollie is waking a short distance check."
        addEvent("Run started.", detail: focusAccepted ? "Focus prompt accepted." : "Focus skipped.", severity: .info)
        addEvent("Put your phone in the other room.", severity: .info)
        UIApplication.shared.isIdleTimerDisabled = true
        beginDistanceCheck(reason: .startup)
        watch.send(WatchMessage(type: .startFocusRun, run: run, proximity: proximityState))
        startTimer()
    }

    func updateDemoDistance(_ distance: Double) {
        let reading = ProximityReading(distanceMeters: distance, source: .demo, confidence: .medium)
        process(reading: reading, messageType: .demoDistanceUpdate, demoDistance: distance)
    }

    func endEarly(reason: EarlyEndReason = .userEnded) {
        guard var run else { return }
        run.state = .endedEarly
        run.endedAt = Date()
        run.actualDurationSeconds = run.endedAt?.timeIntervalSince(run.startedAt) ?? elapsedSeconds
        run.endedEarlyReason = reason
        finish(run: run)
    }

    func pingPhone() {
        ping.pingPhone()
        pingPulseCount += 1
        addEvent("Phone heard the whistle.", severity: .success)
    }

    func requestDistanceCheck() {
        guard run != nil, !demoMode else { return }
        beginDistanceCheck(reason: .manual)
    }

    func resetToSetup() {
        timer?.invalidate()
        timer = nil
        cancelDistanceCheckTasks(sendEndMessage: true)
        pairedWatchTokenData = nil
        sentNearbyTokenData = nil
        sentNearbyTokenAcknowledged = false
        UIApplication.shared.isIdleTimerDisabled = false
        run = nil
        latestReward = nil
        proximityState = .initial
        ollieMessage = "Open the Watch app before sending Ollie out."
        addEvent("Ollie is waiting at the gate.", severity: .info)
    }

    func calibrateSameRoom() {
        thresholds.sameRoomMaxMeters = max(3.0, proximityState.distanceMeters ?? thresholds.sameRoomMaxMeters)
        persistence.thresholds = thresholds
        addEvent("Same-room calibration saved.", severity: .info)
    }

    func calibrateOtherRoom() {
        thresholds.otherRoomMinMeters = max(6.0, proximityState.distanceMeters ?? thresholds.otherRoomMinMeters)
        persistence.thresholds = thresholds
        addEvent("Other-room calibration saved.", severity: .info)
    }

    private func process(reading: ProximityReading, messageType: WatchMessageType, demoDistance: Double? = nil) {
        guard var run else { return }
        run.proximityHistory.append(reading)
        run.proximityHistory = Array(run.proximityHistory.suffix(16))
        let context = ProximityClassifierContext(now: Date(), watchReachable: watch.isReachable, nearbySupported: demoMode || nearby.isSupported, demoMode: demoMode, currentRunState: run.state, plannedEndAt: run.plannedEndAt, phoneAwayValidated: run.phoneAwayValidatedAt != nil)
        proximityState = classifier.classify(readings: run.proximityHistory, previous: proximityState, context: context)

        if let reason = activeDistanceCheckReason, let distance = reading.distanceMeters {
            let firstResultForCheck = !activeDistanceCheckHasResult
            if handleDistanceCheckReading(distance: distance, reason: reason, firstResult: firstResultForCheck, now: context.now, run: &run) {
                return
            }
        }

        if run.state == .placementGrace && context.now.timeIntervalSince(run.startedAt) >= FocusRunRules.closeReturnCheckDelaySeconds {
            run.state = .waitingForPhoneAway
            addEvent("Ollie is still waiting for the phone to reach the pasture.", severity: .info)
        }

        if run.phoneAwayValidatedAt == nil && classifier.shouldValidatePhoneAway(readings: run.proximityHistory, state: proximityState) {
            run.phoneAwayValidatedAt = Date()
            run.state = .running
            addEvent("Phone entered the focus pasture.", severity: .success)
            addEvent("Ollie is guarding your focus.", severity: .success)
        }

        self.run = run
        watch.send(WatchMessage(type: messageType, run: run, proximity: proximityState, demoDistance: demoDistance))
    }

    private func handleDistanceCheckReading(distance: Double, reason: DistanceCheckReason, firstResult: Bool, now: Date, run: inout FocusRun) -> Bool {
        activeDistanceCheckHasResult = true
        let afterGrace = now.timeIntervalSince(run.startedAt) >= FocusRunRules.closeReturnCheckDelaySeconds

        if afterGrace && reason != .startup {
            if distance < FocusRunRules.closeReturnFailDistanceMeters {
                activeCloseSampleCount += 1
                issueCloseWarningIfNeeded(distance: distance, now: now, run: &run)
            } else {
                activeCloseSampleCount = 0
                if run.state == .warningPhoneTooClose {
                    run.state = .running
                    addEvent("Phone moved away again.", detail: "Ollie found enough room to keep the run going.", severity: .success)
                    ollieMessage = "Nice save. Keep the phone away and stay with the work."
                }
            }

            if run.warningCount > FocusRunRules.allowedCloseWarnings && activeCloseSampleCount >= FocusRunRules.requiredCloseSamplesForCheck {
                run.state = .endedEarly
                run.endedAt = now
                run.actualDurationSeconds = now.timeIntervalSince(run.startedAt)
                run.endedEarlyReason = .phoneReturnedTooSoon
                addEvent("Phone returned to the Watch.", detail: "The phone stayed under \(formattedDistance(FocusRunRules.closeReturnFailDistanceMeters))m after \(FocusRunRules.allowedCloseWarnings) warnings.", severity: .warning)
                ollieMessage = "Ollie found the phone too close. This Focus Run ended early."
                finish(run: run)
                return true
            }
        }

        guard firstResult else { return false }
        let distanceText = formattedDistance(distance)
        if distance < FocusRunRules.closeReturnFailDistanceMeters, afterGrace && reason != .startup {
            addEvent("Ollie is still checking.", detail: "Distance check saw \(distanceText)m. Move the phone farther away.", severity: .warning)
        } else {
            switch reason {
            case .startup:
                addEvent("Distance link active.", detail: "Live reading: \(distanceText)m.", severity: .success)
                ollieMessage = "Ollie has the trail. Put the phone down and step away."
            case .scheduled:
                addEvent("Ollie checked the trail.", detail: "Phone is \(distanceText)m away. Keep going.", severity: .success)
                ollieMessage = "Ollie checked in. Your phone is still away."
            case .manual, .remoteManual:
                addEvent("Distance check complete.", detail: "Phone is \(distanceText)m away.", severity: .success)
                ollieMessage = "Distance check complete. Keep the phone parked and keep going."
            }
        }
        return false
    }

    private func issueCloseWarningIfNeeded(distance: Double, now: Date, run: inout FocusRun) {
        guard !activeDistanceCheckWarned else { return }
        activeDistanceCheckWarned = true
        run.warningCount += 1
        run.state = .warningPhoneTooClose
        let warningsLeft = max(0, FocusRunRules.allowedCloseWarnings - run.warningCount)
        let warningText = warningsLeft == 0 ? "Final warning before this run ends." : "\(warningsLeft) warning\(warningsLeft == 1 ? "" : "s") left before Ollie ends the run."
        addEvent("Phone is too close.", detail: "Fresh distance: \(formattedDistance(distance))m. \(warningText)", severity: .warning)
        ollieMessage = "Phone is close. Move it away now to keep this Focus Run alive."
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard var run else { return }
        if Date() >= run.plannedEndAt && run.state != .completed && run.state != .endedEarly {
            guard FocusRunRules.canCompleteSuccessfully(run, demoMode: demoMode) else {
                run.actualDurationSeconds = min(run.plannedDurationSeconds, Date().timeIntervalSince(run.startedAt))
                run.state = .waitingForPhoneAway
                self.run = run
                ollieMessage = "Ollie still needs one confirmed phone-away reading before this run can finish."
                watch.send(WatchMessage(type: .focusRunStateUpdate, run: run, proximity: proximityState))
                return
            }
            run.state = .completed
            run.completedSuccessfully = true
            run.actualDurationSeconds = run.plannedDurationSeconds
            run.endedAt = Date()
            finish(run: run)
            return
        }
        if let latestReading = run.proximityHistory.last, shouldFailForCloseReturn(reading: latestReading, run: run, now: Date()) {
            run.state = .endedEarly
            run.endedAt = Date()
            run.actualDurationSeconds = run.endedAt?.timeIntervalSince(run.startedAt) ?? elapsedSeconds
            run.endedEarlyReason = .phoneReturnedTooSoon
            addEvent("Phone returned to the Watch.", detail: "Distance stayed below \(formattedDistance(FocusRunRules.closeReturnFailDistanceMeters))m after repeated warnings.", severity: .warning)
            finish(run: run)
            return
        }
        if run.state == .placementGrace && Date().timeIntervalSince(run.startedAt) >= FocusRunRules.closeReturnCheckDelaySeconds {
            run.state = .waitingForPhoneAway
            addEvent("Ollie is still waiting for the phone to reach the pasture.", severity: .info)
        }
        run.actualDurationSeconds = min(run.plannedDurationSeconds, Date().timeIntervalSince(run.startedAt))
        self.run = run
        watch.send(WatchMessage(type: .focusRunStateUpdate, run: run, proximity: proximityState))
    }

    private func shouldFailForCloseReturn(reading: ProximityReading, run: FocusRun, now: Date) -> Bool {
        guard activeDistanceCheckID != nil, activeDistanceCheckReason != .startup else { return false }
        guard run.state != .completed && run.state != .endedEarly else { return false }
        guard now < run.plannedEndAt else { return false }
        guard now.timeIntervalSince(run.startedAt) >= FocusRunRules.closeReturnCheckDelaySeconds else { return false }
        guard let distance = reading.distanceMeters else { return false }
        guard now.timeIntervalSince(reading.timestamp) <= thresholds.staleAfterSeconds else { return false }
        return run.warningCount > FocusRunRules.allowedCloseWarnings && distance < FocusRunRules.closeReturnFailDistanceMeters && activeCloseSampleCount >= FocusRunRules.requiredCloseSamplesForCheck
    }

    private func finish(run: FocusRun) {
        timer?.invalidate()
        timer = nil
        cancelDistanceCheckTasks(sendEndMessage: true)
        pairedWatchTokenData = nil
        sentNearbyTokenData = nil
        sentNearbyTokenAcknowledged = false
        UIApplication.shared.isIdleTimerDisabled = false
        var finalRun = run
        let reward = rewardEngine.generateReward(for: finalRun, progress: progress, demoMode: demoMode)
        if let reward {
            finalRun.earnedRewardIDs.append(reward.id)
            rewards.insert(reward, at: 0)
            latestReward = reward
            addEvent(finalRun.completedSuccessfully ? "Ollie brought back a letter." : "Ollie left a muddy paw print.", severity: finalRun.completedSuccessfully ? .success : .info)
        }
        progress = rewardEngine.updatedProgress(after: finalRun, current: progress, reward: reward)
        persistence.progress = progress
        persistence.rewards = rewards
        persistence.lastRun = finalRun
        self.run = finalRun
        ollieMessage = finalRun.completedSuccessfully ? "Ollie brought the run home." : "Ollie came back early."
        addEvent(finalRun.completedSuccessfully ? "Run complete." : "Ollie came back early.", severity: finalRun.completedSuccessfully ? .success : .warning)
        watch.send(WatchMessage(type: finalRun.completedSuccessfully ? .rewardEarned : .endFocusRunEarly, run: finalRun, proximity: proximityState, reward: reward))
    }

    private func addEvent(_ title: String, detail: String? = nil, severity: EventSeverity = .info) {
        events.insert(SessionEvent(title: title, detail: detail, severity: severity), at: 0)
        events = Array(events.prefix(8))
    }

    private func handle(_ message: WatchMessage) {
        switch message.type {
        case .nearbyDiscoveryToken:
            guard message.isFreshRealtimeMessage(for: run) else { return }
            receiveNearbyToken(message.tokenData)
        case .nearbyDiscoveryTokenAcknowledged:
            guard message.isFreshRealtimeMessage(for: run) else { return }
            handleNearbyTokenAcknowledged(message.tokenData)
        case .distanceCheckRequest:
            guard message.isFreshRealtimeMessage(for: run) else { return }
            beginDistanceCheck(reason: .remoteManual)
        case .watchDistanceReading:
            handleWatchDistanceReading(message)
        case .pingPhone:
            pingPhone()
        case .pingWatch:
            watch.send(WatchMessage(type: .focusRunStateUpdate, run: run, proximity: proximityState, reward: latestReward))
        case .endFocusRunEarly:
            endEarly(reason: .userEnded)
        default:
            break
        }
    }

    private func handleWatchDistanceReading(_ message: WatchMessage) {
        guard activeDistanceCheckID != nil else { return }
        guard message.isFreshRealtimeMessage(for: run) else { return }
        process(
            reading: ProximityReading(
                distanceMeters: message.distanceMeters,
                timestamp: message.sentAt,
                source: .nearbyInteraction,
                confidence: message.distanceMeters == nil ? .low : .high
            ),
            messageType: .proximityStateUpdate
        )
    }

    private func beginDistanceCheck(reason: DistanceCheckReason) {
        guard let run, !demoMode else { return }
        guard run.state != .completed && run.state != .endedEarly else { return }
        if activeDistanceCheckID != nil, reason == .scheduled { return }

        sampledDistanceCheckTask?.cancel()
        sampledDistanceCheckTask = nil

        let checkID = UUID()
        activeDistanceCheckID = checkID
        activeDistanceCheckReason = reason
        activeDistanceCheckHasResult = false
        activeDistanceCheckWarned = false
        activeCloseSampleCount = 0

        let now = Date()
        proximityState = ProximityState(
            bucket: .waitingForDistance,
            distanceMeters: nil,
            confidence: .low,
            source: .watchConnectivity,
            lastUpdated: now,
            statusText: reason.title,
            detailText: reason.isUserRequested ? "Ollie is waking a short UWB check now." : "Ollie is waking a short UWB check to save battery."
        )
        ollieMessage = reason.isUserRequested ? "Ollie is checking the phone distance now." : "Ollie will check the phone briefly, then rest the distance link."
        addEvent(reason.title, detail: "Keep both apps open while Ollie gets a fresh reading.", severity: .info)
        watch.send(WatchMessage(type: .distanceCheckRequest, run: run, proximity: proximityState))
        watch.send(WatchMessage(type: .proximityStateUpdate, run: run, proximity: proximityState))
        startNearbyInteraction()
        scheduleDistanceCheckWindowEnd(id: checkID, after: distanceCheckWindowSeconds(for: reason))
    }

    private func distanceCheckWindowSeconds(for reason: DistanceCheckReason) -> TimeInterval {
        switch reason {
        case .startup:
            return FocusRunRules.startupDistanceCheckWindowSeconds
        case .scheduled:
            return FocusRunRules.scheduledDistanceCheckWindowSeconds
        case .manual, .remoteManual:
            return FocusRunRules.manualDistanceCheckWindowSeconds
        }
    }

    private func scheduleDistanceCheckWindowEnd(id: UUID, after seconds: TimeInterval) {
        distanceCheckWindowTask?.cancel()
        distanceCheckWindowTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.finishDistanceCheckWindow(id: id)
        }
    }

    private func finishDistanceCheckWindow(id: UUID) {
        guard activeDistanceCheckID == id else { return }
        if !activeDistanceCheckHasResult {
            addEvent("Distance check timed out.", detail: "Open the Watch app and try Check Distance if this repeats.", severity: .warning)
            ollieMessage = "Ollie could not get a fresh distance reading. Keep the Watch app open for the next check."
        }
        distanceCheckWindowTask = nil
        stopActiveDistanceCheck(sendEndMessage: true)
        scheduleNextSampledDistanceCheckIfNeeded()
    }

    private func scheduleNextSampledDistanceCheckIfNeeded() {
        sampledDistanceCheckTask?.cancel()
        sampledDistanceCheckTask = nil
        guard let run, !demoMode else { return }
        guard run.state != .completed && run.state != .endedEarly else { return }
        let remaining = run.plannedEndAt.timeIntervalSince(Date())
        guard remaining > FocusRunRules.scheduledDistanceCheckWindowSeconds + 5 else { return }

        let upperDelay = min(FocusRunRules.sampledCheckMaximumDelaySeconds, max(5, remaining - FocusRunRules.scheduledDistanceCheckWindowSeconds))
        let lowerDelay = min(FocusRunRules.sampledCheckMinimumDelaySeconds, upperDelay)
        let delay = lowerDelay == upperDelay ? lowerDelay : TimeInterval.random(in: lowerDelay...upperDelay)

        sampledDistanceCheckTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.beginDistanceCheck(reason: .scheduled)
        }
    }

    private func cancelDistanceCheckTasks(sendEndMessage: Bool) {
        distanceCheckWindowTask?.cancel()
        distanceCheckWindowTask = nil
        sampledDistanceCheckTask?.cancel()
        sampledDistanceCheckTask = nil
        stopActiveDistanceCheck(sendEndMessage: sendEndMessage)
    }

    private func stopActiveDistanceCheck(sendEndMessage: Bool) {
        distanceTask?.cancel()
        distanceTask = nil
        nearbyTokenRetryTask?.cancel()
        nearbyTokenRetryTask = nil
        nearby.stop()
        pairedWatchTokenData = nil
        sentNearbyTokenData = nil
        sentNearbyTokenAcknowledged = false
        activeDistanceCheckID = nil
        activeDistanceCheckReason = nil
        activeDistanceCheckHasResult = false
        activeDistanceCheckWarned = false
        activeCloseSampleCount = 0
        if sendEndMessage {
            watch.send(WatchMessage(type: .distanceCheckEnded, run: run, proximity: proximityState))
        }
    }

    private func startNearbyInteraction() {
        guard !demoMode else { return }
        if distanceTask != nil {
            sendNearbyToken()
            return
        }
        distanceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.nearby.start()
                if self.nearby.isSupported {
                    self.sendNearbyToken()
                } else {
                    self.process(reading: ProximityReading(distanceMeters: nil, source: .fallback, confidence: .low), messageType: .proximityStateUpdate)
                    self.addEvent("Nearby Interaction unsupported.", detail: "This device cannot produce precise distance readings for this run.", severity: .warning)
                    self.ollieMessage = "Phone distance is unavailable on this setup."
                }

                for await reading in self.nearby.readings {
                    if Task.isCancelled { break }
                    self.process(reading: reading, messageType: .proximityStateUpdate)
                }
            } catch {
                self.addEvent("Nearby Interaction failed.", detail: error.localizedDescription, severity: .warning)
                self.ollieMessage = "Distance check failed. Try reopening the Watch app and checking again."
            }
        }
    }

    private func receiveNearbyToken(_ tokenData: Data?) {
        guard let tokenData, !demoMode else { return }
        acknowledgeNearbyToken(tokenData)
        guard run != nil else { return }
        if activeDistanceCheckID == nil {
            beginDistanceCheck(reason: .remoteManual)
        }
        if let pairedWatchTokenData, pairedWatchTokenData == tokenData { return }
        pairedWatchTokenData = tokenData
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await self.nearby.start()
            self.nearby.run(withTokenData: tokenData)
            self.addEvent("Watch distance token paired.", severity: .success)
            self.sendNearbyToken()
        }
    }

    private func acknowledgeNearbyToken(_ tokenData: Data) {
        watch.send(WatchMessage(type: .nearbyDiscoveryTokenAcknowledged, run: run, proximity: proximityState, tokenData: tokenData))
    }

    private func handleNearbyTokenAcknowledged(_ tokenData: Data?) {
        guard let tokenData, let sentNearbyTokenData, tokenData == sentNearbyTokenData else { return }
        sentNearbyTokenAcknowledged = true
        nearbyTokenRetryTask?.cancel()
        nearbyTokenRetryTask = nil
    }

    private func sendNearbyToken() {
        guard let tokenData = nearby.discoveryTokenData() else { return }
        if sentNearbyTokenData.map({ $0 != tokenData }) ?? true {
            sentNearbyTokenData = tokenData
            sentNearbyTokenAcknowledged = false
        }
        let message = WatchMessage(type: .nearbyDiscoveryToken, run: run, proximity: proximityState, tokenData: tokenData)
        watch.send(message)
        startNearbyTokenRetry(tokenData: tokenData, message: message)
    }

    private func startNearbyTokenRetry(tokenData: Data, message: WatchMessage) {
        nearbyTokenRetryTask?.cancel()
        nearbyTokenRetryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for attempt in 1...self.nearbyTokenRetryLimit {
                try? await Task.sleep(for: .seconds(self.nearbyTokenRetrySeconds))
                guard !Task.isCancelled else { return }
                guard let sentNearbyTokenData = self.sentNearbyTokenData else { return }
                guard self.activeDistanceCheckID != nil, sentNearbyTokenData == tokenData, !self.sentNearbyTokenAcknowledged else { return }
                self.watch.send(message)
                if attempt == 2 {
                    self.addEvent("Retrying distance token.", detail: "Open the Watch app if distance stays waiting.", severity: .info)
                }
            }
        }
    }

    private func formattedDistance(_ distance: Double) -> String {
        String(format: "%.1f", distance)
    }
}
