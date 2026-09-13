import SwiftUI
import UserNotifications

struct OnboardingReadyStep: View {
    let draft: OnboardingDraft
    let showsTourHandoff: Bool
    var showsSlumberParty = false
    var appProtectionReady = false
    var notificationAuthorization: UNAuthorizationStatus = .notDetermined

    private var summary: OnboardingReadinessSummary {
        OnboardingReadinessSummary(
            draft: draft,
            appProtectionReady: appProtectionReady,
            notificationAuthorized: notificationAuthorized
        )
    }

    private var notificationAuthorized: Bool {
        switch notificationAuthorization {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            OllieRitualView(state: .ready, presentation: .inline)
            onboardingTitle(
                eyebrow: "REVIEW YOUR PLAN",
                title: "A little room for your evening.",
                detail: "Save this plan to see it on Home. You can change it whenever you need."
            )

            OnboardingTimeline(draft: draft)

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    summaryRow("Planned Wind Down", value: timeLabel(summary.nextWindDownStart))
                    summaryRow("Intended bedtime", value: timeLabel(summary.intendedBedtime))
                    summaryRow(
                        "Phone away overnight",
                        value: "\(timeLabel(summary.intendedBedtime)) – \(timeLabel(summary.intendedWakeTime))"
                    )
                    summaryRow("Intended wake time", value: timeLabel(summary.intendedWakeTime))
                    summaryRow("Screen-Free Morning ends", value: timeLabel(summary.morningQuietEnd))
                }
            }

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("YOUR PRIVATE ROUTINE")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    routineGroup(
                        title: summary.isLaterToday ? "Tonight" : "Next Wind Down",
                        steps: summary.eveningAnchors
                    )
                    Divider()
                    routineGroup(title: "The following morning", steps: summary.morningAnchors)
                }
            }

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    summaryRow("Protection", value: shieldingSummary)
                    summaryRow("Reminder", value: reminderSummary)
                }
            }

            Text(summary.appProtectionReady
                 ? "When it is time, open Counting Sheep to begin. Your plan does not start a session."
                 : "Before starting a session, allow Screen Time access and choose apps to limit. You can do that from Home.")
                .font(AppTypography.body.weight(.semibold))
                .foregroundStyle(AppColors.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(handoffMessage)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var handoffMessage: String {
        if showsTourHandoff {
            return "Go to Home saves your plan. The short Home tour is optional."
        }
        return "Save changes to update the plan on Home."
    }

    private var shieldingSummary: String {
        summary.appProtectionReady ? "Setup ready · session not started" : "Needs setup before starting"
    }

    private var reminderSummary: String {
        switch summary.reminderReadiness {
        case .off:
            return "Off"
        case .enabledAndAuthorized:
            return "On at \(timeLabel(summary.nextWindDownStart))"
        case .enabledWithoutAuthorization:
            return "On — notification permission needed"
        }
    }

    private func summaryRow(_ title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                summaryTitle(title)
                Spacer(minLength: AppSpacing.sm)
                summaryValue(value, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                summaryTitle(title)
                summaryValue(value, alignment: .leading)
            }
        }
    }

    private func summaryTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func summaryValue(_ value: String, alignment: TextAlignment) -> some View {
        Text(value)
            .font(AppTypography.body)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func routineGroup(title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.body.weight(.semibold))
            if steps.isEmpty {
                Text("Leave this open for now")
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

    private func timeLabel(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
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

#Preview("Saved plan · reminders denied") {
    var draft = OnboardingDraft()
    draft.remindersEnabled = true
    return ScrollView {
        OnboardingReadyStep(
            draft: draft,
            showsTourHandoff: true,
            appProtectionReady: true,
            notificationAuthorization: .denied
        )
        .padding()
    }
    .background(AppColors.paper)
}

#Preview("Saved plan · large type") {
    ScrollView {
        OnboardingReadyStep(draft: OnboardingDraft(), showsTourHandoff: true)
            .padding()
    }
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
}
