import XCTest

final class FirstRunJourneyTests: XCTestCase {
    func testOldOnboardingDraftMigratesWithoutShiftingLegacyRawValues() throws {
        XCTAssertEqual(CountingSheepOnboardingStep.welcome.rawValue, 0)
        XCTAssertEqual(CountingSheepOnboardingStep.ready.rawValue, 5)
        XCTAssertEqual(CountingSheepOnboardingStep.profile.rawValue, 6)
        XCTAssertEqual(
            CountingSheepOnboardingStep.visibleSteps,
            [.welcome, .profile, .recommendation, .schedule, .quiet, .protection, .gift, .ready]
        )

        var legacy = OnboardingDraft()
        legacy.step = .schedule
        let decoded = try JSONDecoder().decode(OnboardingDraft.self, from: JSONEncoder().encode(legacy))
        XCTAssertEqual(decoded.step, .schedule)
        XCTAssertEqual(decoded.welcomePage, .countingSheep)
        XCTAssertFalse(decoded.profileSkipped)
    }

    func testLegacyOrientationStateMigratesIntoTheExpandedJourney() throws {
        let data = Data(#"{"schemaVersion":4,"status":"inProgress","currentStep":"navigation","milestones":["homeExplained"]}"#.utf8)
        let state = try JSONDecoder().decode(CountingSheepOrientationState.self, from: data)

        XCTAssertEqual(state.schemaVersion, CountingSheepOrientationState.currentSchemaVersion)
        XCTAssertEqual(state.currentStep, .phoneAway)
        XCTAssertEqual(state.status, .inProgress)
        XCTAssertTrue(state.milestones.contains(.homeExplained))
        XCTAssertTrue(state.skippedLessons.isEmpty)
        XCTAssertFalse(state.continueCardDismissed)
    }

    func testCompletedLegacyTourStaysCompleteAndDoesNotRestart() throws {
        let data = Data(#"{"schemaVersion":4,"status":"completed","currentStep":"navigation","milestones":[]}"#.utf8)
        var state = try JSONDecoder().decode(CountingSheepOrientationState.self, from: data)

        XCTAssertTrue(state.isComplete)
        state.advanceTour()
        XCTAssertTrue(state.isComplete)
        XCTAssertFalse(state.shouldShowContinueCard(isCoachMarkPresented: false))
    }

    func testEveryJourneyStepResumesInOrderIncludingOptionalPracticeReward() {
        var state = CountingSheepOrientationState.fresh
        var context = FirstRunAdvanceContext.defaults
        let expectedWithoutPractice = FirstRunJourney.visibleSteps(context: context)
        XCTAssertFalse(expectedWithoutPractice.contains(.practiceReward))

        for step in expectedWithoutPractice.dropLast() {
            XCTAssertEqual(state.currentStep, step)
            state.advanceTour(context: context)
            XCTAssertEqual(state.status, .inProgress)
        }
        XCTAssertEqual(state.currentStep, .completion)
        state.advanceTour(context: context)
        XCTAssertTrue(state.isComplete)

        state = .fresh
        context.practiceCompleted = true
        state.currentStep = .practiceOffer
        state.status = .inProgress
        state.recordPracticeCompleted(context: context)
        XCTAssertEqual(state.currentStep, .practiceReward)
        state.advanceTour(context: context)
        XCTAssertEqual(state.currentStep, .farmMeetSheep)
    }

    func testSkippingDoesNotGrantRewardsOrRepeatFarmActions() {
        var state = CountingSheepOrientationState.fresh
        state.status = .inProgress
        state.currentStep = .practiceOffer
        state.skipCurrentLesson(context: .defaults)

        XCTAssertTrue(state.skippedLessons.contains(.practiceOffer))
        XCTAssertFalse(state.milestones.contains(.practiceCompleted))
        XCTAssertNil(state.practiceRunID)
        XCTAssertEqual(state.currentStep, .farmMeetSheep)

        state.currentStep = .farmShear
        state.skipCurrentLesson(context: .defaults)
        XCTAssertTrue(state.hasRecorded(.skippedShear))
        XCTAssertFalse(state.hasRecorded(.sheared))

        state.recordFarmAction(.sheared)
        state.recordFarmAction(.sheared)
        XCTAssertEqual(state.farmTutorialActions.filter { $0 == .sheared }.count, 1)
        XCTAssertTrue(state.hasRecorded(.skippedShear))

        state.recordFarmAction(.claimedWearable)
        state.recordFarmAction(.claimedWearable)
        XCTAssertTrue(state.hasRecorded(.claimedWearable))
        state.recordFarmAction(.equippedWearable)
        XCTAssertTrue(state.hasRecorded(.equippedWearable))
    }

    func testPracticeRewardRoutesToFarmOnce() {
        var state = CountingSheepOrientationState.fresh
        state.status = .inProgress
        state.currentStep = .practiceOffer
        state.recordPracticeCompleted()
        XCTAssertEqual(state.currentStep, .practiceReward)

        XCTAssertFalse(state.practiceRewardRoutedToFarm)
        state.markPracticeRewardRoutedToFarm()
        state.markPracticeRewardRoutedToFarm()
        XCTAssertTrue(state.practiceRewardRoutedToFarm)
    }

    func testProfileGiftRemainsPendingUntilClaimedAndSkipLeavesItPending() {
        var state = CountingSheepOrientationState.fresh
        let pendingContext = FirstRunAdvanceContext(
            practiceCompleted: false,
            slumberPartyAvailable: false,
            showClaimWearable: true,
            showEquipWearable: true
        )
        XCTAssertTrue(FirstRunJourney.visibleSteps(context: pendingContext).contains(.farmClaimWearable))

        state.status = .inProgress
        state.currentStep = .farmClaimWearable
        state.skipCurrentLesson(context: pendingContext)
        XCTAssertTrue(state.skippedLessons.contains(.farmClaimWearable))
        XCTAssertTrue(state.skippedLessons.contains(.farmEquipWearable))
        XCTAssertFalse(state.hasRecorded(.claimedWearable))
        XCTAssertEqual(state.currentStep, .farmShop)

        let claimedContext = FirstRunAdvanceContext(
            practiceCompleted: false,
            slumberPartyAvailable: false,
            showClaimWearable: false,
            showEquipWearable: true
        )
        XCTAssertFalse(FirstRunJourney.visibleSteps(context: claimedContext).contains(.farmClaimWearable))
        XCTAssertTrue(FirstRunJourney.visibleSteps(context: claimedContext).contains(.farmEquipWearable))

        var claimedState = CountingSheepOrientationState.fresh
        claimedState.status = .inProgress
        claimedState.currentStep = .farmClaimWearable
        claimedState.recordFarmAction(.claimedWearable)
        claimedState.advanceTour(context: claimedContext)
        XCTAssertEqual(claimedState.currentStep, .farmEquipWearable)
    }

    func testSlumberPartyUnavailabilityDoesNotBlockCompletion() {
        var state = CountingSheepOrientationState.fresh
        state.status = .inProgress
        state.currentStep = .slumberParty
        let context = FirstRunAdvanceContext(
            practiceCompleted: false,
            slumberPartyAvailable: false,
            showClaimWearable: false,
            showEquipWearable: false
        )
        state.acknowledgeSlumberPartyUnavailable()
        state.skipCurrentLesson(context: context)

        XCTAssertTrue(state.slumberPartyUnavailableAcknowledged)
        XCTAssertEqual(state.currentStep, .settings)
        state.advanceTour(context: context)
        XCTAssertEqual(state.currentStep, .nights)
        state.advanceTour(context: context)
        XCTAssertEqual(state.currentStep, .completion)
        state.advanceTour(context: context)
        XCTAssertTrue(state.isComplete)
    }

    func testContextualTipsDoNotAppearDuringAnActiveWindDown() {
        var state = CountingSheepOrientationState.fresh
        XCTAssertEqual(state.nextContextualTip(from: [.nights], isWindDownActive: false), .nights)
        XCTAssertNil(state.nextContextualTip(from: [.nights], isWindDownActive: true))
        state.markContextualTipSeen(.nights)
        XCTAssertNil(state.nextContextualTip(from: [.nights], isWindDownActive: false))
    }

    func testContinueCardPausesAndResumesWithoutErasingProgress() {
        var state = CountingSheepOrientationState.fresh
        state.advanceTour()
        XCTAssertEqual(state.currentStep, .start)
        XCTAssertTrue(state.shouldShowContinueCard(isCoachMarkPresented: false))
        XCTAssertFalse(state.shouldShowContinueCard(isCoachMarkPresented: true))

        state.dismissContinueCard()
        XCTAssertEqual(state.status, .dismissed)
        XCTAssertEqual(state.currentStep, .start)
        XCTAssertFalse(state.shouldShowContinueCard(isCoachMarkPresented: false))

        state.resume()
        XCTAssertEqual(state.status, .inProgress)
        XCTAssertEqual(state.currentStep, .start)
        XCTAssertFalse(state.continueCardDismissed)
        XCTAssertTrue(state.shouldShowContinueCard(isCoachMarkPresented: false))
    }

    func testResumeWhileInProgressKeepsTheCurrentLesson() {
        var state = CountingSheepOrientationState.fresh
        state.status = .inProgress
        state.currentStep = .farmShop
        state.resume()
        XCTAssertEqual(state.status, .inProgress)
        XCTAssertEqual(state.currentStep, .farmShop)
        let destination = FirstRunJourney.resumeDestination(for: state)
        XCTAssertEqual(destination?.surface, .farm)
        XCTAssertFalse(destination?.presentPracticeOffer ?? true)

        state.currentStep = .practiceOffer
        XCTAssertEqual(FirstRunJourney.resumeDestination(for: state)?.presentPracticeOffer, true)
    }

    func testSkippingAnAvailableSlumberPartyDoesNotMarkItUnavailable() {
        var state = CountingSheepOrientationState.fresh
        state.status = .inProgress
        state.currentStep = .slumberParty
        let available = FirstRunAdvanceContext(
            practiceCompleted: false,
            slumberPartyAvailable: true,
            showClaimWearable: false,
            showEquipWearable: false
        )
        state.skipCurrentLesson(context: available)
        XCTAssertFalse(state.slumberPartyUnavailableAcknowledged)
        XCTAssertEqual(state.currentStep, .settings)
    }

    func testRecommendationPrefillDoesNotDiagnoseAndKeepsSourceIDs() {
        var draft = OnboardingDraft()
        draft.profileAnswers = WindDownProfileAnswer(
            bedtimeHour: 22,
            bedtimeMinute: 0,
            wakeHour: 6,
            wakeMinute: 30,
            phoneUsePattern: .bothEdges,
            awayFriction: .habitReach,
            eveningActivities: [.read],
            morningActivities: [.openCurtains],
            desiredWindDownMinutes: 45
        )
        let recommendation = draft.profileRecommendation
        draft.applyRecommendation(recommendation)

        XCTAssertEqual(recommendation.displayName, "Wind Down starting point")
        XCTAssertEqual(FirstRunGuideCopy.recommendationTitle, "Your Wind Down starting point")
        XCTAssertEqual(recommendation.kind, .bothEdges)
        XCTAssertFalse(recommendation.summary.lowercased().contains("disorder"))
        XCTAssertFalse(recommendation.summary.lowercased().contains("insomnia"))
        XCTAssertEqual(draft.windDownMinutes, 45)
        XCTAssertEqual(draft.bedtimeHour, 22)
        XCTAssertFalse(recommendation.guidanceIDs.isEmpty)
        for id in recommendation.guidanceIDs {
            XCTAssertTrue(WindDownGuidanceLibrary.items.contains { $0.id == id })
        }
        XCTAssertEqual(
            FirstRunGuideCopy.recommendationDetail,
            "Based on what you told us, these ideas may be useful places to begin."
        )
    }

    func testSkippingTheRecommendationAfterCompletingTheQuestionnaireKeepsTheGift() {
        var draft = OnboardingDraft(step: .profile)
        XCTAssertEqual(draft.continueVisibleStep(), .grantStartingPoint)
        XCTAssertFalse(draft.profileSkipped)
        XCTAssertEqual(draft.step, .recommendation)

        XCTAssertEqual(draft.skipVisibleStep(), .keepCompletedProfile)
        XCTAssertFalse(draft.profileSkipped)
        XCTAssertEqual(draft.step, .schedule)
    }

    func testSkippingTheQuestionnaireDoesNotGrantAStartingPoint() {
        var draft = OnboardingDraft(step: .profile)
        XCTAssertEqual(draft.skipVisibleStep(), .skipQuestionnaire)
        XCTAssertTrue(draft.profileSkipped)
        XCTAssertEqual(draft.step, .schedule)
        XCTAssertEqual(draft.continueVisibleStep(), .none)
    }

    func testContinueFromRecommendationSignalsGrantWithoutMarkingTheProfileSkipped() {
        var draft = OnboardingDraft(step: .recommendation)
        XCTAssertEqual(draft.continueVisibleStep(), .grantStartingPoint)
        XCTAssertFalse(draft.profileSkipped)
        XCTAssertEqual(draft.step, .schedule)
    }

    func testWelcomeNarrativeAvoidsMedicalPromises() {
        for page in OnboardingWelcomePage.allCases {
            let haystack = "\(page.title) \(page.detail)".lowercased()
            XCTAssertFalse(haystack.contains("improve sleep"))
            XCTAssertFalse(haystack.contains("fix"))
            XCTAssertFalse(haystack.contains("insomnia"))
            XCTAssertFalse(haystack.contains("workshop"))
            XCTAssertFalse(haystack.contains("cohort"))
        }
        XCTAssertEqual(FirstRunGuideCopy.practiceGiftTitle(grantedNewSheep: true), "Ollie brought a second sheep home.")
        XCTAssertEqual(
            FirstRunGuideCopy.practiceGiftTitle(grantedNewSheep: false),
            "Practice is in Nights. Your welcome-gift sheep is still on the Farm."
        )
    }
}
