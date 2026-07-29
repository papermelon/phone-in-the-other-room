import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct FocusRunLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var plannedEndAt: Date
        var isComplete: Bool
        var phase: NightWatchPhase? = nil
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
