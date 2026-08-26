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

struct FarmShopProgress: Equatable {
    let qualifyingWindDowns: Int
    let discoveries: Int
    let permanentlyUnlockedTier: Int

    static let newFarm = FarmShopProgress(
        qualifyingWindDowns: 0,
        discoveries: 0,
        permanentlyUnlockedTier: 0
    )
}

enum FarmShopUnlockRequirement: Equatable {
    case immediate
    case milestone(tier: Int, windDowns: Int, discoveries: Int)

    func isSatisfied(by progress: FarmShopProgress) -> Bool {
        switch self {
        case .immediate:
            return true
        case let .milestone(tier, windDowns, discoveries):
            return progress.permanentlyUnlockedTier >= tier
                || progress.qualifyingWindDowns >= windDowns
                || progress.discoveries >= discoveries
        }
    }

    var description: String? {
        switch self {
        case .immediate:
            return nil
        case let .milestone(tier, windDowns, discoveries):
            let discoveryCopy = discoveries == SheepCatalog.all.count
                ? "discover all \(discoveries) sheep"
                : "discover \(discoveries) sheep"
            return "Tier \(tier) · Complete \(windDowns) Wind Downs or \(discoveryCopy)."
        }
    }
}

struct ShepherdRenderAsset: Equatable {
    let hairStyle: ShepherdHairStyle
    let assetName: String
}

enum FarmShopEquippedRenderAsset: Equatable {
    case ollieAccessory(overlayAssetName: String)
    case shepherdOutfit(overlayAssetName: String)
    case shepherdAccessoryByHairStyle([ShepherdRenderAsset])

    func assetName(for hairStyle: ShepherdHairStyle) -> String? {
        switch self {
        case let .shepherdAccessoryByHairStyle(assets):
            return assets.first { $0.hairStyle == hairStyle }?.assetName
        case let .shepherdOutfit(assetName), let .ollieAccessory(assetName):
            return assetName
        }
    }
}

struct FarmShopPresentation: Equatable {
    /// Inventory art is a separate 384x384 illustration. It is never positioned over a character.
    let inventoryAssetName: String?
    /// Decorations use a simpler scene-scale prop in the pasture.
    let sceneAssetName: String?
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
    let unlockRequirement: FarmShopUnlockRequirement
    let decorationZone: FarmDecorationZone?

    var inventoryAssetName: String? { presentation.inventoryAssetName }

    /// Kept as a source-compatible read-only alias for existing production callers and tests.
    var assetName: String? { presentation.inventoryAssetName }

    var equippedRenderAsset: FarmShopEquippedRenderAsset? {
        presentation.equippedRenderAsset
    }

    var sceneAssetName: String? { presentation.sceneAssetName }

    func isUnlocked(for progress: FarmShopProgress) -> Bool {
        unlockRequirement.isSatisfied(by: progress)
    }

    init(
        id: String,
        title: String,
        detail: String,
        category: FarmShopCategory,
        woolCost: Int,
        symbolName: String,
        inventoryAssetName: String? = nil,
        sceneAssetName: String? = nil,
        equippedRenderAsset: FarmShopEquippedRenderAsset? = nil,
        visualStyle: String,
        effect: FarmShopEffect,
        unlockRequirement: FarmShopUnlockRequirement = .immediate,
        decorationZone: FarmDecorationZone? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.category = category
        self.woolCost = woolCost
        self.symbolName = symbolName
        self.presentation = FarmShopPresentation(
            inventoryAssetName: inventoryAssetName,
            sceneAssetName: sceneAssetName,
            equippedRenderAsset: equippedRenderAsset
        )
        self.visualStyle = visualStyle
        self.effect = effect
        self.unlockRequirement = unlockRequirement
        self.decorationZone = decorationZone
    }
}

extension FarmState {
    func shopProgress(qualifyingWindDowns: Int) -> FarmShopProgress {
        FarmShopProgress(
            qualifyingWindDowns: max(0, qualifyingWindDowns),
            discoveries: discoveries.count,
            permanentlyUnlockedTier: unlockedShopTier
        )
    }

    mutating func refreshShopUnlocks(qualifyingWindDowns: Int) {
        let progress = shopProgress(qualifyingWindDowns: qualifyingWindDowns)
        let newlyUnlockedTier = (1...3).last(where: { tier in
            FarmShopCatalog.unlockRequirement(forTier: tier).isSatisfied(by: progress)
        }) ?? 0
        unlockedShopTier = max(unlockedShopTier, newlyUnlockedTier)
    }

    mutating func purchase(
        itemID: String,
        qualifyingWindDowns: Int = 0,
        at date: Date = Date()
    ) throws {
        guard let item = FarmShopCatalog.item(for: itemID) else { throw FarmActionError.itemNotFound }
        guard !ownedShopItemIDs.contains(item.id) else { throw FarmActionError.itemAlreadyOwned }
        guard item.isUnlocked(for: shopProgress(qualifyingWindDowns: qualifyingWindDowns)) else {
            throw FarmActionError.itemLocked
        }

        if case .capacity(let level) = item.effect {
            guard barnCapacityLevel < FarmEconomyRules.maximumCapacityLevel else {
                throw FarmActionError.maximumCapacityReached
            }
            guard level == barnCapacityLevel + 1 else { throw FarmActionError.upgradeOutOfSequence }
        }
        guard woolBalance >= item.woolCost else {
            throw FarmActionError.insufficientFunds
        }

        refreshShopUnlocks(qualifyingWindDowns: qualifyingWindDowns)
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
        guard let zone = item.decorationZone else { throw FarmActionError.itemNotEquippable }
        equipment.decorationPlacements[zone] = item.id
    }

    mutating func putAwayFarmDecoration(itemID: String) throws {
        guard let zone = equipment.decorationPlacements.first(where: { $0.value == itemID })?.key else {
            throw FarmActionError.itemNotPlaced
        }
        equipment.decorationPlacements.removeValue(forKey: zone)
    }

    mutating func displayCollectible(itemID: String) throws {
        let item = try ownedItem(itemID, matching: .collectible)
        guard !equipment.collectibleItemIDs.contains(item.id) else { return }
        guard let slot = FarmCollectibleSlot.allCases.first(where: {
            equipment.collectiblePlacements[$0] == nil
        }) else { throw FarmActionError.displayFull }
        equipment.collectiblePlacements[slot] = item.id
    }

    mutating func storeCollectible(itemID: String) throws {
        guard let slot = equipment.collectiblePlacements.first(where: { $0.value == itemID })?.key else {
            throw FarmActionError.itemNotDisplayed
        }
        equipment.collectiblePlacements.removeValue(forKey: slot)
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
            if let zone = item.decorationZone {
                equipment.decorationPlacements[zone] = item.id
            }
        case .collectible:
            if let slot = FarmCollectibleSlot.allCases.first(where: {
                equipment.collectiblePlacements[$0] == nil
            }) {
                equipment.collectiblePlacements[slot] = item.id
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
