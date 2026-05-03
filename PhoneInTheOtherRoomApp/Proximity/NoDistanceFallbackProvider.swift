import Foundation

final class NoDistanceFallbackProvider: DistanceProvider {
    var readings: AsyncStream<ProximityReading> {
        AsyncStream { continuation in
            continuation.yield(ProximityReading(distanceMeters: nil, source: .fallback, confidence: .low))
            continuation.finish()
        }
    }

    func start() async throws {}
    func stop() {}
}

