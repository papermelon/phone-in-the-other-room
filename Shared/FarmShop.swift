import Foundation

enum FarmShopCategory: String, CaseIterable, Identifiable {
    case barn, ollie, shepherd, farm, collectibles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .barn: return "The Barn"
        case .ollie: return "Ollie"
        case .shepherd: return "Your Shepherd"
        case .farm: return "Farm"
        case .collectibles: return "Collectibles"
        }
    }
}

enum FarmShopEffect: Equatable {
    case capacity(level: Int)
    case ollieAccessory
    case shepherdOutfit
    case shepherdAccessory
    case farmDecoration
    case collectible
}

struct ShepherdRenderAsset: Equatable {
    let hairStyle: ShepherdHairStyle
    let assetName: String
}

enum FarmShopEquippedRenderAsset: Equatable {
    case ollieAccessory(overlayAssetName: String)
    case shepherdAccessoryByHairStyle([ShepherdRenderAsset])

    func assetName(for hairStyle: ShepherdHairStyle) -> String? {
        guard case .shepherdAccessoryByHairStyle(let assets) = self else { return nil }
        return assets.first { $0.hairStyle == hairStyle }?.assetName
    }
}

struct FarmShopPresentation: Equatable {
    /// Inventory art is a separate 384x384 illustration. It is never positioned over a character.
    let inventoryAssetName: String?
    /// Equipped art is either a same-canvas character overlay or absent when the existing
    /// mask-based rendering system is the source of truth for that item.
    let equippedRenderAsset: FarmShopEquippedRenderAsset?
}

struct FarmDecorationAnchor: Equatable {
    /// The x coordinate is the visual center; groundY is the bottom edge of the prop.
    let normalizedCenterX: Double
    let normalizedGroundY: Double
    let size: Double

    var isBounded: Bool {
        (0.12...0.88).contains(normalizedCenterX)
            && (0.20...0.70).contains(normalizedGroundY)
            && (36...72).contains(size)
    }
}

struct FarmShopItem: Equatable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let category: FarmShopCategory
    let woolCost: Int
    let symbolName: String
    let presentation: FarmShopPresentation
    let visualStyle: String
    let effect: FarmShopEffect

    var inventoryAssetName: String? { presentation.inventoryAssetName }

    /// Kept as a source-compatible read-only alias for existing production callers and tests.
    var assetName: String? { presentation.inventoryAssetName }

    var equippedRenderAsset: FarmShopEquippedRenderAsset? {
        presentation.equippedRenderAsset
    }

    init(
        id: String,
        title: String,
        detail: String,
        category: FarmShopCategory,
        woolCost: Int,
        symbolName: String,
        inventoryAssetName: String? = nil,
        equippedRenderAsset: FarmShopEquippedRenderAsset? = nil,
        visualStyle: String,
        effect: FarmShopEffect
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.category = category
        self.woolCost = woolCost
        self.symbolName = symbolName
        self.presentation = FarmShopPresentation(
            inventoryAssetName: inventoryAssetName,
            equippedRenderAsset: equippedRenderAsset
        )
        self.visualStyle = visualStyle
        self.effect = effect
    }
}

enum FarmShopCatalog {
    static let all: [FarmShopItem] = [
        // Keep the established IDs for persisted-purchase compatibility; "Pasture" is
        // the clearer user-facing name for each unlocked Farm area.
        FarmShopItem(id: "barn_paddock_24", title: "Second Pasture", detail: "Room for 24 sheep.", category: .barn, woolCost: 15, symbolName: "square.grid.2x2.fill", visualStyle: "wood", effect: .capacity(level: 1)),
        FarmShopItem(id: "barn_paddock_36", title: "Hill Pasture", detail: "Room for 36 sheep.", category: .barn, woolCost: 36, symbolName: "mountain.2.fill", visualStyle: "grass", effect: .capacity(level: 2)),
        FarmShopItem(id: "barn_paddock_48", title: "Moon Pasture", detail: "Room for 48 sheep.", category: .barn, woolCost: 80, symbolName: "moon.stars.fill", visualStyle: "lavender", effect: .capacity(level: 3)),
        FarmShopItem(id: "barn_paddock_60", title: "Wide Pasture", detail: "The full 60-sheep Farm.", category: .barn, woolCost: 170, symbolName: "sun.horizon.fill", visualStyle: "amber", effect: .capacity(level: 4)),

        FarmShopItem(id: "ollie_moss_bandana", title: "Moss Bandana", detail: "A soft green knot for Ollie.", category: .ollie, woolCost: 3, symbolName: "leaf.fill", inventoryAssetName: "shop/shop_ollie_classic_moss_bandana", equippedRenderAsset: .ollieAccessory(overlayAssetName: "dog/dog_classic_farm_moss_bandana_equipped_overlay"), visualStyle: "grass", effect: .ollieAccessory),
        FarmShopItem(id: "ollie_moon_kerchief", title: "Moon Kerchief", detail: "Night-sky wool for long walks.", category: .ollie, woolCost: 6, symbolName: "moon.stars.fill", inventoryAssetName: "shop/shop_ollie_classic_moon_kerchief", equippedRenderAsset: .ollieAccessory(overlayAssetName: "dog/dog_classic_farm_moon_kerchief_equipped_overlay"), visualStyle: "lavender", effect: .ollieAccessory),
        FarmShopItem(id: "ollie_brass_bell", title: "Brass Farm Bell", detail: "A small bell for the pasture gate.", category: .ollie, woolCost: 4, symbolName: "bell.fill", inventoryAssetName: "shop/shop_ollie_classic_brass_trail_bell", equippedRenderAsset: .ollieAccessory(overlayAssetName: "dog/dog_classic_farm_brass_trail_bell_equipped_overlay"), visualStyle: "amber", effect: .ollieAccessory),

        FarmShopItem(
            id: "shepherd_wool_hat",
            title: "Wool Field Hat",
            detail: "A warm hat for early mornings.",
            category: .shepherd,
            woolCost: 4,
            symbolName: "crown.fill",
            inventoryAssetName: "shop/shop_shepherd_wool_hat",
            equippedRenderAsset: .shepherdAccessoryByHairStyle([
                ShepherdRenderAsset(hairStyle: .cropped, assetName: "farm/farm_shepherd_cropped_wool_field_hat_equipped_overlay"),
                ShepherdRenderAsset(hairStyle: .waves, assetName: "farm/farm_shepherd_waves_wool_field_hat_equipped_overlay"),
                ShepherdRenderAsset(hairStyle: .curls, assetName: "farm/farm_shepherd_curls_wool_field_hat_equipped_overlay"),
                ShepherdRenderAsset(hairStyle: .coils, assetName: "farm/farm_shepherd_coils_wool_field_hat_equipped_overlay"),
                ShepherdRenderAsset(hairStyle: .long, assetName: "farm/farm_shepherd_long_wool_field_hat_equipped_overlay")
            ]),
            visualStyle: "wood",
            effect: .shepherdAccessory
        ),
        FarmShopItem(id: "shepherd_moss_coat", title: "Moss Work Coat", detail: "A green coat with deep pockets.", category: .shepherd, woolCost: 8, symbolName: "tshirt.fill", inventoryAssetName: "shop/shop_shepherd_moss_coat", visualStyle: "grass", effect: .shepherdOutfit),
        FarmShopItem(id: "shepherd_moon_coat", title: "Moonlit Coat", detail: "A dusk-blue coat for nights at the Farm.", category: .shepherd, woolCost: 14, symbolName: "sparkles", inventoryAssetName: "shop/shop_shepherd_moon_coat", visualStyle: "lavender", effect: .shepherdOutfit),

        FarmShopItem(id: "farm_flower_patch", title: "Clover Patch", detail: "A flowering corner for the pasture.", category: .farm, woolCost: 4, symbolName: "camera.macro", inventoryAssetName: "shop/shop_farm_flower_patch", visualStyle: "grass", effect: .farmDecoration),
        FarmShopItem(id: "farm_lanterns", title: "Barn Lanterns", detail: "A warm light beside the Barn.", category: .farm, woolCost: 3, symbolName: "lightbulb.fill", inventoryAssetName: "shop/shop_farm_lanterns", visualStyle: "amber", effect: .farmDecoration),
        FarmShopItem(id: "farm_moon_gate", title: "Moon Gate", detail: "A silver marker for the night pasture.", category: .farm, woolCost: 5, symbolName: "moon.fill", inventoryAssetName: "shop/shop_farm_moon_gate", visualStyle: "lavender", effect: .farmDecoration),
        FarmShopItem(id: "farm_twilight_banner", title: "Twilight Banner", detail: "A wool banner above the fence.", category: .farm, woolCost: 7, symbolName: "flag.fill", inventoryAssetName: "shop/shop_farm_twilight_banner", visualStyle: "berry", effect: .farmDecoration),

        FarmShopItem(id: "collectible_trail_pin", title: "Brass Search Pin", detail: "A keepsake from Ollie’s first map.", category: .collectibles, woolCost: 3, symbolName: "mappin.and.ellipse", inventoryAssetName: "shop/shop_collectible_trail_pin", visualStyle: "amber", effect: .collectible),
        FarmShopItem(id: "collectible_story_bell", title: "Storybook Bell", detail: "A tiny bell from Storybook Barn.", category: .collectibles, woolCost: 10, symbolName: "book.closed.fill", inventoryAssetName: "shop/shop_collectible_story_bell", visualStyle: "wood", effect: .collectible)
    ]

    static func item(for id: String) -> FarmShopItem? {
        all.first { $0.id == id }
    }

    static func items(in category: FarmShopCategory) -> [FarmShopItem] {
        all.filter { $0.category == category }
    }

    static func decorationAnchor(for itemID: String) -> FarmDecorationAnchor? {
        switch itemID {
        case "farm_flower_patch":
            return FarmDecorationAnchor(normalizedCenterX: 0.22, normalizedGroundY: 0.48, size: 48)
        case "farm_lanterns":
            return FarmDecorationAnchor(normalizedCenterX: 0.78, normalizedGroundY: 0.48, size: 48)
        case "farm_moon_gate":
            return FarmDecorationAnchor(normalizedCenterX: 0.52, normalizedGroundY: 0.43, size: 58)
        case "farm_twilight_banner":
            return FarmDecorationAnchor(normalizedCenterX: 0.31, normalizedGroundY: 0.38, size: 56)
        default:
            return nil
        }
    }
}

extension FarmState {
    mutating func purchase(itemID: String, at date: Date = Date()) throws {
        guard let item = FarmShopCatalog.item(for: itemID) else { throw FarmActionError.itemNotFound }
        guard !ownedShopItemIDs.contains(item.id) else { throw FarmActionError.itemAlreadyOwned }

        if case .capacity(let level) = item.effect {
            guard barnCapacityLevel < FarmEconomyRules.maximumCapacityLevel else {
                throw FarmActionError.maximumCapacityReached
            }
            guard level == barnCapacityLevel + 1 else { throw FarmActionError.upgradeOutOfSequence }
        }
        guard woolBalance >= item.woolCost else {
            throw FarmActionError.insufficientFunds
        }

        woolBalance -= item.woolCost
        ownedShopItemIDs.append(item.id)
        ownedShopItemIDs.sort()

        let transactionKind: FarmTransactionKind
        if case .capacity(let level) = item.effect {
            barnCapacityLevel = level
            welcomeOldestPendingUntilFull()
            transactionKind = .capacityUpgrade
        } else {
            applyPurchasedItem(item)
            transactionKind = .purchase
        }

        appendTransaction(FarmTransaction(
            id: UUID(),
            idempotencyKey: "purchase:\(item.id)",
            kind: transactionKind,
            sheepID: nil,
            itemID: item.id,
            woolDelta: -item.woolCost,
            createdAt: date
        ))
    }

    mutating func equip(itemID: String) throws {
        guard ownedShopItemIDs.contains(itemID) else { throw FarmActionError.itemNotOwned }
        guard let item = FarmShopCatalog.item(for: itemID) else { throw FarmActionError.itemNotFound }
        switch item.effect {
        case .capacity:
            break
        case .ollieAccessory:
            try wearOllieAccessory(itemID: item.id)
        case .shepherdOutfit:
            try wearShepherdOutfit(itemID: item.id)
        case .shepherdAccessory:
            try wearShepherdAccessory(itemID: item.id)
        case .farmDecoration:
            try placeFarmDecoration(itemID: item.id)
        case .collectible:
            try displayCollectible(itemID: item.id)
        }
    }

    mutating func wearOllieAccessory(itemID: String) throws {
        let item = try ownedItem(itemID, matching: .ollieAccessory)
        equipment.ollieAccessoryItemID = item.id
    }

    mutating func takeOffOllieAccessory(itemID: String) throws {
        guard equipment.ollieAccessoryItemID == itemID else {
            throw FarmActionError.itemNotEquipped
        }
        equipment.ollieAccessoryItemID = nil
    }

    mutating func wearShepherdOutfit(itemID: String) throws {
        let item = try ownedItem(itemID, matching: .shepherdOutfit)
        shepherd.outfitItemID = item.id
    }

    mutating func takeOffShepherdOutfit(itemID: String) throws {
        guard shepherd.outfitItemID == itemID else {
            throw FarmActionError.itemNotEquipped
        }
        shepherd.outfitItemID = nil
    }

    mutating func wearShepherdAccessory(itemID: String) throws {
        let item = try ownedItem(itemID, matching: .shepherdAccessory)
        shepherd.accessoryItemID = item.id
    }

    mutating func takeOffShepherdAccessory(itemID: String) throws {
        guard shepherd.accessoryItemID == itemID else {
            throw FarmActionError.itemNotEquipped
        }
        shepherd.accessoryItemID = nil
    }

    mutating func placeFarmDecoration(itemID: String) throws {
        let item = try ownedItem(itemID, matching: .farmDecoration)
        if !equipment.farmDecorationItemIDs.contains(item.id) {
            equipment.farmDecorationItemIDs.append(item.id)
        }
    }

    mutating func putAwayFarmDecoration(itemID: String) throws {
        guard equipment.farmDecorationItemIDs.contains(itemID) else {
            throw FarmActionError.itemNotPlaced
        }
        equipment.farmDecorationItemIDs.removeAll { $0 == itemID }
    }

    mutating func displayCollectible(itemID: String) throws {
        let item = try ownedItem(itemID, matching: .collectible)
        if !equipment.collectibleItemIDs.contains(item.id) {
            equipment.collectibleItemIDs.append(item.id)
        }
    }

    mutating func storeCollectible(itemID: String) throws {
        guard equipment.collectibleItemIDs.contains(itemID) else {
            throw FarmActionError.itemNotDisplayed
        }
        equipment.collectibleItemIDs.removeAll { $0 == itemID }
    }

    private mutating func applyPurchasedItem(_ item: FarmShopItem) {
        switch item.effect {
        case .capacity:
            break
        case .ollieAccessory:
            equipment.ollieAccessoryItemID = item.id
        case .shepherdOutfit:
            shepherd.outfitItemID = item.id
        case .shepherdAccessory:
            shepherd.accessoryItemID = item.id
        case .farmDecoration:
            if !equipment.farmDecorationItemIDs.contains(item.id) {
                equipment.farmDecorationItemIDs.append(item.id)
            }
        case .collectible:
            if !equipment.collectibleItemIDs.contains(item.id) {
                equipment.collectibleItemIDs.append(item.id)
            }
        }
    }

    private func ownedItem(_ itemID: String, matching effect: FarmShopEffect) throws -> FarmShopItem {
        guard ownedShopItemIDs.contains(itemID) else { throw FarmActionError.itemNotOwned }
        guard let item = FarmShopCatalog.item(for: itemID) else { throw FarmActionError.itemNotFound }
        switch (item.effect, effect) {
        case (.ollieAccessory, .ollieAccessory),
             (.shepherdOutfit, .shepherdOutfit),
             (.shepherdAccessory, .shepherdAccessory),
             (.farmDecoration, .farmDecoration),
             (.collectible, .collectible):
            return item
        default:
            throw FarmActionError.itemNotEquippable
        }
    }

    private mutating func welcomeOldestPendingUntilFull() {
        let pendingIDs = pendingSheep.sorted { $0.arrivedAt < $1.arrivedAt }.map(\.id)
        for id in pendingIDs where activeSheep.count < activeCapacity {
            guard let index = sheep.firstIndex(where: { $0.id == id }) else { continue }
            sheep[index].status = .active
        }
    }
}
