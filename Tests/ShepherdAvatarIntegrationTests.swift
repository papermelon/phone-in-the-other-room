import XCTest

final class ShepherdAvatarIntegrationTests: XCTestCase {
    func testHeadwearAndClothingStayIndependentThroughPurchaseSwapRemovalAndRestore() throws {
        let hats = FarmShopCatalog.items(in: .shepherd).filter { $0.effect == .shepherdAccessory }
        let clothes = FarmShopCatalog.items(in: .shepherd).filter { $0.effect == .shepherdOutfit && CountingSheepPublicPresentationAllowlist.shepherdOutfitIDs.contains($0.id) }
        for hat in hats {
            for outfit in clothes {
                for hatFirst in [true, false] {
                    var farm = FarmState.empty
                    farm.woolBalance = 1000
                    for item in hatFirst ? [hat, outfit] : [outfit, hat] {
                        try farm.purchase(itemID: item.id, qualifyingWindDowns: 25)
                    }
                    XCTAssertEqual(farm.shepherd.accessoryItemID, hat.id)
                    XCTAssertEqual(farm.shepherd.outfitItemID, outfit.id)
                    farm = try JSONDecoder().decode(FarmState.self, from: JSONEncoder().encode(farm))
                    let dressed = ShepherdStudyAppearance(profile: farm.shepherd)
                    XCTAssertTrue(dressed.hat)
                    XCTAssertNotEqual(dressed.outfit, .shirt)
                    var shared = CountingSheepPublicPresentation.defaultValue
                    shared.shepherdOutfitID = outfit.id
                    shared.shepherdAccessoryID = hat.id
                    let restoredShared = try JSONDecoder().decode(CountingSheepPublicPresentation.self,
                        from: JSONEncoder().encode(shared))
                    XCTAssertEqual(ShepherdStudyAppearance(profile: restoredShared.shepherdProfile), dressed)
                    try farm.takeOffShepherdAccessory(itemID: hat.id)
                    XCTAssertEqual(farm.shepherd.outfitItemID, outfit.id)
                    XCTAssertFalse(ShepherdStudyAppearance(profile: farm.shepherd).hat)
                    try farm.equip(itemID: hat.id)
                    try farm.takeOffShepherdOutfit(itemID: outfit.id)
                    XCTAssertEqual(farm.shepherd.accessoryItemID, hat.id)
                    XCTAssertEqual(ShepherdStudyAppearance(profile: farm.shepherd).outfit, .shirt)
                    try farm.equip(itemID: outfit.id)
                    XCTAssertEqual(ShepherdStudyAppearance(profile: farm.shepherd), dressed)
                    for replacement in clothes where replacement.id != outfit.id {
                        try farm.purchase(itemID: replacement.id, qualifyingWindDowns: 25)
                        XCTAssertEqual(farm.shepherd.accessoryItemID, hat.id)
                        XCTAssertEqual(farm.shepherd.outfitItemID, replacement.id)
                    }
                    for replacement in hats where replacement.id != hat.id {
                        let retainedOutfit = farm.shepherd.outfitItemID
                        try farm.purchase(itemID: replacement.id, qualifyingWindDowns: 25)
                        XCTAssertEqual(farm.shepherd.outfitItemID, retainedOutfit)
                        XCTAssertEqual(farm.shepherd.accessoryItemID, replacement.id)
                    }
                }
            }
        }
    }

    func testLegacyProfileDefaultsWithoutChangingSavedBytesOrEquipment() throws {
        let legacy = Data(#"{"skinTone":"deep","hairStyle":"coils","outfitItemID":"shepherd_moon_coat","accessoryItemID":"shepherd_wool_hat"}"#.utf8)
        let profile = try JSONDecoder().decode(ShepherdProfile.self, from: legacy)
        XCTAssertEqual(profile.headShape, .pear)
        XCTAssertNil(profile.headShapeID)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: legacy) as? NSDictionary,
                       try JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? NSDictionary)
    }

    func testFutureShapeAndEquipmentIDsSurviveWhileRenderingFallback() throws {
        var profile = ShepherdProfile.defaultProfile
        profile.headShapeID = "future_diamond"
        profile.outfitItemID = "future_outfit"
        profile.accessoryItemID = "future_hat"
        profile.shirtItemID = "future_shirt"
        let restored = try JSONDecoder().decode(ShepherdProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(restored, profile)
        XCTAssertEqual(restored.headShape, .pear)
        XCTAssertEqual(ShepherdStudyAppearance(profile: restored).outfit, .shirt)
        XCTAssertFalse(ShepherdStudyAppearance(profile: restored).hat)
    }

    func testEveryExistingWearableHasDistinctRenderingAndTakeOffRestoresAppearance() {
        let outfits = FarmShopCatalog.items(in: .shepherd).filter { $0.effect == .shepherdOutfit }
        let hats = FarmShopCatalog.items(in: .shepherd).filter { $0.effect == .shepherdAccessory }
        XCTAssertEqual(Set(outfits.map { item in
            var profile = ShepherdProfile.defaultProfile
            profile.outfitItemID = item.id
            return ShepherdStudyAppearance(profile: profile).outfit.rawValue
        }).count, outfits.count)
        for shape in ShepherdHeadShape.allCases {
            for hair in ShepherdHairStyle.allCases {
                var profile = ShepherdProfile.defaultProfile
                profile.headShape = shape
                profile.hairStyle = hair
                let bare = ShepherdStudyAppearance(profile: profile)
                for hat in hats {
                    profile.accessoryItemID = hat.id
                    XCTAssertTrue(ShepherdStudyAppearance(profile: profile).hat)
                    profile.accessoryItemID = nil
                    XCTAssertEqual(ShepherdStudyAppearance(profile: profile), bare)
                }
            }
        }
    }

    func testAllHairStylesRemainDistinctAndIndependentOfHeadShape() {
        for shape in ShepherdHeadShape.allCases {
            let rendered = ShepherdHairStyle.allCases.map { hair -> String in
                var profile = ShepherdProfile.defaultProfile
                profile.headShape = shape
                profile.hairStyle = hair
                let appearance = ShepherdStudyAppearance(profile: profile)
                XCTAssertEqual(appearance.head.rawValue, shape.rawValue)
                return appearance.hair.rawValue
            }
            XCTAssertEqual(Set(rendered).count, ShepherdHairStyle.allCases.count)
        }
    }

    func testPrivateBackupAndRestorePreserveAllHeadChoicesAndLegacyProfile() throws {
        for headID in [nil] + ShepherdHeadShape.allCases.map({ Optional($0.rawValue) }) + ["future_shape"] {
            var farm = FarmState.empty
            farm.migrateCumulativeCredit(records: [], searchState: .empty, protectedNightCount: 0)
            farm.shepherd.headShapeID = headID
            farm.shepherd.hairStyle = .long
            farm.shepherd.outfitItemID = "shepherd_moss_coat"
            farm.shepherd.accessoryItemID = "shepherd_wool_hat"
            farm.shepherd.shirtItemID = "shepherd_berry_shirt"
            farm.equipment.ollieCoatID = "fuller"
            farm.ownedShopItemIDs = ["shepherd_berry_shirt", "shepherd_moss_coat", "shepherd_wool_hat"]
            farm.woolBalance = 27
            let document = FarmSaveDocument(lineageID: UUID(), generation: 1,
                values: ["ollie.farm.state": try JSONEncoder().encode(farm)])
            let payload = try FarmBackupPayload(document: document)
            let remote = try FarmBackupPayload.decodeRemote(JSONEncoder().encode(payload))
            XCTAssertEqual(try remote.fingerprint(), try payload.fingerprint())
            let values = try remote.restoredValues(preservingLocalProgress: .empty)
            let restored = try JSONDecoder().decode(FarmState.self, from: XCTUnwrap(values["ollie.farm.state"]))
            XCTAssertEqual(restored, farm)
        }
    }
}

extension ShepherdAvatarIntegrationTests {
    func testCampfireUsesSameSafeCustomizationAndMotionCanBeStatic() {
        for head in ShepherdHeadShape.allCases {
            var presentation = CountingSheepPublicPresentation.defaultValue
            presentation.headShapeID = head.rawValue
            let profile = presentation.shepherdProfile
            XCTAssertEqual(ShepherdStudyAppearance(profile: profile).head.rawValue, head.rawValue)
        }
        for time in [0.0, 1.25, 2.5, 3.75, 5.0] {
            let lift = CampfireShepherdMotionRules.blanketLift(at: time, reduceMotion: false, isActive: true)
            XCTAssertTrue((0...1.8).contains(lift))
            XCTAssertEqual(CampfireShepherdMotionRules.blanketLift(at: time, reduceMotion: true, isActive: true), 0)
            XCTAssertEqual(CampfireShepherdMotionRules.blanketLift(at: time, reduceMotion: false, isActive: false), 0)
        }
        XCTAssertEqual(CampfireShepherdMotionRules.blanketLift(at: .infinity, reduceMotion: false, isActive: true), 0)
    }
}


extension ShepherdAvatarIntegrationTests {
    func testShirtOuterLayerAndHatAreIndependentAcrossPurchasesRemovalAndRestore() throws {
        let layers = ["shepherd_berry_shirt", "shepherd_open_moss_coat", "shepherd_wool_hat"]
        let orders = [[0,1,2], [0,2,1], [1,0,2], [1,2,0], [2,0,1], [2,1,0]]
        for order in orders {
            var farm = FarmState.empty
            farm.woolBalance = 100
            for index in order { try farm.purchase(itemID: layers[index]) }
            XCTAssertEqual(farm.woolBalance, 80)
            farm = try JSONDecoder().decode(FarmState.self, from: JSONEncoder().encode(farm))
            let wearing = ShepherdStudyAppearance(profile: farm.shepherd)
            XCTAssertTrue(wearing.berryShirt)
            XCTAssertTrue(wearing.hat)
            XCTAssertEqual(wearing.outfit, .openCoat)
            try farm.takeOffShepherdOutfit(itemID: layers[1])
            XCTAssertEqual(ShepherdStudyAppearance(profile: farm.shepherd).outfit, .shirt)
            XCTAssertTrue(ShepherdStudyAppearance(profile: farm.shepherd).berryShirt)
            XCTAssertEqual(farm.shepherd.accessoryItemID, layers[2])
            try farm.equip(itemID: layers[1])
            try farm.takeOffShepherdShirt(itemID: layers[0])
            XCTAssertFalse(ShepherdStudyAppearance(profile: farm.shepherd).berryShirt)
            XCTAssertEqual(farm.shepherd.outfitItemID, layers[1])
            try farm.equip(itemID: layers[0])
            for outfit in ["shepherd_moss_coat", "shepherd_field_overalls"] {
                try farm.purchase(itemID: outfit, qualifyingWindDowns: 25)
                XCTAssertEqual(farm.shepherd.shirtItemID, layers[0])
                XCTAssertEqual(farm.shepherd.accessoryItemID, layers[2])
                try farm.takeOffShepherdOutfit(itemID: outfit)
                XCTAssertTrue(ShepherdStudyAppearance(profile: farm.shepherd).berryShirt)
            }
            let before = farm
            XCTAssertThrowsError(try farm.wearShepherdShirt(itemID: layers[2]))
            XCTAssertThrowsError(try farm.takeOffShepherdShirt(itemID: "unowned_shirt"))
            XCTAssertThrowsError(try farm.purchase(itemID: layers[0]))
            XCTAssertEqual(farm, before)
        }
    }

    func testNewLayersKeepExistingSocialPayloadValidWithoutExportingPrivateSlot() throws {
        var profile = ShepherdProfile.defaultProfile
        profile.shirtItemID = "shepherd_berry_shirt"
        profile.outfitItemID = "shepherd_open_moss_coat"
        var presentation = CountingSheepPublicPresentation.defaultValue
        presentation.shepherdOutfitID = profile.sharedOutfitID
        XCTAssertEqual(presentation.shepherdOutfitID, "shepherd_moss_coat")
        XCTAssertTrue(presentation.isAllowlisted())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(PublicCampfireAppearance(presentation))) as? [String: Any])
        XCTAssertNil(object["shirtItemID"])
        XCTAssertEqual(profile.shirtItemID, "shepherd_berry_shirt")
        profile.outfitItemID = "future_coat"
        XCTAssertEqual(profile.sharedOutfitID, "none")
    }

    func testCuratedWardrobeAppearanceRoundTripsAndRendersInCampfire() throws {
        var presentation = CountingSheepPublicPresentation.defaultValue
        presentation.shepherdOutfitID = "shepherd_moss_coat" // older app's fallback
        presentation.shepherdShirtID = "shepherd_berry_shirt"
        presentation.shepherdOuterwearID = "shepherd_open_moss_coat"
        presentation.ollieCoatID = "fuller"
        let decoded = try JSONDecoder().decode(CountingSheepPublicPresentation.self,
            from: JSONEncoder().encode(presentation))
        XCTAssertEqual(decoded, presentation)
        XCTAssertEqual(decoded.shepherdProfile.shirtItemID, "shepherd_berry_shirt")
        XCTAssertEqual(decoded.shepherdProfile.outfitItemID, "shepherd_open_moss_coat")
        XCTAssertEqual(decoded.ollieCoatID, "fuller")
        let campfire = PublicCampfireAppearance(decoded)
        XCTAssertEqual(campfire.presentation.shepherdProfile, decoded.shepherdProfile)
        XCTAssertNil(campfire.forServer(supportsWardrobe: false).shepherdShirtID)
        XCTAssertEqual(campfire.forServer(supportsWardrobe: true).ollieCoatID, "fuller")
        presentation.shepherdShirtID = "private_id"
        XCTAssertFalse(presentation.isAllowlisted())
        XCTAssertNil(presentation.shepherdProfile.shirtItemID)
    }

    func testAllShirtsFitIndependentlyOfHatAndOpenCoat() throws {
        var farm = FarmState.empty
        farm.woolBalance = 100
        try farm.purchase(itemID: "shepherd_wool_hat")
        try farm.purchase(itemID: "shepherd_open_moss_coat")
        for (id, style) in [("shepherd_berry_shirt", ShepherdStudyShirt.berry),
                            ("shepherd_dusk_shirt", .dusk), ("shepherd_amber_shirt", .amber)] {
            try farm.purchase(itemID: id)
            XCTAssertEqual(ShepherdStudyAppearance(profile: farm.shepherd).shirt, style)
            XCTAssertEqual(farm.shepherd.outfitItemID, "shepherd_open_moss_coat")
            XCTAssertEqual(farm.shepherd.accessoryItemID, "shepherd_wool_hat")
            XCTAssertEqual(CountingSheepPublicPresentationAllowlist.shepherdShirtIDs.contains(id), true)
        }
    }
}
