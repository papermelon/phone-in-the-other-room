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

    func testLegacyPresentationDefaultsAvatarToShepherdWithoutErasingUnknownWireValue() throws {
        let legacy = try JSONDecoder().decode(
            CountingSheepPublicPresentation.self,
            from: Data(#"{"skinToneID":"warm","hairStyleID":"waves","shepherdOutfitID":"none","shepherdAccessoryID":"none","ollieOrnamentID":"none","featuredSheepDefinitionID":"none","pastureThemeID":"pasture_meadow"}"#.utf8)
        )
        XCTAssertEqual(legacy.avatarID, SocialAvatarRules.shepherdID)

        let future = try JSONDecoder().decode(
            CountingSheepPublicPresentation.self,
            from: Data(#"{"skinToneID":"warm","hairStyleID":"waves","shepherdOutfitID":"none","shepherdAccessoryID":"none","ollieOrnamentID":"none","featuredSheepDefinitionID":"none","pastureThemeID":"pasture_meadow","avatarID":"future:character"}"#.utf8)
        )
        XCTAssertEqual(future.avatarID, "future:character")
        XCTAssertFalse(SocialAvatarRules.isKnownWireAvatar(future.avatarID))
    }

    func testOnlyDiscoveredSheepCanBeChosenAndTheirIdentitySurvivesActiveFlockChanges() {
        let discovery = SheepDiscoveryRecord(
            definitionID: "juniper",
            firstDiscoveredAt: Date(timeIntervalSince1970: 1),
            encounterCount: 1,
            outcomeIDs: [],
            highestRarity: .rare
        )
        let available = SocialAvatarRules.availableAvatarIDs(discoveries: [discovery])
        XCTAssertEqual(available, ["shepherd", "ollie", "sheep:juniper"])
        XCTAssertTrue(SocialAvatarRules.canSelect("sheep:juniper", discoveries: [discovery]))
        XCTAssertFalse(SocialAvatarRules.canSelect("sheep:mabel", discoveries: [discovery]))
        // Availability uses discovery records, so removing Juniper from the
        // active flock does not alter this explicit social identity.
        XCTAssertTrue(SocialAvatarRules.canSelect("sheep:juniper", discoveries: [discovery]))
    }

    func testFreshRecoveryAdoptsSupportedServerAvatarButLegacyRefreshPreservesExplicitChoice() {
        XCTAssertEqual(
            SocialAvatarAdoptionRules.resolvedAvatarID(
                localAvatarID: SocialAvatarRules.shepherdID,
                hasExplicitLocalSelection: false,
                serverAvatarID: SocialAvatarRules.ollieID,
                serverSupportsAvatars: true
            ),
            SocialAvatarRules.ollieID
        )
        XCTAssertEqual(
            SocialAvatarAdoptionRules.resolvedAvatarID(
                localAvatarID: "sheep:juniper",
                hasExplicitLocalSelection: true,
                serverAvatarID: SocialAvatarRules.shepherdID,
                serverSupportsAvatars: false
            ),
            "sheep:juniper"
        )
    }

    func testPresentationUsesSplitCatalogIdentifiersAndNoneSentinel() {
        XCTAssertTrue(CountingSheepPublicPresentation.defaultValue.isAllowlisted())
        XCTAssertTrue(CountingSheepPublicPresentationAllowlist.shepherdOutfitIDs.contains("none"))
        XCTAssertTrue(CountingSheepPublicPresentationAllowlist.featuredSheepDefinitionIDs.contains("none"))
        XCTAssertTrue(CountingSheepPublicPresentationAllowlist.skinToneIDs.contains(ShepherdSkinTone.deep.rawValue))
        XCTAssertTrue(CountingSheepPublicPresentationAllowlist.hairStyleIDs.contains(ShepherdHairStyle.coils.rawValue))
    }
}
