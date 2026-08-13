import Foundation
import NearbyInteraction
import OSLog
import WatchKit

@MainActor
final class WatchRunViewModel: ObservableObject {
    @Published var run: FocusRun?
    @Published var proximity: ProximityState = .initial
    @Published var reward: RewardItem?
    @Published var connectionText = "Waiting for iPhone"

    private let watch = WatchConnectivityManagerWatch.shared
    private let notifications = WatchNotificationService.shared
    private let nearby = WatchNearbyInteractionSession()
    private var pairedPhoneTokenData: Data?
    private var sentNearbyTokenData: Data?
    private var sentNearbyTokenAcknowledged = false
    private var nearbyTokenRetryTask: Task<Void, Never>?
    private let nearbyTokenRetrySeconds: TimeInterval = 2
    private let nearbyTokenRetryLimit = 6
#if DEBUG
    private let energyLogger = Logger(
        subsystem: "com.ngawangchime.countingsheep",
        category: "Energy.NearbyInteraction.Watch"
    )
#endif

    init() {
#if DEBUG
        if WatchCaptureFixture.applyIfRequested(to: self) {
            return
        }
#endif
        configureCallbacks()
        requestCurrentRun()
    }

#if DEBUG
    init(captureState: WatchCaptureState) {
        WatchCaptureFixture.apply(captureState, to: self)
    }
#endif

    private func configureCallbacks() {
        watch.onMessage = { [weak self] message in
            Task { @MainActor in self?.handle(message) }
        }
        nearby.onDistanceUpdate = { [weak self] distance in
            Task { @MainActor in self?.handleNearbyDistance(distance) }
        }
    }

    deinit {
        nearbyTokenRetryTask?.cancel()
        nearby.stop()
    }

    var remainingSeconds: TimeInterval {
        guard let run else { return 0 }
        return max(0, run.plannedEndAt.timeIntervalSince(Date()))
    }

    var isAdditionalQuiet: Bool {
        run?.nightWatchPlan?.role == .additionalQuiet
    }

    func pingPhone() {
        WKInterfaceDevice.current().play(.click)
        connectionText = watch.isReachable ? "Ping sent to iPhone" : "Ping queued until iPhone is reachable"
        watch.sendWithReply(WatchMessage(type: .pingPhone)) { [weak self] reply in
            Task { @MainActor in
                guard let self else { return }
                if reply?.type == .pingPhone {
                    self.connectionText = "Phone heard the whistle"
                } else {
                    self.connectionText = self.watch.isReachable ? "Ping sent, waiting for phone" : "Ping queued until iPhone is reachable"
                }
            }
        }
    }

    func requestCurrentRun() {
        connectionText = watch.isReachable ? "Looking for Wind Down or Phone Break..." : "Open the iPhone app and begin Wind Down or Phone Break"
        watch.sendWithReply(WatchMessage(type: .pingWatch)) { [weak self] reply in
            Task { @MainActor in
                guard let self else { return }
                if let reply {
                    self.handle(reply)
                } else if self.run == nil {
                    self.connectionText = self.watch.isReachable ? "No active Wind Down or Phone Break found" : "iPhone not reachable"
                }
            }
        }
    }

    func endRun() {
        guard run?.guardKind != .nfcTag else {
            connectionText = isAdditionalQuiet
                ? "Use iPhone and tap the phone-bed tag to end Phone Break"
                : "Use iPhone and tap the phone-bed tag to end Wind Down"
            return
        }
        WKInterfaceDevice.current().play(.stop)
        watch.send(WatchMessage(type: .endFocusRunEarly))
        guard var run else { return }
        run.state = .endedEarly
        run.endedAt = Date()
        run.actualDurationSeconds = run.endedAt?.timeIntervalSince(run.startedAt) ?? 0
        run.endedEarlyReason = .userEnded
        self.run = run
        stopNearbyInteraction()
    }

    func clearRunSummary() {
        run = nil
        reward = nil
        proximity = .initial
        connectionText = "Open the iPhone app for tonight's plan"
    }

    func requestDistanceCheck() {
        guard run?.guardKind == .watchPlacement,
              run?.placementStatus == .awaitingConfirmation else {
            connectionText = isAdditionalQuiet
                ? "Phone Break is keeping time on iPhone"
                : "Wind Down is keeping time on iPhone"
            return
        }
        WKInterfaceDevice.current().play(.click)
        connectionText = "Checking distance..."
        watch.send(WatchMessage(type: .distanceCheckRequest, run: run, proximity: proximity))
        startNearbyInteraction(with: nil)
    }

    private func handle(_ message: WatchMessage) {
        // The iPhone is authoritative. A state update with no run must clear any
        // application-context snapshot left on the Watch by an earlier session.
        if message.type == .focusRunStateUpdate, message.run == nil {
            run = nil
            reward = nil
            proximity = .initial
            stopNearbyInteraction()
        }
        if let run = message.run { self.run = run }
        if let proximity = message.proximity { self.proximity = proximity }
        if let reward = message.reward { self.reward = reward }
        connectionText = "Connected to iPhone"

        switch message.type {
        case .startFocusRun:
            WKInterfaceDevice.current().play(.start)
            notifications.scheduleRunStartedNotification(role: run?.nightWatchPlan?.role ?? .primarySleepBookend)
            if run?.guardKind == .watchPlacement,
               run?.placementStatus == .awaitingConfirmation {
                startNearbyInteraction(with: message.tokenData)
                connectionText = "One quick placement check"
            } else {
                stopNearbyInteraction()
                connectionText = isAdditionalQuiet
                    ? "Phone Break is keeping time on iPhone"
                    : "Wind Down is keeping time on iPhone"
            }
        case .nearbyDiscoveryToken:
            if run?.guardKind == .watchPlacement,
               run?.placementStatus == .awaitingConfirmation {
                startNearbyInteraction(with: message.tokenData)
            }
        case .nearbyDiscoveryTokenAcknowledged:
            handleNearbyTokenAcknowledged(message.tokenData)
        case .distanceCheckRequest:
            if run?.guardKind == .watchPlacement,
               run?.placementStatus == .awaitingConfirmation {
                startNearbyInteraction(with: message.tokenData)
                connectionText = "One quick placement check"
            }
        case .distanceCheckEnded:
            stopNearbyInteraction()
            connectionText = "Distance resting"
        case .proximityStateUpdate:
            if message.run?.placementStatus == .confirmed {
                WKInterfaceDevice.current().play(.success)
            }
        case .rewardEarned:
            stopNearbyInteraction()
            WKInterfaceDevice.current().play(.success)
        case .endFocusRunEarly:
            stopNearbyInteraction()
            WKInterfaceDevice.current().play(.stop)
        case .focusRunStateUpdate where message.run == nil:
            connectionText = "No active Wind Down or Phone Break on iPhone"
        default:
            break
        }
    }

    private func startNearbyInteraction(with peerTokenData: Data?) {
        guard nearby.isSupported else {
            connectionText = "Watch placement isn't available here"
            return
        }

        nearby.start()
        if let peerTokenData {
            acknowledgeNearbyToken(peerTokenData)
            if pairedPhoneTokenData.map({ $0 != peerTokenData }) ?? true {
                pairedPhoneTokenData = peerTokenData
                nearby.run(withTokenData: peerTokenData)
            }
            connectionText = "Distance link active"
        } else {
            connectionText = "Waiting for distance token"
        }

        sendNearbyToken()
    }

    private func stopNearbyInteraction() {
        let hadRetryTask = nearbyTokenRetryTask != nil
        nearbyTokenRetryTask?.cancel()
        nearbyTokenRetryTask = nil
        nearby.stop()
        pairedPhoneTokenData = nil
        sentNearbyTokenData = nil
        sentNearbyTokenAcknowledged = false
#if DEBUG
        if hadRetryTask {
            energyLogger.debug("NI token retry task cancelled during stop")
        }
#endif
    }

    private func sendNearbyToken() {
        guard let tokenData = nearby.discoveryTokenData() else { return }
        if sentNearbyTokenData.map({ $0 != tokenData }) ?? true {
            sentNearbyTokenData = tokenData
            sentNearbyTokenAcknowledged = false
        }
        let message = WatchMessage(type: .nearbyDiscoveryToken, run: run, proximity: proximity, tokenData: tokenData)
        watch.send(message)
        startNearbyTokenRetry(tokenData: tokenData, message: message)
    }

    private func startNearbyTokenRetry(tokenData: Data, message: WatchMessage) {
        nearbyTokenRetryTask?.cancel()
#if DEBUG
        energyLogger.debug(
            "NI token retry task created intervalSeconds=\(self.nearbyTokenRetrySeconds, format: .fixed(precision: 0)) limit=\(self.nearbyTokenRetryLimit)"
        )
#endif
        nearbyTokenRetryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for _ in 1...self.nearbyTokenRetryLimit {
                try? await Task.sleep(for: .seconds(self.nearbyTokenRetrySeconds))
                guard !Task.isCancelled else { return }
                guard let sentNearbyTokenData = self.sentNearbyTokenData else { return }
                guard sentNearbyTokenData == tokenData, !self.sentNearbyTokenAcknowledged else { return }
                self.watch.send(message)
            }
        }
    }

    private func acknowledgeNearbyToken(_ tokenData: Data) {
        watch.send(WatchMessage(type: .nearbyDiscoveryTokenAcknowledged, run: run, proximity: proximity, tokenData: tokenData))
    }

    private func handleNearbyTokenAcknowledged(_ tokenData: Data?) {
        guard let tokenData, let sentNearbyTokenData, tokenData == sentNearbyTokenData else { return }
        sentNearbyTokenAcknowledged = true
        nearbyTokenRetryTask?.cancel()
        nearbyTokenRetryTask = nil
#if DEBUG
        energyLogger.debug("NI token retry task cancelled after acknowledgement")
#endif
    }

    private func handleNearbyDistance(_ distance: Double?) {
        let bucket: ProximityBucket
        let status: String
        let detail: String

        if let distance {
            switch distance {
            case ..<1.5:
                bucket = .withYou
            case ..<5.0:
                bucket = .sameRoom
            case ..<8.0:
                bucket = .doorway
            default:
                bucket = .probablyOtherRoom
            }
            status = bucket.label
            detail = "Measured between your Apple Watch and iPhone."
        } else {
            bucket = .waitingForDistance
            status = ProximityBucket.waitingForDistance.label
            detail = "Waiting for a distance reading from your iPhone."
        }

        proximity = ProximityState(
            bucket: bucket,
            distanceMeters: distance,
            confidence: distance == nil ? .low : .high,
            source: .nearbyInteraction,
            lastUpdated: Date(),
            statusText: status,
            detailText: detail
        )
        connectionText = distance == nil ? "Waiting for distance" : "Distance active"
        watch.send(WatchMessage(type: .watchDistanceReading, run: run, proximity: proximity, distanceMeters: distance))
    }
}

private final class WatchNearbyInteractionSession: NSObject {
    private var session: NISession?
    private var runningPeerTokenData: Data?
    var onDistanceUpdate: ((Double?) -> Void)?
#if DEBUG
    private let energyLogger = Logger(
        subsystem: "com.ngawangchime.countingsheep",
        category: "Energy.NearbyInteraction.Watch"
    )
    private var debugStartedAt: Date?
    private var debugUpdateCount = 0
#endif

    var isSupported: Bool {
        NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
    }

    func start() {
        guard session == nil, isSupported else { return }
        let session = NISession()
        session.delegate = self
        self.session = session
#if DEBUG
        debugStartedAt = Date()
        debugUpdateCount = 0
        energyLogger.debug("NI started")
#endif
    }

    func run(withTokenData tokenData: Data) {
        guard runningPeerTokenData != tokenData,
              let peerToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: tokenData) else {
            return
        }
        runningPeerTokenData = tokenData
        session?.run(NINearbyPeerConfiguration(peerToken: peerToken))
    }

    func discoveryTokenData() -> Data? {
        guard let token = session?.discoveryToken else { return nil }
        return try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    func stop() {
        guard session != nil else { return }
        session?.invalidate()
        session = nil
        runningPeerTokenData = nil
#if DEBUG
        let duration = debugStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        energyLogger.debug(
            "NI stopped durationSeconds=\(duration, format: .fixed(precision: 2)) updates=\(self.debugUpdateCount)"
        )
        debugStartedAt = nil
        debugUpdateCount = 0
#endif
    }
}

extension WatchNearbyInteractionSession: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
#if DEBUG
        debugUpdateCount += 1
#endif
        onDistanceUpdate?(nearbyObjects.first?.distance.map(Double.init))
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        runningPeerTokenData = nil
#if DEBUG
        energyLogger.debug("NI invalidated error=\(error.localizedDescription, privacy: .public)")
#endif
        onDistanceUpdate?(nil)
    }
}
