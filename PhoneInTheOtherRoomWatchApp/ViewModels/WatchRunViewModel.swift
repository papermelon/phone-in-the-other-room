import Foundation
import NearbyInteraction
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

    init() {
        watch.onMessage = { [weak self] message in
            Task { @MainActor in self?.handle(message) }
        }
        nearby.onDistanceUpdate = { [weak self] distance in
            Task { @MainActor in self?.handleNearbyDistance(distance) }
        }
        requestCurrentRun()
    }

    var remainingSeconds: TimeInterval {
        guard let run else { return 0 }
        return max(0, run.plannedEndAt.timeIntervalSince(Date()))
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
        connectionText = watch.isReachable ? "Looking for active run..." : "Open the iPhone app and start a run"
        watch.sendWithReply(WatchMessage(type: .pingWatch)) { [weak self] reply in
            Task { @MainActor in
                guard let self else { return }
                if let reply, reply.run != nil {
                    self.handle(reply)
                } else if self.run == nil {
                    self.connectionText = self.watch.isReachable ? "No active iPhone run found" : "iPhone not reachable"
                }
            }
        }
    }

    func endRun() {
        WKInterfaceDevice.current().play(.failure)
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
        connectionText = "Open the iPhone app to start another run"
    }

    func requestDistanceCheck() {
        WKInterfaceDevice.current().play(.click)
        connectionText = "Checking distance..."
        watch.send(WatchMessage(type: .distanceCheckRequest, run: run, proximity: proximity))
        startNearbyInteraction(with: nil)
    }

    private func handle(_ message: WatchMessage) {
        if let run = message.run { self.run = run }
        if let proximity = message.proximity { self.proximity = proximity }
        if let reward = message.reward { self.reward = reward }
        connectionText = "Connected to iPhone"

        switch message.type {
        case .startFocusRun:
            WKInterfaceDevice.current().play(.start)
            notifications.scheduleRunStartedNotification()
            startNearbyInteraction(with: message.tokenData)
        case .nearbyDiscoveryToken:
            startNearbyInteraction(with: message.tokenData)
        case .nearbyDiscoveryTokenAcknowledged:
            handleNearbyTokenAcknowledged(message.tokenData)
        case .distanceCheckRequest:
            startNearbyInteraction(with: message.tokenData)
            connectionText = "Distance check active"
        case .distanceCheckEnded:
            stopNearbyInteraction()
            connectionText = "Distance resting"
        case .proximityStateUpdate, .demoDistanceUpdate:
            if message.run?.state == .warningPhoneTooClose {
                WKInterfaceDevice.current().play(.notification)
            } else if message.run?.phoneAwayValidatedAt != nil {
                WKInterfaceDevice.current().play(.success)
            }
        case .rewardEarned:
            stopNearbyInteraction()
            WKInterfaceDevice.current().play(.success)
        case .endFocusRunEarly:
            stopNearbyInteraction()
            WKInterfaceDevice.current().play(.failure)
        default:
            break
        }
    }

    private func startNearbyInteraction(with peerTokenData: Data?) {
        guard nearby.isSupported else {
            connectionText = "Nearby Interaction unsupported"
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
        nearbyTokenRetryTask?.cancel()
        nearbyTokenRetryTask = nil
        nearby.stop()
        pairedPhoneTokenData = nil
        sentNearbyTokenData = nil
        sentNearbyTokenAcknowledged = false
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
            detail = "Measured from NINearbyObject.distance on Apple Watch."
        } else {
            bucket = .waitingForDistance
            status = ProximityBucket.waitingForDistance.label
            detail = "Waiting for NINearbyObject.distance."
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

    var isSupported: Bool {
        NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
    }

    func start() {
        guard session == nil, isSupported else { return }
        let session = NISession()
        session.delegate = self
        self.session = session
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
        session?.invalidate()
        session = nil
        runningPeerTokenData = nil
    }
}

extension WatchNearbyInteractionSession: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        onDistanceUpdate?(nearbyObjects.first?.distance.map(Double.init))
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        runningPeerTokenData = nil
        onDistanceUpdate?(nil)
    }
}
