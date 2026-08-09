import XCTest

final class OrientationTests: XCTestCase {
    func testLegacyOrientationFlagsMigrateIntoVersionedState() throws {
        let data = Data(#"{"schemaVersion":0,"homeExplained":true,"windDownSaved":true,"practiceStarted":true}"#.utf8)

        let state = try JSONDecoder().decode(CountingSheepOrientationState.self, from: data)

        XCTAssertEqual(state.schemaVersion, CountingSheepOrientationState.currentSchemaVersion)
        XCTAssertEqual(state.status, .inProgress)
        XCTAssertTrue(state.milestones.contains(.homeExplained))
        XCTAssertTrue(state.milestones.contains(.windDownSaved))
        XCTAssertTrue(state.milestones.contains(.practiceStarted))
        XCTAssertNil(state.practiceRunID)
    }

    func testLegacySkippedStateRemainsPermanentlySkippedUntilReplay() throws {
        let data = Data(#"{"schemaVersion": 0, "skipped": true}"#.utf8)
        var state = try JSONDecoder().decode(CountingSheepOrientationState.self, from: data)

        XCTAssertEqual(state.status, .skipped)
        state.mark(.homeExplained)
        XCTAssertEqual(state.status, .skipped)

        state.replay()
        XCTAssertEqual(state.status, .inProgress)
        XCTAssertTrue(state.milestones.isEmpty)
    }

    func testMilestonesFollowRealOrientationTransitions() {
        var state = CountingSheepOrientationState.fresh
        let periodID = UUID()
        let runID = UUID()

        state.mark(.homeExplained)
        state.mark(.windDownSaved)
        state.recordPracticePeriod(periodID)
        XCTAssertFalse(state.milestones.contains(.practiceStarted))

        state.recordPracticeRun(runID)
        XCTAssertTrue(state.milestones.contains(.practiceStarted))
        XCTAssertEqual(state.practicePeriodID, periodID)
        XCTAssertEqual(state.practiceRunID, runID)

        state.mark(.practiceCompleted)
        XCTAssertFalse(state.isComplete)
        state.mark(.practiceRecordViewed)
        state.mark(.nightsExplored)
        state.mark(.farmExplored)
        state.mark(.settingsExplored)

        XCTAssertEqual(state.status, .completed)
        XCTAssertTrue(state.requiredMilestones.isSubset(of: state.milestones))
    }

    func testDismissalIsResumableAndDoesNotEraseProgress() {
        var state = CountingSheepOrientationState.fresh
        state.mark(.homeExplained)
        state.dismiss()

        XCTAssertEqual(state.status, .dismissed)
        XCTAssertTrue(state.milestones.contains(.homeExplained))

        state.resume()
        XCTAssertEqual(state.status, .inProgress)
        XCTAssertTrue(state.milestones.contains(.homeExplained))
    }

    func testPassiveTabVisitsDoNotSilentlyResumeDismissedOrientation() {
        var state = CountingSheepOrientationState.fresh
        state.mark(.homeExplained)
        state.dismiss()

        state.mark(.nightsExplored)
        state.mark(.farmExplored)
        state.mark(.settingsExplored)

        XCTAssertEqual(state.status, .dismissed)
        XCTAssertTrue(state.milestones.contains(.nightsExplored))
        XCTAssertTrue(state.milestones.contains(.farmExplored))
        XCTAssertTrue(state.milestones.contains(.settingsExplored))
    }
}
