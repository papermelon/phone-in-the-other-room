import XCTest

final class WindDownStartContextTests: XCTestCase {
    func testMissingSourceAndPracticeIDsDoNotMarkAnOrdinaryStartAsPractice() {
        XCTAssertFalse(
            WindDownStartContext.isPracticeOccurrence(
                sourceID: nil,
                practicePeriodID: nil
            )
        )
    }

    func testPracticeOccurrenceRequiresMatchingNonNilIDs() {
        let practiceID = UUID()

        XCTAssertTrue(
            WindDownStartContext.isPracticeOccurrence(
                sourceID: practiceID,
                practicePeriodID: practiceID
            )
        )
        XCTAssertFalse(
            WindDownStartContext.isPracticeOccurrence(
                sourceID: UUID(),
                practicePeriodID: practiceID
            )
        )
    }

    func testPracticeUsesPersistedPeriodIdentityInsteadOfTitle() {
        let practiceID = UUID()
        let interval = DateInterval(start: Date(), duration: 5 * 60)
        let occurrence = WindDownOccurrence(
            id: practiceID,
            routineID: practiceID,
            role: .additionalQuiet,
            interval: interval
        )
        let period = WindDownSchedulePeriod(
            occurrence: occurrence,
            title: "Anything the person chose",
            recurring: false
        )

        let context = WindDownStartContext(period: period, practicePeriodID: practiceID)

        XCTAssertEqual(context.kind, .practice)
        XCTAssertEqual(context.durationMinutes, 5)
        XCTAssertTrue(context.isAdditionalQuiet)
    }

    func testAdditionalQuietDistinguishesOneTimeAndRepeatingPeriods() {
        let interval = DateInterval(start: Date(), duration: 20 * 60)
        let routineID = UUID()
        let occurrence = WindDownOccurrence(
            routineID: routineID,
            role: .additionalQuiet,
            interval: interval
        )

        let oneTime = WindDownStartContext(
            period: WindDownSchedulePeriod(
                occurrence: occurrence,
                title: "Reading quiet",
                recurring: false
            ),
            practicePeriodID: nil
        )
        let repeating = WindDownStartContext(
            period: WindDownSchedulePeriod(
                occurrence: occurrence,
                title: "Reading quiet",
                recurring: true
            ),
            practicePeriodID: nil
        )

        XCTAssertEqual(oneTime.kind, .oneTimeQuiet)
        XCTAssertEqual(repeating.kind, .repeatingQuiet)
    }

    func testLegacyRunDefaultsToRequestingShielding() throws {
        let run = FocusRun(
            plannedDurationSeconds: 300,
            appShieldingRequested: false
        )
        let encoded = try JSONEncoder().encode(run)
        let decoded = try JSONDecoder().decode(FocusRun.self, from: encoded)
        XCTAssertFalse(decoded.appShieldingRequested)

        let legacy = Data(#"{"plannedDurationSeconds":300}"#.utf8)
        let decodedLegacy = try JSONDecoder().decode(FocusRun.self, from: legacy)
        XCTAssertTrue(decodedLegacy.appShieldingRequested)
    }
}
