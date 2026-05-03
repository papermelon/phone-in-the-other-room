import Foundation

final class DemoDistanceProvider: DistanceProvider {
    private var continuation: AsyncStream<ProximityReading>.Continuation?
    private(set) lazy var readings: AsyncStream<ProximityReading> = AsyncStream { continuation in
        self.continuation = continuation
    }

    func start() async throws {}

    func stop() {
        continuation?.finish()
    }

    func push(distance: Double) {
        continuation?.yield(ProximityReading(distanceMeters: distance, source: .demo, confidence: .medium))
    }
}

