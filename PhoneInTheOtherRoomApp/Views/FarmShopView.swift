import SwiftUI

struct FarmShopView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var category: FarmShopCategory

    init(initialCategory: FarmShopCategory = .ollie) {
        _category = State(initialValue: initialCategory)
    }

    private var state: FarmState { viewModel.farmState }
    private var items: [FarmShopItem] { FarmShopCatalog.items(in: category) }
    private var ownedCount: Int { items.filter { state.ownedShopItemIDs.contains($0.id) }.count }
    private var itemColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                shopHeader
                categoryGrid
                categoryStory
                if category == .shepherd { shepherdLink }
                LazyVGrid(columns: itemColumns, alignment: .leading, spacing: AppSpacing.sm) {
                    ForEach(items) { item in
                        FarmShopItemCard(item: item, state: state)
                    }
                }
                .animation(AppMotion.navigation, value: category)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Farm Shop")
        .navigationBarTitleDisplayMode(.inline)
        .farmActionAlert(viewModel: viewModel)
    }

    private var shopHeader: some View {
        PixelCard {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .fill(AppColors.grass.opacity(0.12))
                    Image(systemName: "storefront.fill")
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppColors.grass)
                }
                .frame(width: 62, height: 62)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("FARM SHOP")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("Bring a little of the Farm home.")
                        .font(AppTypography.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Shear or trade sheep for wool, then choose what matters to you.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                WoolBalanceBadge(value: state.woolBalance)
            }
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: AppSpacing.xs)], spacing: AppSpacing.xs) {
            ForEach(FarmShopCategory.allCases) { option in
                Button {
                    withAnimation(AppMotion.navigation) { category = option }
                } label: {
                    VStack(spacing: AppSpacing.xxs) {
                        Image(systemName: option.shopSymbol)
                            .font(.title3.weight(.bold))
                            .frame(height: 26)
                        Text(option.shopTitle)
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .foregroundStyle(category == option ? Color.white : AppColors.ink)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(
                        category == option ? AppColors.grass : AppColors.surface,
                        in: RoundedRectangle(cornerRadius: AppRadius.md)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(
                                category == option ? AppColors.stroke : AppColors.stroke.opacity(0.20),
                                lineWidth: category == option ? 2 : 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(category == option ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Farm Shop categories")
    }

    private var categoryStory: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            categoryArtwork
                .frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(category.shopEyebrow)
                    .font(pixelFont(.caption2))
                    .foregroundStyle(AppColors.grass)
                Text(category.shopDescription)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(ownedCount) of \(items.count) brought home")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.stroke.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var categoryArtwork: some View {
        switch category {
        case .barn:
            PixelAssetImage(name: AssetSlot.Farm.barn)
        case .ollie:
            OllieFarmAvatar(accessoryItemID: state.equipment.ollieAccessoryItemID, size: 84)
        case .shepherd:
            ShepherdAvatarView(profile: state.shepherd, size: 84)
        case .farm:
            let item = items.first { state.equipment.farmDecorationItemIDs.contains($0.id) } ?? items.first
            if let item { FarmShopItemImage(item: item, size: 84) }
        case .collectibles:
            let item = items.first { state.equipment.collectibleItemIDs.contains($0.id) } ?? items.first
            if let item { FarmShopItemImage(item: item, size: 84) }
        }
    }

    private var shepherdLink: some View {
        NavigationLink {
            ShepherdCustomizationView()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                ShepherdAvatarView(profile: state.shepherd, size: 58)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("YOUR SHEPHERD")
                        .font(pixelFont(.caption2))
                        .foregroundStyle(AppColors.grass)
                    Text("Choose your look and open the wardrobe")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.muted)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.stroke.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct FarmShopItemCard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let item: FarmShopItem
    let state: FarmState

    private var isOwned: Bool { state.ownedShopItemIDs.contains(item.id) }
    private var canAfford: Bool { state.woolBalance >= item.woolCost }
    private var isActive: Bool {
        switch item.effect {
        case .capacity(let level): return state.barnCapacityLevel >= level
        case .ollieAccessory: return state.equipment.ollieAccessoryItemID == item.id
        case .shepherdOutfit: return state.shepherd.outfitItemID == item.id
        case .shepherdAccessory: return state.shepherd.accessoryItemID == item.id
        case .farmDecoration: return state.equipment.farmDecorationItemIDs.contains(item.id)
        case .collectible: return state.equipment.collectibleItemIDs.contains(item.id)
        }
    }
    private var isNextCapacityUpgrade: Bool {
        guard case .capacity(let level) = item.effect else { return true }
        return level == state.barnCapacityLevel + 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            art
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(item.title)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                statusBadge
            }
            Text(item.detail)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            priceRow
            action
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 284, alignment: .topLeading)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(isActive ? AppColors.grass : AppColors.stroke.opacity(0.20), lineWidth: isActive ? 2 : 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var art: some View {
        ZStack {
            LinearGradient(
                colors: [farmVisualColor(item.visualStyle).opacity(0.18), AppColors.wool.opacity(0.26)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            FarmShopItemImage(item: item, size: 108)
                .padding(AppSpacing.xs)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 116)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(farmVisualColor(item.visualStyle).opacity(0.22), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isActive {
            shopBadge(activeStatusTitle, color: AppColors.success)
        } else if isOwned {
            shopBadge("OWNED", color: AppColors.grass)
        }
    }

    private var activeStatusTitle: String {
        switch item.effect {
        case .capacity: return "OPEN"
        case .ollieAccessory, .shepherdOutfit, .shepherdAccessory: return "WORN"
        case .farmDecoration: return "PLACED"
        case .collectible: return "DISPLAYED"
        }
    }

    private func shopBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(pixelFont(.caption2))
            .foregroundStyle(color)
            .padding(.horizontal, AppSpacing.xxs)
            .padding(.vertical, 3)
            .background(color.opacity(0.10), in: Capsule())
    }

    private var priceRow: some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: "cloud.fill")
                .accessibilityHidden(true)
            Text("\(item.woolCost) wool")
                .font(AppTypography.caption.weight(.bold))
            Spacer(minLength: 0)
            if !canAfford && !isOwned {
                Text("\(item.woolCost - state.woolBalance) short")
                    .font(.caption2.weight(.semibold))
            }
        }
        .foregroundStyle(canAfford || isOwned ? AppColors.ink : AppColors.berry)
    }

    @ViewBuilder
    private var action: some View {
        if isOwned {
            if isCapacityItem {
                Label(capacityOwnedLabel, systemImage: "checkmark")
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.success)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppColors.success.opacity(0.09), in: RoundedRectangle(cornerRadius: AppRadius.md))
            } else {
                switch item.effect {
                case .ollieAccessory:
                    equipmentButton(isActive ? "Take off" : "Wear") {
                        if isActive { viewModel.takeOffOllieAccessory(item.id) }
                        else { viewModel.wearOllieAccessory(item.id) }
                    }
                case .shepherdOutfit:
                    equipmentButton(isActive ? "Take off" : "Wear") {
                        if isActive { viewModel.takeOffShepherdOutfit(item.id) }
                        else { viewModel.wearShepherdOutfit(item.id) }
                    }
                case .shepherdAccessory:
                    equipmentButton(isActive ? "Take off" : "Wear") {
                        if isActive { viewModel.takeOffShepherdAccessory(item.id) }
                        else { viewModel.wearShepherdAccessory(item.id) }
                    }
                case .farmDecoration:
                    equipmentButton(isActive ? "Put away" : "Place") {
                        if isActive { viewModel.putAwayFarmDecoration(item.id) }
                        else { viewModel.placeFarmDecoration(item.id) }
                    }
                case .collectible:
                    equipmentButton(isActive ? "Store" : "Display") {
                        if isActive { viewModel.storeFarmCollectible(item.id) }
                        else { viewModel.displayFarmCollectible(item.id) }
                    }
                case .capacity:
                    EmptyView()
                }
            }
        } else if !isNextCapacityUpgrade {
            Text("Open the previous pasture first")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .multilineTextAlignment(.center)
        } else {
            Button(canAfford ? "Bring home" : "Keep gathering wool") {
                viewModel.purchaseFarmShopItem(item.id)
            }
            .buttonStyle(PixelChipButtonStyle(isSelected: false))
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(!canAfford)
        }
    }

    private func equipmentButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(PixelChipButtonStyle(isSelected: isActive))
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private var isCapacityItem: Bool {
        if case .capacity = item.effect { return true }
        return false
    }

    private var capacityOwnedLabel: String {
        guard case .capacity(let level) = item.effect else { return "Open" }
        return "\(FarmEconomyRules.capacity(forLevel: level))-sheep space"
    }
}

private struct WoolBalanceBadge: View {
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "cloud.fill")
                .font(.headline.weight(.bold))
            Text("\(value)")
                .font(PixelTypography.mono(.headline))
            Text("WOOL")
                .font(pixelFont(.caption2))
        }
        .foregroundStyle(AppColors.bark)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.wool.opacity(0.72), in: RoundedRectangle(cornerRadius: AppRadius.md))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) wool available")
    }
}

private extension FarmShopCategory {
    var shopTitle: String {
        switch self {
        case .barn: return "Barn"
        case .ollie: return "Ollie"
        case .shepherd: return "Shepherd"
        case .farm: return "Farm"
        case .collectibles: return "Keepsakes"
        }
    }

    var shopSymbol: String {
        switch self {
        case .barn: return "house.lodge.fill"
        case .ollie: return "pawprint.fill"
        case .shepherd: return "person.fill"
        case .farm: return "leaf.fill"
        case .collectibles: return "shippingbox.fill"
        }
    }

    var shopEyebrow: String {
        switch self {
        case .barn: return "ROOM TO GROW"
        case .ollie: return "FOR OLLIE"
        case .shepherd: return "YOUR WARDROBE"
        case .farm: return "AROUND THE FARM"
        case .collectibles: return "TRAIL KEEPSAKES"
        }
    }

    var shopDescription: String {
        switch self {
        case .barn: return "Open another pasture when your flock needs more room."
        case .ollie: return "Small trail treasures for the collie who brings everyone home."
        case .shepherd: return "Clothes and field gear for your place beside Ollie."
        case .farm: return "Add warm corners and familiar landmarks to the pasture."
        case .collectibles: return "Keep a few objects from the stories behind the flock."
        }
    }
}
