import Foundation

/// Converts the calm foreground travel used by the journey scene into a stable
/// six-frame gait without tying the animation to an absolute wall-clock epoch.
struct NightJourneyGait {
    static let frameCount = 6
    // A full six-frame stride now takes two seconds. The distance ratio stays
    // aligned with the artwork so Ollie's paws do not appear to slide.
    static let frameChangesPerSecond = 3.0
    static let foregroundSpeed = 6.0

    static var distancePerFrame: Double {
        foregroundSpeed / frameChangesPerSecond
    }

    static func foregroundDistance(elapsedSinceStart: TimeInterval) -> Double {
        guard elapsedSinceStart.isFinite else { return 0 }
        return max(0, elapsedSinceStart) * foregroundSpeed
    }

    static func frame(forForegroundDistance distance: Double, reduceMotion: Bool = false) -> Int {
        guard !reduceMotion, distance.isFinite, distance >= 0 else { return 0 }

        let frameNumber = floor(distance / distancePerFrame)
        let wrappedFrame = frameNumber.truncatingRemainder(dividingBy: Double(frameCount))
        return Int(wrappedFrame)
    }
}
