import XCTest

final class OnboardingTests: XCTestCase {
    func testFirstRunCountsEveryVisiblePageAndKeepsLegacyCasesDecodable() throws {
        XCTAssertEqual(
            CountingSheepOnboardingStep.visibleSteps,
            [.welcome, .profile, .recommendation, .gift, .schedule, .quiet, .protection, .ready]
        )
        XCTAssertEqual(OnboardingWelcomePage.visiblePages, [.countingSheep, .ollie])
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

        var draft = OnboardingDraft()
        XCTAssertEqual(draft.visiblePageNumber, 1)
        XCTAssertEqual(draft.visiblePageCount, 9)
        draft.welcomePage = .ollie
        XCTAssertEqual(draft.visiblePageNumber, 2)
        draft.step = .profile
        XCTAssertEqual(draft.visiblePageNumber, 3)
        draft.step = .recommendation
        XCTAssertEqual(draft.visiblePageNumber, 4)
        draft.step = .ready
        XCTAssertEqual(draft.visiblePageNumber, 9)
    }

    func testSkippingQuestionnaireRemovesTheResultFromTheHonestPageCount() {
        var draft = OnboardingDraft(step: .profile)

        XCTAssertEqual(draft.visiblePageNumber, 3)
        XCTAssertEqual(draft.visiblePageCount, 9)

        XCTAssertEqual(draft.skipVisibleStep(), .skipQuestionnaire)
        XCTAssertEqual(draft.step, .gift)
        XCTAssertEqual(draft.visiblePageNumber, 4)
        XCTAssertEqual(draft.visiblePageCount, 8)
    }

    func testQuestionnaireRequiresSixExplicitMeaningfulAnswers() {
        var draft = OnboardingDraft(step: .profile)
        XCTAssertFalse(draft.hasCompletedProfileQuestions)

        for question in CountingSheepOnboarding.profileQuestions.dropLast() {
            draft.completedProfileQuestions.insert(question)
        }
        XCTAssertFalse(draft.hasCompletedProfileQuestions)
        draft.completedProfileQuestions.insert(.desiredChange)
        XCTAssertTrue(draft.hasCompletedProfileQuestions)
    }

    func testQuestionnaireAdvancesAndResumesOneQuestionAtATime() throws {
        var draft = OnboardingDraft(step: .profile)
        draft.profileAnswers.bedtimeDelay = .sometimes
        draft.completedProfileQuestions.insert(.bedtimeDelay)

        XCTAssertEqual(draft.continueVisibleStep(), .none)
        XCTAssertEqual(draft.step, .profile)
        XCTAssertEqual(draft.currentProfileQuestion, .automaticReaching)
        XCTAssertEqual(draft.profileQuestionIndex, 1)

        let restored = try JSONDecoder().decode(OnboardingDraft.self, from: JSONEncoder().encode(draft))
        XCTAssertEqual(restored.currentProfileQuestion, .automaticReaching)
        XCTAssertEqual(restored.profileAnswers.bedtimeDelay, .sometimes)
    }

    func testReturningToAnEarlierQuestionPreservesAndReplacesItsExplicitAnswer() {
        var draft = OnboardingDraft(step: .profile)
        draft.profileAnswers.bedtimeDelay = .sometimes
        draft.completedProfileQuestions.insert(.bedtimeDelay)
        draft.continueVisibleStep()
        draft.profileAnswers.automaticReaching = .often
        draft.completedProfileQuestions.insert(.automaticReaching)

        draft.profileQuestionIndex -= 1
        XCTAssertEqual(draft.currentProfileQuestion, .bedtimeDelay)
        XCTAssertEqual(draft.profileAnswers.bedtimeDelay, .sometimes)
        XCTAssertTrue(draft.hasAnsweredCurrentProfileQuestion)

        draft.profileAnswers.bedtimeDelay = .rarely
        draft.continueVisibleStep()
        XCTAssertEqual(draft.currentProfileQuestion, .automaticReaching)
        XCTAssertEqual(draft.profileAnswers.bedtimeDelay, .rarely)
        XCTAssertEqual(draft.profileAnswers.automaticReaching, .often)
    }

    func testInterruptedGiftSelectionResumesWithoutChangingItsLegacyStepValue() throws {
        var draft = OnboardingDraft(step: .gift)
        draft.selectedWelcomeGiftItemID = "shepherd_moon_coat"

        let restored = try JSONDecoder().decode(OnboardingDraft.self, from: JSONEncoder().encode(draft))

        XCTAssertEqual(restored.step, .gift)
        XCTAssertEqual(restored.selectedWelcomeGiftItemID, "shepherd_moon_coat")
        XCTAssertEqual(restored.stageCount, CountingSheepOnboardingStep.visibleSteps.count)
    }

    func testQuestionProgressDoesNotCreateAdditionalOnboardingStages() {
        var draft = OnboardingDraft(step: .profile)
        let stageCount = draft.stageCount
        let stageNumber = draft.currentStageNumber
        draft.profileQuestionIndex = 5

        XCTAssertEqual(draft.stageCount, stageCount)
        XCTAssertEqual(draft.currentStageNumber, stageNumber)
        XCTAssertEqual(draft.visiblePageCount, 9)
    }

    func testPresentationModeSeparatesFixturesFromReplay() {
        XCTAssertFalse(OnboardingPresentationMode.firstRun.preservesExistingSettings)
        XCTAssertFalse(OnboardingPresentationMode.fixture.preservesExistingSettings)
        XCTAssertTrue(OnboardingPresentationMode.replay.preservesExistingSettings)
    }

    func testConfiguredPlansAndActiveRunsBypassOnboardingDespiteAnOldDraft() {
        for state in [(configured: true, active: false), (configured: false, active: true)] {
            XCTAssertEqual(
                CountingSheepRootRoute.resolve(
                    onboardingVersion: 0,
                    currentOnboardingVersion: CountingSheepOnboarding.currentVersion,
                    hasOnboardingDraft: true,
                    hasConfiguredNightWatch: state.configured,
                    hasActiveRun: state.active
                ),
                .home
            )
        }
    }

    func testDefaultsLeadWithAppShieldingAndScheduledStart() {
        let draft = OnboardingDraft.defaults()

        XCTAssertEqual(draft.protectionChoice, .appShielding)
        XCTAssertEqual(draft.selectedGuardKind, .honorTimer)
        XCTAssertTrue(draft.shieldingEnabled)
        XCTAssertFalse(draft.automaticStartEnabled)
        XCTAssertFalse(draft.remindersEnabled)
        XCTAssertEqual(draft.windDownMinutes, 30)
        XCTAssertEqual(draft.morningQuietMinutes, 30)
        XCTAssertTrue(draft.eveningRoutine.isEmpty)
        XCTAssertTrue(draft.morningRoutine.isEmpty)
    }

    func testRecommendationShowsExamplesWithoutEnrollingThem() {
        var draft = OnboardingDraft()
        draft.bedtimeHour = 21
        draft.windDownMinutes = 60
        let recommendation = draft.profileRecommendation
        draft.applyRecommendation(recommendation)

        XCTAssertTrue(draft.eveningRoutine.isEmpty)
        XCTAssertTrue(draft.morningRoutine.isEmpty)
        XCTAssertEqual(draft.bedtimeHour, 21)
        XCTAssertEqual(draft.windDownMinutes, 60)
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

    func testRoutineTextDoesNotBecomeTheBroaderOfflinePurpose() {
        var draft = OnboardingDraft()
        draft.eveningCueText = "Finish my watercolor"
        draft.morningCueText = "Sit by the window"

        let preferences = draft.makeNightWatchPreferences()
        let purpose = draft.makeOfflinePurpose()

        XCTAssertEqual(preferences.eveningCueText, "Finish my watercolor")
        XCTAssertEqual(preferences.morningCueText, "Sit by the window")
        XCTAssertNil(purpose.customText)
        XCTAssertEqual(purpose.category, .rest)
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

    func testReminderChoiceSurvivesConfigurationAndManualStartRemainsTheDefault() {
        var draft = OnboardingDraft()
        draft.remindersEnabled = true

        XCTAssertTrue(draft.makeNotificationPreferences().remindersEnabled)
        XCTAssertFalse(draft.makeNightWatchPreferences().automaticStartEnabled)
        XCTAssertFalse(draft.makePrimaryWindDownRoutine().automaticStartEnabled)
    }

    func testReadinessReportsActualProtectionAndNotificationAuthorization() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        var draft = OnboardingDraft()
        draft.remindersEnabled = true
        draft.eveningRoutine = [.suggested(.read, phase: .evening)]
        draft.morningRoutine = [.suggested(.openCurtains, phase: .morning)]

        let denied = OnboardingReadinessSummary(
            draft: draft,
            appProtectionReady: false,
            notificationAuthorized: false,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(denied.reminderReadiness, .enabledWithoutAuthorization)
        XCTAssertFalse(denied.appProtectionReady)
        XCTAssertFalse(denied.startsAutomatically)
        XCTAssertEqual(denied.eveningAnchors, ["Put phone away", "Read a paper book"])

        let ready = OnboardingReadinessSummary(
            draft: draft,
            appProtectionReady: true,
            notificationAuthorized: true,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(ready.reminderReadiness, .enabledAndAuthorized)
        XCTAssertTrue(ready.appProtectionReady)
    }

    func testPastTodaysEligibleStartUsesNextWindDown() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 26, hour: 23, minute: 15
        )))
        let summary = OnboardingReadinessSummary(
            draft: OnboardingDraft(),
            appProtectionReady: true,
            notificationAuthorized: false,
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(summary.isLaterToday)
        XCTAssertEqual(calendar.component(.day, from: summary.nextWindDownStart), 27)
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
        XCTAssertEqual(normalized.map(\.title), ["First idea", "Read a paper book", "Stretch or move gently"])
        XCTAssertFalse(normalized.contains { $0.title == WindDownRoutineStep.phoneAwayTitle })
    }

    func testMorningRoutineLimitsRetainTheFirstTwoOrderedIdeas() {
        let normalized = WindDownRoutineStep.normalized([
            .suggested(.openCurtains, phase: .morning),
            .custom("Water the windowsill plants", phase: .morning),
            .suggested(.makeBed, phase: .morning)
        ], for: .morning)

        XCTAssertEqual(normalized.map(\.title), ["Open the curtains", "Water the windowsill plants"])
        XCTAssertEqual(normalized.count, WindDownRoutineStep.maximumMorningCount)
    }

    func testTheFirstOrderedSuggestionCannotBeOverriddenByALaterCustomIdea() {
        var preferences = NightWatchPreferences.defaults
        preferences.eveningRoutine = [
            .suggested(.read, phase: .evening),
            .custom("A later private idea", phase: .evening)
        ]
        preferences.syncLegacyFieldsFromRoutine()

        XCTAssertEqual(preferences.eveningActivity, .read)
        XCTAssertNil(preferences.eveningCueText)
        XCTAssertEqual(
            preferences.presentedEveningRoutineTitles,
            ["Put phone away", "Read a paper book", "A later private idea"]
        )
    }

    func testCuratedMorningAndEveningAdditionsUseExistingRoutineModel() {
        XCTAssertTrue(PhoneFreeActivity.eveningChoices.contains(.brushTeeth))
        XCTAssertTrue(PhoneFreeActivity.eveningChoices.contains(.quietConversation))
        XCTAssertTrue(PhoneFreeActivity.eveningChoices.contains(.brainDump))
        XCTAssertTrue(PhoneFreeActivity.eveningChoices.contains(.sleepwear))
        XCTAssertTrue(PhoneFreeActivity.eveningChoices.contains(.relaxation))
        XCTAssertTrue(PhoneFreeActivity.eveningChoices.contains(.quietMusic))
        XCTAssertTrue(PhoneFreeActivity.eveningChoices.contains(.calmHobby))
        XCTAssertTrue(PhoneFreeActivity.morningChoices.contains(.makeBed))
        XCTAssertEqual(PhoneFreeActivity.morningChoices.filter { $0 != .journal }.count, 6)
        XCTAssertFalse(PhoneFreeActivity.read.onboardingRationale.isEmpty)
        XCTAssertEqual(WindDownRoutineStep.custom(String(repeating: "x", count: 100), phase: .evening).title.count, 80)
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
