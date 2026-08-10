import SwiftUI

struct OnboardingWelcomeStep: View {
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "A QUIETER NIGHT",
                title: "Put your phone to bed.\nWake before it does.",
                detail: "Counting Sheep helps you put the phone in another room before bed, then keeps the first quiet part of morning phone-free."
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
