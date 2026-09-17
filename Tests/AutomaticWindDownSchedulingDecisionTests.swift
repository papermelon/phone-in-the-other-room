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

    func testAutomaticStatusShowsNextInstalledStart() {
        let start = Date(timeIntervalSince1970: 1_900_000_000)
        let presentation = AutomaticWindDownStatusPresentation.resolve(
            enabled: true,
            scheduledStart: start,
            repairNeeded: false,
            readiness: .ready
        )

        XCTAssertEqual(presentation, .scheduled(start))
        XCTAssertTrue(presentation.detail.contains("Next automatic start"))
        XCTAssertFalse(presentation.needsRepair)
    }

    func testAutomaticStatusShowsRepairInsteadOfPretendingScheduleIsActive() {
        let presentation = AutomaticWindDownStatusPresentation.resolve(
            enabled: true,
            scheduledStart: nil,
            repairNeeded: true,
            readiness: .ready
        )

        XCTAssertTrue(presentation.needsRepair)
        XCTAssertEqual(presentation.title, "Automatic Wind Down needs repair")
        XCTAssertTrue(presentation.detail.contains("Automatic start is waiting"))
        XCTAssertTrue(presentation.detail.contains("could not prepare or request app protection"))
    }
    func testRepairNamesCurrentMissingPrerequisiteBeforeHistoricalFailure() {
        for readiness in [ShieldingReadiness.authorizationRequired, .denied, .revoked, .noSelection, .unavailable] {
            let presentation = AutomaticWindDownStatusPresentation.resolve(
                enabled: true, scheduledStart: nil, repairNeeded: true, readiness: readiness
            )
            XCTAssertEqual(presentation.title, readiness.title)
            XCTAssertTrue(presentation.detail.contains(readiness.detail))
        }
    }

    func testAutomaticTimerRequiresInstalledFutureProtection() {
        XCTAssertTrue(AutomaticWindDownInstallationDecision.canSaveSchedule(after: .scheduled))
        for outcome in [QuietTimeShieldingOutcome.disabled, .noSelection, .failed("monitor installation"), .applied, .cleared] {
            XCTAssertFalse(AutomaticWindDownInstallationDecision.canSaveSchedule(after: outcome))
        }
    }

}
