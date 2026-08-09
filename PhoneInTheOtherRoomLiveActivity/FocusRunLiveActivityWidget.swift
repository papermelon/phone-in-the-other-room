import ActivityKit
import SwiftUI
import WidgetKit

struct FocusRunLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusRunLiveActivityAttributes.self) { context in
            FocusRunLiveActivityView(state: context.state, runID: context.attributes.runID)
                .activityBackgroundTint(Color(red: 0.08, green: 0.14, blue: 0.09))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image("dog/dog_sleeping")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                }
                DynamicIslandExpandedRegion(.center) {
                    FocusRunCountdown(state: context.state)
                        .font(.headline.monospacedDigit())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    let guidance = guidance(
                        for: context.state,
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
                Image(systemName: "moon.stars.fill")
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
                    .accessibilityLabel("Wind Down is active")
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: "moon.stars.fill")
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
                    .accessibilityLabel("Wind Down is active")
            }
        }
    }

    private func guidance(
        for state: FocusRunLiveActivityAttributes.ContentState,
        runID: UUID
    ) -> NightWatchLiveActivityGuidance {
        if let terminalPresentation = state.terminalPresentation {
            return NightWatchLiveActivityGuidance(
                primary: terminalPresentation.headline,
                secondary: terminalPresentation.message
            )
        }
        let phase = state.currentPhase
        let activityTitle = phase == .windDown
            ? state.eveningActivityTitle
            : phase == .morningQuiet ? state.morningActivityTitle : nil
        return NightWatchGuidance.liveActivityGuidance(
            for: phase,
            activityTitle: activityTitle,
            seed: runID
        )
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
            plannedEndAt: now.addingTimeInterval(3 * 60 * 60),
            isComplete: false,
            phase: .windDown,
            bedtimeAt: nextTransition,
            wakeAt: nextTransition.addingTimeInterval(8 * 60 * 60),
            morningQuietEndsAt: nextTransition.addingTimeInterval(8 * 60 * 60 + 30 * 60),
            eveningActivityTitle: PhoneFreeActivity.read.title,
            morningActivityTitle: PhoneFreeActivity.openCurtains.title
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

private struct FocusRunLiveActivityView: View {
    let state: FocusRunLiveActivityAttributes.ContentState
    let runID: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 11) {
                Image("dog/dog_sleeping")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
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
                        .lineLimit(1)
                    if let terminalStatus = state.terminalStatus {
                        Image(systemName: terminalStatus == .completed ? "checkmark.circle.fill" : "pause.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
                    } else if state.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
                    } else {
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
                    .fixedSize(horizontal: false, vertical: true)
                if let secondary = guidance.secondary {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var headerText: String {
        if let terminalPresentation = state.terminalPresentation {
            return terminalPresentation.headline
        }
        switch state.currentPhase {
        case .windDown: return "PHONE-FREE WIND-DOWN"
        case .overnight: return "SLEEP TIME"
        case .morningQuiet: return "PHONE-FREE MORNING"
        case .complete: return "QUIET TIME COMPLETE"
        case nil: return "OLLIE IS ON WATCH"
        }
    }

    private var timerInterval: ClosedRange<Date> {
        let now = Date()
        return now...max(now, state.nextTransitionAt)
    }

    private var guidance: NightWatchLiveActivityGuidance {
        if let terminalPresentation = state.terminalPresentation {
            return NightWatchLiveActivityGuidance(
                primary: terminalPresentation.headline,
                secondary: terminalPresentation.message
            )
        }
        let phase = state.currentPhase
        let activityTitle = phase == .windDown
            ? state.eveningActivityTitle
            : phase == .morningQuiet ? state.morningActivityTitle : nil
        return NightWatchGuidance.liveActivityGuidance(
            for: phase,
            activityTitle: activityTitle,
            seed: runID
        )
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
        return now...max(now, state.nextTransitionAt)
    }
}

private extension FocusRunLiveActivityAttributes.ContentState {
    var terminalPresentation: FocusRunLiveActivityTerminalPresentation? {
        if let terminalStatus {
            return terminalStatus.presentation
        }
        return isComplete ? FocusRunLiveActivityTerminalStatus.completed.presentation : nil
    }

    var currentPhase: NightWatchPhase? {
        if terminalStatus == .endedEarly {
            return nil
        }
        if terminalStatus == .completed || isComplete {
            return .complete
        }
        return phase ?? phase(at: Date())
    }

    var isDisplayComplete: Bool {
        terminalStatus == .completed || (terminalStatus == nil && (isComplete || currentPhase == .complete))
    }

    var nextTransitionAt: Date {
        switch currentPhase {
        case .windDown: return bedtimeAt ?? plannedEndAt
        case .overnight: return wakeAt ?? plannedEndAt
        case .morningQuiet, .complete, nil: return morningQuietEndsAt ?? plannedEndAt
        }
    }

    func phase(at date: Date) -> NightWatchPhase? {
        guard let bedtimeAt, let wakeAt, let morningQuietEndsAt else { return nil }
        if date >= morningQuietEndsAt { return .complete }
        if date >= wakeAt { return .morningQuiet }
        if date >= bedtimeAt { return .overnight }
        return .windDown
    }
}

@main
struct CountingSheepLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        FocusRunLiveActivityWidget()
        QuietNoteWidget()
    }
}
