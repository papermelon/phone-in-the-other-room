import XCTest

final class ProximityClassifierTests: XCTestCase {
    func testSustainedOtherRoomValidatesOnlyAfterRequiredSamples() {
        let classifier = ProximityClassifier()
        let now = Date()
        let readings = [
            ProximityReading(distanceMeters: 8.4, timestamp: now, source: .nearbyInteraction),
            ProximityReading(distanceMeters: 8.7, timestamp: now, source: .nearbyInteraction)
        ]
        let context = ProximityClassifierContext(now: now, watchReachable: true, nearbySupported: true, demoMode: false, currentRunState: .waitingForPhoneAway, plannedEndAt: nil, phoneAwayValidated: false)
        let state = classifier.classify(readings: readings, previous: nil, context: context)
        XCTAssertEqual(state.bucket, .doorway)

        let sustained = readings + [ProximityReading(distanceMeters: 9.1, timestamp: now, source: .nearbyInteraction)]
        let sustainedState = classifier.classify(readings: sustained, previous: state, context: context)
        XCTAssertEqual(sustainedState.bucket, .probablyOtherRoom)
        XCTAssertTrue(classifier.shouldValidatePhoneAway(readings: sustained, state: sustainedState))
    }

    func testOneNoisyCloseReadingDoesNotWarn() {
        let classifier = ProximityClassifier()
        let now = Date()
        let readings = [
            ProximityReading(distanceMeters: 8.8, timestamp: now, source: .nearbyInteraction),
            ProximityReading(distanceMeters: 9.0, timestamp: now, source: .nearbyInteraction),
            ProximityReading(distanceMeters: 1.2, timestamp: now, source: .nearbyInteraction)
        ]
        let state = ProximityState(bucket: .sameRoom, distanceMeters: 1.2, confidence: .medium, source: .nearbyInteraction, lastUpdated: now, statusText: "", detailText: "")
        XCTAssertFalse(classifier.shouldWarnPhoneTooClose(readings: readings, state: state))
    }

    func testDemoModeUsesMediumConfidence() {
        let classifier = ProximityClassifier()
        let now = Date()
        let reading = ProximityReading(distanceMeters: 9.5, timestamp: now, source: .demo)
        let context = ProximityClassifierContext(now: now, watchReachable: false, nearbySupported: false, demoMode: true, currentRunState: .demo, plannedEndAt: nil, phoneAwayValidated: false)
        let state = classifier.classify(readings: [reading], previous: nil, context: context)
        XCTAssertEqual(state.bucket, .demo)
        XCTAssertEqual(state.confidence, .medium)
    }

    func testSupportedSessionWithoutDistanceWaitsInsteadOfUnsupported() {
        let classifier = ProximityClassifier()
        let now = Date()
        let context = ProximityClassifierContext(now: now, watchReachable: true, nearbySupported: true, demoMode: false, currentRunState: .placementGrace, plannedEndAt: nil, phoneAwayValidated: false)
        let state = classifier.classify(readings: [], previous: nil, context: context)
        XCTAssertEqual(state.bucket, .waitingForDistance)
        XCTAssertEqual(state.confidence, .low)
    }

    func testCompletedRunAddsDailyFocusStars() {
        var run = FocusRun(plannedDurationSeconds: 31 * 60)
        run.state = .completed
        run.completedSuccessfully = true
        run.endedAt = Date()

        let progress = RewardEngine().updatedProgress(after: run, current: .empty, reward: nil)

        XCTAssertEqual(progress.todayRecord.completedFocusMinutes, 31)
        XCTAssertEqual(progress.todayRecord.successfulRuns, 1)
        XCTAssertEqual(progress.todayRecord.earnedStars, [.silver, .gold])
        XCTAssertEqual(progress.totalFocusStars, 2)
        XCTAssertEqual(progress.sheepBalance, 2)
        XCTAssertEqual(progress.coinBalance, 10)
    }

    func testLegacyProgressDecodesWithoutDailyRecords() throws {
        let data = """
        {
          "totalCompletedRuns": 2,
          "totalFocusMinutes": 50,
          "currentStreak": 1,
          "longestStreak": 2,
          "rewardsCollected": 2,
          "ollieLevel": 1
        }
        """.data(using: .utf8)!

        let progress = try JSONDecoder().decode(UserProgress.self, from: data)

        XCTAssertEqual(progress.totalCompletedRuns, 2)
        XCTAssertEqual(progress.dailyFocusRecords, [])
        XCTAssertEqual(progress.todayRecord.completedFocusMinutes, 0)
        XCTAssertEqual(progress.sheepBalance, 0)
        XCTAssertEqual(progress.coinBalance, 0)
    }

    func testRunCannotCompleteWithoutPhoneAwayValidationOutsideDemoMode() {
        let startedAt = Date()
        var run = FocusRun(plannedDurationSeconds: 25 * 60, startedAt: startedAt)
        run.endedAt = startedAt.addingTimeInterval(run.plannedDurationSeconds)

        XCTAssertFalse(FocusRunRules.canCompleteSuccessfully(run, demoMode: false))
        XCTAssertTrue(FocusRunRules.canCompleteSuccessfully(run, demoMode: true))

        run.phoneAwayValidatedAt = startedAt.addingTimeInterval(30)
        XCTAssertTrue(FocusRunRules.canCompleteSuccessfully(run, demoMode: false))
    }

    func testRealtimeWatchMessageRequiresMatchingRunAndFreshSentAt() {
        let now = Date()
        let currentRun = FocusRun(plannedDurationSeconds: 25 * 60, startedAt: now)
        let fresh = WatchMessage(type: .watchDistanceReading, run: currentRun, distanceMeters: 8.2, sentAt: now.addingTimeInterval(-2))
        XCTAssertTrue(fresh.isFreshRealtimeMessage(for: currentRun, now: now))

        let old = WatchMessage(type: .watchDistanceReading, run: currentRun, distanceMeters: 8.2, sentAt: now.addingTimeInterval(-60))
        XCTAssertFalse(old.isFreshRealtimeMessage(for: currentRun, now: now))

        let otherRun = FocusRun(plannedDurationSeconds: 25 * 60, startedAt: now)
        let wrongRun = WatchMessage(type: .watchDistanceReading, run: otherRun, distanceMeters: 8.2, sentAt: now)
        XCTAssertFalse(wrongRun.isFreshRealtimeMessage(for: currentRun, now: now))
    }

    func testSleepSummaryMergesOverlappingIntervals() {
        let start = Date(timeIntervalSince1970: 1_800)
        let intervals = [
            DateInterval(start: start, end: start.addingTimeInterval(60 * 60)),
            DateInterval(start: start.addingTimeInterval(30 * 60), end: start.addingTimeInterval(90 * 60)),
            DateInterval(start: start.addingTimeInterval(120 * 60), end: start.addingTimeInterval(150 * 60))
        ]

        let summary = SleepIntervalMath.summary(for: intervals)

        XCTAssertEqual(summary?.durationSeconds, 120 * 60)
        XCTAssertEqual(summary?.startDate, start)
        XCTAssertEqual(summary?.endDate, start.addingTimeInterval(150 * 60))
    }

    func testAnalyticsRecordsMergeFocusHistoryWithPlaceholders() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = Date(timeIntervalSince1970: 86_400 * 10)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var progress = UserProgress.empty
        progress.recordCompletedRun(minutes: 30, warnings: 1, rewardEarned: true, at: yesterday, calendar: calendar)

        let records = FocusAnalyticsEngine.dayRecords(
            progress: progress,
            days: 2,
            endingAt: today,
            screenTimePlaceholders: [calendar.startOfDay(for: yesterday): 210],
            sleepPlaceholders: [calendar.startOfDay(for: yesterday): 430],
            calendar: calendar
        )

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.first?.focusMinutes, 30)
        XCTAssertEqual(records.first?.screenTimeMinutes, 210)
        XCTAssertEqual(records.first?.screenTimeSource, .screenTimePlaceholder)
        XCTAssertEqual(records.first?.sleepMinutes, 430)
        XCTAssertEqual(records.first?.sleepSource, .healthPlaceholder)
    }

    func testManualAnalyticsEntriesOverridePlaceholders() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 86_400 * 10))

        let records = FocusAnalyticsEngine.dayRecords(
            progress: .empty,
            days: 1,
            endingAt: today,
            manualEntries: [ManualAnalyticsEntry(day: today, screenTimeMinutes: 180, sleepMinutes: 460, calendar: calendar)],
            screenTimePlaceholders: [today: 240],
            sleepPlaceholders: [today: 390],
            calendar: calendar
        )

        XCTAssertEqual(records.first?.screenTimeMinutes, 180)
        XCTAssertEqual(records.first?.screenTimeSource, .manual)
        XCTAssertEqual(records.first?.sleepMinutes, 460)
        XCTAssertEqual(records.first?.sleepSource, .manual)
    }

    func testManualAnalyticsEntriesIncludeSocialAndBedtimeScreenTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 86_400 * 10))

        let records = FocusAnalyticsEngine.dayRecords(
            progress: .empty,
            days: 1,
            endingAt: today,
            manualEntries: [
                ManualAnalyticsEntry(
                    day: today,
                    screenTimeMinutes: 300,
                    socialScreenTimeMinutes: 95,
                    bedtimeScreenTimeMinutes: 45,
                    sleepMinutes: 420,
                    calendar: calendar
                )
            ],
            calendar: calendar
        )

        XCTAssertEqual(records.first?.socialScreenTimeMinutes, 95)
        XCTAssertEqual(records.first?.socialScreenTimeSource, .manual)
        XCTAssertEqual(records.first?.bedtimeScreenTimeMinutes, 45)
        XCTAssertEqual(records.first?.bedtimeScreenTimeSource, .manual)
    }

    func testAnalyticsCorrelationNeedsThreePairedSamples() {
        let day = Date(timeIntervalSince1970: 0)
        let records = [
            AnalyticsDayRecord(day: day, focusMinutes: 10, screenTimeMinutes: 300),
            AnalyticsDayRecord(day: day.addingTimeInterval(86_400), focusMinutes: 20, screenTimeMinutes: 240)
        ]

        let correlation = FocusAnalyticsEngine.correlations(for: records).first { $0.title == "Focus vs Screen Time" }
        XCTAssertNil(correlation?.coefficient)
        XCTAssertEqual(correlation?.sampleSize, 2)
    }

    func testAnalyticsCorrelationDetectsNegativeRelationship() {
        let day = Date(timeIntervalSince1970: 0)
        let records = [
            AnalyticsDayRecord(day: day, focusMinutes: 10, screenTimeMinutes: 300),
            AnalyticsDayRecord(day: day.addingTimeInterval(86_400), focusMinutes: 20, screenTimeMinutes: 240),
            AnalyticsDayRecord(day: day.addingTimeInterval(86_400 * 2), focusMinutes: 30, screenTimeMinutes: 180),
            AnalyticsDayRecord(day: day.addingTimeInterval(86_400 * 3), focusMinutes: 40, screenTimeMinutes: 120)
        ]

        let correlation = FocusAnalyticsEngine.correlations(for: records).first { $0.title == "Focus vs Screen Time" }
        XCTAssertEqual(correlation?.sampleSize, 4)
        XCTAssertEqual(correlation?.coefficient ?? 0, -1, accuracy: 0.0001)
    }

    func testAnalyticsCorrelationHandlesZeroVariance() {
        let day = Date(timeIntervalSince1970: 0)
        let records = [
            AnalyticsDayRecord(day: day, focusMinutes: 20, screenTimeMinutes: 200),
            AnalyticsDayRecord(day: day.addingTimeInterval(86_400), focusMinutes: 20, screenTimeMinutes: 220),
            AnalyticsDayRecord(day: day.addingTimeInterval(86_400 * 2), focusMinutes: 20, screenTimeMinutes: 240)
        ]

        let correlation = FocusAnalyticsEngine.correlations(for: records).first { $0.title == "Focus vs Screen Time" }
        XCTAssertNil(correlation?.coefficient)
        XCTAssertEqual(correlation?.strengthLabel, "Needs data")
    }

    func testAnalyticsCSVExportIncludesSourceColumns() {
        let record = AnalyticsDayRecord(
            day: Date(timeIntervalSince1970: 0),
            focusMinutes: 25,
            successfulRuns: 1,
            warnings: 0,
            rewardsEarned: 1,
            screenTimeMinutes: 220,
            sleepMinutes: 420,
            screenTimeSource: .screenTimePlaceholder,
            sleepSource: .healthPlaceholder
        )

        let csv = FocusAnalyticsEngine.csvString(for: [record])

        XCTAssertTrue(csv.contains("screen_time_source"))
        XCTAssertTrue(csv.contains("social_screen_time_minutes"))
        XCTAssertTrue(csv.contains("bedtime_screen_time_minutes"))
        XCTAssertTrue(csv.contains("screenTimePlaceholder"))
        XCTAssertTrue(csv.contains("healthPlaceholder"))
    }

    func testAnalyticsCSVCanHideExactDates() {
        let record = AnalyticsDayRecord(
            day: Date(timeIntervalSince1970: 0),
            focusMinutes: 25,
            screenTimeMinutes: 220,
            screenTimeSource: .manual
        )

        let csv = FocusAnalyticsEngine.csvString(for: [record], privacyMode: .relativeDays)

        XCTAssertTrue(csv.contains("day_0"))
        XCTAssertFalse(csv.contains("1970-01-01"))
    }

    func testAnalyticsExportPackageStoresPrivacyMode() {
        let package = FocusAnalyticsEngine.exportPackage(records: [], privacyMode: .relativeDays)

        XCTAssertEqual(package.privacyMode, .relativeDays)
        XCTAssertEqual(package.appSchemaVersion, 2)
    }
}
