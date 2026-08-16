import SwiftUI

struct OnboardingGiftStep: View {
    let recommendation: WindDownProfileRecommendation?
    let profileSkipped: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            OllieRitualView(state: .ready, presentation: .inline)
            onboardingTitle(
                eyebrow: "A WELCOME GIFT",
                title: profileSkipped ? "You can choose a starting point later." : "A gift is waiting on the Farm.",
                detail: profileSkipped
                    ? "Wind Down still works. You can answer the starting-point questions later from Settings."
                    : "Your Wind Down starting point left a free shepherd wearable. Claim it during the Farm guide; it does not spend wool."
            )

            if let wearable = recommendation?.wearableItem, !profileSkipped {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(wearable.title)
                            .font(AppTypography.headline)
                        Text("Ollie can help you put it on the shepherd after you reach Farm.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview("Profile gift") {
    OnboardingGiftStep(
        recommendation: WindDownProfileMapper.recommendation(for: .defaults),
        profileSkipped: false
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Profile skipped") {
    OnboardingGiftStep(recommendation: nil, profileSkipped: true)
        .padding()
        .background(AppColors.paper)
        .preferredColorScheme(.dark)
}
