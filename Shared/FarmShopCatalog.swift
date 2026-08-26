import Foundation

enum FarmShopCatalog {
    private static let tier1 = FarmShopUnlockRequirement.milestone(
        tier: 1,
        windDowns: 3,
        discoveries: 4
    )
    private static let tier2 = FarmShopUnlockRequirement.milestone(
        tier: 2,
        windDowns: 10,
        discoveries: 8
    )
    private static let tier3 = FarmShopUnlockRequirement.milestone(
        tier: 3,
        windDowns: 25,
        discoveries: SheepCatalog.all.count
    )

    static let all: [FarmShopItem] = capacityItems + ollieItems + shepherdItems
        + decorationItems + collectibleItems

    private static let capacityItems: [FarmShopItem] = [
        FarmShopItem(id: "barn_paddock_24", title: "Second Pasture", detail: "Room for 24 sheep.", category: .barn, woolCost: 15, symbolName: "square.grid.2x2.fill", inventoryAssetName: "shop/shop_barn_second_pasture", visualStyle: "wood", effect: .capacity(level: 1)),
        FarmShopItem(id: "barn_paddock_36", title: "Hill Pasture", detail: "Room for 36 sheep.", category: .barn, woolCost: 36, symbolName: "mountain.2.fill", inventoryAssetName: "shop/shop_barn_hill_pasture", visualStyle: "grass", effect: .capacity(level: 2)),
        FarmShopItem(id: "barn_paddock_48", title: "Moon Pasture", detail: "Room for 48 sheep.", category: .barn, woolCost: 80, symbolName: "moon.stars.fill", inventoryAssetName: "shop/shop_barn_moon_pasture", visualStyle: "lavender", effect: .capacity(level: 3)),
        FarmShopItem(id: "barn_paddock_60", title: "Wide Pasture", detail: "The full 60-sheep Farm.", category: .barn, woolCost: 170, symbolName: "sun.horizon.fill", inventoryAssetName: "shop/shop_barn_wide_pasture", visualStyle: "amber", effect: .capacity(level: 4))
    ]

    private static let ollieItems: [FarmShopItem] = [
        FarmShopItem(id: "ollie_moss_bandana", title: "Moss Bandana", detail: "A soft green knot for Ollie.", category: .ollie, woolCost: 3, symbolName: "leaf.fill", inventoryAssetName: "shop/shop_ollie_classic_moss_bandana", equippedRenderAsset: .ollieAccessory(overlayAssetName: "dog/dog_classic_farm_moss_bandana_equipped_overlay"), visualStyle: "grass", effect: .ollieAccessory),
        FarmShopItem(id: "ollie_moon_kerchief", title: "Moon Kerchief", detail: "Night-sky wool for long walks.", category: .ollie, woolCost: 6, symbolName: "moon.stars.fill", inventoryAssetName: "shop/shop_ollie_classic_moon_kerchief", equippedRenderAsset: .ollieAccessory(overlayAssetName: "dog/dog_classic_farm_moon_kerchief_equipped_overlay"), visualStyle: "lavender", effect: .ollieAccessory),
        FarmShopItem(id: "ollie_brass_bell", title: "Brass Farm Bell", detail: "A small bell for the pasture gate.", category: .ollie, woolCost: 4, symbolName: "bell.fill", inventoryAssetName: "shop/shop_ollie_classic_brass_trail_bell", equippedRenderAsset: .ollieAccessory(overlayAssetName: "dog/dog_classic_farm_brass_trail_bell_equipped_overlay"), visualStyle: "amber", effect: .ollieAccessory),
        FarmShopItem(id: "ollie_clover_collar", title: "Clover Collar", detail: "A clover-green collar for near-field trails.", category: .ollie, woolCost: 8, symbolName: "clover.fill", inventoryAssetName: "shop/shop_ollie_clover_collar", equippedRenderAsset: .ollieAccessory(overlayAssetName: "dog/dog_classic_farm_clover_collar_equipped_overlay"), visualStyle: "grass", effect: .ollieAccessory, unlockRequirement: tier1),
        FarmShopItem(id: "ollie_sunrise_scarf", title: "Sunrise Scarf", detail: "A soft amber scarf for early rounds.", category: .ollie, woolCost: 12, symbolName: "sunrise.fill", inventoryAssetName: "shop/shop_ollie_sunrise_scarf", equippedRenderAsset: .ollieAccessory(overlayAssetName: "dog/dog_classic_farm_sunrise_scarf_equipped_overlay"), visualStyle: "amber", effect: .ollieAccessory, unlockRequirement: tier2),
        FarmShopItem(id: "ollie_star_keeper_cape", title: "Star-Keeper Cape", detail: "A midnight cape for the longest trails.", category: .ollie, woolCost: 20, symbolName: "sparkles", inventoryAssetName: "shop/shop_ollie_star_keeper_cape", equippedRenderAsset: .ollieAccessory(overlayAssetName: "dog/dog_classic_farm_star_keeper_cape_equipped_overlay"), visualStyle: "lavender", effect: .ollieAccessory, unlockRequirement: tier3)
    ]

    private static let shepherdItems: [FarmShopItem] = [
        FarmShopItem(id: "shepherd_wool_hat", title: "Wool Field Hat", detail: "A warm hat for early mornings.", category: .shepherd, woolCost: 4, symbolName: "crown.fill", inventoryAssetName: "shop/shop_shepherd_wool_hat", equippedRenderAsset: headwearAssets("wool_field_hat"), visualStyle: "wood", effect: .shepherdAccessory),
        FarmShopItem(id: "shepherd_moss_coat", title: "Moss Work Coat", detail: "A green coat with deep pockets.", category: .shepherd, woolCost: 8, symbolName: "tshirt.fill", inventoryAssetName: "shop/shop_shepherd_moss_coat", equippedRenderAsset: .shepherdOutfit(overlayAssetName: "farm/farm_shepherd_moss_work_coat_equipped_overlay"), visualStyle: "grass", effect: .shepherdOutfit, unlockRequirement: tier1),
        FarmShopItem(id: "shepherd_moon_coat", title: "Moonlit Coat", detail: "A dusk-blue coat for nights at the Farm.", category: .shepherd, woolCost: 14, symbolName: "sparkles", inventoryAssetName: "shop/shop_shepherd_moon_coat", equippedRenderAsset: .shepherdOutfit(overlayAssetName: "farm/farm_shepherd_moonlit_coat_equipped_overlay"), visualStyle: "lavender", effect: .shepherdOutfit, unlockRequirement: tier2),
        FarmShopItem(id: "shepherd_clover_headscarf", title: "Clover Headscarf", detail: "A soft green wrap for breezy mornings.", category: .shepherd, woolCost: 6, symbolName: "leaf.fill", inventoryAssetName: "shop/shop_shepherd_clover_headscarf", equippedRenderAsset: headwearAssets("clover_headscarf"), visualStyle: "grass", effect: .shepherdAccessory, unlockRequirement: tier1),
        FarmShopItem(id: "shepherd_moon_beanie", title: "Moon Beanie", detail: "A knitted cap in quiet moonlit blue.", category: .shepherd, woolCost: 10, symbolName: "moon.fill", inventoryAssetName: "shop/shop_shepherd_moon_beanie", equippedRenderAsset: headwearAssets("moon_beanie"), visualStyle: "lavender", effect: .shepherdAccessory, unlockRequirement: tier2),
        FarmShopItem(id: "shepherd_field_overalls", title: "Field Overalls", detail: "Sturdy overalls for pasture work.", category: .shepherd, woolCost: 12, symbolName: "figure.walk", inventoryAssetName: "shop/shop_shepherd_field_overalls", equippedRenderAsset: .shepherdOutfit(overlayAssetName: "farm/farm_shepherd_field_overalls_equipped_overlay"), visualStyle: "wood", effect: .shepherdOutfit, unlockRequirement: tier2),
        FarmShopItem(id: "shepherd_star_keeper_cloak", title: "Star-Keeper Cloak", detail: "A deep-blue cloak lined with tiny stars.", category: .shepherd, woolCost: 22, symbolName: "star.fill", inventoryAssetName: "shop/shop_shepherd_star_keeper_cloak", equippedRenderAsset: .shepherdOutfit(overlayAssetName: "farm/farm_shepherd_star_keeper_cloak_equipped_overlay"), visualStyle: "lavender", effect: .shepherdOutfit, unlockRequirement: tier3)
    ]

    private static let decorationItems: [FarmShopItem] = [
        decoration(id: "farm_flower_patch", title: "Clover Patch", detail: "A flowering corner for the pasture.", cost: 4, symbol: "camera.macro", inventory: "shop/shop_farm_flower_patch", scene: "farm/farm_decoration_clover_patch_placed", style: "grass", zone: .leftMeadow),
        decoration(id: "farm_lanterns", title: "Barn Lanterns", detail: "A warm light beside the Barn.", cost: 3, symbol: "lightbulb.fill", inventory: "shop/shop_farm_lanterns", scene: "farm/farm_decoration_barn_lanterns_placed", style: "amber", zone: .rightMeadow),
        decoration(id: "farm_moon_gate", title: "Moon Gate", detail: "A silver marker for the night pasture.", cost: 5, symbol: "moon.fill", inventory: "shop/shop_farm_moon_gate", scene: "farm/farm_decoration_moon_gate_placed", style: "lavender", zone: .centerHorizon),
        decoration(id: "farm_twilight_banner", title: "Twilight Banner", detail: "A wool banner above the fence.", cost: 7, symbol: "flag.fill", inventory: "shop/shop_farm_twilight_banner", scene: "farm/farm_decoration_twilight_banner_placed", style: "berry", zone: .leftFence, unlock: tier1),
        decoration(id: "farm_story_bench", title: "Story Bench", detail: "A quiet seat beside the clover path.", cost: 8, symbol: "chair.lounge.fill", inventory: "shop/shop_farm_story_bench", scene: "farm/farm_decoration_story_bench_placed", style: "wood", zone: .leftMeadow, unlock: tier1),
        decoration(id: "farm_sheep_trough", title: "Sheep Trough", detail: "A sturdy water trough for the flock.", cost: 9, symbol: "drop.fill", inventory: "shop/shop_farm_sheep_trough", scene: "farm/farm_decoration_sheep_trough_placed", style: "wood", zone: .rightMeadow, unlock: tier1),
        decoration(id: "farm_dusk_pond", title: "Dusk Pond", detail: "Still water that catches the evening sky.", cost: 14, symbol: "water.waves", inventory: "shop/shop_farm_dusk_pond", scene: "farm/farm_decoration_dusk_pond_placed", style: "lavender", zone: .waterEdge, unlock: tier2),
        decoration(id: "farm_old_oak", title: "Old Oak", detail: "A broad tree for shade and stories.", cost: 20, symbol: "tree.fill", inventory: "shop/shop_farm_old_oak", scene: "farm/farm_decoration_old_oak_placed", style: "grass", zone: .barnCorner, unlock: tier3)
    ]

    private static let collectibleItems: [FarmShopItem] = [
        collectible(id: "collectible_trail_pin", title: "Brass Search Pin", detail: "A keepsake from Ollie’s first map.", cost: 3, symbol: "mappin.and.ellipse", asset: "shop/shop_collectible_trail_pin", style: "amber"),
        collectible(id: "collectible_story_bell", title: "Storybook Bell", detail: "A tiny bell from Storybook Barn.", cost: 10, symbol: "book.closed.fill", asset: "shop/shop_collectible_story_bell", style: "wood", unlock: tier2),
        collectible(id: "collectible_hoofprint_tile", title: "Hoofprint Tile", detail: "A little clay print from the near pasture.", cost: 5, symbol: "pawprint.fill", asset: "shop/shop_collectible_hoofprint_tile", style: "wood"),
        collectible(id: "collectible_wool_almanac", title: "Wool Almanac", detail: "Notes on fleece, weather, and patient work.", cost: 8, symbol: "book.pages.fill", asset: "shop/shop_collectible_wool_almanac", style: "grass", unlock: tier1),
        collectible(id: "collectible_sunrise_compass", title: "Sunrise Compass", detail: "A brass compass that points toward morning.", cost: 14, symbol: "safari.fill", asset: "shop/shop_collectible_sunrise_compass", style: "amber", unlock: tier2),
        collectible(id: "collectible_high_moor_star", title: "High Moor Star", detail: "A small silver star from Ollie’s longest trail.", cost: 17, symbol: "star.fill", asset: "shop/shop_collectible_high_moor_star", style: "lavender", unlock: tier3)
    ]

    static func item(for id: String) -> FarmShopItem? { all.first { $0.id == id } }
    static func items(in category: FarmShopCategory) -> [FarmShopItem] { all.filter { $0.category == category } }
    static func isFinishedShepherdWearable(_ itemID: String) -> Bool { WelcomeRewardCatalog.isFinishedShepherdWearable(itemID) }
    static func decorationZone(for itemID: String) -> FarmDecorationZone? { item(for: itemID)?.decorationZone }

    static func unlockRequirement(forTier tier: Int) -> FarmShopUnlockRequirement {
        switch tier {
        case 1: return tier1
        case 2: return tier2
        case 3: return tier3
        default: return .immediate
        }
    }

    static func decorationAnchor(for zone: FarmDecorationZone) -> FarmDecorationAnchor {
        switch zone {
        case .leftMeadow: return FarmDecorationAnchor(normalizedCenterX: 0.20, normalizedGroundY: 0.52, size: 50)
        case .rightMeadow: return FarmDecorationAnchor(normalizedCenterX: 0.80, normalizedGroundY: 0.52, size: 50)
        case .centerHorizon: return FarmDecorationAnchor(normalizedCenterX: 0.52, normalizedGroundY: 0.43, size: 60)
        case .leftFence: return FarmDecorationAnchor(normalizedCenterX: 0.32, normalizedGroundY: 0.39, size: 54)
        case .waterEdge: return FarmDecorationAnchor(normalizedCenterX: 0.65, normalizedGroundY: 0.56, size: 60)
        case .barnCorner: return FarmDecorationAnchor(normalizedCenterX: 0.84, normalizedGroundY: 0.40, size: 68)
        }
    }

    static func decorationAnchor(for itemID: String) -> FarmDecorationAnchor? {
        decorationZone(for: itemID).map(decorationAnchor)
    }

    private static func headwearAssets(_ slug: String) -> FarmShopEquippedRenderAsset {
        .shepherdAccessoryByHairStyle(ShepherdHairStyle.allCases.map {
            ShepherdRenderAsset(
                hairStyle: $0,
                assetName: "farm/farm_shepherd_\($0.rawValue)_\(slug)_equipped_overlay"
            )
        })
    }

    private static func decoration(id: String, title: String, detail: String, cost: Int, symbol: String, inventory: String, scene: String, style: String, zone: FarmDecorationZone, unlock: FarmShopUnlockRequirement = .immediate) -> FarmShopItem {
        FarmShopItem(id: id, title: title, detail: detail, category: .farm, woolCost: cost, symbolName: symbol, inventoryAssetName: inventory, sceneAssetName: scene, visualStyle: style, effect: .farmDecoration, unlockRequirement: unlock, decorationZone: zone)
    }

    private static func collectible(id: String, title: String, detail: String, cost: Int, symbol: String, asset: String, style: String, unlock: FarmShopUnlockRequirement = .immediate) -> FarmShopItem {
        FarmShopItem(id: id, title: title, detail: detail, category: .collectibles, woolCost: cost, symbolName: symbol, inventoryAssetName: asset, visualStyle: style, effect: .collectible, unlockRequirement: unlock)
    }
}
