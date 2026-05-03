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
            if pairedPhoneTokenData != peerTokenData {
                pairedPhoneTokenData = peerTokenData
                nearby.run(withTokenData: peerTokenData)
            }
            connectionText = "Distance link active"
        } else {
            connectionText = "Waiting for distance token"
        }

        guard let tokenData = nearby.discoveryTokenData() else { return }
        guard sentNearbyTokenData != tokenData else { return }
        sentNearbyTokenData = tokenData
        watch.send(WatchMessage(type: .nearbyDiscoveryToken, run: run, proximity: proximity, tokenData: tokenData))
    }

    private func stopNearbyInteraction() {
        nearby.stop()
        pairedPhoneTokenData = nil
        sentNearbyTokenData = nil
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
            bucket = .signalLost
            status = ProximityBucket.signalLost.label
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
