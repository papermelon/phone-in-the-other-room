import XCTest

final class CompletionRewardPresentationTests: XCTestCase {
    func testMissingCreditDoesNotImplyFarmGrowthFromExistingMeter() {
        let presentation = CompletionRewardPresentation(outcome: nil, credit: nil, isPhoneAway: false, bankedSeconds: 3000)
        XCTAssertNil(presentation.sheepID)
        XCTAssertNil(presentation.progressFraction)
        XCTAssertEqual(presentation.headline, "Wind Down finished")
    }

    func testIncompleteTrackingDoesNotPresentNewGrowth() {
        let credit = FarmCreditReceipt(creditedSeconds: 0, excludedAccessSeconds: 0,
            trackingIncomplete: true, migrated: false, outcomeIDs: [])
        let presentation = CompletionRewardPresentation(outcome: nil, credit: credit, isPhoneAway: false, bankedSeconds: 3000)
        XCTAssertNil(presentation.progressFraction)
        XCTAssertEqual(presentation.headline, "Wind Down finished")
    }

    func testProgressUsesSeparateModeMetersAndRemainsBounded() {
        let credit = FarmCreditReceipt(creditedSeconds: 600, excludedAccessSeconds: 0,
            trackingIncomplete: false, migrated: false, outcomeIDs: [])
        let morning = CompletionRewardPresentation(outcome: nil, credit: credit, isPhoneAway: false, bankedSeconds: 210 * 60)
        let phoneAway = CompletionRewardPresentation(outcome: nil, credit: credit, isPhoneAway: true, bankedSeconds: 50 * 60)
        XCTAssertEqual(morning.progressFraction, 0.5)
        XCTAssertEqual(phoneAway.progressFraction, 0.5)
        XCTAssertEqual(CompletionRewardPresentation(outcome: nil, credit: credit, isPhoneAway: true, bankedSeconds: -1).progressFraction, 0)
        XCTAssertEqual(CompletionRewardPresentation(outcome: nil, credit: credit, isPhoneAway: true, bankedSeconds: 10000).progressFraction, 1)
    }

    func testOnlyFoundOutcomePresentsASheepAndNeverChangesTheOutcome() {
        for result in [SheepSearchOutcome.Result.found, .trailOnly] {
            let outcome = SheepSearchOutcome(id: UUID(), runID: UUID(), protectedNightNumber: 3,
                result: result, sheepID: "example", rarity: nil, habitat: nil, trailStrength: 0,
                encounterOdds: 0, trailDistance: 0, consecutiveNoFinds: 0, bonusPoints: 0, createdAt: Date())
            let presentation = CompletionRewardPresentation(outcome: outcome, credit: nil, isPhoneAway: false)
            XCTAssertEqual(presentation.sheepID, result == .found ? "example" : nil)
            XCTAssertEqual(presentation.actionTitle, result == .found ? "Meet your sheep" : "Open Search Journal")
            XCTAssertNil(presentation.progressFraction)
            XCTAssertEqual(outcome.result, result)
        }
    }
}
