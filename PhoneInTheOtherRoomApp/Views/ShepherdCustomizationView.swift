import SwiftUI

struct ShepherdCustomizationView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var nameDraft = ""
    @State private var nameFeedback: String?

    private var state: FarmState { viewModel.farmState }
    private var ownedWearables: [FarmShopItem] {
        FarmShopCatalog.items(in: .shepherd).filter { state.ownedShopItemIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                avatarCard
                ShepherdNameCard(
                    profile: viewModel.userProfile,
                    draftName: $nameDraft,
                    feedback: $nameFeedback,
                    onSave: { viewModel.saveShepherdDisplayName($0) }
                )
                ShepherdAppearanceControls(
                    profile: state.shepherd,
                    onSkinTone: viewModel.setShepherdSkinTone,
                    onHairStyle: viewModel.setShepherdHairStyle
                )
                wardrobeSection
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Your Shepherd")
        .navigationBarTitleDisplayMode(.inline)
        .farmActionAlert(viewModel: viewModel)
    }

    private var avatarCard: some View {
        PixelCard {
            VStack(spacing: AppSpacing.sm) {
                ShepherdAvatarView(profile: state.shepherd, size: 180)
                Text("YOUR SHEPHERD")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("This is your place beside Ollie at the Farm.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var wardrobeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("WARDROBE")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            if ownedWearables.isEmpty {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("The wardrobe has room.")
                            .font(AppTypography.headline)
                        Text("Bring home hats and coats from the Farm Shop.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                        NavigationLink("Browse shepherd wearables") {
                            FarmShopView(initialCategory: .shepherd)
                        }
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            } else {
                ForEach(ownedWearables) { item in
                    HStack(spacing: AppSpacing.sm) {
                        FarmShopItemImage(item: item, size: 54)
                            .frame(width: 54, height: 54)
                            .background(farmVisualColor(item.visualStyle).opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.md))
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(item.title).font(AppTypography.headline)
                            Text(isEquipped(item) ? "Equipped" : "Owned")
                                .font(AppTypography.caption)
                                .foregroundStyle(isEquipped(item) ? AppColors.success : AppColors.secondaryText)
                        }
                        Spacer()
                        Button(isEquipped(item) ? "Take off" : "Wear") {
                            toggleWearable(item)
                        }
                        .buttonStyle(PixelChipButtonStyle(isSelected: isEquipped(item)))
                        .frame(minWidth: 72, minHeight: 44)
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.md))
                }
            }
        }
    }

    private func isEquipped(_ item: FarmShopItem) -> Bool {
        switch item.effect {
        case .shepherdOutfit: return state.shepherd.outfitItemID == item.id
        case .shepherdAccessory: return state.shepherd.accessoryItemID == item.id
        default: return false
        }
    }

    private func toggleWearable(_ item: FarmShopItem) {
        switch item.effect {
        case .shepherdOutfit:
            if isEquipped(item) { viewModel.takeOffShepherdOutfit(item.id) }
            else { viewModel.wearShepherdOutfit(item.id) }
        case .shepherdAccessory:
            if isEquipped(item) { viewModel.takeOffShepherdAccessory(item.id) }
            else { viewModel.wearShepherdAccessory(item.id) }
        default:
            break
        }
    }

}

struct ShepherdAppearanceControls: View {
    let profile: ShepherdProfile
    let onSkinTone: (ShepherdSkinTone) -> Void
    let onHairStyle: (ShepherdHairStyle) -> Void
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("SKIN TONE")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(ShepherdSkinTone.allCases) { tone in skinChoice(tone) }
                    }
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("HAIR")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: compact ? 78 : 88), spacing: AppSpacing.sm)],
                    spacing: AppSpacing.sm
                ) {
                    ForEach(ShepherdHairStyle.allCases) { style in hairChoice(style) }
                }
            }
        }
    }

    private func skinChoice(_ tone: ShepherdSkinTone) -> some View {
        Button { onSkinTone(tone) } label: {
            VStack(spacing: AppSpacing.xxs) {
                Circle()
                    .fill(shepherdSkinColor(tone))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Circle().stroke(
                            profile.skinTone == tone ? AppColors.grass : AppColors.stroke.opacity(0.22),
                            lineWidth: profile.skinTone == tone ? 3 : 1
                        )
                    }
                Text(tone.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.ink)
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 64, minHeight: 64)
        .accessibilityLabel("\(tone.title) skin tone")
        .accessibilityAddTraits(profile.skinTone == tone ? .isSelected : [])
    }

    private func hairChoice(_ style: ShepherdHairStyle) -> some View {
        Button { onHairStyle(style) } label: {
            VStack(spacing: AppSpacing.xxs) {
                ShepherdAvatarView(
                    profile: ShepherdProfile(
                        skinTone: profile.skinTone,
                        hairStyle: style,
                        outfitItemID: profile.outfitItemID,
                        accessoryItemID: nil
                    ),
                    size: compact ? 58 : 68
                )
                Text(style.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(.vertical, AppSpacing.xs)
            .background(
                profile.hairStyle == style
                    ? AppColors.grass.opacity(0.14)
                    : AppColors.surface.opacity(0.45),
                in: RoundedRectangle(cornerRadius: AppRadius.md)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(
                        profile.hairStyle == style ? AppColors.grass : AppColors.stroke.opacity(0.16),
                        lineWidth: profile.hairStyle == style ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(style.title) hair")
        .accessibilityAddTraits(profile.hairStyle == style ? .isSelected : [])
    }
}

#Preview("Your Shepherd") {
    NavigationStack {
        VStack(spacing: AppSpacing.md) {
            ShepherdAvatarView(profile: FarmPreviewData.fullState.shepherd, size: 180)
            Text("Five skin tones and five hair styles")
                .font(AppTypography.body)
        }
        .padding()
        .background(AppColors.paper)
    }
}

#Preview("Shepherd hair variants") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))]) {
        ForEach(ShepherdHairStyle.allCases) { style in
            VStack {
                ShepherdAvatarView(
                    profile: ShepherdProfile(
                        skinTone: .warm,
                        hairStyle: style,
                        outfitItemID: nil,
                        accessoryItemID: nil
                    ),
                    size: 120
                )
                Text(style.title)
                    .font(AppTypography.caption)
            }
        }
    }
    .padding()
    .background(AppColors.paper)
}
