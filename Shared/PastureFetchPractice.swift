import Foundation

/// Five deliberate throws, separate from Farm rewards and session credit.
struct PastureFetchPractice: Equatable {
    struct Target: Equatable {
        let point: PastureScenePoint
        let radius: Double
        let description: String

        func points(for landing: PastureScenePoint) -> Int {
            let distance = point.distance(to: landing)
            guard distance.isFinite else { return 0 }
            return distance <= radius * 0.4 ? 3 : distance <= radius ? 1 : 0
        }
    }

    static let targets: [Target] = [
        .init(point: .init(x: 0.50, y: 0.59), radius: 0.12, description: "Clover is nearby, straight ahead."),
        .init(point: .init(x: 0.13, y: 0.45), radius: 0.10, description: "Clover is in the far left corner."),
        .init(point: .init(x: 0.87, y: 0.77), radius: 0.09, description: "Clover is in the near right corner."),
        .init(point: .init(x: 0.87, y: 0.45), radius: 0.09, description: "Clover is in the far right corner."),
        .init(point: .init(x: 0.13, y: 0.77), radius: 0.09, description: "Clover is in the near left corner.")
    ]
    static let maximumScore = targets.count * 3
    private(set) var scores: [Int] = []
    var score: Int { scores.reduce(0, +) }
    var isComplete: Bool { scores.count == Self.targets.count }
    var target: Target? { isComplete ? nil : Self.targets[scores.count] }

    mutating func record(landing: PastureScenePoint) {
        guard let target else { return }
        scores.append(target.points(for: landing))
    }

    /// Heading is clockwise from straight ahead; strength uses the same travel model as a slow swipe.
    static func translation(heading: Double, strength: Double) -> PastureScenePoint? {
        guard heading.isFinite, strength.isFinite,
              (-180...180).contains(heading), (1...100).contains(strength) else { return nil }
        let radians = heading * .pi / 180
        let distance = (0.05 + strength / 100 * 0.65) / 1.35
        return .init(x: sin(radians) * distance, y: -cos(radians) * distance)
    }
}

extension FarmState {
    mutating func recordFetchPractice(_ practice: PastureFetchPractice) {
        guard practice.isComplete else { return }
        fetchPracticeBest = max(fetchPracticeBest ?? 0, practice.score)
    }
}
