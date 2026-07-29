import XCTest

final class ProximityClassifierTests: XCTestCase {
    func testShieldingOnlyAppliesToQuietBookends() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan(
            intendedBedtime: start.addingTimeInterval(30 * 60),
            wakeTime: start.addingTimeInterval(8 * 60 * 60),
            protectedUntil: start.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .stretch
        )
        var run = FocusRun(
            plannedDurationSeconds: 8.5 * 60 * 60,
            startedAt: start,
            state: .running,
            guardKind: .honorTimer,
            nightWatchPlan: plan
        )
        XCTAssertTrue(QuietTimeShieldingPolicy.shouldShield(
            run: run, at: start.addingTimeInterval(5 * 60), isEnabled: true
        ))
        XCTAssertFalse(QuietTimeShieldingPolicy.shouldShield(
            run: run, at: start.addingTimeInterval(4 * 60 * 60), isEnabled: true
        ))
        XCTAssertTrue(QuietTimeShieldingPolicy.shouldShield(
            run: run, at: start.addingTimeInterval(8.25 * 60 * 60), isEnabled: true
        ))
        run.state = .endedEarly
        XCTAssertFalse(QuietTimeShieldingPolicy.shouldShield(
            run: run, at: start.addingTimeInterval(5 * 60), isEnabled: true
        ))
    }
    func testScreenTimeSharedStorageUsesStableAppGroupAndOllieKeys() {
        XCTAssertEqual(
            ScreenTimeSharedStorage.appGroupIdentifier,
            "group.com.ngawangchime.countingsheep"
        )
        XCTAssertEqual(
            ScreenTimeSharedStorage.selectionKey(for: .bedtime),
            "ollie.screenTime.selection.bedtime"
        )
        XCTAssertEqual(
            ScreenTimeSharedStorage.legacySelectionKey(for: .bedtime),
            "phoneOther.screenTime.selection.bedtime"
        )
    }

    func testScreenTimeReportDefaultsAreIndependentValuesDerivedFromQuietTime() {
        var quietTime = NightWatchPreferences.defaults
        quietTime.bedtimeHour = 23
        quietTime.bedtimeMinute = 0
        quietTime.wakeHour = 7
        quietTime.wakeMinute = 15
        quietTime.morningQuietMinutes = 30

        var report = ScreenTimeReportPreferences.defaults(for: quietTime)
        report.setMinute(18 * 60, for: .evening, isStart: true)
        quietTime.windDownMinutes = 90

        XCTAssertEqual(report.eveningStartMinute, 18 * 60)
        XCTAssertEqual(report.eveningEndMinute, 23 * 60)
        XCTAssertEqual(report.morningStartMinute, 7 * 60 + 15)
        XCTAssertEqual(report.morningEndMinute, 7 * 60 + 45)
    }

    func testScreenTimeReportIntervalCanCrossMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 26, hour: 7)
        )!
        let report = ScreenTimeReportPreferences(
            eveningStartMinute: 22 * 60,
            eveningEndMinute: 1 * 60,
            morningStartMinute: 7 * 60,
            morningEndMinute: 9 * 60
        )

        let interval = report.latestInterval(for: .evening, now: now, calendar: calendar)

        XCTAssertEqual(calendar.component(.hour, from: interval.start), 22)
        XCTAssertEqual(calendar.component(.hour, from: interval.end), 1)
        XCTAssertEqual(interval.duration, 3 * 60 * 60)
    }

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
        var run = FocusRun(plannedDurationSeconds: 25 * 60, startedAt: startedAt, guardKind: .watchPlacement)
        run.endedAt = startedAt.addingTimeInterval(run.plannedDurationSeconds)

        XCTAssertFalse(FocusRunRules.canCompleteSuccessfully(run, demoMode: false))
        XCTAssertTrue(FocusRunRules.canCompleteSuccessfully(run, demoMode: true))

        run.phoneAwayValidatedAt = startedAt.addingTimeInterval(30)
        run.placementStatus = .confirmed
        XCTAssertTrue(FocusRunRules.canCompleteSuccessfully(run, demoMode: false))
    }

    func testPhoneAwayTimerCompletesWithoutWatchEvidence() {
        let run = FocusRun(plannedDurationSeconds: 25 * 60, guardKind: .honorTimer)

        XCTAssertTrue(FocusRunRules.canCompleteSuccessfully(run, demoMode: false))
    }

    func testQRCodeGuardNeedsPlacementConfirmation() {
        var run = FocusRun(plannedDurationSeconds: 25 * 60, guardKind: .qrCode)
        XCTAssertFalse(FocusRunRules.canCompleteSuccessfully(run, demoMode: false))

        run.placementStatus = .confirmed
        run.placementEvidence = PlacementEvidence(guardKind: .qrCode, confirmedAt: Date(), note: "Test phone bed")
        XCTAssertTrue(FocusRunRules.canCompleteSuccessfully(run, demoMode: false))
    }

    func testUnavailableWatchPlacementStillCompletesAsATimer() {
        var run = FocusRun(plannedDurationSeconds: 25 * 60, guardKind: .watchPlacement)
        run.placementStatus = .unavailable

        XCTAssertTrue(FocusRunRules.canCompleteSuccessfully(run, demoMode: false))
    }

    func testLegacyFocusRunDecodesAsWatchPlacement() throws {
        let data = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "plannedDurationSeconds": 1500,
          "startedAt": 1000,
          "state": "running",
          "proximityHistory": [],
          "warningCount": 0,
          "completedSuccessfully": false,
          "earnedRewardIDs": []
        }
        """.data(using: .utf8)!

        let run = try JSONDecoder().decode(FocusRun.self, from: data)
        XCTAssertEqual(run.guardKind, .watchPlacement)
        XCTAssertEqual(run.placementStatus, .awaitingConfirmation)
        XCTAssertNil(run.nightWatchPlan)
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

    func testScreenTimeBucketsAggregateMatchingHoursAndUseHourCapacity() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(60 * 60)
        let buckets = ScreenTimeReportMath.aggregate([
            ScreenTimeActivityBucket(
                startDate: start,
                endDate: end,
                selectedAppDuration: 10 * 60
            ),
            ScreenTimeActivityBucket(
                startDate: start,
                endDate: end,
                selectedAppDuration: 20 * 60
            )
        ])

        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets.first?.selectedAppDuration, 30 * 60)
        XCTAssertEqual(buckets[0].fillFraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(ScreenTimeReportMath.selectedAppPercentage(for: buckets), 50)
    }

    func testScreenTimeHourlyBucketsKeepQuietHoursVisible() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let interval = DateInterval(
            start: start,
            end: start.addingTimeInterval(3 * 60 * 60)
        )
        let samples = [
            ScreenTimeActivityBucket(
                startDate: start.addingTimeInterval(60 * 60),
                endDate: start.addingTimeInterval(2 * 60 * 60),
                selectedAppDuration: 15 * 60
            )
        ]

        let buckets = ScreenTimeReportMath.hourlyBuckets(
            in: interval,
            from: samples
        )

        XCTAssertEqual(buckets.count, 3)
        XCTAssertEqual(buckets[0].selectedAppDuration, 0)
        XCTAssertEqual(buckets[1].selectedAppDuration, 15 * 60)
        XCTAssertEqual(buckets[2].selectedAppDuration, 0)
        XCTAssertEqual(ScreenTimeReportMath.selectedAppPercentage(for: buckets), 8)
    }

    func testSleepSummaryKeepsItsNightEndingDate() {
        let nightEndingDate = Date(timeIntervalSince1970: 1_800_000_000)
        let sleepStart = nightEndingDate.addingTimeInterval(-7 * 60 * 60)
        let summary = SleepIntervalMath.summary(
            for: [
                DateInterval(
                    start: sleepStart,
                    end: nightEndingDate
                )
            ],
            nightEndingDate: nightEndingDate
        )

        XCTAssertEqual(summary?.nightEndingDate, nightEndingDate)
    }

    func testWakeTimeRangeHandlesTimesAcrossMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 27)
        )!
        let summaries = [
            SleepSummary(
                durationSeconds: 7 * 60 * 60,
                startDate: nil,
                endDate: calendar.date(byAdding: .minute, value: 23 * 60 + 50, to: day)
            ),
            SleepSummary(
                durationSeconds: 7 * 60 * 60,
                startDate: nil,
                endDate: calendar.date(byAdding: .day, value: 1, to: day)
            ),
            SleepSummary(
                durationSeconds: 7 * 60 * 60,
                startDate: nil,
                endDate: calendar.date(byAdding: .minute, value: 10, to: day)
            )
        ]

        let range = SleepIntervalMath.wakeTimeRange(for: summaries, calendar: calendar)

        XCTAssertEqual(range, WakeTimeRange(sampleCount: 3, minutes: 20))
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

        let correlation = FocusAnalyticsEngine.correlations(for: records).first { $0.title == "Quiet Bookends vs Screen Time" }
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

        let correlation = FocusAnalyticsEngine.correlations(for: records).first { $0.title == "Quiet Bookends vs Screen Time" }
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

        let correlation = FocusAnalyticsEngine.correlations(for: records).first { $0.title == "Quiet Bookends vs Screen Time" }
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
