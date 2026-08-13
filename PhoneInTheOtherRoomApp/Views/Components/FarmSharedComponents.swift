import SwiftUI
import UIKit

struct FarmBalanceBar: View {
    let state: FarmState
    var linksEnabled = false

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if linksEnabled {
                NavigationLink { FarmBarnView() } label: {
                    metric(
                        icon: "sheep.fill",
                        fallbackIcon: "pawprint.fill",
                        value: "\(state.activeSheep.count)/\(state.activeCapacity)",
                        label: "Flock"
                    )
                }
                NavigationLink { TrailNotesArchiveView() } label: {
                    metric(icon: "book.closed.fill", value: "\(state.discoveries.count)", label: "Known sheep")
                }
                NavigationLink { FarmShopView() } label: {
                    metric(icon: "cloud.fill", value: "\(state.woolBalance)", label: "Wool")
                }
            } else {
                metric(
                    icon: "sheep.fill",
                    fallbackIcon: "pawprint.fill",
                    value: "\(state.activeSheep.count)/\(state.activeCapacity)",
                    label: "Flock"
                )
                metric(icon: "book.closed.fill", value: "\(state.discoveries.count)", label: "Known sheep")
                metric(icon: "cloud.fill", value: "\(state.woolBalance)", label: "Wool")
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
    }

    private func metric(
        icon: String,
        fallbackIcon: String? = nil,
        value: String,
        label: String
    ) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            Image(systemName: UIImage(systemName: icon) == nil ? (fallbackIcon ?? icon) : icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.grass)
            Text(value)
                .font(PixelTypography.mono(.caption))
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.stroke.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct FarmSheepSprite: View {
    let sheep: FlockSheep
    let protectedNightCount: Int
    var size: CGFloat = 64
    var showsStatusBadge = true

    private var definition: SheepDefinition? {
        SheepCatalog.definition(for: sheep.definitionID)
    }

    private var woolReady: Bool {
        FarmEconomyRules.isWoolReady(for: sheep, protectedNightCount: protectedNightCount)
    }

    private var woolVisualState: SheepWoolVisualState {
        FarmEconomyRules.woolVisualState(
            for: sheep,
            protectedNightCount: protectedNightCount
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PixelAssetImage(
                name: definition?.assetName(for: woolVisualState) ?? AssetSlot.Sheep.common
            )
                .opacity(sheep.status == .sold ? 0.45 : 1)
                .frame(width: size, height: size)

            if showsStatusBadge {
                if sheep.status == .pending {
                    statusBadge("hourglass", color: AppColors.amber)
                } else if woolReady {
                    statusBadge("cloud.fill", color: AppColors.wool)
                } else {
                    statusBadge("scissors", color: AppColors.lavender)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func statusBadge(_ symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: max(7, size * 0.12), weight: .black))
            .foregroundStyle(AppColors.bark)
            .padding(max(2, size * 0.045))
            .background(color, in: Circle())
            .overlay { Circle().stroke(AppColors.bark.opacity(0.4), lineWidth: 1) }
    }

    private var accessibilityLabel: String {
        let wool = woolReady ? "wool ready" : "wool regrowing"
        return "\(sheep.displayName), \(sheep.rarity.title), \(wool)"
    }
}

struct FarmShopItemImage: View {
    let item: FarmShopItem
    var size: CGFloat = 64

    var body: some View {
        FarmCatalogAssetImage(
            assetName: item.inventoryAssetName,
            fallbackSymbol: item.symbolName,
            fallbackColor: farmVisualColor(item.visualStyle),
            size: size
        )
        .accessibilityHidden(true)
    }
}

private struct FarmCatalogAssetImage: View {
    let assetName: String?
    let fallbackSymbol: String
    let fallbackColor: Color
    let size: CGFloat

    var body: some View {
        Group {
            if let assetName, UIImage(named: assetName) != nil {
                PixelAssetImage(name: assetName)
            } else {
                Image(systemName: fallbackSymbol)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(fallbackColor)
                    .padding(size * 0.18)
            }
        }
        .frame(width: size, height: size)
    }
}

struct FarmEquippedOverlayImage: View {
    let assetName: String?
    let size: CGFloat

    @ViewBuilder
    var body: some View {
        if let assetName, UIImage(named: assetName) != nil {
            PixelAssetImage(name: assetName)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

struct OllieFarmAvatar: View {
    let accessoryItemID: String?
    var size: CGFloat = 72

    private var equippedOverlayAssetName: String? {
        guard let item = accessoryItemID.flatMap(FarmShopCatalog.item),
              case .ollieAccessory(let assetName) = item.equippedRenderAsset else {
            return nil
        }
        return assetName
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ollieBase
            if equippedOverlayAssetName != nil {
                FarmEquippedOverlayImage(assetName: equippedOverlayAssetName, size: size)
                    .shadow(color: AppShadows.cardColor, radius: 1, y: 1)

                // Repaint Ollie's head and upper chest above the accessory. The
                // feathered depth matte makes the collar opening disappear behind
                // his chin and neck fur instead of reading as a flat sticker.
                ollieBase
                    .mask(accessoryDepthMask)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var ollieBase: some View {
        FarmCatalogAssetImage(
            assetName: AssetSlot.Dog.farmNeutralIdle,
            fallbackSymbol: "pawprint.fill",
            fallbackColor: AppColors.grass,
            size: size
        )
    }

    private var accessoryDepthMask: some View {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.54),
                .init(color: .clear, location: 0.64)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: size, height: size)
    }

    private var accessibilityLabel: String {
        if let item = accessoryItemID.flatMap(FarmShopCatalog.item) {
            return "Ollie wearing \(item.title)"
        }
        return "Ollie in the pasture"
    }
}

struct ShepherdAvatarView: View {
    let profile: ShepherdProfile
    var size: CGFloat = 84

    private var outfit: FarmShopItem? {
        profile.outfitItemID.flatMap(FarmShopCatalog.item)
    }

    private var accessoryRenderAssetName: String? {
        guard let accessory = profile.accessoryItemID.flatMap(FarmShopCatalog.item),
              let equippedRenderAsset = accessory.equippedRenderAsset else {
            return nil
        }
        return equippedRenderAsset.assetName(for: profile.hairStyle)
    }

    var body: some View {
        ZStack(alignment: .top) {
            avatarImage(avatarAssets.base)

            avatarMask(avatarAssets.skinMask)
                .foregroundStyle(shepherdSkinColor(profile.skinTone))

            if let outfit {
                avatarMask(avatarAssets.outfitMask)
                    .foregroundStyle(farmVisualColor(outfit.visualStyle))
            }

            FarmEquippedOverlayImage(assetName: accessoryRenderAssetName, size: size)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your Shepherd, \(profile.skinTone.title) skin, \(profile.hairStyle.title) hair")
    }

    private func avatarImage(_ name: String) -> some View {
        Image(name)
            .resizable()
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
    }

    private func avatarMask(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
    }

    private var avatarAssets: (base: String, skinMask: String, outfitMask: String) {
        switch profile.hairStyle {
        case .cropped:
            (
                AssetSlot.Farm.shepherdDefault,
                AssetSlot.Farm.shepherdSkinMask,
                AssetSlot.Farm.shepherdOutfitMask
            )
        case .waves:
            (
                AssetSlot.Farm.shepherdHairWaves,
                AssetSlot.Farm.shepherdHairWavesSkinMask,
                AssetSlot.Farm.shepherdHairWavesOutfitMask
            )
        case .curls:
            (
                AssetSlot.Farm.shepherdHairCurls,
                AssetSlot.Farm.shepherdHairCurlsSkinMask,
                AssetSlot.Farm.shepherdHairCurlsOutfitMask
            )
        case .coils:
            (
                AssetSlot.Farm.shepherdHairCoils,
                AssetSlot.Farm.shepherdHairCoilsSkinMask,
                AssetSlot.Farm.shepherdHairCoilsOutfitMask
            )
        case .long:
            (
                AssetSlot.Farm.shepherdHairLong,
                AssetSlot.Farm.shepherdHairLongSkinMask,
                AssetSlot.Farm.shepherdHairLongOutfitMask
            )
        }
    }
}

struct FarmKeepsakeDisplay: View {
    let state: FarmState

    private var displayedItems: [FarmShopItem] {
        state.equipment.collectibleItemIDs.compactMap(FarmShopCatalog.item)
            .filter { $0.effect == .collectible }
    }

    @ViewBuilder
    var body: some View {
        if !displayedItems.isEmpty {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("KEEPSAKES ON DISPLAY")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text("Small stories from the trail, kept close to the Barn.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    LazyHGrid(rows: [GridItem(.fixed(100))], spacing: AppSpacing.sm) {
                        ForEach(displayedItems) { item in
                            VStack(spacing: AppSpacing.xxs) {
                                FarmShopItemImage(item: item, size: 58)
                                Text(item.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppColors.ink)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(width: 84)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Displayed keepsake: \(item.title)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

func shepherdSkinColor(_ tone: ShepherdSkinTone) -> Color {
    switch tone {
    case .porcelain: return Color(red: 0.95, green: 0.78, blue: 0.66)
    case .warm: return Color(red: 0.82, green: 0.59, blue: 0.43)
    case .olive: return Color(red: 0.68, green: 0.49, blue: 0.33)
    case .brown: return Color(red: 0.47, green: 0.30, blue: 0.20)
    case .deep: return Color(red: 0.29, green: 0.18, blue: 0.13)
    }
}

func farmVisualColor(_ style: String) -> Color {
    switch style {
    case "grass": return AppColors.grass
    case "lavender": return AppColors.lavender
    case "amber": return AppColors.amber
    case "berry": return AppColors.berry
    default: return AppColors.wood
    }
}

extension View {
    func farmActionAlert(viewModel: FocusRunViewModel) -> some View {
        alert(
            "Farm update",
            isPresented: Binding(
                get: { viewModel.farmActionMessage != nil },
                set: { if !$0 { viewModel.clearFarmActionMessage() } }
            )
        ) {
            Button("OK") { viewModel.clearFarmActionMessage() }
        } message: {
            Text(viewModel.farmActionMessage ?? "")
        }
    }
}
