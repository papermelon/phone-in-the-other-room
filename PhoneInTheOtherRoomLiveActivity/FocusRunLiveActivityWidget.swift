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
                Image("dog/dog_sleeping")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } compactTrailing: {
                FocusRunCountdown(state: context.state)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            } minimal: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
            }
        }
    }

    private func guidance(
        for state: FocusRunLiveActivityAttributes.ContentState,
        runID: UUID
    ) -> NightWatchLiveActivityGuidance {
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
                    if state.isDisplayComplete {
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
        switch state.currentPhase {
        case .windDown: return "PHONE-FREE WIND-DOWN"
        case .overnight: return "SLEEP TIME"
        case .morningQuiet: return "PHONE-FREE MORNING"
        case .complete: return "A PROTECTED NIGHT"
        case nil: return "OLLIE IS ON WATCH"
        }
    }

    private var timerInterval: ClosedRange<Date> {
        let now = Date()
        return now...max(now, state.nextTransitionAt)
    }

    private var guidance: NightWatchLiveActivityGuidance {
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
        if state.isDisplayComplete {
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
    var currentPhase: NightWatchPhase? {
        phase ?? phase(at: Date())
    }

    var isDisplayComplete: Bool {
        isComplete || currentPhase == .complete
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
    }
}
