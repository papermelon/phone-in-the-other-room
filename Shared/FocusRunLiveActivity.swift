import Foundation

enum FocusRunLiveActivityTerminalStatus: String, Codable, Hashable {
    case completed
    case endedEarly

    var presentation: FocusRunLiveActivityTerminalPresentation {
        switch self {
        case .completed:
            return FocusRunLiveActivityTerminalPresentation(
                headline: "WIND DOWN COMPLETE",
                message: "Ollie kept the quiet. Nice work."
            )
        case .endedEarly:
            return FocusRunLiveActivityTerminalPresentation(
                headline: "WIND DOWN ENDED",
                message: "Wind Down ended early. Your receipt is ready in Counting Sheep."
            )
        }
    }
}

struct FocusRunLiveActivityTerminalPresentation: Equatable {
    let headline: String
    let message: String
}

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct FocusRunLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var plannedEndAt: Date
        var isComplete: Bool
        var phase: NightWatchPhase? = nil
        /// Optional so existing ActivityKit states decode as the primary ritual.
        var role: WindDownOccurrenceRole? = nil
        var terminalStatus: FocusRunLiveActivityTerminalStatus? = nil
        var bedtimeAt: Date? = nil
        var wakeAt: Date? = nil
        var morningQuietEndsAt: Date? = nil
        var eveningActivityTitle: String? = nil
        var morningActivityTitle: String? = nil
        /// Independent, bounded morning state. It never carries results.
        var screenFreeMorning: ScreenFreeMorningPresentation? = nil
    }

    var runID: UUID
    var plannedDurationSeconds: TimeInterval
}
#endif
