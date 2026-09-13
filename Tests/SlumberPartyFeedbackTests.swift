import XCTest

final class SlumberPartyFeedbackTests: XCTestCase {
    func testPresentationKeepsFeedbackBoundedAndHumanReadable() {
        let partyID = UUID()
        let single = SlumberPartyCheerFeedback(
            partyID: partyID,
            cheer: .warmWave,
            count: 1,
            observedAt: Date(timeIntervalSince1970: 100)
        )
        let group = SlumberPartyCheerFeedback(
            partyID: partyID,
            cheer: .pawPrint,
            count: 3,
            observedAt: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(single.presentation.message, "Your Slumber Party sent a warm wave.")
        XCTAssertEqual(single.presentation.symbol, "hand.wave.fill")
        XCTAssertEqual(group.presentation.message, "Your Slumber Party sent 3 paw prints.")
        XCTAssertEqual(group.presentation.symbol, "pawprint.fill")
    }

    func testWatchMessageRoundTripsSilentCheer() throws {
        let sourceID = UUID()
        let feedback = SlumberPartyCheerFeedback(
            partyID: UUID(),
            cheer: .moonGlow,
            count: 2,
            observedAt: Date(timeIntervalSince1970: 300),
            sourceEventID: sourceID
        )
        let message = WatchMessage(
            type: .slumberPartyCheer,
            slumberPartyCheer: feedback,
            sentAt: Date(timeIntervalSince1970: 301)
        )

        let decoded = WatchMessageCodec.message(
            from: WatchMessageCodec.dictionary(from: message)
        )

        XCTAssertEqual(decoded?.type, .slumberPartyCheer)
        XCTAssertEqual(decoded?.slumberPartyCheer, feedback)
    }

    func testSourceScopedFeedbackOnlyAppliesToItsRunWhileLegacyStillApplies() {
        let runID = UUID()
        let scoped = SlumberPartyCheerFeedback(partyID: UUID(), cheer: .warmWave, count: 1, observedAt: .now, sourceEventID: runID)
        XCTAssertTrue(SlumberPartyCheerFeedbackApplicability.accepts(scoped, currentRunID: runID))
        XCTAssertFalse(SlumberPartyCheerFeedbackApplicability.accepts(scoped, currentRunID: UUID()))

        let legacy = SlumberPartyCheerFeedback(partyID: UUID(), cheer: .moonGlow, count: 1, observedAt: .now)
        XCTAssertTrue(SlumberPartyCheerFeedbackApplicability.accepts(legacy, currentRunID: UUID()))
    }
}
