import XCTest

final class FarmShopExpansionTests: XCTestCase {
    func testCatalogIDsAreUniqueAndNewPricesStayExact() {
        XCTAssertEqual(Set(FarmShopCatalog.all.map(\.id)).count, FarmShopCatalog.all.count)
        let expected: [String: Int] = [
            "ollie_clover_collar": 8, "ollie_sunrise_scarf": 12,
            "ollie_star_keeper_cape": 20, "shepherd_clover_headscarf": 6,
            "shepherd_moon_beanie": 10, "shepherd_field_overalls": 12,
            "shepherd_star_keeper_cloak": 22, "farm_story_bench": 8,
            "farm_sheep_trough": 9, "farm_dusk_pond": 14, "farm_old_oak": 20,
            "collectible_hoofprint_tile": 5, "collectible_wool_almanac": 8,
            "collectible_sunrise_compass": 14, "collectible_high_moor_star": 17
        ]
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: FarmShopCatalog.all.compactMap { item in
                expected[item.id].map { _ in (item.id, item.woolCost) }
            }),
            expected
        )
    }

    func testUnlockRequirementsAcceptEitherPermanentMilestonePath() {
        let tier1 = FarmShopCatalog.unlockRequirement(forTier: 1)
        let tier2 = FarmShopCatalog.unlockRequirement(forTier: 2)
        let tier3 = FarmShopCatalog.unlockRequirement(forTier: 3)

        XCTAssertEqual(SheepCatalog.all.count, 12)
        XCTAssertFalse(tier1.isSatisfied(by: .newFarm))
        XCTAssertTrue(tier1.isSatisfied(by: progress(windDowns: 3)))
        XCTAssertTrue(tier1.isSatisfied(by: progress(discoveries: 4)))
        XCTAssertTrue(tier2.isSatisfied(by: progress(windDowns: 10)))
        XCTAssertTrue(tier2.isSatisfied(by: progress(discoveries: 8)))
        XCTAssertTrue(tier3.isSatisfied(by: progress(windDowns: 25)))
        XCTAssertTrue(tier3.isSatisfied(by: progress(discoveries: 12)))
        XCTAssertTrue(tier3.isSatisfied(by: progress(permanentlyUnlockedTier: 3)))
    }

    func testAllDiscoveriesRequirementInterpolatesItsCount() {
        let requirement = FarmShopUnlockRequirement.milestone(
            tier: 3,
            windDowns: 25,
            discoveries: SheepCatalog.all.count
        )

        XCTAssertEqual(
            requirement.description,
            "Tier 3 · Complete 25 Wind Downs or discover all \(SheepCatalog.all.count) sheep."
        )
    }

    func testLockedPurchaseIsAtomicAndUnlockTierPersists() throws {
        var state = FarmState.empty
        state.woolBalance = 50
        let before = state

        XCTAssertThrowsError(try state.purchase(itemID: "ollie_sunrise_scarf")) { error in
            XCTAssertEqual(error as? FarmActionError, .itemLocked)
        }
        XCTAssertEqual(state, before)

        try state.purchase(itemID: "ollie_sunrise_scarf", qualifyingWindDowns: 10)
        XCTAssertEqual(state.unlockedShopTier, 2)
        let decoded = try JSONDecoder().decode(FarmState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.unlockedShopTier, 2)
        XCTAssertTrue(FarmShopCatalog.unlockRequirement(forTier: 2).isSatisfied(
            by: decoded.shopProgress(qualifyingWindDowns: 0)
        ))
    }

    func testLegacyEquipmentMigratesIntoDeterministicBoundedSlots() throws {
        let data = Data(#"{"farmDecorationItemIDs":["farm_flower_patch","farm_story_bench","farm_lanterns","future_prop"],"collectibleItemIDs":["one","two","three","four","five"]}"#.utf8)
        let equipment = try JSONDecoder().decode(FarmEquipment.self, from: data)

        XCTAssertEqual(equipment.decorationPlacements[.leftMeadow], "farm_flower_patch")
        XCTAssertEqual(equipment.decorationPlacements[.rightMeadow], "farm_lanterns")
        XCTAssertEqual(equipment.decorationPlacements.count, 2)
        XCTAssertEqual(equipment.collectibleItemIDs, ["one", "two", "three", "four"])
    }

    func testDecorationZonesReplacePlacementWithoutChangingOwnership() throws {
        var state = FarmState.empty
        state.woolBalance = 30
        try state.purchase(itemID: "farm_flower_patch")
        try state.purchase(itemID: "farm_story_bench", qualifyingWindDowns: 3)

        XCTAssertEqual(state.equipment.decorationPlacements[.leftMeadow], "farm_story_bench")
        XCTAssertTrue(state.ownedShopItemIDs.contains("farm_flower_patch"))
        XCTAssertTrue(state.ownedShopItemIDs.contains("farm_story_bench"))
    }

    func testKeepsakeShelfStoresOverflowButPreservesOwnership() throws {
        var state = FarmState.empty
        state.woolBalance = 100
        let itemIDs = FarmShopCatalog.items(in: .collectibles).prefix(5).map(\.id)
        for itemID in itemIDs {
            try state.purchase(itemID: itemID, qualifyingWindDowns: 25)
        }

        XCTAssertEqual(state.equipment.collectiblePlacements.count, 4)
        XCTAssertEqual(state.ownedShopItemIDs.filter(itemIDs.contains).count, 5)
        XCTAssertThrowsError(try state.displayCollectible(itemID: itemIDs[4])) { error in
            XCTAssertEqual(error as? FarmActionError, .displayFull)
        }
    }

    func testEconomySnapshotAggregatesKindsWithoutTimestampsOrNames() throws {
        var state = FarmState.empty
        state.sheep = [FlockSheep(
            id: UUID(), definitionID: "mabel", displayName: "Mabel", arrivedAt: Date(),
            protectedNightNumber: 1, rarity: .common
        )]
        let sheepID = try XCTUnwrap(state.activeSheep.first?.id)
        _ = try state.shear(sheepID: sheepID, protectedNightCount: 1)
        state.woolBalance += 5
        try state.purchase(itemID: "ollie_moss_bandana")

        let snapshot = state.economySnapshot
        XCTAssertEqual(snapshot.woolEarnedByKind[FarmTransactionKind.shearing.rawValue], 1)
        XCTAssertEqual(snapshot.woolSpentByKind[FarmTransactionKind.purchase.rawValue], 3)
        XCTAssertEqual(snapshot.woolBalance, state.woolBalance)
        XCTAssertEqual(snapshot.ownedItemCount, 1)
        let json = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
        XCTAssertFalse(json.contains("createdAt"))
        XCTAssertFalse(json.contains("displayName"))
    }

    private func progress(
        windDowns: Int = 0,
        discoveries: Int = 0,
        permanentlyUnlockedTier: Int = 0
    ) -> FarmShopProgress {
        FarmShopProgress(
            qualifyingWindDowns: windDowns,
            discoveries: discoveries,
            permanentlyUnlockedTier: permanentlyUnlockedTier
        )
    }
}
