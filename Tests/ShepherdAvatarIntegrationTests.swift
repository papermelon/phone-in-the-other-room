import XCTest

final class ShepherdAvatarIntegrationTests: XCTestCase {
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

}
