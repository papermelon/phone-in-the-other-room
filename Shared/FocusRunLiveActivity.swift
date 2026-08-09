import Foundation

enum FocusRunLiveActivityTerminalStatus: String, Codable, Hashable {
    case completed
    case endedEarly

    var presentation: FocusRunLiveActivityTerminalPresentation {
        switch self {
        case .completed:
            return FocusRunLiveActivityTerminalPresentation(
                headline: "QUIET TIME COMPLETE",
                message: "Ollie kept the quiet. Nice work."
            )
        case .endedEarly:
            return FocusRunLiveActivityTerminalPresentation(
                headline: "QUIET TIME ENDED",
                message: "Quiet time ended early. Your receipt is ready in Counting Sheep."
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
        var terminalStatus: FocusRunLiveActivityTerminalStatus? = nil
        var bedtimeAt: Date? = nil
        var wakeAt: Date? = nil
        var morningQuietEndsAt: Date? = nil
        var eveningActivityTitle: String? = nil
        var morningActivityTitle: String? = nil
    }

    var runID: UUID
    var plannedDurationSeconds: TimeInterval
}
#endif
