import XCTest

final class HomeWindowPhaseTests: XCTestCase {
    func testDayStartsAtSixLocalTime() throws {
        let calendar = calendar(in: "Asia/Singapore")
        XCTAssertEqual(HomeWindowPhase.phase(at: try date(6, 0, calendar: calendar), calendar: calendar, timeZone: calendar.timeZone), .day)
        XCTAssertEqual(HomeWindowPhase.phase(at: try date(17, 59, calendar: calendar), calendar: calendar, timeZone: calendar.timeZone), .day)
    }

    func testNightBeginsAtSixPMAndContinuesUntilSixAM() throws {
        let calendar = calendar(in: "America/Los_Angeles")
        XCTAssertEqual(HomeWindowPhase.phase(at: try date(18, 0, calendar: calendar), calendar: calendar, timeZone: calendar.timeZone), .night)
        XCTAssertEqual(HomeWindowPhase.phase(at: try date(5, 59, calendar: calendar), calendar: calendar, timeZone: calendar.timeZone), .night)
    }

    func testSuppliedTimeZoneDeterminesTheLocalPhase() throws {
        let utc = TimeZone(secondsFromGMT: 0)!
        let singapore = TimeZone(identifier: "Asia/Singapore")!
        let calendar = calendar(in: utc.identifier)
        let instant = try date(12, 0, calendar: calendar)

        XCTAssertEqual(HomeWindowPhase.phase(at: instant, calendar: calendar, timeZone: utc), .day)
        XCTAssertEqual(HomeWindowPhase.phase(at: instant, calendar: calendar, timeZone: singapore), .night)
    }

    private func calendar(in timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int, calendar: Calendar) throws -> Date {
        let components = DateComponents(year: 2026, month: 8, day: 28, hour: hour, minute: minute)
        return try XCTUnwrap(calendar.date(from: components))
    }
}
