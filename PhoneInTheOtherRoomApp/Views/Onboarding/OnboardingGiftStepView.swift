import SwiftUI

struct OnboardingGiftStep: View {
    let recommendation: WindDownProfileRecommendation?
    let profileSkipped: Bool
    var onKeepCurrentOutfit: () -> Void = {}
    var onWearMoonlitCoat: (String) -> Void = { _ in }
    @State private var choice: GiftChoice?

    private enum GiftChoice { case keep, wear }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            OllieRitualView(state: .ready, presentation: .inline)
            onboardingTitle(
                eyebrow: "A WELCOME GIFT",
                title: profileSkipped ? "You can choose a starting point later." : "A gift is waiting on the Farm.",
                detail: profileSkipped
                    ? "Wind Down still works. You can answer the starting-point questions later from Settings."
                    : "Moonlit Coat was added to your wardrobe. Choose whether to wear it now."
            )

            if let wearable = recommendation?.wearableItem, !profileSkipped {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(alignment: .center, spacing: AppSpacing.md) {
                            FarmShopItemImage(item: wearable, size: 92)
                                .frame(width: 104, height: 104)
                                .background(AppColors.lavender.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.md))
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(wearable.title)
                                    .font(AppTypography.headline)
                                Text("Welcome gift · Owned")
                                    .font(AppTypography.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.grass)
                            }
                        }
                        ShepherdAvatarView(
                            profile: previewProfile(for: wearable),
                            size: 170
                        )
                            .frame(maxWidth: .infinity)
                        Text(choice == .wear ? "Moonlit Coat is on your Shepherd." : choice == .keep ? "Your current outfit stays on." : "Your current outfit is still on.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: AppSpacing.sm) {
                                giftButton("Keep my current outfit", isSelected: choice == .keep) {
                                    choice = .keep
                                    onKeepCurrentOutfit()
                                }
                                giftButton("Wear Moonlit Coat", isSelected: choice == .wear) {
                                    choice = .wear
                                    onWearMoonlitCoat(wearable.id)
                                }
                            }
                            VStack(spacing: AppSpacing.xs) {
                                giftButton("Wear Moonlit Coat", isSelected: choice == .wear) {
                                    choice = .wear
                                    onWearMoonlitCoat(wearable.id)
                                }
                                giftButton("Keep my current outfit", isSelected: choice == .keep) {
                                    choice = .keep
                                    onKeepCurrentOutfit()
                                }
                            }
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func previewProfile(for wearable: FarmShopItem) -> ShepherdProfile {
        var profile = FarmState.empty.shepherd
        profile.outfitItemID = wearable.id
        return profile
    }

    private func giftButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(PixelChipButtonStyle(isSelected: isSelected))
            .frame(maxWidth: .infinity, minHeight: 48)
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
