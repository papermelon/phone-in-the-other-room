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

    func testIndependentScreenFreeMorningIsExcludedFromWindDownImpactMetric() {
        let bedtime = Date(timeIntervalSince1970: 1_800_000_000)
        let primaryPlan = NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: bedtime.addingTimeInterval(8 * 60 * 60),
            protectedUntil: bedtime.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let additionalPlan = NightWatchPlan.additionalQuiet(
            start: bedtime.addingTimeInterval(-4 * 60 * 60),
            end: bedtime.addingTimeInterval(-3 * 60 * 60)
        )
        let primary = NightWatchRecord(
            id: UUID(), plan: primaryPlan, startedAt: bedtime.addingTimeInterval(-30 * 60),
            endedAt: primaryPlan.protectedUntil, startMethod: .honorTimer, outcome: .completed,
            creditedWindDownMinutes: 30, creditedMorningQuietMinutes: 30
        )
        let additional = NightWatchRecord(
            id: UUID(), plan: additionalPlan, startedAt: additionalPlan.intendedBedtime,
            endedAt: additionalPlan.protectedUntil, startMethod: .honorTimer, outcome: .completed,
            creditedWindDownMinutes: 60, role: .additionalQuiet
        )
        let sleep = SleepSummary(
            durationSeconds: 7 * 60 * 60,
            startDate: bedtime,
            endDate: primaryPlan.wakeTime,
            nightEndingDate: primaryPlan.wakeTime
        )

        let samples = ImpactMeasurementEngine.samples(
            history: NightWatchHistory(records: [primary, additional]),
            sleeps: [sleep],
            checkIns: MorningCheckInHistory()
        )

        XCTAssertEqual(samples.count, 1)
        XCTAssertTrue(samples[0].completedRitual)
        // A new Wind Down impact row contains only its factual Wind Down
        // bookend. Screen-Free Morning is private and settles separately.
        XCTAssertEqual(samples[0].quietMinutes, 30)
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
