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

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Label("Ollie has a trail to follow", systemImage: "pawprint.fill")
                        .font(AppTypography.headline)
                    Text("Only an eligible completed protected night can move Ollie’s sheep search forward. Practice quiet and one-time quiet periods are recorded separately.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }

            HStack(alignment: .center, spacing: AppSpacing.sm) {
                OllieRitualView(state: .ready, size: 92)
                if let starterSheep = SheepCatalog.all.first {
                    SheepPosterCard(
                        sheep: starterSheep,
                        status: .missing,
                        outcome: nil,
                        showExactOdds: false
                    )
                }
            }
            .frame(maxWidth: 340)
        }
    }
}

#Preview("Welcome") {
    OnboardingWelcomeStep()
        .padding()
        .background(AppColors.paper)
}
