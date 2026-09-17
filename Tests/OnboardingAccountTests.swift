import XCTest

final class OnboardingAccountTests: XCTestCase {
    func testOldDraftWithoutAccountFieldsDecodesIntoTheNewUserJourney() throws {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(OnboardingDraft())) as? [String: Any]
        )
        object.removeValue(forKey: "journeyRoute")
        object.removeValue(forKey: "returningUserDeviceSetup")
        object.removeValue(forKey: "accountInvitationSkipped")

        let draft = try JSONDecoder().decode(
            OnboardingDraft.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertFalse(draft.returningUserDeviceSetup)
        XCTAssertFalse(draft.accountInvitationSkipped)
        XCTAssertTrue(draft.journeySteps.contains(.account))
    }

    func testGiftFlowsToTheOptionalAccountInvitation() {
        var draft = OnboardingDraft(step: .gift)

        draft.moveToNextVisibleStep()

        XCTAssertEqual(draft.step, .account)
        XCTAssertEqual(draft.journeySteps.firstIndex(of: .account), 4)
    }

    func testReturningRestoreRoutesOnlyToDeviceSetupAndSurvivesRelaunch() throws {
        var draft = OnboardingDraft(step: .welcome)
        draft.beginReturningUserDeviceSetup()

        XCTAssertEqual(draft.step, .schedule)
        XCTAssertEqual(draft.journeySteps, [.schedule, .quiet, .ready])
        XCTAssertFalse(draft.journeySteps.contains(.gift))
        XCTAssertFalse(draft.journeySteps.contains(.account))

        let restored = try JSONDecoder().decode(OnboardingDraft.self, from: JSONEncoder().encode(draft))
        XCTAssertTrue(restored.returningUserDeviceSetup)
        XCTAssertEqual(restored.step, .schedule)
        XCTAssertEqual(restored.journeySteps, [.schedule, .quiet, .ready])
    }

    func testReplayOmitsAccountInvitationWithoutChangingExistingRawCases() {
        let draft = OnboardingDraft.replay(from: .defaults)

        XCTAssertEqual(draft.journeyRoute, .legacy)
        XCTAssertTrue(draft.accountInvitationSkipped)
        XCTAssertFalse(draft.journeySteps.contains(.account))
        XCTAssertEqual(CountingSheepOnboardingStep.gift.rawValue, 8)
    }

    func testSkippingGiftUsesTheCurrentJourneyWhenAccountIsExcluded() {
        var draft = OnboardingDraft(step: .gift)
        draft.accountInvitationSkipped = true

        XCTAssertEqual(draft.skipVisibleStep(), .none)
        XCTAssertEqual(draft.step, .schedule)
    }

    func testReturnerScheduleHasNoBackJourneyIntoGiftOrAccount() {
        var draft = OnboardingDraft()
        draft.beginReturningUserDeviceSetup()

        XCTAssertEqual(draft.journeySteps.first, .schedule)
        XCTAssertFalse(draft.journeySteps.contains(.gift))
        XCTAssertFalse(draft.journeySteps.contains(.account))
    }

    func testStaleRestoreEventsAreIgnoredByReplayAndFixturePresentations() {
        XCTAssertFalse(CountingSheepOnboarding.acceptsCommittedRestoreRoute(
            presentationMode: .replay,
            onboardingVersion: 0
        ))
        XCTAssertFalse(CountingSheepOnboarding.acceptsCommittedRestoreRoute(
            presentationMode: .fixture,
            onboardingVersion: 0
        ))
        XCTAssertFalse(CountingSheepOnboarding.acceptsCommittedRestoreRoute(
            presentationMode: .firstRun,
            onboardingVersion: CountingSheepOnboarding.currentVersion
        ))
        XCTAssertTrue(CountingSheepOnboarding.acceptsCommittedRestoreRoute(
            presentationMode: .firstRun,
            onboardingVersion: 0
        ))
    }

    func testLegacyReturningDraftKeepsProtectionStageAndHonestPageCount() throws {
        var draft = OnboardingDraft()
        draft.journeyRoute = .legacy
        draft.beginReturningUserDeviceSetup()
        let restored = try JSONDecoder().decode(OnboardingDraft.self, from: JSONEncoder().encode(draft))
        XCTAssertEqual(restored.journeySteps, [.schedule, .quiet, .protection, .ready])
        XCTAssertEqual(restored.visiblePageCount, 4)
        XCTAssertEqual(restored.visiblePageNumber, 1)
    }

    func testReplayKeepsRoutineAndGiftPathWithoutAnAccountInvitation() {
        var preferences = NightWatchPreferences.defaults
        preferences.eveningRoutine = [.custom("Make room for painting", phase: .evening)]
        preferences.morningRoutine = [.suggested(.breakfast, phase: .morning)]
        preferences.bedtimeHour = 22
        preferences.isConfigured = true
        preferences.automaticStartEnabled = true
        let draft = OnboardingDraft.replay(from: preferences)
        XCTAssertEqual(draft.journeyRoute, .legacy)
        XCTAssertEqual(draft.eveningRoutine, preferences.eveningRoutine)
        XCTAssertEqual(draft.morningRoutine, preferences.morningRoutine)
        XCTAssertEqual(draft.bedtimeHour, 22)
        XCTAssertTrue(draft.automaticStartEnabled)
        XCTAssertTrue(draft.journeySteps.contains(.gift))
        XCTAssertTrue(draft.journeySteps.contains(.profile))
        XCTAssertFalse(draft.journeySteps.contains(.account))
    }

}
