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
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .fill(farmVisualColor(item.visualStyle).opacity(0.14))
            switch item.effect {
            case .ollieAccessory:
                OllieFarmAvatar(accessoryItemID: item.id, size: 190)
            case .shepherdOutfit, .shepherdAccessory:
                ShepherdAvatarView(profile: previewShepherd, size: 210)
            case .farmDecoration:
                PixelAssetImage(name: AssetSlot.Farm.backgroundDay, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                FarmDecorationSceneImage(item: item, size: 130)
                    .offset(y: 38)
            case .capacity, .collectible:
                FarmShopItemImage(item: item, size: 190)
            }
            if !isUnlocked {
                Color.black.opacity(0.28)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                Image(systemName: "lock.fill")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppColors.paper)
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

    private var statusCard: some View {
        PixelCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: isUnlocked ? "cloud.fill" : "lock.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isUnlocked ? AppColors.bark : AppColors.grass)
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
            Text("This item is safely stored at the Farm.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
        } else if isUnlocked {
            Button(canAfford ? "Bring home for \(item.woolCost) wool" : "Keep gathering wool") {
                viewModel.purchaseFarmShopItem(item.id)
            }
            .buttonStyle(PixelPrimaryButtonStyle())
            .disabled(!canAfford)
        }
    }

    private var previewShepherd: ShepherdProfile {
        var profile = state.shepherd
        switch item.effect {
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
