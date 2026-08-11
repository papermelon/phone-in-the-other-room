import SwiftUI

struct ShepherdCustomizationView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    private var state: FarmState { viewModel.farmState }
    private var ownedWearables: [FarmShopItem] {
        FarmShopCatalog.items(in: .shepherd).filter { state.ownedShopItemIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                avatarCard
                skinSection
                hairSection
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

    private var skinSection: some View {
        choiceSection(title: "SKIN TONE") {
            ForEach(ShepherdSkinTone.allCases) { tone in
                Button {
                    viewModel.setShepherdSkinTone(tone)
                } label: {
                    VStack(spacing: AppSpacing.xxs) {
                        Circle()
                            .fill(shepherdSkinColor(tone))
                            .frame(width: 42, height: 42)
                            .overlay {
                                Circle().stroke(
                                    state.shepherd.skinTone == tone ? AppColors.grass : AppColors.stroke.opacity(0.22),
                                    lineWidth: state.shepherd.skinTone == tone ? 3 : 1
                                )
                            }
                        Text(tone.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.ink)
                    }
                }
                .buttonStyle(.plain)
                .frame(minWidth: 64, minHeight: 64)
            }
        }
    }

    private var hairSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("HAIR")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: AppSpacing.sm)],
                spacing: AppSpacing.sm
            ) {
                ForEach(ShepherdHairStyle.allCases) { style in
                    Button {
                        viewModel.setShepherdHairStyle(style)
                    } label: {
                        VStack(spacing: AppSpacing.xxs) {
                            ShepherdAvatarView(
                                profile: ShepherdProfile(
                                    skinTone: state.shepherd.skinTone,
                                    hairStyle: style,
                                    outfitItemID: state.shepherd.outfitItemID,
                                    accessoryItemID: nil
                                ),
                                size: 68
                            )
                            Text(style.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppColors.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                        .background(
                            state.shepherd.hairStyle == style
                                ? AppColors.grass.opacity(0.14)
                                : AppColors.surface.opacity(0.45),
                            in: RoundedRectangle(cornerRadius: AppRadius.md)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(
                                    state.shepherd.hairStyle == style
                                        ? AppColors.grass
                                        : AppColors.stroke.opacity(0.16),
                                    lineWidth: state.shepherd.hairStyle == style ? 2 : 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(style.title) hair")
                    .accessibilityAddTraits(state.shepherd.hairStyle == style ? .isSelected : [])
                }
            }
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

    private func choiceSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm, content: content)
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
