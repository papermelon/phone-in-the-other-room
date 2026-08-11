import Foundation

enum FarmActionError: Error, Equatable {
    case sheepNotFound
    case sheepNotActive
    case woolRegrowing
    case barnFull
    case itemNotFound
    case itemAlreadyOwned
    case itemNotOwned
    case itemNotEquippable
    case itemNotEquipped
    case itemNotPlaced
    case itemNotDisplayed
    case insufficientFunds
    case upgradeOutOfSequence
    case maximumCapacityReached
}

enum FarmEconomyRules {
    static let capacities = [12, 24, 36, 48, 60]
    static let capacityUpgradeWoolCosts = [15, 36, 80, 170]
    static let legacyCashPerWool = 5
    static let maximumCapacityLevel = capacities.count - 1

    static func capacity(forLevel level: Int) -> Int {
        capacities[min(maximumCapacityLevel, max(0, level))]
    }

    static func upgradeCost(fromLevel level: Int) -> Int? {
        guard level >= 0, level < capacityUpgradeWoolCosts.count else { return nil }
        return capacityUpgradeWoolCosts[level]
    }

    static func convertLegacyCashToWool(_ cash: Int) -> Int {
        let safeCash = max(0, cash)
        return safeCash / legacyCashPerWool + (safeCash % legacyCashPerWool == 0 ? 0 : 1)
    }

    static func woolYield(for rarity: SheepRarity) -> Int {
        switch rarity {
        case .common: return 1
        case .uncommon: return 2
        case .rare: return 4
        case .legendary: return 7
        }
    }

    static func regrowthNights(for rarity: SheepRarity) -> Int {
        switch rarity {
        case .common: return 2
        case .uncommon: return 3
        case .rare: return 4
        case .legendary: return 5
        }
    }

    static func baseTradeWoolValue(for rarity: SheepRarity) -> Int {
        switch rarity {
        case .common: return 3
        case .uncommon: return 6
        case .rare: return 13
        case .legendary: return 30
        }
    }

    static func remainingRegrowthNights(
        for sheep: FlockSheep,
        protectedNightCount: Int
    ) -> Int {
        guard let lastSheared = sheep.lastShearedProtectedNight else { return 0 }
        let readyAt = lastSheared + regrowthNights(for: sheep.rarity)
        return max(0, readyAt - protectedNightCount)
    }

    static func isWoolReady(for sheep: FlockSheep, protectedNightCount: Int) -> Bool {
        remainingRegrowthNights(for: sheep, protectedNightCount: protectedNightCount) == 0
    }

    static func woolVisualState(
        for sheep: FlockSheep,
        protectedNightCount: Int
    ) -> SheepWoolVisualState {
        let remaining = remainingRegrowthNights(
            for: sheep,
            protectedNightCount: protectedNightCount
        )
        guard remaining > 0 else { return .woolReady }
        return remaining == regrowthNights(for: sheep.rarity) ? .shorn : .regrowing
    }

    static func tradeWoolValue(for sheep: FlockSheep, protectedNightCount: Int) -> Int {
        let base = baseTradeWoolValue(for: sheep.rarity)
        guard !isWoolReady(for: sheep, protectedNightCount: protectedNightCount) else { return base }
        return Int(floor(Double(base) * 0.75))
    }
}

enum SheepWoolVisualState: String, CaseIterable, Equatable {
    case woolReady = "wool_ready"
    case shorn
    case regrowing
}

extension FarmState {
    @discardableResult
    mutating func shear(
        sheepID: UUID,
        protectedNightCount: Int,
        at date: Date = Date()
    ) throws -> Int {
        guard let index = sheep.firstIndex(where: { $0.id == sheepID }) else {
            throw FarmActionError.sheepNotFound
        }
        guard sheep[index].status == .active else { throw FarmActionError.sheepNotActive }
        guard FarmEconomyRules.isWoolReady(
            for: sheep[index],
            protectedNightCount: protectedNightCount
        ) else { throw FarmActionError.woolRegrowing }

        let yield = FarmEconomyRules.woolYield(for: sheep[index].rarity)
        sheep[index].lastShearedProtectedNight = max(0, protectedNightCount)
        sheep[index].timesSheared += 1
        woolBalance += yield
        appendTransaction(FarmTransaction(
            id: UUID(),
            idempotencyKey: "shear:\(sheepID.uuidString):\(sheep[index].timesSheared)",
            kind: .shearing,
            sheepID: sheepID,
            itemID: nil,
            woolDelta: yield,
            createdAt: date
        ))
        return yield
    }

    @discardableResult
    mutating func tradeToAnotherFarm(
        sheepID: UUID,
        protectedNightCount: Int,
        at date: Date = Date()
    ) throws -> Int {
        guard let index = sheep.firstIndex(where: { $0.id == sheepID }) else {
            throw FarmActionError.sheepNotFound
        }
        guard [.active, .pending].contains(sheep[index].status) else {
            throw FarmActionError.sheepNotActive
        }
        let idempotencyKey = "sell:\(sheepID.uuidString)"
        guard !transactions.contains(where: { $0.idempotencyKey == idempotencyKey }) else {
            throw FarmActionError.sheepNotActive
        }
        let value = FarmEconomyRules.tradeWoolValue(
            for: sheep[index],
            protectedNightCount: protectedNightCount
        )
        sheep[index].status = .sold
        woolBalance += value
        appendTransaction(FarmTransaction(
            id: UUID(),
            idempotencyKey: idempotencyKey,
            kind: .sale,
            sheepID: sheepID,
            itemID: nil,
            woolDelta: value,
            createdAt: date
        ))
        return value
    }

    mutating func welcomePending(sheepID: UUID) throws {
        guard activeSheep.count < activeCapacity else { throw FarmActionError.barnFull }
        guard let index = sheep.firstIndex(where: { $0.id == sheepID }) else {
            throw FarmActionError.sheepNotFound
        }
        guard sheep[index].status == .pending else { throw FarmActionError.sheepNotActive }
        sheep[index].status = .active
    }

    mutating func toggleFavorite(sheepID: UUID) throws {
        guard let index = sheep.firstIndex(where: { $0.id == sheepID }) else {
            throw FarmActionError.sheepNotFound
        }
        guard sheep[index].status == .active else { throw FarmActionError.sheepNotActive }
        sheep[index].isFavorite.toggle()
    }

    mutating func setTrackedSheep(_ definitionID: String?) {
        trackedSheepDefinitionID = definitionID
    }

    mutating func setShepherdSkinTone(_ skinTone: ShepherdSkinTone) {
        shepherd.skinTone = skinTone
    }

    mutating func setShepherdHairStyle(_ hairStyle: ShepherdHairStyle) {
        shepherd.hairStyle = hairStyle
    }

    mutating func appendTransaction(_ transaction: FarmTransaction) {
        guard !transactions.contains(where: { $0.idempotencyKey == transaction.idempotencyKey }) else {
            return
        }
        transactions.append(transaction)
        transactions = Array(transactions.suffix(Self.maximumTransactions))
    }
}
