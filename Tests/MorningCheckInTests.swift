import XCTest

final class MorningCheckInTests: XCTestCase {
    func testHistoryNormalizesAndReplacesSameDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let morning = Date(timeIntervalSince1970: 1_800_000_000)
        let evening = morning.addingTimeInterval(8 * 60 * 60)
        var history = MorningCheckInHistory(calendar: calendar)

        history.upsert(
            MorningCheckIn(
                day: morning,
                sleepOnset: .fifteenTo30,
                restfulness: nil,
                bedtimeSleepiness: nil
            ),
            calendar: calendar
        )
        history.upsert(
            MorningCheckIn(
                day: evening,
                sleepOnset: .under15,
                restfulness: .rested,
                bedtimeSleepiness: .sleepy
            ),
            calendar: calendar
        )

        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.entry(for: morning, calendar: calendar)?.sleepOnset, .under15)
        XCTAssertEqual(history.entry(for: morning, calendar: calendar)?.summary, "3 of 3 answered")
    }

    func testEmptyEntryRemovesExistingCheckIn() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        var history = MorningCheckInHistory(
            entries: [
                MorningCheckIn(
                    day: date,
                    sleepOnset: .notSure,
                    restfulness: .somewhat,
                    bedtimeSleepiness: nil
                )
            ]
        )

        history.upsert(
            MorningCheckIn(
                day: date,
                sleepOnset: nil,
                restfulness: nil,
                bedtimeSleepiness: nil
            )
        )

        XCTAssertTrue(history.entries.isEmpty)
    }

    func testHistoryRoundTripsAndKeepsNewest45Entries() throws {
        let entries = (0..<50).map { offset in
            MorningCheckIn(
                day: Date(timeIntervalSince1970: TimeInterval(offset * 86_400)),
                sleepOnset: .under15,
                restfulness: .rested,
                bedtimeSleepiness: .sleepy
            )
        }
        let history = MorningCheckInHistory(entries: entries)

        let data = try JSONEncoder().encode(history)
        let decoded = try JSONDecoder().decode(MorningCheckInHistory.self, from: data)

        XCTAssertEqual(decoded.entries.count, 45)
        XCTAssertEqual(decoded, history)
    }
}
