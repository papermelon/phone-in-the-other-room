import Foundation
import NearbyInteraction
import OSLog

final class NearbyInteractionDistanceProvider: NSObject, DistanceProvider {
    private var session: NISession?
    private var continuation: AsyncStream<ProximityReading>.Continuation?
    private var runningPeerTokenData: Data?
#if DEBUG
    private let energyLogger = Logger(
        subsystem: "com.ngawangchime.countingsheep",
        category: "Energy.NearbyInteraction.Phone"
    )
    private var debugStartedAt: Date?
    private var debugUpdateCount = 0
#endif
    private(set) lazy var readings: AsyncStream<ProximityReading> = AsyncStream { continuation in
        self.continuation = continuation
    }

    var isRunning: Bool { session != nil }

    var isSupported: Bool {
        NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
    }

    func start() async throws {
        guard session == nil else { return }
        guard isSupported else {
            continuation?.yield(ProximityReading(distanceMeters: nil, source: .fallback, confidence: .low))
            return
        }
        let session = NISession()
        session.delegate = self
        self.session = session
#if DEBUG
        debugStartedAt = Date()
        debugUpdateCount = 0
        energyLogger.debug("NI started")
#endif
    }

    func run(with peerToken: NIDiscoveryToken) {
        session?.run(NINearbyPeerConfiguration(peerToken: peerToken))
    }

    func run(withTokenData tokenData: Data) {
        guard runningPeerTokenData != tokenData,
              let peerToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: tokenData) else {
            return
        }
        runningPeerTokenData = tokenData
        run(with: peerToken)
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

extension NearbyInteractionDistanceProvider: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
#if DEBUG
        debugUpdateCount += 1
#endif
        continuation?.yield(ProximityReading(distanceMeters: object.distance.map(Double.init), source: .nearbyInteraction, directionAvailable: object.direction != nil, confidence: .high))
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
#if DEBUG
        energyLogger.debug("NI invalidated error=\(error.localizedDescription, privacy: .public)")
#endif
        continuation?.yield(ProximityReading(distanceMeters: nil, source: .fallback, confidence: .low))
    }
}
