import Foundation

protocol DistanceProvider {
    func start() async throws
    func stop()
    var readings: AsyncStream<ProximityReading> { get }
}

