import XCTest

final class NotificationCopyTests: XCTestCase {
    func testLegacyNotificationPreferencesDecodeWithoutOverrides() throws {
        let data = Data(#"{"remindersEnabled":true,"cadence":"quiet"}"#.utf8)
        let decoded = try JSONDecoder().decode(NotificationPreferences.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, NotificationPreferences.currentSchemaVersion)
        XCTAssertTrue(decoded.copyOverrides.isEmpty)
    }

    func testPlaceholdersRenderAndUnknownTokensAreReported() {
        let context = NotificationCopyContext(
            activityTitle: "Read a book",
            purpose: "a personal project",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            minutes: 30
        )

        XCTAssertEqual(
            NotificationCopyRenderer.render(
                "{activity} · {purpose} · {minutes} · {time}",
                context: context
            ).contains("Read a book"),
            true
        )
        XCTAssertEqual(
            NotificationCopyRenderer.unresolvedPlaceholders(in: "Hello {unknown}"),
            ["{unknown}"]
        )
    }

    func testEditableOverrideReplacesBothTitleAndBody() {
        let copy = NotificationCopyResolver.resolve(
            id: .windDownStart,
            moment: .windDownReminder,
            context: NotificationCopyContext(
                activityTitle: "Read",
                date: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            overrides: [
                NotificationCopyOverride(
                    id: .windDownStart,
                    title: "My quiet starts",
                    body: "{activity} is waiting for me."
                )
            ]
        )

        XCTAssertEqual(copy.title, "My quiet starts")
        XCTAssertEqual(copy.body, "Read is waiting for me.")
    }

    func testFixedShieldingCopyIgnoresOverrides() {
        let copy = NotificationCopyResolver.resolve(
            id: .shieldingFailed,
            moment: .shieldingFailed,
            context: .empty,
            overrides: [
                NotificationCopyOverride(
                    id: .shieldingFailed,
                    title: "A different title",
                    body: "A different body"
                )
            ]
        )

        XCTAssertEqual(copy.title, "A quick protection note")
        XCTAssertFalse(copy.body.contains("A different body"))
    }

    func testCopyOverrideRoundTripsAndCanBeReset() throws {
        var preferences = NotificationPreferences.defaults
        preferences.setCopyOverride(
            NotificationCopyOverride(id: .complete, title: "Wake", body: "The phone can wake.")
        )
        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(NotificationPreferences.self, from: data)

        XCTAssertEqual(decoded.copyOverride(for: .complete)?.title, "Wake")
        var reset = decoded
        reset.resetCopy(for: .complete)
        XCTAssertNil(reset.copyOverride(for: .complete))
    }
}
