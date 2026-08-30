import XCTest

final class HomeStartRoutingTests: XCTestCase {
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
