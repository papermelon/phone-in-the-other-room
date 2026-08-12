import SwiftUI

struct OnboardingReadyStep: View {
    let draft: OnboardingDraft
    let showsTourHandoff: Bool

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            OllieRitualView(state: .ready, presentation: .inline)
            onboardingTitle(
                eyebrow: "SAVED FOR TONIGHT",
                title: "Your Wind Down is ready.",
                detail: "Here is the plan Counting Sheep will keep on this iPhone. You can edit it later in Settings."
            )

            OnboardingTimeline(draft: draft)

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    summaryRow("Bedtime", value: timeLabel(hour: draft.bedtimeHour, minute: draft.bedtimeMinute))
                    summaryRow("Wake time", value: timeLabel(hour: draft.wakeHour, minute: draft.wakeMinute))
                    summaryRow("Quiet before bed", value: QuietTimeDurationOptions.label(for: draft.windDownMinutes))
                    summaryRow("Quiet after waking", value: QuietTimeDurationOptions.label(for: draft.morningQuietMinutes))
                    summaryRow("Evening cue", value: draft.eveningCueText ?? "None")
                    summaryRow("Morning cue", value: draft.morningCueText ?? "None")
                    summaryRow("Selected apps", value: shieldingSummary)
                }
            }

            Text(handoffMessage)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var handoffMessage: String {
        if showsTourHandoff {
            return "Next: Home will show your saved plan, followed by a short two-step tour of the real app."
        }
        return "Your saved changes will appear on Home."
    }

    private var shieldingSummary: String {
        draft.shieldingEnabled ? "App limits on" : "Off for now"
    }

    private func summaryRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            Spacer(minLength: AppSpacing.sm)
            Text(value)
                .font(AppTypography.body)
                .multilineTextAlignment(.trailing)
        }
    }

    private func timeLabel(hour: Int, minute: Int) -> String {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        )?.formatted(date: .omitted, time: .shortened) ?? "—"
    }
}

#Preview("Saved plan") {
    OnboardingReadyStep(draft: OnboardingDraft(), showsTourHandoff: true)
        .padding()
        .background(AppColors.paper)
}
