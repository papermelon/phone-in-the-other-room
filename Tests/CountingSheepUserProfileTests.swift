import XCTest

final class CountingSheepUserProfileTests: XCTestCase {
    func testDisplayNameNormalizesVisibleCharactersAndRejectsUnsafeCharacters() {
        XCTAssertEqual(try? CountingSheepDisplayName.validate("  Åna\n  D’Lune-2 ").get(), "Åna D’Lune-2")
        XCTAssertEqual(CountingSheepDisplayName.validate("A"), .failure(.tooShort))
        XCTAssertEqual(CountingSheepDisplayName.validate("Moss!"), .failure(.unsupportedCharacter))
        XCTAssertEqual(CountingSheepDisplayName.validate(String(repeating: "a", count: 25)), .failure(.tooLong))
    }

    func testInitialAndMigrationNameAreFreeWhileNoOpDoesNotSpendChange() {
        let profile = CountingSheepUserProfile(displayName: "", hasEstablishedDisplayName: false)
        let initial = CountingSheepDisplayNameChangeRules.decision(current: profile, proposedName: "  Clover  ", now: Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(initial, .accepted(normalizedName: "Clover", recordChangeAt: nil))
        let established = CountingSheepDisplayNameChangeRules.applying(initial, to: profile)
        XCTAssertTrue(established.successfulDisplayNameChangeDates.isEmpty)
        XCTAssertEqual(CountingSheepDisplayNameChangeRules.decision(current: established, proposedName: "Clover", now: Date()), .noChange(normalizedName: "Clover"))
    }

    func testTwoChangesAreLimitedInRollingFourteenDaysAndAgeOut() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        var profile = CountingSheepUserProfile(displayName: "Moss", hasEstablishedDisplayName: true)
        for name in ["Clover", "Juniper"] {
            let decision = CountingSheepDisplayNameChangeRules.decision(current: profile, proposedName: name, now: now)
            profile = CountingSheepDisplayNameChangeRules.applying(decision, to: profile)
        }
        XCTAssertEqual(CountingSheepDisplayNameChangeRules.decision(current: profile, proposedName: "Hazel", now: now), .changeLimitReached)
        let afterWindow = now.addingTimeInterval(14 * 24 * 60 * 60 + 1)
        XCTAssertEqual(CountingSheepDisplayNameChangeRules.decision(current: profile, proposedName: "Hazel", now: afterWindow), .accepted(normalizedName: "Hazel", recordChangeAt: afterWindow))
    }

    func testConditionalRevisionMakesStaleNameChangeRaceVisibleToServer() {
        let current = CountingSheepUserProfile(displayName: "Moss", revision: 7, hasEstablishedDisplayName: true)
        XCTAssertTrue(CountingSheepUserProfileRevisionRules.canApply(expectedRevision: 7, to: current))
        XCTAssertFalse(CountingSheepUserProfileRevisionRules.canApply(expectedRevision: 6, to: current))
        let now = Date(timeIntervalSince1970: 1_000)
        let left = CountingSheepDisplayNameChangeRules.decision(current: current, proposedName: "Clover", now: now)
        let right = CountingSheepDisplayNameChangeRules.decision(current: current, proposedName: "Juniper", now: now)
        guard case let .accepted(leftName, leftDate?) = left,
              case let .accepted(rightName, rightDate?) = right else {
            return XCTFail("Both stale local proposals should require server revision arbitration")
        }
        XCTAssertEqual(leftName, "Clover")
        XCTAssertEqual(rightName, "Juniper")
        XCTAssertEqual(leftDate, now)
        XCTAssertEqual(rightDate, now)
    }

    func testProfileLegacyAndUnknownPresentationDecodeSafely() throws {
        let legacy = try JSONDecoder().decode(CountingSheepUserProfile.self, from: Data(#"{"displayName":"Moss"}"#.utf8))
        XCTAssertEqual(legacy.displayName, "Moss")
        XCTAssertEqual(legacy.presentation, .defaultValue)
        XCTAssertFalse(legacy.hasEstablishedDisplayName)

        let unknown = try JSONDecoder().decode(CountingSheepPublicPresentation.self, from: Data(#"{"skinToneID":"not-owned","hairStyleID":"waves","shepherdOutfitID":"none","shepherdAccessoryID":"none","ollieOrnamentID":"none","featuredSheepDefinitionID":"none","pastureThemeID":"pasture_meadow","future":"ignored"}"#.utf8))
        XCTAssertFalse(unknown.isAllowlisted())
    }

    func testPresentationUsesSplitCatalogIdentifiersAndNoneSentinel() {
        XCTAssertTrue(CountingSheepPublicPresentation.defaultValue.isAllowlisted())
        XCTAssertTrue(CountingSheepPublicPresentationAllowlist.shepherdOutfitIDs.contains("none"))
        XCTAssertTrue(CountingSheepPublicPresentationAllowlist.featuredSheepDefinitionIDs.contains("none"))
        XCTAssertTrue(CountingSheepPublicPresentationAllowlist.skinToneIDs.contains(ShepherdSkinTone.deep.rawValue))
        XCTAssertTrue(CountingSheepPublicPresentationAllowlist.hairStyleIDs.contains(ShepherdHairStyle.coils.rawValue))
    }
}
