import XCTest

final class EmergencyExitChallengeTests: XCTestCase {
    func testReasonFlowRequiresNonEmptyReasonAndMatchingSecondEntry() {
        let runID = UUID()
        var machine = EmergencyExitChallengeMachine()
        _ = machine.begin(for: runID)

        XCTAssertFalse(machine.submitReason("  \n", for: runID))
        XCTAssertTrue(machine.submitReason("Reply to a message", for: runID))
        XCTAssertEqual(machine.challenge?.reason, "Reply to a message")
        XCTAssertFalse(machine.challenge?.canConfirm == true)
        XCTAssertFalse(machine.submitConfirmation("Something else", for: runID))
        XCTAssertTrue(machine.submitConfirmation("  reply to a message  ", for: runID))
        XCTAssertTrue(machine.consumeConfirmation(for: runID))
        XCTAssertFalse(machine.consumeConfirmation(for: runID))
    }

    func testReasonMatchingToleratesSmartApostropheAndCase() {
        var machine = EmergencyExitChallengeMachine()
        let runID = UUID()
        _ = machine.begin(for: runID)
        XCTAssertTrue(machine.submitReason("I’m reaching for a friend", for: runID))
        XCTAssertTrue(machine.submitConfirmation("i'm reaching for a friend", for: runID))
    }

    func testCannedInputsDoNotGrantWithoutAUserReason() {
        var machine = EmergencyExitChallengeMachine()
        let runID = UUID()
        _ = machine.begin(for: runID)
        XCTAssertTrue(machine.submitReason("END", for: runID))
        XCTAssertFalse(machine.challenge?.canConfirm == true)
        XCTAssertFalse(machine.consumeConfirmation(for: runID))
    }
}
