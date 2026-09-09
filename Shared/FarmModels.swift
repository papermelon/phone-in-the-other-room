import Foundation

enum FlockSheepStatus: String, Codable, CaseIterable {
    case active
    case pending
    case sold
}

struct FlockSheep: Codable, Equatable, Identifiable {
    let id: UUID
    let definitionID: String
    var displayName: String
    let sourceOutcomeID: UUID?
    let sourceRunID: UUID?
    let arrivedAt: Date
    let protectedNightNumber: Int
    let rarity: SheepRarity
    var isFavorite: Bool
    var lastShearedProtectedNight: Int?
    var timesSheared: Int
    var status: FlockSheepStatus
    var equippedCosmeticIDs: [String]

    init(
        id: UUID,
        definitionID: String,
        displayName: String,
        sourceOutcomeID: UUID? = nil,
        sourceRunID: UUID? = nil,
        arrivedAt: Date,
        protectedNightNumber: Int,
        rarity: SheepRarity,
        isFavorite: Bool = false,
        lastShearedProtectedNight: Int? = nil,
        timesSheared: Int = 0,
        status: FlockSheepStatus = .active,
        equippedCosmeticIDs: [String] = []
    ) {
        self.id = id
        self.definitionID = definitionID
        self.displayName = displayName
        self.sourceOutcomeID = sourceOutcomeID
        self.sourceRunID = sourceRunID
        self.arrivedAt = arrivedAt
        self.protectedNightNumber = max(0, protectedNightNumber)
        self.rarity = rarity
        self.isFavorite = isFavorite
        self.lastShearedProtectedNight = lastShearedProtectedNight
        self.timesSheared = max(0, timesSheared)
        self.status = status
        self.equippedCosmeticIDs = equippedCosmeticIDs
    }
}

struct SheepDiscoveryRecord: Codable, Equatable, Identifiable {
    var id: String { definitionID }
    let definitionID: String
    var firstDiscoveredAt: Date
    var encounterCount: Int
    var outcomeIDs: [UUID]
    var highestRarity: SheepRarity
}

enum FarmTransactionKind: String, Codable {
    case arrival
    case shearing
    case sale
    case purchase
    case capacityUpgrade
    case currencyConsolidation
    case starterGrant
    case welcomeGift
    case onboardingPracticeArrival
    case slumberPartyGrant
    case sunriseTrail

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .arrival
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct FarmTransaction: Codable, Equatable, Identifiable {
    let id: UUID
    let idempotencyKey: String
    let kind: FarmTransactionKind
    let sheepID: UUID?
    let itemID: String?
    let woolDelta: Int
    let legacyCashDelta: Int?
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, idempotencyKey, kind, sheepID, itemID, woolDelta, legacyCashDelta, cashDelta, createdAt
    }

    init(
        id: UUID,
        idempotencyKey: String,
        kind: FarmTransactionKind,
        sheepID: UUID?,
        itemID: String?,
        woolDelta: Int,
        legacyCashDelta: Int? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.idempotencyKey = idempotencyKey
        self.kind = kind
        self.sheepID = sheepID
        self.itemID = itemID
        self.woolDelta = woolDelta
        self.legacyCashDelta = legacyCashDelta
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        idempotencyKey = try container.decode(String.self, forKey: .idempotencyKey)
        kind = try container.decode(FarmTransactionKind.self, forKey: .kind)
        sheepID = try container.decodeIfPresent(UUID.self, forKey: .sheepID)
        itemID = try container.decodeIfPresent(String.self, forKey: .itemID)
        woolDelta = try container.decodeIfPresent(Int.self, forKey: .woolDelta) ?? 0
        legacyCashDelta = try container.decodeIfPresent(Int.self, forKey: .legacyCashDelta)
            ?? container.decodeIfPresent(Int.self, forKey: .cashDelta)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(idempotencyKey, forKey: .idempotencyKey)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(sheepID, forKey: .sheepID)
        try container.encodeIfPresent(itemID, forKey: .itemID)
        try container.encode(woolDelta, forKey: .woolDelta)
        try container.encodeIfPresent(legacyCashDelta, forKey: .legacyCashDelta)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

enum ShepherdSkinTone: String, Codable, CaseIterable, Identifiable {
    case porcelain, warm, olive, brown, deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .porcelain: return "Porcelain"
        case .warm: return "Warm"
        case .olive: return "Olive"
        case .brown: return "Brown"
        case .deep: return "Deep"
        }
    }
}

enum ShepherdHairStyle: String, Codable, CaseIterable, Identifiable {
    case cropped, waves, curls, coils, long

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cropped: return "Cropped"
        case .waves: return "Waves"
        case .curls: return "Curls"
        case .coils: return "Coils"
        case .long: return "Long"
        }
    }
}

enum ShepherdHeadShape: String, CaseIterable, Identifiable {
    case pear, round, boxy, triangular
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct ShepherdProfile: Codable, Equatable {
    var skinTone: ShepherdSkinTone
    var hairStyle: ShepherdHairStyle
    var outfitItemID: String?
    var accessoryItemID: String?
    // Preserve future IDs through a save round-trip; render a known shape until supported.
    var headShapeID: String? = nil
    var headShape: ShepherdHeadShape {
        get { headShapeID.flatMap(ShepherdHeadShape.init(rawValue:)) ?? .pear }
        set { headShapeID = newValue.rawValue }
    }

    private enum CodingKeys: String, CodingKey {
        case skinTone, hairStyle, outfitItemID, accessoryItemID, headShapeID
    }

    init(skinTone: ShepherdSkinTone, hairStyle: ShepherdHairStyle,
         outfitItemID: String?, accessoryItemID: String?, headShapeID: String? = nil) {
        self.skinTone = skinTone
        self.hairStyle = hairStyle
        self.outfitItemID = outfitItemID
        self.accessoryItemID = accessoryItemID
        self.headShapeID = headShapeID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        skinTone = try c.decode(ShepherdSkinTone.self, forKey: .skinTone)
        hairStyle = try c.decode(ShepherdHairStyle.self, forKey: .hairStyle)
        outfitItemID = try c.decodeIfPresent(String.self, forKey: .outfitItemID)
        accessoryItemID = try c.decodeIfPresent(String.self, forKey: .accessoryItemID)
        headShapeID = try c.decodeIfPresent(String.self, forKey: .headShapeID)
    }

    static let defaultProfile = ShepherdProfile(
        skinTone: .warm,
        hairStyle: .waves,
        outfitItemID: nil,
        accessoryItemID: nil
    )
}

enum FarmDecorationZone: String, Codable, CaseIterable, Hashable {
    case leftMeadow
    case rightMeadow
    case centerHorizon
    case leftFence
    case waterEdge
    case barnCorner
}

enum FarmCollectibleSlot: String, Codable, CaseIterable, Hashable {
    case left
    case centerLeft
    case centerRight
    case right
}

struct FarmEquipment: Codable, Equatable {
    var ollieAccessoryItemID: String?
    var decorationPlacements: [FarmDecorationZone: String]
    var collectiblePlacements: [FarmCollectibleSlot: String]

    static let empty = FarmEquipment(
        ollieAccessoryItemID: nil,
        decorationPlacements: [:],
        collectiblePlacements: [:]
    )

    var farmDecorationItemIDs: [String] {
        get { FarmDecorationZone.allCases.compactMap { decorationPlacements[$0] } }
        set {
            decorationPlacements = Dictionary(uniqueKeysWithValues: zip(
                FarmDecorationZone.allCases,
                newValue.prefix(FarmDecorationZone.allCases.count)
            ))
        }
    }

    var collectibleItemIDs: [String] {
        get { FarmCollectibleSlot.allCases.compactMap { collectiblePlacements[$0] } }
        set {
            collectiblePlacements = Dictionary(uniqueKeysWithValues: zip(
                FarmCollectibleSlot.allCases,
                newValue.prefix(FarmCollectibleSlot.allCases.count)
            ))
        }
    }

    private enum CodingKeys: String, CodingKey {
        case ollieAccessoryItemID, decorationPlacements, collectiblePlacements
        case farmDecorationItemIDs, collectibleItemIDs
    }

    init(
        ollieAccessoryItemID: String?,
        decorationPlacements: [FarmDecorationZone: String],
        collectiblePlacements: [FarmCollectibleSlot: String]
    ) {
        self.ollieAccessoryItemID = ollieAccessoryItemID
        self.decorationPlacements = decorationPlacements
        self.collectiblePlacements = collectiblePlacements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ollieAccessoryItemID = try container.decodeIfPresent(String.self, forKey: .ollieAccessoryItemID)
        decorationPlacements = try container.decodeIfPresent(
            [FarmDecorationZone: String].self,
            forKey: .decorationPlacements
        ) ?? [:]
        collectiblePlacements = try container.decodeIfPresent(
            [FarmCollectibleSlot: String].self,
            forKey: .collectiblePlacements
        ) ?? [:]

        if decorationPlacements.isEmpty {
            let legacy = try container.decodeIfPresent([String].self, forKey: .farmDecorationItemIDs) ?? []
            for itemID in legacy {
                guard let zone = FarmShopCatalog.decorationZone(for: itemID),
                      decorationPlacements[zone] == nil else { continue }
                decorationPlacements[zone] = itemID
            }
        }
        if collectiblePlacements.isEmpty {
            let legacy = try container.decodeIfPresent([String].self, forKey: .collectibleItemIDs) ?? []
            for (slot, itemID) in zip(FarmCollectibleSlot.allCases, legacy) {
                collectiblePlacements[slot] = itemID
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(ollieAccessoryItemID, forKey: .ollieAccessoryItemID)
        try container.encode(decorationPlacements, forKey: .decorationPlacements)
        try container.encode(collectiblePlacements, forKey: .collectiblePlacements)
    }
}

struct FarmState: Codable, Equatable {
    static let currentSchemaVersion = 3
    static let maximumTransactions = 256
    static let currencyConsolidationKey = "currency:wool-only:v2"

    var schemaVersion: Int
    var sheep: [FlockSheep]
    var discoveries: [SheepDiscoveryRecord]
    var barnCapacityLevel: Int
    var woolBalance: Int
    var unlockedShopTier: Int
    var ownedShopItemIDs: [String]
    var equipment: FarmEquipment
    var shepherd: ShepherdProfile
    var transactions: [FarmTransaction]
    var trackedSheepDefinitionID: String?

    static let empty = FarmState(
        schemaVersion: currentSchemaVersion,
        sheep: [],
        discoveries: [],
        barnCapacityLevel: 0,
        woolBalance: 0,
        unlockedShopTier: 0,
        ownedShopItemIDs: [],
        equipment: .empty,
        shepherd: .defaultProfile,
        transactions: [],
        trackedSheepDefinitionID: nil
    )

    var activeSheep: [FlockSheep] { sheep.filter { $0.status == .active } }
    var pendingSheep: [FlockSheep] { sheep.filter { $0.status == .pending } }
    var soldSheep: [FlockSheep] { sheep.filter { $0.status == .sold } }
    var activeCapacity: Int { FarmEconomyRules.capacity(forLevel: barnCapacityLevel) }
    var isBarnFull: Bool { activeSheep.count >= activeCapacity }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, sheep, discoveries, barnCapacityLevel, woolBalance, cashBalance
        case unlockedShopTier
        case ownedShopItemIDs, equipment, shepherd, transactions, trackedSheepDefinitionID
    }

    init(
        schemaVersion: Int,
        sheep: [FlockSheep],
        discoveries: [SheepDiscoveryRecord],
        barnCapacityLevel: Int,
        woolBalance: Int,
        unlockedShopTier: Int,
        ownedShopItemIDs: [String],
        equipment: FarmEquipment,
        shepherd: ShepherdProfile,
        transactions: [FarmTransaction],
        trackedSheepDefinitionID: String?
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.sheep = sheep
        self.discoveries = discoveries
        self.barnCapacityLevel = min(FarmEconomyRules.maximumCapacityLevel, max(0, barnCapacityLevel))
        self.woolBalance = max(0, woolBalance)
        self.unlockedShopTier = min(3, max(0, unlockedShopTier))
        self.ownedShopItemIDs = Array(Set(ownedShopItemIDs)).sorted()
        self.equipment = equipment
        self.shepherd = shepherd
        self.transactions = Array(transactions.suffix(Self.maximumTransactions))
        self.trackedSheepDefinitionID = trackedSheepDefinitionID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        let legacyCash = decodedSchemaVersion < Self.currentSchemaVersion
            ? max(0, try container.decodeIfPresent(Int.self, forKey: .cashBalance) ?? 0)
            : 0
        let convertedWool = FarmEconomyRules.convertLegacyCashToWool(legacyCash)
        self.init(
            schemaVersion: Self.currentSchemaVersion,
            sheep: try container.decodeIfPresent([FlockSheep].self, forKey: .sheep) ?? [],
            discoveries: try container.decodeIfPresent([SheepDiscoveryRecord].self, forKey: .discoveries) ?? [],
            barnCapacityLevel: try container.decodeIfPresent(Int.self, forKey: .barnCapacityLevel) ?? 0,
            woolBalance: (try container.decodeIfPresent(Int.self, forKey: .woolBalance) ?? 0) + convertedWool,
            unlockedShopTier: try container.decodeIfPresent(Int.self, forKey: .unlockedShopTier) ?? 0,
            ownedShopItemIDs: try container.decodeIfPresent([String].self, forKey: .ownedShopItemIDs) ?? [],
            equipment: try container.decodeIfPresent(FarmEquipment.self, forKey: .equipment) ?? .empty,
            shepherd: try container.decodeIfPresent(ShepherdProfile.self, forKey: .shepherd) ?? .defaultProfile,
            transactions: try container.decodeIfPresent([FarmTransaction].self, forKey: .transactions) ?? [],
            trackedSheepDefinitionID: try container.decodeIfPresent(String.self, forKey: .trackedSheepDefinitionID)
        )
        if legacyCash > 0,
           !transactions.contains(where: { $0.idempotencyKey == Self.currencyConsolidationKey }) {
            appendTransaction(FarmTransaction(
                id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
                idempotencyKey: Self.currencyConsolidationKey,
                kind: .currencyConsolidation,
                sheepID: nil,
                itemID: nil,
                woolDelta: convertedWool,
                legacyCashDelta: -legacyCash,
                createdAt: Date(timeIntervalSince1970: 0)
            ))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(sheep, forKey: .sheep)
        try container.encode(discoveries, forKey: .discoveries)
        try container.encode(barnCapacityLevel, forKey: .barnCapacityLevel)
        try container.encode(woolBalance, forKey: .woolBalance)
        try container.encode(unlockedShopTier, forKey: .unlockedShopTier)
        try container.encode(ownedShopItemIDs, forKey: .ownedShopItemIDs)
        try container.encode(equipment, forKey: .equipment)
        try container.encode(shepherd, forKey: .shepherd)
        try container.encode(transactions, forKey: .transactions)
        try container.encodeIfPresent(trackedSheepDefinitionID, forKey: .trackedSheepDefinitionID)
    }
}
