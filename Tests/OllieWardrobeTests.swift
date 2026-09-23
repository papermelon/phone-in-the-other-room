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
            let pose = try XCTUnwrap(OllieNeckwearPose.forAsset(name), name)
            XCTAssertTrue((0...512).contains(pose.neckLeft.x), name)
            XCTAssertTrue((0...512).contains(pose.neckRight.x), name)
            XCTAssertTrue((0...512).contains(pose.bibTip.y), name)
        }
        XCTAssertNil(OllieNeckwearPose.forAsset("unknown"))
        XCTAssertNil(OllieNeckwearPose.forAsset("dog/dog_ollie_motion_pose_99"))
    }

    func testRestHidesLooseDetailsAndRunUsesIndividualRegistration() throws {
        let upright = try XCTUnwrap(OllieNeckwearPose.forAsset(NightJourneyAssets.ollieHomeIdleFrames[0]))
        let curled = try XCTUnwrap(OllieNeckwearPose.forAsset("dog/dog_ollie_motion_pose_09"))
        XCTAssertTrue(upright.showsFrontDetail)
        XCTAssertFalse(curled.showsFrontDetail)
        XCTAssertNotEqual(OllieNeckwearPose.forAsset(NightJourneyAssets.ollieRunFrames[0]),
                          OllieNeckwearPose.forAsset(NightJourneyAssets.ollieRunFrames[1]))
    }

    func testEveryGarmentUsesTheSameNonCollapsedPoseRegistration() throws {
        let motion = OllieCompanionAction.allCases.flatMap {
            OllieCompanionSpriteManifest.production.sequence(for: $0)?.frames.map(\.assetName) ?? []
        }
        for name in Set(motion + NightJourneyAssets.ollieHomeIdleFrames + NightJourneyAssets.ollieRunFrames + ["dog/dog_classic_farm_idle"]) {
            let pose = try XCTUnwrap(OllieNeckwearPose.forAsset(name), name)
            let neck = CGPoint(x: pose.neckRight.x - pose.neckLeft.x, y: pose.neckRight.y - pose.neckLeft.y)
            let bib = CGPoint(x: pose.bibTip.x - pose.neckLeft.x, y: pose.bibTip.y - pose.neckLeft.y)
            // Positive area is required by the cloth transform and its fur occlusion cut.
            XCTAssertGreaterThan(neck.x * bib.y - neck.y * bib.x, 500, name)
        }
        XCTAssertNil(OllieNeckwearPose.forAsset("unknown"))
        XCTAssertNil(OllieNeckwearPose.forAsset("dog/dog_ollie_motion_pose_99"))
    }

    func testHeadTiltMovesNecklineWhileBibStaysOnChest() throws {
        let idle = try XCTUnwrap(OllieNeckwearPose.forAsset(NightJourneyAssets.ollieHomeIdleFrames[0]))
        let tilt = try XCTUnwrap(OllieNeckwearPose.forAsset(NightJourneyAssets.ollieHomeIdleFrames[4]))
        XCTAssertLessThan(tilt.neckRight.y, idle.neckRight.y - 10)
        XCTAssertLessThan(tilt.neckLeft.x, idle.neckLeft.x - 5)
        XCTAssertLessThan(abs(tilt.bibTip.x - idle.bibTip.x), 5)
        XCTAssertEqual(tilt.bibTip.y, idle.bibTip.y)
        let curled = try XCTUnwrap(OllieNeckwearPose.forAsset("dog/dog_ollie_motion_pose_09"))
        XCTAssertFalse(curled.showsTie)
        XCTAssertFalse(curled.showsFrontDetail)
        XCTAssertLessThan(curled.bibTip.y, 400, "Resting cloth must stay above the foreground paws")
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


extension OllieWardrobeTests {
    func testFullerCoatRequiresEveryProductionPoseAndMissingFrameFallsBackAsOnePack() throws {
        let bases = OllieCoatStyle.baseAssets
        XCTAssertEqual(bases.count, 23)
        let assets = Set(bases.compactMap(OllieCoatStyle.fullerAsset))
        XCTAssertEqual(assets.count, 23)
        XCTAssertTrue(OllieCoatStyle.hasCompletePack(available: assets))
        for asset in assets { XCTAssertFalse(OllieCoatStyle.hasCompletePack(available: assets.subtracting([asset]))) }
        XCTAssertNil(OllieCoatStyle.fullerAsset(for: "unknown"))
        for base in bases {
            let pose = try XCTUnwrap(OllieFullerCoatRegistration.neckwear(for: base))
            XCTAssertTrue((0...512).contains(pose.neckLeft.x))
            XCTAssertTrue((0...512).contains(pose.bibTip.y))
            XCTAssertLessThan(abs(OllieFullerCoatRegistration.groundOffset(for: base)), 80)
        }
    }

    func testCoatAndGarmentPersistIndependentlyIncludingUnknownFutureCoat() throws {
        for coat in [nil, "fuller", "future_coat"] {
            var state = FarmState.empty
            state.woolBalance = 100
            state.equipment.ollieCoatID = coat
            try state.purchase(itemID: "ollie_moss_bandana")
            let restored = try JSONDecoder().decode(FarmState.self, from: JSONEncoder().encode(state))
            XCTAssertEqual(restored, state)
            XCTAssertEqual(restored.equipment.ollieCoatID, coat)
            XCTAssertEqual(restored.equipment.ollieCoat, coat == "fuller" ? .fuller : .classic)
            try state.takeOffOllieAccessory(itemID: "ollie_moss_bandana")
            XCTAssertEqual(state.equipment.ollieCoatID, coat)
            state.equipment.ollieCoatID = nil
            XCTAssertTrue(state.ownedShopItemIDs.contains("ollie_moss_bandana"))
        }
    }
}
