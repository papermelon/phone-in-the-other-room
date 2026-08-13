import SwiftUI

struct OnboardingReadyStep: View {
    let draft: OnboardingDraft
    let showsTourHandoff: Bool
    var showsSlumberParty = false

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
                    summaryRow("Selected apps", value: shieldingSummary)
                }
            }

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("YOUR PRIVATE ROUTINE")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    routineGroup(title: "Evening", steps: [WindDownRoutineStep.phoneAwayTitle] + draft.eveningRoutine.map(\.title))
                    Divider()
                    routineGroup(title: "Morning", steps: draft.morningRoutine.map(\.title))
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
            return "Next: Home will show your saved plan, followed by a short three-step tour of the real app."
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

    private func routineGroup(title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.body.weight(.semibold))
            if steps.isEmpty {
                Text("No ideas saved")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            } else {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
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

#Preview("Saved plan · Slumber Party") {
    ScrollView {
        OnboardingReadyStep(
            draft: OnboardingDraft(),
            showsTourHandoff: true,
            showsSlumberParty: true
        )
        .padding()
    }
    .background(AppColors.paper)
}

#Preview("Saved plan · no morning ideas") {
    var draft = OnboardingDraft()
    draft.morningRoutine = []
    return OnboardingReadyStep(draft: draft, showsTourHandoff: false)
        .padding()
        .background(AppColors.paper)
}
