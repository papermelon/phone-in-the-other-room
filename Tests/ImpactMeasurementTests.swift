import XCTest

final class ImpactMeasurementTests: XCTestCase {
    func testSleepComparisonUsesCompletedAndBaselineNights() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let samples = [
            sample(day: start, quiet: 0, completed: false, sleep: 390),
            sample(day: start.addingTimeInterval(86_400), quiet: 0, completed: false, sleep: 410),
            sample(day: start.addingTimeInterval(2 * 86_400), quiet: 50, completed: true, sleep: 440),
            sample(day: start.addingTimeInterval(3 * 86_400), quiet: 60, completed: true, sleep: 460)
        ]

        let comparison = ImpactMeasurementEngine.sleepComparison(for: samples)

        XCTAssertEqual(comparison?.baselineAverageSleepMinutes, 400)
        XCTAssertEqual(comparison?.protectedAverageSleepMinutes, 450)
        XCTAssertEqual(comparison?.differenceMinutes, 50)
        XCTAssertNotNil(comparison?.quietSleepCorrelation)
    }

    func testSleepComparisonWaitsForEnoughNightsInBothGroups() {
        let samples = [
            sample(day: Date(), quiet: 0, completed: false, sleep: 400),
            sample(day: Date().addingTimeInterval(86_400), quiet: 45, completed: true, sleep: 440)
        ]

        XCTAssertNil(ImpactMeasurementEngine.sleepComparison(for: samples))
    }

    func testImpactUploadsIncludeBaselineAndFutureNightsWithoutExactDates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let consent = Date(timeIntervalSince1970: 1_800_000_000)
        let existingID = UUID()
        let samples = [
            sample(
                day: calendar.date(byAdding: .day, value: -31, to: consent)!,
                quiet: 10,
                completed: false,
                sleep: 400
            ),
            sample(
                day: calendar.date(byAdding: .day, value: -30, to: consent)!,
                quiet: 20,
                completed: false,
                sleep: 410
            ),
            sample(
                day: calendar.date(byAdding: .day, value: 90, to: consent)!,
                quiet: 60,
                completed: true,
                sleep: 450
            )
        ]

        let records = ImpactMeasurementEngine.uploadRecords(
            for: samples,
            consentedAt: consent,
            existingIDs: [-30: existingID],
            appVersion: "1.0",
            calendar: calendar
        )

        XCTAssertEqual(records.map(\.relativeNight).sorted(), [-30, 90])
        XCTAssertEqual(records.first(where: { $0.relativeNight == -30 })?.id, existingID)
        XCTAssertEqual(records.first(where: { $0.relativeNight == 90 })?.sleepMinutes, 450)
    }

    private func sample(
        day: Date,
        quiet: Int,
        completed: Bool,
        sleep: Int
    ) -> NightImpactSample {
        NightImpactSample(
            nightEndingDate: day,
            plannedQuietMinutes: completed ? 60 : 0,
            quietMinutes: quiet,
            completedRitual: completed,
            startMethod: completed ? .honorTimer : nil,
            shieldEvidence: .notRequested,
            sleepMinutes: sleep,
            coreSleepMinutes: nil,
            deepSleepMinutes: nil,
            remSleepMinutes: nil,
            restfulness: nil
        )
    }
}
