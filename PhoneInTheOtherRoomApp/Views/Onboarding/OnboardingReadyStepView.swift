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
                    summaryRow("Evening cue", value: draft.eveningCueText ?? "None")
                    summaryRow("Morning cue", value: draft.morningCueText ?? "None")
                    summaryRow("Selected apps", value: shieldingSummary)
                }
            }

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("WHAT THESE NAMES MEAN")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    term(
                        "Wind Down",
                        detail: "Your usual nightly phone-away ritual: quiet before bed, overnight, and quiet after waking."
                    )
                    Divider()
                    term(
                        "Phone Break",
                        detail: "Optional phone-away time outside Wind Down. Every 75 completed Phone Break minutes opens a bonus search. A search may find a sheep or leave a clue."
                    )
                    if showsSlumberParty {
                        Divider()
                        term(
                            "Slumber Party",
                            detail: "An optional invite-only seven-night challenge under Farm. It shares only tucked-away phones and completed quiet mornings."
                        )
                    }
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

    private func term(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.body)
            Text(detail)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
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
