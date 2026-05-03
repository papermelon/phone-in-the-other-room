import Foundation
import UIKit

@MainActor
final class ProximitySessionCoordinator: ObservableObject {
    @Published var run: FocusRun?
    @Published var proximityState: ProximityState = .initial
    @Published var events: [SessionEvent] = []
    @Published var latestReward: RewardItem?
    @Published var progress: UserProgress
    @Published var rewards: [RewardItem]
    @Published var pingPulseCount = 0

    private var thresholds: ThresholdProfile
    private let persistence: PersistenceService
    private let classifier: ProximityClassifier
    private let rewardEngine = RewardEngine()
    private let watch = WatchConnectivityManager.shared
    private let ping = PingService()
    private let nearby = NearbyInteractionDistanceProvider()
    private var timer: Timer?
    private var distanceTask: Task<Void, Never>?
    private var pairedWatchTokenData: Data?
    private var sentNearbyTokenData: Data?
    private var demoMode = false
    private let closeReturnFailDistanceMeters = 0.3
    private let closeReturnCheckDelaySeconds: TimeInterval = 20

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
        addEvent("Run started.", detail: focusAccepted ? "Focus prompt accepted." : "Focus skipped.", severity: .info)
        addEvent("Put your phone in the other room.", severity: .info)
        UIApplication.shared.isIdleTimerDisabled = true
        startNearbyInteraction()
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

    func resetToSetup() {
        timer?.invalidate()
        timer = nil
        distanceTask?.cancel()
        distanceTask = nil
        nearby.stop()
        pairedWatchTokenData = nil
        sentNearbyTokenData = nil
        UIApplication.shared.isIdleTimerDisabled = false
        run = nil
        latestReward = nil
        proximityState = .initial
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

        if shouldFailForCloseReturn(reading: reading, run: run, now: context.now) {
            run.state = .endedEarly
            run.endedAt = context.now
            run.actualDurationSeconds = context.now.timeIntervalSince(run.startedAt)
            run.endedEarlyReason = .phoneReturnedTooSoon
            run.warningCount += 1
            addEvent("Phone returned to the Watch.", detail: "Distance dropped below \(closeReturnFailDistanceMeters)m after the first \(Int(closeReturnCheckDelaySeconds)) seconds.", severity: .warning)
            finish(run: run)
            return
        }

        if run.state == .placementGrace && context.now.timeIntervalSince(run.startedAt) >= closeReturnCheckDelaySeconds {
            run.state = .running
            addEvent("Ollie is guarding your focus.", severity: .success)
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

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard var run else { return }
        if Date() >= run.plannedEndAt && run.state != .completed && run.state != .endedEarly {
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
            run.warningCount += 1
            addEvent("Phone returned to the Watch.", detail: "Distance dropped below \(closeReturnFailDistanceMeters)m after the first \(Int(closeReturnCheckDelaySeconds)) seconds.", severity: .warning)
            finish(run: run)
            return
        }
        if run.state == .placementGrace && Date().timeIntervalSince(run.startedAt) >= closeReturnCheckDelaySeconds {
            run.state = .running
            addEvent("Ollie is guarding your focus.", severity: .success)
        }
        run.actualDurationSeconds = min(run.plannedDurationSeconds, Date().timeIntervalSince(run.startedAt))
        self.run = run
        watch.send(WatchMessage(type: .focusRunStateUpdate, run: run, proximity: proximityState))
    }

    private func shouldFailForCloseReturn(reading: ProximityReading, run: FocusRun, now: Date) -> Bool {
        guard run.state != .completed && run.state != .endedEarly else { return false }
        guard now < run.plannedEndAt else { return false }
        guard now.timeIntervalSince(run.startedAt) >= closeReturnCheckDelaySeconds else { return false }
        guard let distance = reading.distanceMeters else { return false }
        guard now.timeIntervalSince(reading.timestamp) <= thresholds.staleAfterSeconds else { return false }
        return distance < closeReturnFailDistanceMeters
    }

    private func finish(run: FocusRun) {
        timer?.invalidate()
        timer = nil
        distanceTask?.cancel()
        distanceTask = nil
        nearby.stop()
        pairedWatchTokenData = nil
        sentNearbyTokenData = nil
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
            receiveNearbyToken(message.tokenData)
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

    private func startNearbyInteraction() {
        guard !demoMode else { return }
        distanceTask?.cancel()
        distanceTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.nearby.start()
                if self.nearby.isSupported {
                    self.addEvent("Nearby Interaction ready.", detail: "Waiting for the Watch distance token.", severity: .info)
                    self.sendNearbyToken()
                } else {
                    self.process(reading: ProximityReading(distanceMeters: nil, source: .fallback, confidence: .low), messageType: .proximityStateUpdate)
                    self.addEvent("Nearby Interaction unsupported.", detail: "iPhone 16 Pro and Apple Watch Series 9 should support precise distance; keep both apps open and check permissions.", severity: .warning)
                }

                for await reading in self.nearby.readings {
                    if Task.isCancelled { break }
                    self.process(reading: reading, messageType: .proximityStateUpdate)
                }
            } catch {
                self.addEvent("Nearby Interaction failed.", detail: error.localizedDescription, severity: .warning)
            }
        }
    }

    private func receiveNearbyToken(_ tokenData: Data?) {
        guard let tokenData, !demoMode else { return }
        guard pairedWatchTokenData != tokenData else { return }
        pairedWatchTokenData = tokenData
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await self.nearby.start()
            self.nearby.run(withTokenData: tokenData)
            self.addEvent("Watch distance token paired.", severity: .success)
            self.sendNearbyToken()
        }
    }

    private func sendNearbyToken() {
        guard let tokenData = nearby.discoveryTokenData() else { return }
        guard sentNearbyTokenData != tokenData else { return }
        sentNearbyTokenData = tokenData
        watch.send(WatchMessage(type: .nearbyDiscoveryToken, run: run, proximity: proximityState, tokenData: tokenData))
    }
}
