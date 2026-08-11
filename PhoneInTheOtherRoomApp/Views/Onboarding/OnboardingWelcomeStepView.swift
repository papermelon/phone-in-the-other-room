import SwiftUI

struct OnboardingWelcomeStep: View {
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: AppCopy.OnboardingWelcome.eyebrow.value,
                title: AppCopy.OnboardingWelcome.title.value,
                detail: AppCopy.OnboardingWelcome.detail.value
            )

            OnboardingTimeline(draft: OnboardingDraft())

            VStack(spacing: AppSpacing.sm) {
                OllieRitualView(state: .ready, size: 112)
                Text("Ollie keeps watch while the phone rests somewhere else.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 320)
        }
    }
}

#Preview("Welcome") {
    OnboardingWelcomeStep()
        .padding()
        .background(AppColors.paper)
}
