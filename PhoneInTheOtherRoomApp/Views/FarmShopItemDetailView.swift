import SwiftUI

struct FarmShopItemDetailView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss

    let item: FarmShopItem
    let progress: FarmShopProgress

    private var state: FarmState { viewModel.farmState }
    private var isOwned: Bool { state.ownedShopItemIDs.contains(item.id) }
    private var isWelcomeGift: Bool { viewModel.persistence.welcomeRewardLedger.grant(of: .profileWearable)?.itemID == item.id }
    private var isUnlocked: Bool { isOwned || item.isUnlocked(for: progress) }
    private var canAfford: Bool { state.woolBalance >= item.woolCost }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                preview
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(item.category.title.uppercased())
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(item.title)
                        .font(AppTypography.display(26))
                        .foregroundStyle(AppColors.ink)
                    Text(item.detail)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                }
                Text(placementDescription)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                statusCard
                action
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Shop preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .farmActionAlert(viewModel: viewModel)
    }

    @ViewBuilder
    private var preview: some View {
        if item.effect == .ollieAccessory {
            OllieWardrobePreview(itemID: item.id)
                .frame(maxWidth: .infinity)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        } else {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(farmVisualColor(item.visualStyle).opacity(0.14))
            switch item.effect {
            case .ollieAccessory:
                OllieFarmAvatar(accessoryItemID: item.id, size: 190)
            case .shepherdOutfit, .shepherdAccessory, .shepherdShirt:
                ShepherdAvatarView(profile: previewShepherd, size: 210)
            case .farmDecoration:
                GeometryReader { proxy in
                    ZStack {
                        PixelAssetImage(name: AssetSlot.Farm.backgroundDay, contentMode: .fill)
                            .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                        if let anchor = FarmShopCatalog.decorationAnchor(for: item.id) {
                            FarmDecorationSceneImage(item: item, size: CGFloat(anchor.size))
                                .position(x: proxy.size.width * anchor.normalizedCenterX,
                                          y: proxy.size.height * anchor.normalizedGroundY - anchor.size / 2)
                        }
                    }
                }.clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            case .capacity, .collectible, .fetchBall:
                FarmShopItemImage(item: item, size: 190)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.stroke.opacity(0.20), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of \(item.title)")
        }
    }

    private var statusCard: some View {
        PixelCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: isUnlocked ? "cloud.fill" : "lock.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isUnlocked ? AppColors.bark : AppColors.grass)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(isWelcomeGift ? "Welcome gift · Owned" : isOwned ? "Already yours" : "\(item.woolCost) wool")
                        .font(AppTypography.headline)
                    if !isUnlocked, let requirement = item.unlockRequirement.description {
                        Text(requirement)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    } else if !isOwned {
                        Text("You have \(state.woolBalance) wool.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var action: some View {
        if isOwned {
            FarmShopOwnedItemAction(item: item, state: state)
        } else if isUnlocked {
            Button(canAfford ? "Bring home for \(item.woolCost) wool" : "Keep gathering wool") {
                viewModel.purchaseFarmShopItem(item.id)
            }
            .buttonStyle(PixelPrimaryButtonStyle())
            .disabled(!canAfford)
        }
    }

    private var placementDescription: String {
        switch item.effect {
        case .fetchBall:
            return "Equipped for free fetch and clover practice. All balls throw the same way. Your other balls stay in the Shop, ready to switch. Practice is free with the original ball."
        case .ollieAccessory:
            return "Ollie wears one accessory at a time. Bringing this home changes his look; his other accessories stay in the wardrobe."
        case .shepherdShirt:
            return "Changes your shirt and keeps your headwear and outer layer selected. Closed coats may cover it; taking them off reveals your shirt."
        case .shepherdOutfit:
            return "Changes your outer layer and keeps your shirt and headwear selected. Your previous outer layer stays in the wardrobe."
        case .shepherdAccessory:
            return "Changes your headwear and keeps your clothing on. Your previous headwear stays in the wardrobe."
        case .farmDecoration:
            return item.id == "farm_lanterns"
                ? "Placed beside your Barn. These are personal decorations; the Slumber Party lantern is a separate group project."
                : "Placed in your pasture when you bring it home. Anything in the same spot returns to storage."
        case .collectible:
            return "Displayed on your Farm’s keepsake shelf. If all four spots are filled, it stays in storage until you make room."
        case .capacity:
            return "Opens more room for your flock. Pasture upgrades are added in order."
        }
    }

    private var previewShepherd: ShepherdProfile {
        var profile = state.shepherd
        switch item.effect {
        case .shepherdShirt: profile.shirtItemID = item.id
        case .shepherdOutfit: profile.outfitItemID = item.id
        case .shepherdAccessory: profile.accessoryItemID = item.id
        default: break
        }
        return profile
    }
}

#Preview("Locked Shop item") {
    NavigationStack {
        FarmShopItemDetailView(
            item: FarmShopCatalog.item(for: "farm_old_oak")!,
            progress: .newFarm
        )
    }
    .environmentObject(FocusRunViewModel())
}
