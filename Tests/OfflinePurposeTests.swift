import XCTest

final class OfflinePurposeTests: XCTestCase {
    func testDefaultsKeepCustomWordingOutOfNotifications() {
        let profile = OfflinePurposeProfile.defaultProfile

        XCTAssertEqual(profile.category, .rest)
        XCTAssertNil(profile.customText)
        XCTAssertFalse(profile.allowsCustomTextInNotifications)
        XCTAssertEqual(profile.inAppDisplayPhrase, "Making room for rest")
        XCTAssertEqual(profile.completionPhrase, "You made room for rest.")
        XCTAssertEqual(profile.reminderPhrase, "Make a little room for quiet.")
    }

    func testCustomTextCollapsesWhitespaceAndTrimsEmptyInput() {
        let normalized = OfflinePurposeProfile(
            category: .custom,
            customText: "  finishing\n my   watercolor  "
        )
        let empty = OfflinePurposeProfile(category: .custom, customText: " \n\t ")

        XCTAssertEqual(normalized.customText, "finishing my watercolor")
        XCTAssertNil(empty.customText)
        XCTAssertEqual(
            empty.inAppDisplayPhrase,
            "Making room for something that matters to you"
        )
    }

    func testCustomTextIsTruncatedByCharacter() {
        let input = String(repeating: "🐑", count: OfflinePurposeProfile.maximumCustomTextLength + 10)
        let profile = OfflinePurposeProfile(category: .custom, customText: input)

        XCTAssertEqual(
            profile.customText?.count,
            OfflinePurposeProfile.maximumCustomTextLength
        )
        XCTAssertEqual(profile.customText?.last, "🐑")
    }

    func testCategoryAndCustomDisplayPhrasesAreWarmAndSpecific() {
        XCTAssertEqual(
            OfflinePurposeProfile(category: .read).inAppDisplayPhrase,
            "Making room for reading"
        )
        XCTAssertEqual(
            OfflinePurposeProfile(
                category: .custom,
                customText: "my garden plan"
            ).inAppDisplayPhrase,
            "Making room for my garden plan"
        )
    }

    func testReminderUsesCustomTextOnlyAfterExplicitOptIn() {
        let privateProfile = OfflinePurposeProfile(
            category: .custom,
            customText: "my first novel"
        )
        let optedInProfile = OfflinePurposeProfile(
            category: .custom,
            customText: "my first novel",
            allowsCustomTextInNotifications: true
        )

        XCTAssertEqual(privateProfile.reminderPhrase, "Make a little room for quiet.")
        XCTAssertEqual(
            optedInProfile.reminderPhrase,
            "Make a little room for my first novel."
        )
    }

    func testProfileRoundTripsThroughJSON() throws {
        let profile = OfflinePurposeProfile(
            category: .custom,
            customText: "learning to draw",
            allowsCustomTextInNotifications: true
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(OfflinePurposeProfile.self, from: data)

        XCTAssertEqual(decoded, profile)
    }

    func testLegacyJSONDefaultsNotificationOptInToFalse() throws {
        let data = Data(#"{"category":"custom","customText":"private project"}"#.utf8)

        let decoded = try JSONDecoder().decode(OfflinePurposeProfile.self, from: data)

        XCTAssertFalse(decoded.allowsCustomTextInNotifications)
        XCTAssertEqual(decoded.reminderPhrase, "Make a little room for quiet.")
    }
}
