import Foundation

enum FarmMigration {
    private static let repeatNames = [
        "Acorn", "Aster", "Barley", "Basil", "Bean", "Beech", "Berry", "Biscuit",
        "Bluebell", "Brambleby", "Briar", "Buckwheat", "Button", "Cedar", "Chai", "Clover",
        "Cricket", "Daisy", "Dandelion", "Dewdrop", "Dove", "Fern", "Fig", "Flax",
        "Foggy", "Ginger", "Hazelnut", "Heather", "Hickory", "Honey", "Ivy", "Kettle",
        "Lark", "Lavender", "Maple", "Meadow", "Miso", "Moss", "Mulberry", "Nettle",
        "Nutmeg", "Pebble", "Pepper", "Pine", "Poppy", "Primrose", "Puddle", "Quince",
        "Reed", "Robin", "Rosemary", "Sage", "Sorrel", "Sprig", "Tansy", "Thistle",
        "Toast", "Truffle", "Tulip", "Waffle", "Walnut", "Willow", "Yarrow", "Zinnia"
    ]

    static func migrated(
        existing: FarmState?,
        searchState: SheepSearchState,
        now: Date = Date()
    ) -> FarmState {
        var state = existing ?? .empty
        state.reconcile(searchState: searchState, now: now)
        return state
    }

    static func stableLegacyID(for definitionID: String) -> UUID {
        stableUUID(from: "legacy:\(definitionID)")
    }

    static func stableRepeatName(
        outcomeID: UUID,
        existingNames: Set<String>
    ) -> String {
        let seed = stableHash(outcomeID.uuidString)
        for offset in 0..<repeatNames.count {
            let candidate = repeatNames[(seed + offset) % repeatNames.count]
            if !existingNames.contains(candidate) { return candidate }
        }
        let root = repeatNames[seed % repeatNames.count]
        var suffix = 2
        while existingNames.contains("\(root) \(suffix)") { suffix += 1 }
        return "\(root) \(suffix)"
    }

    private static func stableUUID(from value: String) -> UUID {
        let first = stableHash64(value)
        let second = stableHash64("farm:\(value)")
        let bytes: [UInt8] = (0..<8).map { UInt8((first >> UInt64($0 * 8)) & 0xFF) }
            + (0..<8).map { UInt8((second >> UInt64($0 * 8)) & 0xFF) }
        let tuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple)
    }

    private static func stableHash(_ value: String) -> Int {
        Int(stableHash64(value) % UInt64(repeatNames.count))
    }

    private static func stableHash64(_ value: String) -> UInt64 {
        value.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

extension FarmState {
    mutating func reconcile(searchState: SheepSearchState, now: Date = Date()) {
        let foundOutcomes = searchState.outcomes
            .filter { $0.result == .found && $0.sheepID != nil }
            .sorted {
                if $0.createdAt == $1.createdAt { return $0.id.uuidString < $1.id.uuidString }
                return $0.createdAt < $1.createdAt
            }
        for outcome in foundOutcomes {
            recordArrival(outcome)
        }

        let definitionsWithOutcomes = Set(foundOutcomes.compactMap(\.sheepID))
        for definitionID in searchState.foundSheepIDs where !definitionsWithOutcomes.contains(definitionID) {
            recordLegacyDiscovery(definitionID: definitionID, now: now)
        }
    }

    mutating func recordArrival(_ outcome: SheepSearchOutcome) {
        guard outcome.result == .found,
              let definitionID = outcome.sheepID,
              let definition = SheepCatalog.definition(for: definitionID),
              !sheep.contains(where: { $0.sourceOutcomeID == outcome.id }) else { return }

        let hasCanonicalInstance = discoveries.contains { $0.definitionID == definitionID }
        let name = hasCanonicalInstance
            ? FarmMigration.stableRepeatName(
                outcomeID: outcome.id,
                existingNames: Set(sheep.map(\.displayName))
            )
            : definition.name
        let status: FlockSheepStatus = activeSheep.count < activeCapacity ? .active : .pending
        let flockSheep = FlockSheep(
            id: outcome.id,
            definitionID: definitionID,
            displayName: name,
            sourceOutcomeID: outcome.id,
            sourceRunID: outcome.runID,
            arrivedAt: outcome.createdAt,
            protectedNightNumber: outcome.protectedNightNumber,
            rarity: outcome.rarity ?? definition.rarity,
            status: status
        )
        sheep.append(flockSheep)
        recordDiscovery(
            definitionID: definitionID,
            rarity: flockSheep.rarity,
            date: outcome.createdAt,
            outcomeID: outcome.id
        )
        if trackedSheepDefinitionID == definitionID {
            trackedSheepDefinitionID = nil
        }
        appendTransaction(FarmTransaction(
            id: UUID(),
            idempotencyKey: "arrival:\(outcome.id.uuidString)",
            kind: transactionKind(for: outcome.origin),
            sheepID: flockSheep.id,
            itemID: nil,
            woolDelta: 0,
            createdAt: outcome.createdAt
        ))
    }

    private func transactionKind(for origin: SheepSearchOrigin) -> FarmTransactionKind {
        switch origin {
        case .starter: return .starterGrant
        case .onboardingPractice: return .onboardingPracticeArrival
        case .windDown, .phoneBreak, .unspecified: return .arrival
        }
    }

    private mutating func recordLegacyDiscovery(definitionID: String, now: Date) {
        guard let definition = SheepCatalog.definition(for: definitionID) else { return }
        let stableID = FarmMigration.stableLegacyID(for: definitionID)
        guard !sheep.contains(where: { $0.id == stableID }) else { return }
        let status: FlockSheepStatus = activeSheep.count < activeCapacity ? .active : .pending
        sheep.append(FlockSheep(
            id: stableID,
            definitionID: definitionID,
            displayName: definition.name,
            arrivedAt: now,
            protectedNightNumber: SheepCatalog.arrivalNight(for: definition),
            rarity: definition.rarity,
            status: status
        ))
        recordDiscovery(
            definitionID: definitionID,
            rarity: definition.rarity,
            date: now,
            outcomeID: nil
        )
    }

    private mutating func recordDiscovery(
        definitionID: String,
        rarity: SheepRarity,
        date: Date,
        outcomeID: UUID?
    ) {
        if let index = discoveries.firstIndex(where: { $0.definitionID == definitionID }) {
            if let outcomeID, discoveries[index].outcomeIDs.contains(outcomeID) { return }
            discoveries[index].encounterCount += 1
            discoveries[index].firstDiscoveredAt = min(discoveries[index].firstDiscoveredAt, date)
            if let outcomeID { discoveries[index].outcomeIDs.append(outcomeID) }
            if rarity.rank > discoveries[index].highestRarity.rank {
                discoveries[index].highestRarity = rarity
            }
        } else {
            discoveries.append(SheepDiscoveryRecord(
                definitionID: definitionID,
                firstDiscoveredAt: date,
                encounterCount: 1,
                outcomeIDs: outcomeID.map { [$0] } ?? [],
                highestRarity: rarity
            ))
        }
    }
}
