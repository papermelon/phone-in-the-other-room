import XCTest

final class OnboardingTests: XCTestCase {
    func testFirstRunUsesFiveVisibleStepsAndKeepsLegacyReminderCaseDecodable() throws {
        XCTAssertEqual(
            CountingSheepOnboardingStep.visibleSteps,
            [.welcome, .profile, .recommendation, .schedule, .quiet, .protection, .gift, .ready]
        )
        XCTAssertEqual(CountingSheepOnboardingStep.ready.progress, 1)
        XCTAssertEqual(CountingSheepOnboardingStep.welcome.rawValue, 0)
        XCTAssertEqual(CountingSheepOnboardingStep.ready.rawValue, 5)

        var legacyDraft = OnboardingDraft()
        legacyDraft.step = .automaticStart
        let decoded = try JSONDecoder().decode(
            OnboardingDraft.self,
            from: JSONEncoder().encode(legacyDraft)
        )
        XCTAssertEqual(decoded.step, .automaticStart)
    }

    func testDefaultsLeadWithAppShieldingAndScheduledStart() {
        let draft = OnboardingDraft.defaults()

        XCTAssertEqual(draft.protectionChoice, .appShielding)
        XCTAssertEqual(draft.selectedGuardKind, .honorTimer)
        XCTAssertTrue(draft.shieldingEnabled)
        XCTAssertTrue(draft.automaticStartEnabled)
        XCTAssertTrue(draft.remindersEnabled)
        XCTAssertEqual(draft.windDownMinutes, 30)
        XCTAssertEqual(draft.morningQuietMinutes, 30)
        XCTAssertTrue(draft.eveningRoutine.isEmpty)
        XCTAssertTrue(draft.morningRoutine.isEmpty)
    }

    func testRecommendationShowsExamplesWithoutEnrollingThem() {
        var draft = OnboardingDraft()
        let recommendation = draft.profileRecommendation
        draft.applyRecommendation(recommendation)

        XCTAssertTrue(draft.eveningRoutine.isEmpty)
        XCTAssertTrue(draft.morningRoutine.isEmpty)
        XCTAssertEqual(draft.windDownMinutes, recommendation.desiredWindDownMinutes)
    }

    func testDraftMapsToConfiguredNightWatchAndPrivatePurpose() {
        var draft = OnboardingDraft()
        draft.bedtimeHour = 22
        draft.bedtimeMinute = 45
        draft.wakeHour = 6
        draft.wakeMinute = 30
        draft.windDownMinutes = 45
        draft.morningQuietMinutes = 30
        draft.protectionChoice = .nfcAndAppShielding
        draft.purposeCategory = .custom
        draft.customPurpose = "Read a few pages"
        draft.allowsCustomTextInNotifications = false

        let preferences = draft.makeNightWatchPreferences()
        let purpose = draft.makeOfflinePurpose()

        XCTAssertTrue(preferences.isConfigured)
        XCTAssertEqual(preferences.guardKind, .nfcTag)
        XCTAssertEqual(preferences.bedtimeHour, 22)
        XCTAssertEqual(preferences.windDownMinutes, 45)
        XCTAssertEqual(purpose.category, .custom)
        XCTAssertEqual(purpose.customText, "Read a few pages")
        XCTAssertFalse(purpose.allowsCustomTextInNotifications)
    }

    func testDraftCreatesThePrimaryRoutineForTheSavedHomePlan() {
        var draft = OnboardingDraft()
        draft.bedtimeHour = 22
        draft.bedtimeMinute = 45
        draft.windDownMinutes = 45
        draft.automaticStartEnabled = false
        let routineID = UUID()

        let routine = draft.makePrimaryWindDownRoutine(existingID: routineID)

        XCTAssertEqual(routine.id, routineID)
        XCTAssertEqual(routine.role, .primarySleepBookend)
        XCTAssertEqual(routine.start, WindDownClockTime(hour: 22, minute: 0))
        XCTAssertEqual(routine.end, WindDownClockTime(hour: 7, minute: 0))
        XCTAssertFalse(routine.automaticStartEnabled)
    }

    func testOpenEndedCuesBecomeEditableNightWatchText() {
        var draft = OnboardingDraft()
        draft.eveningCueText = "Finish my watercolor"
        draft.morningCueText = "Sit by the window"

        let preferences = draft.makeNightWatchPreferences()
        let purpose = draft.makeOfflinePurpose()

        XCTAssertEqual(preferences.eveningCueText, "Finish my watercolor")
        XCTAssertEqual(preferences.morningCueText, "Sit by the window")
        XCTAssertEqual(purpose.customText, "Finish my watercolor")
        XCTAssertFalse(purpose.allowsCustomTextInNotifications)
    }

    func testDraftRoundTripsWithCodable() throws {
        var draft = OnboardingDraft()
        draft.step = .protection
        draft.protectionChoice = .nfcAndAppShielding
        draft.remindersEnabled = false

        let data = try JSONEncoder().encode(draft)
        let decoded = try JSONDecoder().decode(OnboardingDraft.self, from: data)

        XCTAssertEqual(decoded, draft)
    }

    func testReleaseProtectionChoicesMapOnlyToCurrentGuardKinds() {
        XCTAssertEqual(WindDownProtectionChoice.appShielding.guardKind, .honorTimer)
        XCTAssertEqual(WindDownProtectionChoice.nfcAndAppShielding.guardKind, .nfcTag)
        XCTAssertEqual(WindDownProtectionChoice.from(guardKind: .watchPlacement), .appShielding)
        XCTAssertEqual(WindDownProtectionChoice.from(guardKind: .qrCode), .appShielding)
        XCTAssertEqual(SessionGuardKind.watchPlacement.releaseCompatibleKind, .honorTimer)
        XCTAssertEqual(SessionGuardKind.qrCode.releaseCompatibleKind, .honorTimer)
    }

    func testReplayPreservesTheCurrentNFCChoiceWithoutResettingProgress() {
        let preferences = NightWatchPreferences(
            bedtimeHour: 22,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            guardKind: .nfcTag,
            isConfigured: true
        )

        XCTAssertEqual(OnboardingDraft.replay(from: preferences).protectionChoice, .nfcAndAppShielding)
    }

    func testLegacyDraftCuesMigrateToPrivateOneStepRoutines() throws {
        var draft = OnboardingDraft()
        draft.eveningCueText = "  Finish my watercolor  "
        draft.morningCueText = "Sit by the window"
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as? [String: Any]
        )
        object.removeValue(forKey: "eveningRoutine")
        object.removeValue(forKey: "morningRoutine")

        let decoded = try JSONDecoder().decode(
            OnboardingDraft.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(decoded.eveningRoutine.map(\.title), ["Finish my watercolor"])
        XCTAssertEqual(decoded.morningRoutine.map(\.title), ["Sit by the window"])
        XCTAssertEqual(decoded.eveningCueText, "Finish my watercolor")
        XCTAssertEqual(decoded.morningCueText, "Sit by the window")
    }

    func testRoutineLimitsPreserveOrderAndKeepPhoneAwayOutOfStorage() {
        let steps = [
            WindDownRoutineStep.custom("First idea", phase: .evening),
            WindDownRoutineStep.suggested(.read, phase: .evening),
            WindDownRoutineStep.custom("Put phone away", phase: .evening),
            WindDownRoutineStep.suggested(.stretch, phase: .evening),
            WindDownRoutineStep.suggested(.journal, phase: .evening),
            WindDownRoutineStep.suggested(.makeTea, phase: .evening),
            WindDownRoutineStep.suggested(.openCurtains, phase: .morning)
        ]

        let normalized = WindDownRoutineStep.normalized(steps, for: .evening)

        XCTAssertEqual(normalized.count, 3)
        XCTAssertEqual(normalized.map(\.title), ["First idea", "Read a paper book", "Stretch gently"])
        XCTAssertFalse(normalized.contains { $0.title == WindDownRoutineStep.phoneAwayTitle })
    }

    func testExplicitEmptyRoutinesStayEmptyAndHaveNoCompletionState() throws {
        let preferences = NightWatchPreferences(
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            eveningRoutine: [],
            morningRoutine: [],
            guardKind: .honorTimer,
            isConfigured: true
        )
        let data = try JSONEncoder().encode(preferences)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let decoded = try JSONDecoder().decode(NightWatchPreferences.self, from: data)

        XCTAssertEqual(decoded.eveningRoutine, [])
        XCTAssertEqual(decoded.morningRoutine, [])
        XCTAssertFalse(object.keys.contains { $0.lowercased().contains("complete") })
        XCTAssertEqual(decoded.presentedEveningRoutineTitles, [WindDownRoutineStep.phoneAwayTitle])
        XCTAssertEqual(decoded.presentedMorningRoutineTitles, [])
    }

    func testRoutineSummariesHideCustomWordsWithoutConsent() {
        let preferences = NightWatchPreferences(
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            eveningRoutine: [.custom("My private note", phase: .evening)],
            morningRoutine: [.custom("My morning note", phase: .morning)],
            guardKind: .honorTimer,
            isConfigured: true
        )

        XCTAssertEqual(preferences.makePlan().eveningRoutineSummary(allowsPersonalText: false), "Put phone away")
        XCTAssertEqual(preferences.makePlan().eveningRoutineSummary(allowsPersonalText: true), "Put phone away · My private note")
        XCTAssertNil(preferences.makePlan().morningRoutineSummary(allowsPersonalText: false))
        XCTAssertEqual(preferences.makePlan().morningRoutineSummary(allowsPersonalText: true), "My morning note")
    }
}
