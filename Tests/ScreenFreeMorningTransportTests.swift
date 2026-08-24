import XCTest

final class ScreenFreeMorningTransportTests: XCTestCase {
    func testLegacyWatchMessageDecodesWithoutMorningProjection() throws {
        let message = WatchMessage(type: .focusRunStateUpdate)
        guard var object = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(message)
        ) as? [String: Any] else {
            return XCTFail("Expected a Watch message object")
        }
        object.removeValue(forKey: "screenFreeMorning")
        let decoded = try JSONDecoder().decode(
            WatchMessage.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertNil(decoded.screenFreeMorning)
    }

    func testMorningWatchProjectionCarriesTimeAndStatusOnly() {
        let now = Date(timeIntervalSince1970: 3_000)
        let occurrence = MorningQuietOccurrence(
            scheduledStart: now,
            scheduledEnd: now.addingTimeInterval(30 * 60),
            actualStart: now,
            outcome: .active
        )
        let message = WatchMessage(
            type: .focusRunStateUpdate,
            screenFreeMorning: ScreenFreeMorningPresentation(occurrence: occurrence, at: now.addingTimeInterval(60))
        )
        XCTAssertEqual(message.screenFreeMorning?.status, .active)
        XCTAssertEqual(message.screenFreeMorning?.endsAt, occurrence.scheduledEnd)
        XCTAssertNil(message.reward)
    }
}
