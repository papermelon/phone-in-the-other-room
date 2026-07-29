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
                    Text(detailText(for: context.state, runID: context.attributes.runID))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
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

    private func detailText(
        for state: FocusRunLiveActivityAttributes.ContentState,
        runID: UUID
    ) -> String {
        let phase = state.currentPhase
        let activityTitle = phase == .windDown
            ? state.eveningActivityTitle
            : phase == .morningQuiet ? state.morningActivityTitle : nil
        return NightWatchGuidance.liveActivityDetail(
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
        HStack(spacing: 12) {
            Image("dog/dog_sleeping")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 42, height: 42)
                .padding(5)
                .background(Color(red: 0.22, green: 0.34, blue: 0.23), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(headerText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(red: 0.75, green: 0.84, blue: 0.60))
                if state.isDisplayComplete {
                    Text("Your phone-free night is ready.")
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text(
                        timerInterval: timerInterval,
                        countsDown: true,
                        showsHours: true
                    )
                        .font(.title2.monospacedDigit().weight(.bold))
                    Text(detailText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
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

    private var detailText: String {
        let phase = state.currentPhase
        let activityTitle = phase == .windDown
            ? state.eveningActivityTitle
            : phase == .morningQuiet ? state.morningActivityTitle : nil
        return NightWatchGuidance.liveActivityDetail(
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
