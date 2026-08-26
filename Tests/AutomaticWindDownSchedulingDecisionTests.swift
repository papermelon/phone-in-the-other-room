import XCTest

final class AutomaticWindDownSchedulingDecisionTests: XCTestCase {
    func testActiveRunPreservesItsExistingShieldAndSchedule() {
        XCTAssertEqual(
            AutomaticWindDownSchedulingDecision.resolve(
                isRunActive: true,
                isConfigured: true,
                hasAutomaticRoutine: true,
                guardKind: .nfcTag,
                hasWindDownTag: false
            ),
            .preserveActiveRun
        )
    }

    func testMissingWindDownTagCancelsAutomaticNFCSchedule() {
        XCTAssertEqual(
            AutomaticWindDownSchedulingDecision.resolve(
                isRunActive: false,
                isConfigured: true,
                hasAutomaticRoutine: true,
                guardKind: .nfcTag,
                hasWindDownTag: false
            ),
            .cancelMissingWindDownTag
        )
    }

    func testTimerScheduleDoesNotRequireTag() {
        XCTAssertEqual(
            AutomaticWindDownSchedulingDecision.resolve(
                isRunActive: false,
                isConfigured: true,
                hasAutomaticRoutine: true,
                guardKind: .honorTimer,
                hasWindDownTag: false
            ),
            .schedule
        )
    }
}
