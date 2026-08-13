import XCTest

final class OrientationTests: XCTestCase {
    func testLegacyOrientationFlagsMigrateIntoVersionedState() throws {
        let data = Data(#"{"schemaVersion":0,"homeExplained":true,"windDownSaved":true,"practiceStarted":true}"#.utf8)

        let state = try JSONDecoder().decode(CountingSheepOrientationState.self, from: data)

        XCTAssertEqual(state.schemaVersion, CountingSheepOrientationState.currentSchemaVersion)
        XCTAssertEqual(state.status, .inProgress)
        XCTAssertEqual(state.currentStep, .navigation)
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

    func testPracticeMilestonesDoNotGateTheThreeStepTour() {
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

        XCTAssertFalse(state.isComplete)

        state.advanceTour()
        XCTAssertEqual(state.currentStep, .start)
        XCTAssertEqual(state.status, .inProgress)
        state.advanceTour()
        XCTAssertEqual(state.currentStep, .navigation)
        XCTAssertEqual(state.status, .inProgress)
        state.advanceTour()
        XCTAssertTrue(state.isComplete)
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

    func testTourCanMoveBackAndReplayFromTheBeginning() {
        var state = CountingSheepOrientationState.fresh

        state.advanceTour()
        XCTAssertEqual(state.currentStep, .start)
        state.advanceTour()
        XCTAssertEqual(state.currentStep, .navigation)
        state.moveBack()
        XCTAssertEqual(state.currentStep, .start)
        state.moveBack()
        XCTAssertEqual(state.currentStep, .home)
        state.completeTour()
        XCTAssertTrue(state.isComplete)

        state.replay()
        XCTAssertEqual(state.status, .inProgress)
        XCTAssertEqual(state.currentStep, .home)
    }

    func testVersionTwoNavigationStepRemainsAtNavigation() throws {
        let data = Data(#"{"schemaVersion":2,"status":"inProgress","currentStep":"navigation","milestones":[]}"#.utf8)

        let state = try JSONDecoder().decode(CountingSheepOrientationState.self, from: data)

        XCTAssertEqual(state.schemaVersion, CountingSheepOrientationState.currentSchemaVersion)
        XCTAssertEqual(state.currentStep, .navigation)
    }

    func testCompletedLegacyTourCanShowNewContextualTips() throws {
        let data = Data(#"{"schemaVersion":3,"status":"completed","currentStep":"navigation","milestones":[]}"#.utf8)
        let state = try JSONDecoder().decode(CountingSheepOrientationState.self, from: data)
        XCTAssertTrue(state.canShowContextualTips)
        XCTAssertEqual(state.nextContextualTip(from: [.nights]), .nights)
    }

    func testSkippedAndDismissedToursSuppressContextualTips() {
        var skipped = CountingSheepOrientationState.fresh
        skipped.skipPermanently()
        XCTAssertNil(skipped.nextContextualTip(from: [.nights]))

        var dismissed = CountingSheepOrientationState.fresh
        dismissed.dismiss()
        XCTAssertNil(dismissed.nextContextualTip(from: [.nights]))
        dismissed.resume()
        XCTAssertEqual(dismissed.nextContextualTip(from: [.nights]), .nights)
    }

    func testContextualTipsAreOneTimeAndReplayClearsThem() {
        var state = CountingSheepOrientationState.fresh
        XCTAssertEqual(state.nextContextualTip(from: [.nights, .farm]), .nights)
        state.markContextualTipSeen(.nights)
        XCTAssertEqual(state.nextContextualTip(from: [.nights, .farm]), .farm)
        state.disableContextualTips()
        XCTAssertNil(state.nextContextualTip(from: [.farm]))
        state.replay()
        XCTAssertTrue(state.seenContextualTips.isEmpty)
        XCTAssertFalse(state.contextualTipsDisabled)
        XCTAssertEqual(state.nextContextualTip(from: [.nights]), .nights)
    }

    func testBarnCapacityTipAlsoSatisfiesTheGenericFarmTip() {
        var state = CountingSheepOrientationState.fresh
        state.markContextualTipSeen(.barnCapacity)
        XCTAssertTrue(state.seenContextualTips.contains(.barnCapacity))
        XCTAssertTrue(state.seenContextualTips.contains(.farm))
        XCTAssertNil(state.nextContextualTip(from: [.farm]))
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
