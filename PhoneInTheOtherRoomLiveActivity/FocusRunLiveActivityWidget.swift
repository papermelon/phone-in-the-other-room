import ActivityKit
import SwiftUI
import WidgetKit

struct FocusRunLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusRunLiveActivityAttributes.self) { context in
            FocusRunLiveActivityView(
                state: context.state.resolvedForDisplay(at: Date(), isStale: context.isStale),
                runID: context.attributes.runID
            )
                .activityBackgroundTint(Color(red: 0.08, green: 0.14, blue: 0.09))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state.resolvedForDisplay(at: Date(), isStale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: state.symbolName)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
                }
                DynamicIslandExpandedRegion(.center) {
                    FocusRunCountdown(state: state)
                        .font(.headline.monospacedDigit())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: state.symbolName)
                        .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    let guidance = guidance(
                        for: state,
                        runID: context.attributes.runID
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(guidance.primary)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        if let secondary = guidance.secondary {
                            Text(secondary)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.76))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                }
            } compactLeading: {
                Image(systemName: state.symbolName)
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
                    .accessibilityLabel(state.statusAccessibilityLabel)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: state.symbolName)
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
                    .accessibilityLabel(state.statusAccessibilityLabel)
            }
        }
    }

    private func guidance(
        for state: FocusRunLiveActivityAttributes.ContentState,
        runID: UUID
    ) -> NightWatchLiveActivityGuidance {
        state.guidance(runID: runID)
    }

}

private enum FocusRunLiveActivityPreviewData {
    static let runID = UUID(uuidString: "B4D7DA4C-8D3C-43F9-9BE8-4D8C1E9D7A10")!
    static let attributes = FocusRunLiveActivityAttributes(
        runID: runID,
        plannedDurationSeconds: 90 * 60
    )

    static func activeState(remaining: TimeInterval) -> FocusRunLiveActivityAttributes.ContentState {
        let now = Date()
        let nextTransition = now.addingTimeInterval(remaining)
        return FocusRunLiveActivityAttributes.ContentState(
            plannedEndAt: nextTransition.addingTimeInterval(8 * 60 * 60),
            isComplete: false,
            phase: .windDown,
            bedtimeAt: nextTransition,
            wakeAt: nextTransition.addingTimeInterval(8 * 60 * 60),
            morningQuietEndsAt: nextTransition.addingTimeInterval(8 * 60 * 60 + 30 * 60),
            eveningActivityTitle: PhoneFreeActivity.read.title,
            morningActivityTitle: PhoneFreeActivity.openCurtains.title,
            eveningRoutineTitles: [PhoneFreeActivity.sleepwear, .brushTeeth, .relaxation].map(\.title),
            morningRoutineTitles: [PhoneFreeActivity.openCurtains, .breakfast].map(\.title)
        )
    }

    static let completeState = FocusRunLiveActivityAttributes.ContentState(
        plannedEndAt: Date(),
        isComplete: true,
        phase: .complete,
        bedtimeAt: Date().addingTimeInterval(-9 * 60 * 60),
        wakeAt: Date().addingTimeInterval(-60 * 60),
        morningQuietEndsAt: Date().addingTimeInterval(-1),
        eveningActivityTitle: PhoneFreeActivity.read.title,
        morningActivityTitle: PhoneFreeActivity.openCurtains.title
    )

    static let endedEarlyState = FocusRunLiveActivityAttributes.ContentState(
        plannedEndAt: Date(),
        isComplete: false,
        phase: nil,
        terminalStatus: .endedEarly,
        bedtimeAt: Date().addingTimeInterval(-9 * 60 * 60),
        wakeAt: Date().addingTimeInterval(-60 * 60),
        morningQuietEndsAt: Date().addingTimeInterval(-1),
        eveningActivityTitle: PhoneFreeActivity.read.title,
        morningActivityTitle: PhoneFreeActivity.openCurtains.title
    )

    static let screenFreeMorningState = FocusRunLiveActivityAttributes.ContentState(
        plannedEndAt: Date().addingTimeInterval(25 * 60),
        isComplete: false,
        screenFreeMorning: ScreenFreeMorningPresentation(
            occurrence: MorningQuietOccurrence(
                scheduledStart: Date().addingTimeInterval(-5 * 60),
                scheduledEnd: Date().addingTimeInterval(25 * 60),
                actualStart: Date().addingTimeInterval(-5 * 60),
                outcome: .active
            )
        )
    )
}

#Preview("Live Activity — compact, 38:55", as: .dynamicIsland(.compact), using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.activeState(remaining: 38 * 60 + 55)
}

#Preview("Live Activity — compact, 1:38:55", as: .dynamicIsland(.compact), using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.activeState(remaining: 60 * 60 + 38 * 60 + 55)
}

#Preview("Live Activity — expanded", as: .dynamicIsland(.expanded), using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.activeState(remaining: 38 * 60 + 55)
}

#Preview("Live Activity — Lock Screen / banner", as: .content, using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.activeState(remaining: 38 * 60 + 55)
}

#Preview("Live Activity — minimal", as: .dynamicIsland(.minimal), using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.activeState(remaining: 38 * 60 + 55)
}

#Preview("Live Activity — complete", as: .dynamicIsland(.compact), using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.completeState
}

#Preview("Live Activity — complete, expanded", as: .dynamicIsland(.expanded), using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.completeState
}

#Preview("Live Activity — complete, Lock Screen / banner", as: .content, using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.completeState
}

#Preview("Live Activity — complete, minimal", as: .dynamicIsland(.minimal), using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.completeState
}

#Preview("Live Activity — ended early", as: .content, using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.endedEarlyState
}

#Preview("Live Activity — Screen-Free Morning", as: .content, using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.screenFreeMorningState
}

#Preview("Live Activity — Screen-Free Morning, compact", as: .dynamicIsland(.compact), using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.screenFreeMorningState
}

#Preview("Live Activity — Screen-Free Morning, expanded", as: .dynamicIsland(.expanded), using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.screenFreeMorningState
}

#Preview("Live Activity — Screen-Free Morning, minimal", as: .dynamicIsland(.minimal), using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.screenFreeMorningState
}

#Preview("Live Activity — bedtime passed, old evening payload", as: .content, using: FocusRunLiveActivityPreviewData.attributes) {
    FocusRunLiveActivityWidget()
} contentStates: {
    FocusRunLiveActivityPreviewData.activeState(remaining: -1)
}

#Preview("Live Activity — three ideas, large text") {
    FocusRunLiveActivityView(
        state: FocusRunLiveActivityPreviewData.activeState(remaining: 1800),
        runID: FocusRunLiveActivityPreviewData.runID
    )
    .environment(\.dynamicTypeSize, .accessibility1)
    .frame(width: 350)
    .background(Color(red: 0.08, green: 0.14, blue: 0.09))
}

#Preview("Live Activity — expired payload, large text") {
    FocusRunLiveActivityView(
        state: FocusRunLiveActivityAttributes.ContentState(
            plannedEndAt: Date().addingTimeInterval(-60), isComplete: false, phase: .morningQuiet
        ).resolvedForDisplay(at: Date(), isStale: true),
        runID: FocusRunLiveActivityPreviewData.runID
    )
    .environment(\.dynamicTypeSize, .accessibility1)
    .frame(width: 350)
    .background(Color(red: 0.08, green: 0.14, blue: 0.09))
}

private struct FocusRunLiveActivityView: View {
    let state: FocusRunLiveActivityAttributes.ContentState
    let runID: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 11) {
                Image(systemName: state.symbolName)
                    .font(.title2.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .padding(5)
                    .background(
                        Color(red: 0.22, green: 0.34, blue: 0.23),
                        in: RoundedRectangle(cornerRadius: 10)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(headerText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
                        .lineLimit(state.isDisplayComplete ? nil : 1)
                        .fixedSize(horizontal: false, vertical: true)
                    if state.terminalStatus == .endedEarly {
                        Image(systemName: "pause.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
                    } else if !state.isDisplayComplete {
                        Text(
                            timerInterval: timerInterval,
                            countsDown: true,
                            showsHours: true
                        )
                        .font(.title2.monospacedDigit().weight(.bold))
                        .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(guidance.primary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let secondary = guidance.secondary {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([guidance.primary, guidance.secondary].compactMap { $0 }.joined(separator: " "))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var headerText: String {
        if let completion = state.completionPresentation { return completion.headline }
        if state.slumberPartyCheer != nil { return "SLUMBER PARTY" }
        if let morning = state.screenFreeMorning { return morning.status.timerTitle.uppercased() }
        if let terminalPresentation = state.terminalPresentation {
            return terminalPresentation.headline
        }
        if state.isAdditionalQuiet { return "PHONE AWAY" }
        switch state.currentPhase {
        case .windDown: return "WIND DOWN · UNTIL BEDTIME"
        case .overnight: return "OVERNIGHT · UNTIL MORNING"
        case .morningQuiet: return "SCREEN-FREE MORNING"
        case .complete: return "WIND DOWN TIMER ENDED"
        case nil: return "WIND DOWN"
        }
    }

    private var timerInterval: ClosedRange<Date> {
        let now = Date()
        return now...max(now, state.countdownEnd(at: now))
    }

    private var guidance: NightWatchLiveActivityGuidance {
        state.guidance(runID: runID)
    }

}

private struct FocusRunCountdown: View {
    let state: FocusRunLiveActivityAttributes.ContentState

    var body: some View {
        if let terminalStatus = state.terminalStatus {
            Image(systemName: terminalStatus == .completed ? "checkmark.circle.fill" : "pause.circle.fill")
                .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
        } else if state.isDisplayComplete {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
        } else {
            Text(
                timerInterval: timerInterval,
                countsDown: true,
                showsHours: true
            )
        }
    }

    private var timerInterval: ClosedRange<Date> {
        let now = Date()
        return now...max(now, state.countdownEnd(at: now))
    }
}

private extension FocusRunLiveActivityAttributes.ContentState {
    var symbolName: String {
        if isDisplayComplete { return "checkmark.circle.fill" }
        if screenFreeMorning != nil { return "sun.max.fill" }
        if isAdditionalQuiet { return "timer" }
        return currentPhase == .morningQuiet ? "sun.max.fill" : "moon.fill"
    }

    func guidance(runID: UUID) -> NightWatchLiveActivityGuidance {
        if let completion = completionPresentation {
            return NightWatchLiveActivityGuidance(primary: completion.message, secondary: nil)
        }
        if let feedback = self.slumberPartyCheer {
            return NightWatchLiveActivityGuidance(
                primary: "A quiet cheer from your party",
                secondary: feedback.presentation.message
            )
        }
        if let morning = self.screenFreeMorning {
            return NightWatchLiveActivityGuidance(
                primary: morning.status.timerTitle,
                secondary: morning.isActive ? "Ends at \(OllieFormat.time(morning.endsAt))" : nil
            )
        }
        if let terminalPresentation = self.terminalPresentation {
            return NightWatchLiveActivityGuidance(
                primary: terminalPresentation.headline,
                secondary: terminalPresentation.message
            )
        }
        if self.isAdditionalQuiet {
            return NightWatchLiveActivityGuidance(
                primary: "Phone Away is running.",
                secondary: "Ends at \(OllieFormat.time(self.plannedEndAt))"
            )
        }
        let phase = self.currentPhase
        if phase == .overnight {
            return NightWatchLiveActivityGuidance(
                primary: "Settle in for the night.",
                secondary: "Morning starts at \(OllieFormat.time(wakeAt ?? plannedEndAt))."
            )
        }
        let activityTitle = phase == .windDown
            ? self.eveningActivityTitle
            : phase == .morningQuiet ? self.morningActivityTitle : nil
        return NightWatchGuidance.liveActivityGuidance(
            for: phase,
            activityTitle: activityTitle,
            seed: runID,
            routineTitles: phase == .windDown ? eveningRoutineTitles : morningRoutineTitles
        )
    }
    var occurrenceRole: WindDownOccurrenceRole {
        role ?? .primarySleepBookend
    }

    var isAdditionalQuiet: Bool {
        occurrenceRole == .additionalQuiet
    }

    var terminalPresentation: FocusRunLiveActivityTerminalPresentation? {
        guard screenFreeMorning == nil else { return nil }
        if let terminalStatus {
            return terminalStatus.presentation(for: occurrenceRole)
        }
        return isComplete
            ? FocusRunLiveActivityTerminalStatus.completed.presentation(for: occurrenceRole)
            : nil
    }

    var statusAccessibilityLabel: String {
        if let completion = completionPresentation {
            return "\(completion.headline.capitalized). \(completion.message)"
        }
        if let morning = screenFreeMorning {
            return morning.status.timerTitle
        }
        if let terminalPresentation {
            return terminalPresentation.headline.capitalized
        }
        return isAdditionalQuiet ? "Phone Away timer is active" : "Wind Down timer is active"
    }

    var currentPhase: NightWatchPhase? {
        if terminalStatus == .endedEarly { return nil }
        if terminalStatus == .completed || isComplete { return .complete }
        return phase ?? displayPhase(at: Date())
    }



}

private extension ScreenFreeMorningPresentation.Status {
    var timerTitle: String {
        switch self {
        case .scheduled: return "Screen-Free Morning is planned"
        case .active: return "Screen-Free Morning timer is running"
        case .skipped: return "Screen-Free Morning was skipped"
        case .finished: return "Screen-Free Morning timer ended"
        }
    }
}

@main
struct CountingSheepLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        FocusRunLiveActivityWidget()
        QuietNoteWidget()
    }
}
