import XCTest

final class HomeStartRoutingTests: XCTestCase {
    func testDefaultPhoneAwayOverlapSelectsWindDownWithoutMovingAutomaticStart() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 22, minute: 30))!
        let routine = WindDownRoutine(title: "Wind Down", role: .primarySleepBookend,
                                      start: .init(hour: 22, minute: 30), end: .init(hour: 7, minute: 0))
        let schedule = WindDownScheduleState(routines: [routine])
        for lead in [1801.0, 1800.0, 1799.0, 60.0, 0.0, -60.0] {
            let now = start.addingTimeInterval(-lead)
            let choice = HomeStartRoutingPolicy.windDownPeriod(in: schedule, at: now, calendar: calendar)
            XCTAssertEqual(choice != nil, lead < 1800, "lead seconds: \(lead)")
            if let choice { XCTAssertEqual(choice.sourceID, routine.id) }
        }
        let early = start.addingTimeInterval(-1200)
        XCTAssertNil(WindDownScheduleEngine.eligibleOccurrence(in: schedule, at: early, calendar: calendar))
        let chosen = try XCTUnwrap(HomeStartRoutingPolicy.windDownPeriod(in: schedule, at: early, calendar: calendar))
        let preferences = NightWatchPreferences(bedtimeHour: 23, bedtimeMinute: 0, wakeHour: 7, wakeMinute: 0,
            windDownMinutes: 30, morningQuietMinutes: 30, eveningActivity: .read,
            morningActivity: .openCurtains, guardKind: .honorTimer, isConfigured: true)
        let plan = WindDownScheduleEngine.plan(for: chosen, preferences: preferences, startedAt: early, calendar: calendar)
        XCTAssertEqual(plan.intendedBedtime, start.addingTimeInterval(1800))
        XCTAssertEqual(plan.role, .primarySleepBookend)
    }

    func testEarlyHomeChoiceCrossesMidnightAndIgnoresPhoneAwayAndDisabledRoutines() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 23, minute: 50))!
        var night = WindDownRoutine(title: "Night", role: .primarySleepBookend,
                                   start: .init(hour: 0, minute: 10), end: .init(hour: 8, minute: 0))
        let day = WindDownRoutine(title: "Phone Away", role: .additionalQuiet,
                                 start: .init(hour: 23, minute: 45), end: .init(hour: 23, minute: 59))
        XCTAssertEqual(HomeStartRoutingPolicy.windDownPeriod(in: .init(routines: [day, night]), at: now, calendar: calendar)?.sourceID, night.id)
        night.enabled = false
        XCTAssertNil(HomeStartRoutingPolicy.windDownPeriod(in: .init(routines: [day, night]), at: now, calendar: calendar))
        XCTAssertNil(HomeStartRoutingPolicy.windDownPeriod(in: .init(), at: now, calendar: calendar))
    }

    func testPublishesOnlyTheCoordinatorAdmittedRun() {
        let admittedRun = FocusRun(
            id: UUID(), plannedDurationSeconds: 30 * 60, startedAt: Date(), guardKind: .honorTimer
        )

        XCTAssertEqual(
            HomeStartRoutingPolicy.admission(for: .started(admittedRun)),
            HomeStartAdmission(id: admittedRun.id)
        )
        XCTAssertNil(HomeStartRoutingPolicy.admission(for: .rejected(.activeRun(UUID()))))
        XCTAssertNil(HomeStartRoutingPolicy.admission(for: .rejected(.activeScreenFreeMorning(UUID()))))
    }

    func testRoutesOnlyWhenAdmissionMatchesAuthoritativeActiveRun() {
        let admitted = HomeStartAdmission(id: UUID())

        XCTAssertTrue(HomeStartRoutingPolicy.shouldRoute(admission: admitted, activeRunID: admitted.id))
        XCTAssertFalse(HomeStartRoutingPolicy.shouldRoute(admission: admitted, activeRunID: UUID()))
        XCTAssertFalse(HomeStartRoutingPolicy.shouldRoute(admission: admitted, activeRunID: nil))
        XCTAssertFalse(HomeStartRoutingPolicy.shouldRoute(admission: nil, activeRunID: admitted.id))
        XCTAssertFalse(HomeStartRoutingPolicy.shouldRoute(admission: nil, activeRunID: nil))
    }

    func testWindDownHeadingUsesTonightOnlyForAnUpcomingBedtimeToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_788_000_000)

        XCTAssertEqual(
            HomeStartRoutingPolicy.windDownHeading(
                intendedBedtime: now.addingTimeInterval(60), now: now, calendar: calendar
            ),
            "TONIGHT"
        )
        XCTAssertEqual(
            HomeStartRoutingPolicy.windDownHeading(
                intendedBedtime: now.addingTimeInterval(-60), now: now, calendar: calendar
            ),
            "WIND DOWN"
        )
        XCTAssertEqual(
            HomeStartRoutingPolicy.windDownHeading(
                intendedBedtime: now.addingTimeInterval(86_400), now: now, calendar: calendar
            ),
            "WIND DOWN"
        )
        XCTAssertEqual(
            HomeStartRoutingPolicy.windDownHeading(intendedBedtime: nil, now: now, calendar: calendar),
            "WIND DOWN"
        )
    }
}
