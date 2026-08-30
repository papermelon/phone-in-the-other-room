import Foundation

/// The V4 social contract publishes only real local activity. Keeping this
/// decision pure prevents the practice exclusion from depending on callback
/// ordering in the run coordinator.
enum NightFlockV4PublicationEvent: Sendable {
    case starting
    case active
    case terminal
}

enum NightFlockV4PublicationPolicy {
    static func allows(
        _ event: NightFlockV4PublicationEvent,
        role: WindDownOccurrenceRole?,
        isPractice: Bool
    ) -> Bool {
        guard !isPractice, let role else { return false }
        switch event {
        case .starting:
            return role == .primarySleepBookend
        case .active, .terminal:
            return role == .primarySleepBookend || role == .additionalQuiet
        }
    }
}
