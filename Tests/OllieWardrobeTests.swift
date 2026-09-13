import XCTest

final class OllieWardrobeTests: XCTestCase {
    func testEveryPurchasableOllieItemHasAFittedGarment() {
        XCTAssertEqual(Set(FarmShopCatalog.items(in: .ollie).map(\.id)), Set(OllieGarment.allCases.map(\.rawValue)))
        XCTAssertNil(OllieGarment(itemID: nil))
        XCTAssertNil(OllieGarment(itemID: "collectible_wool_almanac"))
        XCTAssertNil(OllieGarment(itemID: "future_item"))
    }

    func testEveryHomeMotionAndChaseFrameHasNeckRegistration() throws {
        let motion = OllieCompanionAction.allCases.flatMap {
            OllieCompanionSpriteManifest.production.sequence(for: $0)?.frames.map(\.assetName) ?? []
        }
        for name in Set(motion + NightJourneyAssets.ollieHomeIdleFrames + NightJourneyAssets.ollieRunFrames + ["dog/dog_classic_farm_idle"]) {
            let fit = try XCTUnwrap(OllieGarmentFit.forAsset(name), name)
            XCTAssertTrue((0...512).contains(fit.x), name)
            XCTAssertTrue((0...512).contains(fit.y), name)
            XCTAssertTrue((40...160).contains(fit.width), name)
            XCTAssertTrue((0.1...1).contains(fit.drape), name)
        }
        XCTAssertNil(OllieGarmentFit.forAsset("unknown"))
        XCTAssertNil(OllieGarmentFit.forAsset("dog/dog_ollie_motion_pose_99"))
    }

    func testRestFoldsClothAwayAndRunUsesIndividualRegistration() throws {
        let upright = try XCTUnwrap(OllieGarmentFit.forAsset(NightJourneyAssets.ollieHomeIdleFrames[0]))
        let curled = try XCTUnwrap(OllieGarmentFit.forAsset("dog/dog_ollie_motion_pose_09"))
        XCTAssertLessThan(curled.drape, upright.drape)
        XCTAssertGreaterThan(curled.angle, upright.angle)
        XCTAssertNotEqual(OllieGarmentFit.forAsset(NightJourneyAssets.ollieRunFrames[0]),
                          OllieGarmentFit.forAsset(NightJourneyAssets.ollieRunFrames[1]))
    }

    func testBuyingAndChangingLookPreservesWardrobeAcrossSaveRestore() throws {
        var state = FarmState.empty
        state.woolBalance = 100
        for garment in OllieGarment.allCases {
            try state.purchase(itemID: garment.rawValue, qualifyingWindDowns: 25)
            XCTAssertEqual(state.equipment.ollieAccessoryItemID, garment.rawValue)
        }
        let restored = try JSONDecoder().decode(FarmState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored.equipment.ollieAccessoryItemID, OllieGarment.starKeeperCape.rawValue)
        XCTAssertTrue(Set(OllieGarment.allCases.map(\.rawValue)).isSubset(of: Set(restored.ownedShopItemIDs)))
        let balance = state.woolBalance
        try state.wearOllieAccessory(itemID: OllieGarment.mossBandana.rawValue)
        try state.takeOffOllieAccessory(itemID: OllieGarment.mossBandana.rawValue)
        XCTAssertNil(state.equipment.ollieAccessoryItemID)
        XCTAssertEqual(state.woolBalance, balance)
        XCTAssertThrowsError(try state.wearOllieAccessory(itemID: "collectible_wool_almanac"))
    }
}
