import XCTest

final class PhoneFreeCueTests: XCTestCase {
    func testCueNormalizesWhitespaceAndLength() {
        let cue = PhoneFreeCue.normalized("  finish\nmy   watercolor  ")
        XCTAssertEqual(cue, "finish my watercolor")

        let long = PhoneFreeCue.normalized(String(repeating: "🐑", count: 100))
        XCTAssertEqual(long?.count, PhoneFreeCue.maximumTextLength)
    }

    func testPlanRoundTripsCustomEveningAndMorningCues() throws {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let plan = NightWatchPlan(
            intendedBedtime: start.addingTimeInterval(60 * 60),
            wakeTime: start.addingTimeInterval(9 * 60 * 60),
            protectedUntil: start.addingTimeInterval(9.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            eveningCueText: "Finish my watercolor",
            morningCueText: "Sit by the window"
        )

        let decoded = try JSONDecoder().decode(
            NightWatchPlan.self,
            from: JSONEncoder().encode(plan)
        )
        XCTAssertEqual(decoded.eveningActivityTitle, "Finish my watercolor")
        XCTAssertEqual(decoded.morningActivityTitle, "Sit by the window")
    }

    func testLegacyPlanStillUsesSuggestedActivityTitles() throws {
        let data = Data("{\"intendedBedtime\":1003600,\"wakeTime\":1032400,\"protectedUntil\":1034200,\"windDownMinutes\":30,\"morningQuietMinutes\":30,\"eveningActivity\":\"read\",\"morningActivity\":\"openCurtains\"}".utf8)

        let decoded = try JSONDecoder().decode(NightWatchPlan.self, from: data)
        XCTAssertEqual(decoded.eveningActivityTitle, "Read")
        XCTAssertEqual(decoded.morningActivityTitle, "Open curtains")
    }
}
