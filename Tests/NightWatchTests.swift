import XCTest

final class NightWatchTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testPlanSpansWindDownOvernightAndMorningQuiet() throws {
        let startedAt = try date(2026, 7, 18, 22, 30)
        let preferences = makePreferences()

        let plan = preferences.makePlan(startedAt: startedAt, calendar: calendar)

        XCTAssertEqual(plan.intendedBedtime, try date(2026, 7, 18, 23, 0))
        XCTAssertEqual(plan.wakeTime, try date(2026, 7, 19, 7, 0))
        XCTAssertEqual(plan.protectedUntil, try date(2026, 7, 19, 7, 30))
        XCTAssertEqual(plan.phase(at: try date(2026, 7, 18, 22, 45)), .windDown)
        XCTAssertEqual(plan.phase(at: try date(2026, 7, 19, 1, 0)), .overnight)
        XCTAssertEqual(plan.phase(at: try date(2026, 7, 19, 7, 15)), .morningQuiet)
        XCTAssertEqual(plan.phase(at: try date(2026, 7, 19, 7, 30)), .complete)
        XCTAssertEqual(
            plan.nextTransition(after: try date(2026, 7, 19, 1, 0)),
            try date(2026, 7, 19, 7, 0)
        )
        XCTAssertEqual(
            plan.nextTransition(after: try date(2026, 7, 19, 7, 15)),
            try date(2026, 7, 19, 7, 30)
        )
    }

    func testNewDefaultsPreferNFCAndAutomaticWindDown() {
        XCTAssertEqual(NightWatchPreferences.defaults.guardKind, .nfcTag)
        XCTAssertTrue(NightWatchPreferences.defaults.automaticStartEnabled)
    }

    func testOlderPreferencesDecodeWithAutomaticStartOff() throws {
        let data = try JSONEncoder().encode(makePreferences())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object.removeValue(forKey: "automaticStartEnabled")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(NightWatchPreferences.self, from: legacyData)

        XCTAssertFalse(decoded.automaticStartEnabled)
        XCTAssertEqual(decoded.guardKind, .honorTimer)
    }

    func testAfterMidnightStartIsTreatedAsLateTuckIn() throws {
        let startedAt = try date(2026, 7, 19, 0, 30)

        let plan = makePreferences().makePlan(startedAt: startedAt, calendar: calendar)

        XCTAssertEqual(plan.intendedBedtime, try date(2026, 7, 18, 23, 0))
        XCTAssertEqual(plan.wakeTime, try date(2026, 7, 19, 7, 0))
        XCTAssertEqual(plan.phase(at: startedAt), .overnight)
    }

    func testStartWindowOpensAtWindDownRatherThanAllDay() throws {
        let preferences = makePreferences()

        XCTAssertFalse(preferences.isStartWindowOpen(at: try date(2026, 7, 18, 8, 0), calendar: calendar))
        XCTAssertTrue(preferences.isStartWindowOpen(at: try date(2026, 7, 18, 22, 30), calendar: calendar))
        XCTAssertTrue(preferences.isStartWindowOpen(at: try date(2026, 7, 19, 0, 30), calendar: calendar))
        XCTAssertEqual(
            preferences.nextStart(after: try date(2026, 7, 19, 0, 30), calendar: calendar),
            try date(2026, 7, 19, 22, 30)
        )
    }

    func testQuietCreditExcludesOvernightHoursAndLateWindDownMinutes() throws {
        let startedAt = try date(2026, 7, 18, 22, 45)
        let plan = makePreferences().makePlan(startedAt: startedAt, calendar: calendar)

        XCTAssertEqual(plan.creditedQuietMinutes(startedAt: startedAt), 45)
        XCTAssertEqual(
            plan.creditedQuietMinutes(startedAt: startedAt, through: try date(2026, 7, 19, 3, 0)),
            15
        )
        XCTAssertEqual(plan.creditedWindDownMinutes(startedAt: startedAt), 15)
        XCTAssertEqual(plan.creditedMorningQuietMinutes(startedAt: startedAt), 30)
        XCTAssertEqual(plan.creditedQuietMinutes(startedAt: startedAt, through: startedAt), 0)
    }

    func testCompletedNightWatchRewardsOnlyBookendMinutes() throws {
        let startedAt = try date(2026, 7, 18, 22, 30)
        let plan = makePreferences().makePlan(startedAt: startedAt, calendar: calendar)
        var run = FocusRun(
            plannedDurationSeconds: plan.protectedUntil.timeIntervalSince(startedAt),
            startedAt: startedAt,
            state: .completed,
            guardKind: .honorTimer,
            nightWatchPlan: plan
        )
        run.completedSuccessfully = true
        run.endedAt = plan.protectedUntil
        run.actualDurationSeconds = run.plannedDurationSeconds

        let progress = RewardEngine().updatedProgress(after: run, current: .empty, reward: nil)

        XCTAssertEqual(run.creditedQuietMinutes, 60)
        XCTAssertEqual(run.creditedWindDownMinutes, 30)
        XCTAssertEqual(run.creditedMorningQuietMinutes, 30)
        XCTAssertEqual(progress.totalFocusMinutes, 60)
        XCTAssertEqual(progress.record(for: plan.intendedBedtime, calendar: calendar)?.completedFocusMinutes, 60)
        XCTAssertNil(progress.record(for: plan.protectedUntil, calendar: calendar))
    }

    func testLegacyFocusRunStillDecodesWithoutNightWatchPlan() throws {
        let data = """
        {
          "id": "00000000-0000-0000-0000-000000000002",
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

        XCTAssertNil(run.nightWatchPlan)
        XCTAssertFalse(run.isNightWatch)
        XCTAssertEqual(run.creditedQuietMinutes, 25)
    }

    func testOvernightTimerUsesHours() {
        XCTAssertEqual(OllieFormat.timer(8 * 60 * 60 + 5 * 60 + 9), "08:05:09")
        XCTAssertEqual(OllieFormat.timer(5 * 60 + 9), "05:09")
    }

    func testGuidanceStaysStableWithinEachNightWatchPhase() throws {
        let runID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000042"))

        XCTAssertEqual(
            NightWatchGuidance.tip(for: .windDown, seed: runID),
            NightWatchGuidance.tip(for: .windDown, seed: runID)
        )
        XCTAssertEqual(
            NightWatchGuidance.tip(for: .morningQuiet, seed: runID),
            NightWatchGuidance.tip(for: .morningQuiet, seed: runID)
        )
        XCTAssertNil(NightWatchGuidance.tip(for: .overnight, seed: runID))
    }

    func testLiveActivityGuidanceSeparatesTheChosenActivityFromTheTip() throws {
        let runID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000042"))
        let guidance = NightWatchGuidance.liveActivityGuidance(
            for: .morningQuiet,
            activityTitle: "Open the curtains",
            seed: runID
        )

        XCTAssertEqual(NightWatchPhase.windDown.title, "Phone-free wind-down")
        XCTAssertEqual(NightWatchPhase.overnight.title, "Sleep time")
        XCTAssertEqual(NightWatchPhase.morningQuiet.title, "Phone-free morning")
        XCTAssertEqual(guidance.primary, "This morning: Open the curtains.")
        XCTAssertFalse(try XCTUnwrap(guidance.secondary).isEmpty)
    }

    func testNotificationCopyExplainsEachNightWatchTransition() {
        let windDown = NightWatchGuidance.notificationCopy(
            for: .windDownReminder,
            tip: "Put a paper book where the phone used to be."
        )
        let sleepTime = NightWatchGuidance.notificationCopy(for: .sleepTime)
        let morning = NightWatchGuidance.notificationCopy(
            for: .phoneFreeMorning,
            activityTitle: "Open curtains",
            tip: "Drink some water before checking the day."
        )
        let complete = NightWatchGuidance.notificationCopy(for: .complete)

        XCTAssertTrue(windDown.body.contains("phone-free wind-down"))
        XCTAssertTrue(windDown.body.contains("paper book"))
        XCTAssertTrue(sleepTime.title.contains("Sleep time"))
        XCTAssertTrue(morning.body.contains("phone-free morning"))
        XCTAssertTrue(morning.body.contains("open curtains"))
        XCTAssertTrue(morning.body.contains("Drink some water"))
        XCTAssertTrue(complete.title.contains("wake"))
    }

    func testPlanKeepsLocalWakeTimeAcrossSpringDSTChange() throws {
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let startedAt = try XCTUnwrap(losAngeles.date(from: DateComponents(
            timeZone: losAngeles.timeZone,
            year: 2026,
            month: 3,
            day: 7,
            hour: 22,
            minute: 30
        )))

        let plan = makePreferences().makePlan(startedAt: startedAt, calendar: losAngeles)
        let wakeComponents = losAngeles.dateComponents([.year, .month, .day, .hour, .minute], from: plan.wakeTime)

        XCTAssertEqual(wakeComponents.year, 2026)
        XCTAssertEqual(wakeComponents.month, 3)
        XCTAssertEqual(wakeComponents.day, 8)
        XCTAssertEqual(wakeComponents.hour, 7)
        XCTAssertEqual(wakeComponents.minute, 0)
        XCTAssertEqual(plan.protectedUntil.timeIntervalSince(plan.wakeTime), 30 * 60, accuracy: 1)
    }

    private func makePreferences() -> NightWatchPreferences {
        NightWatchPreferences(
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            guardKind: .honorTimer,
            isConfigured: true
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}
