import XCTest

final class FarmEconomySimulationTests: XCTestCase {
    func testCollectorAndDecoratorStrategiesMeetEarlyAndLongRangeTargets() throws {
        let collectorAt14 = try simulate(until: 14, strategy: .collector)
        let decoratorAt14 = try simulate(until: 14, strategy: .decorator)
        let collectorAt60 = try simulate(until: 60, strategy: .collector)

        XCTAssertLessThanOrEqual(collectorAt14.firstPurchaseNight ?? .max, 5)
        XCTAssertTrue((4...8).contains(collectorAt14.state.ownedShopItemIDs.count))
        XCTAssertTrue((4...8).contains(decoratorAt14.state.ownedShopItemIDs.count))
        XCTAssertLessThan(collectorAt60.state.ownedShopItemIDs.count, 27)
    }

    func testDuplicateTradingIsUsefulWithoutDominatingPatientShearing() throws {
        let result = try simulate(until: 60, strategy: .duplicateTrader)
        let earned = result.state.economySnapshot.woolEarnedByKind
        let shearing = earned[FarmTransactionKind.shearing.rawValue, default: 0]
        let trading = earned[FarmTransactionKind.sale.rawValue, default: 0]

        XCTAssertGreaterThan(trading, 0)
        XCTAssertLessThan(trading, shearing)
    }

    private enum Strategy: Equatable {
        case collector
        case decorator
        case duplicateTrader
    }

    private struct Result {
        var state: FarmState
        var firstPurchaseNight: Int?
    }

    private func simulate(until finalNight: Int, strategy: Strategy) throws -> Result {
        var state = FarmState.empty
        var firstPurchaseNight: Int?
        let arrivals: [Int: (String, SheepRarity)] = [
            0: ("starter", .common),
            1: ("clover", .common),
            2: ("moon", .uncommon),
            3: ("clover", .common),
            8: ("moor", .rare),
            13: ("moon", .common),
            21: ("clover", .uncommon),
            34: ("moor", .rare),
            48: ("clover", .common)
        ]
        state.sheep.append(sheep(for: arrivals[0]!, night: 0))
        state.sheep.append(sheep(for: ("practice", .common), night: 0, idSuffix: 999))

        for night in 1...finalNight {
            if let arrival = arrivals[night] {
                let newcomer = sheep(for: arrival, night: night)
                let isDuplicate = state.sheep.contains { sheep in
                    sheep.status != .sold && sheep.definitionID == newcomer.definitionID
                }
                state.sheep.append(newcomer)
                if strategy == .duplicateTrader, isDuplicate {
                    _ = try state.tradeToAnotherFarm(
                        sheepID: newcomer.id,
                        protectedNightCount: night
                    )
                }
            }

            let shearingLimit = strategy == .decorator ? 2 : 1
            let readySheep = state.activeSheep.filter {
                FarmEconomyRules.isWoolReady(for: $0, protectedNightCount: night)
            }
            for sheep in readySheep.prefix(shearingLimit) {
                _ = try state.shear(sheepID: sheep.id, protectedNightCount: night)
            }

            guard strategy != .duplicateTrader else { continue }
            let category: FarmShopCategory? = strategy == .decorator ? .farm : nil
            let candidate = FarmShopCatalog.all
                .filter { $0.category != .barn }
                .filter { category == nil || $0.category == category }
                .filter { !state.ownedShopItemIDs.contains($0.id) }
                .filter { $0.isUnlocked(for: state.shopProgress(qualifyingWindDowns: night)) }
                .filter { $0.woolCost <= state.woolBalance }
                .sorted { lhs, rhs in
                    lhs.woolCost == rhs.woolCost ? lhs.id < rhs.id : lhs.woolCost < rhs.woolCost
                }
                .first
            if let candidate {
                try state.purchase(itemID: candidate.id, qualifyingWindDowns: night)
                firstPurchaseNight = firstPurchaseNight ?? night
            }
        }
        return Result(state: state, firstPurchaseNight: firstPurchaseNight)
    }

    private func sheep(
        for arrival: (String, SheepRarity),
        night: Int,
        idSuffix: Int? = nil
    ) -> FlockSheep {
        FlockSheep(
            id: UUID(uuidString: String(
                format: "00000000-0000-0000-0001-%012d",
                idSuffix ?? night
            ))!,
            definitionID: arrival.0,
            displayName: arrival.0,
            arrivedAt: Date(timeIntervalSince1970: Double(night)),
            protectedNightNumber: night,
            rarity: arrival.1
        )
    }
}
