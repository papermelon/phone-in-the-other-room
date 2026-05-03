import Foundation
import NearbyInteraction

final class NearbyInteractionDistanceProvider: NSObject, DistanceProvider {
    private var session: NISession?
    private var continuation: AsyncStream<ProximityReading>.Continuation?
    private var runningPeerTokenData: Data?
    private(set) lazy var readings: AsyncStream<ProximityReading> = AsyncStream { continuation in
        self.continuation = continuation
    }

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
        session?.invalidate()
        session = nil
        runningPeerTokenData = nil
    }
}

extension NearbyInteractionDistanceProvider: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        continuation?.yield(ProximityReading(distanceMeters: object.distance.map(Double.init), source: .nearbyInteraction, directionAvailable: object.direction != nil, confidence: .high))
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        continuation?.yield(ProximityReading(distanceMeters: nil, source: .fallback, confidence: .low))
    }
}
