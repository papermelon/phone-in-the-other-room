import Foundation

enum FocusRunLiveActivityTerminalStatus: String, Codable, Hashable {
    case completed
    case endedEarly

    var presentation: FocusRunLiveActivityTerminalPresentation {
        presentation(for: .primarySleepBookend)
    }

    func presentation(
        for role: WindDownOccurrenceRole
    ) -> FocusRunLiveActivityTerminalPresentation {
        let mode = role == .additionalQuiet ? "Phone Away" : "Wind Down"
        switch self {
        case .completed:
            return FocusRunLiveActivityTerminalPresentation(
                headline: "\(mode.uppercased()) TIMER ENDED",
                message: "Well done. Open Counting Sheep for your summary."
            )
        case .endedEarly:
            return FocusRunLiveActivityTerminalPresentation(
                headline: "\(mode.uppercased()) ENDED EARLY",
                message: "Your recorded minutes are saved in Counting Sheep."
            )
        }
    }
}

struct FocusRunLiveActivityTerminalPresentation: Equatable {
    let headline: String
    let message: String
}

enum FocusRunLiveActivityLifecycle {
    /// Only currently running timers may retain a system surface on app return.
    /// A linked morning shares the parent ID even after Wind Down settles.
    static func retainedRunIDs(
        run: FocusRun?, mornings: [MorningQuietOccurrence], at date: Date
    ) -> Set<UUID> {
        var ids = Set(mornings.filter {
            $0.outcome == .active && $0.scheduledEnd > date && $0.liveActivityRequested
        }.map { $0.linkedWindDownRunID ?? $0.id })
        if let run, ![.setup, .completed, .endedEarly].contains(run.state),
           run.plannedEndAt > date, run.liveActivityRequested {
            ids.insert(run.id)
        }
        return ids
    }
}

enum FocusRunLiveActivityCue {
    /// ActivityKit limits the whole payload to 4 KB. Bound by UTF-8 bytes so
    /// long composed emoji in a custom idea cannot crowd out the schedule.
    static func bounded(_ text: String) -> String {
        guard text.utf8.count > 160 else { return text }
        var result = ""
        for character in text {
            let candidate = result + String(character)
            guard candidate.utf8.count <= 157 else { break }
            result = candidate
        }
        return result.isEmpty ? "Your quiet idea" : result + "…"
    }
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
        /// Local Lock Screen cues. Older app/server payloads retain the single-title fallback.
        var eveningRoutineTitles: [String]? = nil
        var morningRoutineTitles: [String]? = nil
        /// Independent, bounded morning state. It never carries results.
        var screenFreeMorning: ScreenFreeMorningPresentation? = nil
        /// Brief, silent social encouragement. Missing on older activity states.
        var slumberPartyCheer: SlumberPartyCheerFeedback? = nil
    }

    var runID: UUID
    var plannedDurationSeconds: TimeInterval
}
// Rendering a known schedule is separate from settling the run or proving protection.
@available(iOS 16.1, *)
extension FocusRunLiveActivityAttributes.ContentState {
    func displayPhase(at date: Date) -> NightWatchPhase? {
        if terminalStatus == .endedEarly { return nil }
        if terminalStatus == .completed || isComplete { return .complete }
        if let morning = screenFreeMorning {
            return date >= morning.endsAt ? .complete : .morningQuiet
        }
        if role == .additionalQuiet { return date >= plannedEndAt ? .complete : .windDown }
        guard let bedtimeAt, let wakeAt, let morningQuietEndsAt else {
            return date >= plannedEndAt ? .complete : phase
        }
        if date >= morningQuietEndsAt { return .complete }
        if date >= wakeAt { return .morningQuiet }
        if date >= bedtimeAt { return .overnight }
        return .windDown
    }

    func countdownEnd(at date: Date) -> Date {
        if let morning = screenFreeMorning { return morning.endsAt }
        if role == .additionalQuiet { return plannedEndAt }
        switch displayPhase(at: date) {
        case .windDown: return bedtimeAt ?? plannedEndAt
        case .overnight: return wakeAt ?? plannedEndAt
        case .morningQuiet, .complete, nil: return morningQuietEndsAt ?? plannedEndAt
        }
    }

    /// Ask the system to invalidate this presentation at the next clock boundary,
    /// rather than leaving the evening countdown valid until the whole night ends.
    func nextContentRefreshDate(at date: Date) -> Date? {
        guard terminalStatus == nil, !isComplete else { return nil }
        let boundary = countdownEnd(at: date)
        return boundary > date ? boundary : nil
    }

    func resolvedForDisplay(at date: Date, isStale: Bool) -> Self {
        var result = self
        // Referencing isStale makes the widget depend on ActivityKit's system-owned
        // freshness change. The anchors, not the last app-sent phase, decide the UI.
        let minimumDate: Date
        if isStale, screenFreeMorning == nil, role != .additionalQuiet, phase == .windDown {
            minimumDate = bedtimeAt ?? date
        } else {
            minimumDate = date
        }
        result.phase = displayPhase(at: max(date, minimumDate))
        return result
    }

    /// A clock-derived completion is display-only; it never changes settlement fields.
    var isDisplayComplete: Bool {
        terminalStatus == .completed || (terminalStatus == nil && (isComplete || phase == .complete))
    }

    var completionPresentation: FocusRunLiveActivityTerminalPresentation? {
        if let morning = screenFreeMorning {
            guard isDisplayComplete, morning.status != .skipped else { return nil }
            return FocusRunLiveActivityTerminalPresentation(
                headline: "SCREEN-FREE MORNING TIMER ENDED",
                message: "A gentle start to the day. Well done."
            )
        }
        if let terminalStatus { return terminalStatus.presentation(for: role ?? .primarySleepBookend) }
        return isDisplayComplete
            ? FocusRunLiveActivityTerminalStatus.completed.presentation(for: role ?? .primarySleepBookend)
            : nil
    }
}
#endif
