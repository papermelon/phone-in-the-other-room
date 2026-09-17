import Foundation

/// Absolute-time response, independent of display refresh rate. Ground anchors
/// stay fixed while a small damped lift gives a release or pet some softness.
enum PasturePlay {
    struct Response: Equatable { var lift: Double; var tilt: Double; var squash: Double }
    static func response(elapsed: TimeInterval, reduceMotion: Bool) -> Response {
        guard !reduceMotion, elapsed.isFinite, elapsed >= 0, elapsed < 0.7 else {
            return .init(lift: 0, tilt: 0, squash: 1)
        }
        let decay = exp(-7 * elapsed)
        return .init(lift: abs(sin(elapsed * 18)) * decay * 7,
                     tilt: sin(elapsed * 16) * decay * 3,
                     squash: 1 - cos(elapsed * 18) * decay * 0.05)
    }

    static func fetchTarget(from origin: PastureScenePoint) -> PastureScenePoint {
        SharedPastureRules.bounded(.init(x: origin.x < 0.5 ? 0.75 : 0.30, y: 0.68))
    }

    static func gatheringPoints(around shepherd: PastureScenePoint, count: Int) -> [PastureScenePoint] {
        (0..<min(12, max(0, count))).map { index in
            let angle = Double(index) * 2.399963
            let radius = 0.12 + 0.035 * Double(index / 4)
            return SharedPastureRules.bounded(.init(x: shepherd.x + cos(angle) * radius,
                                                    y: shepherd.y + sin(angle) * radius * 0.65))
        }
    }
}
