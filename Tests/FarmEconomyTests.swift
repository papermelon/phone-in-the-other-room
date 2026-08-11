import XCTest

final class FarmEconomyTests: XCTestCase {
    func testFarmStateDecodesFromMissingKeys() throws {
        let state = try JSONDecoder().decode(FarmState.self, from: Data("{}".utf8))

        XCTAssertEqual(state, .empty)
        XCTAssertEqual(state.activeCapacity, 12)
    }

    func testVersionOneCashBalanceConvertsToWoolOnceAndIsNotReencoded() throws {
        let legacy = Data(#"{"schemaVersion":1,"woolBalance":2,"cashBalance":6}"#.utf8)

        let migrated = try JSONDecoder().decode(FarmState.self, from: legacy)
        let encoded = try JSONEncoder().encode(migrated)
        let decodedAgain = try JSONDecoder().decode(FarmState.self, from: encoded)

        XCTAssertEqual(migrated.schemaVersion, 2)
        XCTAssertEqual(migrated.woolBalance, 4)
        XCTAssertEqual(migrated.transactions.count, 1)
        XCTAssertEqual(migrated.transactions.first?.kind, .currencyConsolidation)
        XCTAssertEqual(migrated.transactions.first?.woolDelta, 2)
        XCTAssertEqual(migrated.transactions.first?.legacyCashDelta, -6)
        XCTAssertEqual(decodedAgain, migrated)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains(#""cashBalance""#))
    }

    func testLegacyTransactionCashDeltaRemainsAsAuditData() throws {
        let legacy = Data(#"{"id":"00000000-0000-0000-0000-000000000001","idempotencyKey":"sell:legacy","kind":"sale","woolDelta":0,"cashDelta":12,"createdAt":0}"#.utf8)

        let transaction = try JSONDecoder().decode(FarmTransaction.self, from: legacy)
        let encoded = try JSONEncoder().encode(transaction)

        XCTAssertEqual(transaction.legacyCashDelta, 12)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains(#""cashDelta""#))
    }

    func testMigrationCreatesOneSheepPerFoundOutcomeAndIsIdempotent() {
        let first = foundOutcome(id: uuid(1), runID: uuid(101), definitionID: "mabel", night: 1)
        let second = foundOutcome(id: uuid(2), runID: uuid(102), definitionID: "mabel", night: 12)
        var search = SheepSearchState.empty
        search.append(first)
        search.append(second)

        let migrated = FarmMigration.migrated(existing: nil, searchState: search)
        let reconciled = FarmMigration.migrated(existing: migrated, searchState: search)

        XCTAssertEqual(migrated, reconciled)
        XCTAssertEqual(migrated.sheep.count, 2)
        XCTAssertEqual(Set(migrated.sheep.compactMap(\.sourceOutcomeID)), Set([first.id, second.id]))
        XCTAssertEqual(migrated.discoveries.first?.encounterCount, 2)
        XCTAssertEqual(migrated.sheep.first?.displayName, "Mabel")
        XCTAssertNotEqual(migrated.sheep[0].displayName, migrated.sheep[1].displayName)
    }

    func testMigrationCreatesStableLegacySheepWithoutHistoricalOutcome() {
        var search = SheepSearchState.empty
        search.foundSheepIDs = ["oat"]

        let first = FarmMigration.migrated(existing: nil, searchState: search, now: Date(timeIntervalSince1970: 10))
        let second = FarmMigration.migrated(existing: first, searchState: search, now: Date(timeIntervalSince1970: 99))

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.sheep.map(\.id), [FarmMigration.stableLegacyID(for: "oat")])
        XCTAssertEqual(first.sheep.first?.displayName, "Oat")
    }

    func testMigrationPlacesOverflowIntoPendingArrivals() {
        var search = SheepSearchState.empty
        for index in 1...13 {
            search.append(foundOutcome(
                id: uuid(index),
                runID: uuid(100 + index),
                definitionID: "mabel",
                night: index
            ))
        }

        let state = FarmMigration.migrated(existing: nil, searchState: search)

        XCTAssertEqual(state.activeSheep.count, 12)
        XCTAssertEqual(state.pendingSheep.count, 1)
        XCTAssertEqual(state.sheep.count, 13)
    }

    func testShearingYieldsWoolAndRegrowsThroughProtectedNights() throws {
        var state = stateWithActiveSheep(rarity: .uncommon)
        let sheepID = try XCTUnwrap(state.activeSheep.first?.id)

        let amount = try state.shear(sheepID: sheepID, protectedNightCount: 10)

        XCTAssertEqual(amount, 2)
        XCTAssertEqual(state.woolBalance, 2)
        XCTAssertEqual(state.activeSheep.first?.timesSheared, 1)
        XCTAssertEqual(
            FarmEconomyRules.remainingRegrowthNights(for: state.activeSheep[0], protectedNightCount: 11),
            2
        )
        XCTAssertThrowsError(try state.shear(sheepID: sheepID, protectedNightCount: 12))
        XCTAssertEqual(try state.shear(sheepID: sheepID, protectedNightCount: 13), 2)
    }

    func testRecentlyShearedTradeUsesSeventyFivePercentModifier() throws {
        var state = stateWithActiveSheep(rarity: .rare)
        let sheepID = try XCTUnwrap(state.activeSheep.first?.id)
        _ = try state.shear(sheepID: sheepID, protectedNightCount: 20)

        let trade = try state.tradeToAnotherFarm(sheepID: sheepID, protectedNightCount: 21)

        XCTAssertEqual(trade, 9)
        XCTAssertEqual(state.woolBalance, 13)
        XCTAssertEqual(state.soldSheep.count, 1)
        XCTAssertThrowsError(try state.tradeToAnotherFarm(sheepID: sheepID, protectedNightCount: 21))
        XCTAssertEqual(state.woolBalance, 13)
    }

    func testPendingSheepCanBeTradedWithoutJoiningThePasture() throws {
        var state = stateWithActiveSheep(rarity: .common)
        let pending = FlockSheep(
            id: uuid(77),
            definitionID: "pippin",
            displayName: "Pippin",
            arrivedAt: Date(),
            protectedNightNumber: 2,
            rarity: .common,
            status: .pending
        )
        state.sheep.append(pending)

        XCTAssertEqual(try state.tradeToAnotherFarm(sheepID: pending.id, protectedNightCount: 2), 3)
        XCTAssertTrue(state.pendingSheep.isEmpty)
        XCTAssertTrue(state.soldSheep.contains { $0.id == pending.id })
    }

    func testCapacityUpgradeIsSequentialAndWelcomesPendingSheep() throws {
        var state = FarmState.empty
        state.woolBalance = 1_000
        for index in 0..<13 {
            state.sheep.append(FlockSheep(
                id: uuid(index + 1),
                definitionID: "mabel",
                displayName: "Sheep \(index)",
                arrivedAt: Date(timeIntervalSince1970: Double(index)),
                protectedNightNumber: index + 1,
                rarity: .common,
                status: index < 12 ? .active : .pending
            ))
        }

        XCTAssertThrowsError(try state.purchase(itemID: "barn_paddock_36"))
        try state.purchase(itemID: "barn_paddock_24")

        XCTAssertEqual(state.barnCapacityLevel, 1)
        XCTAssertEqual(state.activeCapacity, 24)
        XCTAssertEqual(state.activeSheep.count, 13)
        XCTAssertTrue(state.pendingSheep.isEmpty)
        XCTAssertEqual(state.woolBalance, 985)
    }

    func testPurchaseRejectsInsufficientFundsAndRepeatedPurchase() throws {
        var state = FarmState.empty

        XCTAssertThrowsError(try state.purchase(itemID: "ollie_moss_bandana"))
        XCTAssertEqual(state.woolBalance, 0)
        XCTAssertTrue(state.ownedShopItemIDs.isEmpty)

        state.woolBalance = 3
        try state.purchase(itemID: "ollie_moss_bandana")
        XCTAssertEqual(state.woolBalance, 0)
        XCTAssertEqual(state.equipment.ollieAccessoryItemID, "ollie_moss_bandana")
        XCTAssertThrowsError(try state.purchase(itemID: "ollie_moss_bandana"))
        XCTAssertEqual(state.woolBalance, 0)
    }

    func testPurchaseAutoEquipsPlacesAndDisplaysProductionItems() throws {
        var state = FarmState.empty
        state.woolBalance = 20

        try state.purchase(itemID: "ollie_moss_bandana")
        try state.purchase(itemID: "shepherd_wool_hat")
        try state.purchase(itemID: "farm_flower_patch")
        try state.purchase(itemID: "collectible_trail_pin")

        XCTAssertEqual(state.equipment.ollieAccessoryItemID, "ollie_moss_bandana")
        XCTAssertEqual(state.shepherd.accessoryItemID, "shepherd_wool_hat")
        XCTAssertEqual(state.equipment.farmDecorationItemIDs, ["farm_flower_patch"])
        XCTAssertEqual(state.equipment.collectibleItemIDs, ["collectible_trail_pin"])
    }

    func testWearingSecondItemReplacesOnlyItsMatchingSlot() throws {
        var state = FarmState.empty
        state.woolBalance = 50

        try state.purchase(itemID: "ollie_moss_bandana")
        try state.purchase(itemID: "shepherd_moss_coat")
        try state.purchase(itemID: "farm_lanterns")
        try state.purchase(itemID: "collectible_trail_pin")
        try state.purchase(itemID: "ollie_moon_kerchief")
        try state.purchase(itemID: "shepherd_moon_coat")

        XCTAssertEqual(state.equipment.ollieAccessoryItemID, "ollie_moon_kerchief")
        XCTAssertEqual(state.shepherd.outfitItemID, "shepherd_moon_coat")
        XCTAssertEqual(state.equipment.farmDecorationItemIDs, ["farm_lanterns"])
        XCTAssertEqual(state.equipment.collectibleItemIDs, ["collectible_trail_pin"])
    }

    func testUnequippingClearsOnlySelectedSlot() throws {
        var state = FarmState.empty
        state.woolBalance = 40
        try state.purchase(itemID: "ollie_moss_bandana")
        try state.purchase(itemID: "shepherd_wool_hat")
        try state.purchase(itemID: "shepherd_moss_coat")
        try state.purchase(itemID: "farm_lanterns")
        try state.purchase(itemID: "collectible_trail_pin")

        try state.takeOffOllieAccessory(itemID: "ollie_moss_bandana")
        try state.takeOffShepherdAccessory(itemID: "shepherd_wool_hat")
        try state.putAwayFarmDecoration(itemID: "farm_lanterns")
        try state.storeCollectible(itemID: "collectible_trail_pin")

        XCTAssertNil(state.equipment.ollieAccessoryItemID)
        XCTAssertNil(state.shepherd.accessoryItemID)
        XCTAssertEqual(state.shepherd.outfitItemID, "shepherd_moss_coat")
        XCTAssertTrue(state.equipment.farmDecorationItemIDs.isEmpty)
        XCTAssertTrue(state.equipment.collectibleItemIDs.isEmpty)
    }

    func testOwnedEquipmentAndShepherdProfilePersist() throws {
        var state = FarmState.empty
        state.woolBalance = 30
        try state.purchase(itemID: "ollie_moss_bandana")
        try state.purchase(itemID: "shepherd_wool_hat")
        try state.purchase(itemID: "shepherd_moss_coat")
        try state.purchase(itemID: "farm_lanterns")
        try state.purchase(itemID: "collectible_trail_pin")
        state.setShepherdSkinTone(.deep)
        state.setShepherdHairStyle(.coils)

        let decoded = try JSONDecoder().decode(FarmState.self, from: JSONEncoder().encode(state))

        XCTAssertEqual(decoded.shepherd.skinTone, .deep)
        XCTAssertEqual(decoded.shepherd.hairStyle, .coils)
        XCTAssertEqual(decoded.shepherd.accessoryItemID, "shepherd_wool_hat")
        XCTAssertEqual(decoded.shepherd.outfitItemID, "shepherd_moss_coat")
        XCTAssertEqual(decoded.equipment.ollieAccessoryItemID, "ollie_moss_bandana")
        XCTAssertEqual(decoded.equipment.farmDecorationItemIDs, ["farm_lanterns"])
        XCTAssertEqual(decoded.equipment.collectibleItemIDs, ["collectible_trail_pin"])
        XCTAssertEqual(decoded.woolBalance, 9)
    }

    func testShopSeparatesInventoryThumbnailFromEquippedRenderArt() throws {
        let ollie = try XCTUnwrap(FarmShopCatalog.item(for: "ollie_moss_bandana"))
        let hat = try XCTUnwrap(FarmShopCatalog.item(for: "shepherd_wool_hat"))

        XCTAssertEqual(ollie.inventoryAssetName, "shop/shop_ollie_classic_moss_bandana")
        XCTAssertEqual(
            ollie.equippedRenderAsset,
            .ollieAccessory(overlayAssetName: "dog/dog_classic_farm_moss_bandana_equipped_overlay")
        )
        XCTAssertEqual(hat.inventoryAssetName, "shop/shop_shepherd_wool_hat")
        XCTAssertEqual(
            hat.equippedRenderAsset?.assetName(for: .coils),
            "farm/farm_shepherd_coils_wool_field_hat_equipped_overlay"
        )
    }

    func testUnknownPresentationIDsDoNotEraseOwnershipDuringRoundTrip() throws {
        var state = FarmState.empty
        state.ownedShopItemIDs = ["future_cosmetic"]
        state.equipment.ollieAccessoryItemID = "future_cosmetic"

        let decoded = try JSONDecoder().decode(FarmState.self, from: JSONEncoder().encode(state))

        XCTAssertEqual(decoded.ownedShopItemIDs, ["future_cosmetic"])
        XCTAssertEqual(decoded.equipment.ollieAccessoryItemID, "future_cosmetic")
    }

    func testFarmDecorationAnchorsAreStableAndBounded() {
        let anchors = FarmShopCatalog.items(in: .farm).compactMap {
            FarmShopCatalog.decorationAnchor(for: $0.id)
        }

        XCTAssertEqual(anchors.count, 4)
        XCTAssertTrue(anchors.allSatisfy(\.isBounded))
        XCTAssertEqual(
            FarmShopCatalog.decorationAnchor(for: "farm_moon_gate"),
            FarmShopCatalog.decorationAnchor(for: "farm_moon_gate")
        )
    }

    func testDiscoveryAndTrailNotesSurviveTrading() throws {
        let outcome = foundOutcome(id: uuid(1), runID: uuid(2), definitionID: "oat", night: 5)
        var search = SheepSearchState.empty
        search.append(outcome)
        var state = FarmMigration.migrated(existing: nil, searchState: search)
        let sheepID = try XCTUnwrap(state.activeSheep.first?.id)

        _ = try state.tradeToAnotherFarm(sheepID: sheepID, protectedNightCount: 5)

        XCTAssertEqual(state.discoveries.map(\.definitionID), ["oat"])
        XCTAssertEqual(state.discoveries.first?.outcomeIDs, [outcome.id])
        XCTAssertEqual(search.outcomes, [outcome])
    }

    func testMaximumCapacityAndShopCategoryMinimums() throws {
        var state = FarmState.empty
        state.woolBalance = 1_000
        for itemID in ["barn_paddock_24", "barn_paddock_36", "barn_paddock_48", "barn_paddock_60"] {
            try state.purchase(itemID: itemID)
        }

        XCTAssertEqual(state.activeCapacity, 60)
        XCTAssertEqual(state.barnCapacityLevel, FarmEconomyRules.maximumCapacityLevel)
        XCTAssertEqual(FarmShopCatalog.items(in: .barn).count, 4)
        XCTAssertEqual(
            FarmShopCatalog.items(in: .barn).map(\.title),
            ["Second Pasture", "Hill Pasture", "Moon Pasture", "Wide Pasture"]
        )
        XCTAssertGreaterThanOrEqual(FarmShopCatalog.items(in: .ollie).count, 3)
        XCTAssertGreaterThanOrEqual(FarmShopCatalog.items(in: .shepherd).count, 3)
        XCTAssertGreaterThanOrEqual(FarmShopCatalog.items(in: .farm).count, 4)
        XCTAssertGreaterThanOrEqual(FarmShopCatalog.items(in: .collectibles).count, 2)
        XCTAssertTrue(
            FarmShopCatalog.all
                .filter { $0.category != .barn }
                .allSatisfy { $0.assetName?.hasPrefix("shop/shop_") == true }
        )
    }

    func testPublishedCapacityCostsAndRarityRulesStayExact() {
        XCTAssertEqual(FarmEconomyRules.capacities, [12, 24, 36, 48, 60])
        XCTAssertEqual(FarmEconomyRules.capacityUpgradeWoolCosts, [15, 36, 80, 170])
        XCTAssertEqual([0, 1, 5, 6, 10].map(FarmEconomyRules.convertLegacyCashToWool), [0, 1, 1, 2, 2])
        XCTAssertEqual(SheepRarity.allCases.map(FarmEconomyRules.woolYield), [1, 2, 4, 7])
        XCTAssertEqual(SheepRarity.allCases.map(FarmEconomyRules.regrowthNights), [2, 3, 4, 5])
        XCTAssertEqual(SheepRarity.allCases.map(FarmEconomyRules.baseTradeWoolValue), [3, 6, 13, 30])
        XCTAssertEqual(FarmShopCatalog.all.map(\.woolCost), [15, 36, 80, 170, 3, 6, 4, 4, 8, 14, 4, 3, 5, 7, 3, 10])
    }

    func testWoolVisualStateMovesFromShornThroughRegrowingToReady() {
        let sheep = FlockSheep(
            id: uuid(90),
            definitionID: "midnight",
            displayName: "Midnight",
            arrivedAt: Date(),
            protectedNightNumber: 1,
            rarity: .uncommon,
            lastShearedProtectedNight: 10
        )

        XCTAssertEqual(
            FarmEconomyRules.woolVisualState(for: sheep, protectedNightCount: 10),
            .shorn
        )
        XCTAssertEqual(
            FarmEconomyRules.woolVisualState(for: sheep, protectedNightCount: 11),
            .regrowing
        )
        XCTAssertEqual(
            FarmEconomyRules.woolVisualState(for: sheep, protectedNightCount: 13),
            .woolReady
        )
    }

    func testTrackedTrailClearsWhenThatDefinitionIsDiscovered() {
        var state = FarmState.empty
        state.setTrackedSheep("oat")

        state.recordArrival(foundOutcome(id: uuid(8), runID: uuid(108), definitionID: "oat", night: 5))

        XCTAssertNil(state.trackedSheepDefinitionID)
    }

    func testFailedEconomyActionsNeverCreateNegativeBalances() throws {
        var state = FarmState.empty
        state.woolBalance = 1

        XCTAssertThrowsError(try state.purchase(itemID: "shepherd_moon_coat"))
        XCTAssertEqual(state.woolBalance, 1)
        XCTAssertTrue(state.transactions.isEmpty)
    }

    private func stateWithActiveSheep(rarity: SheepRarity) -> FarmState {
        var state = FarmState.empty
        state.sheep = [FlockSheep(
            id: uuid(50),
            definitionID: "mabel",
            displayName: "Mabel",
            arrivedAt: Date(),
            protectedNightNumber: 1,
            rarity: rarity
        )]
        return state
    }

    private func foundOutcome(
        id: UUID,
        runID: UUID,
        definitionID: String,
        night: Int
    ) -> SheepSearchOutcome {
        let definition = SheepCatalog.definition(for: definitionID)!
        return SheepSearchOutcome(
            id: id,
            runID: runID,
            protectedNightNumber: night,
            result: .found,
            sheepID: definitionID,
            rarity: definition.rarity,
            habitat: definition.habitat,
            trailStrength: 60,
            encounterOdds: 1,
            trailDistance: 2,
            consecutiveNoFinds: 0,
            bonusPoints: 0,
            createdAt: Date(timeIntervalSince1970: Double(night))
        )
    }

    private func uuid(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!
    }
}
