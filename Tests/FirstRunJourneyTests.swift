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

    func testHomeAndFarmChaptersStaySeparateAndChapterScoped() {
        var state = CountingSheepOrientationState.fresh
        XCTAssertEqual(FirstRunJourney.count(for: .homeBasics), 4)
        XCTAssertEqual(FirstRunJourney.count(for: .farmTour), 4)
        XCTAssertFalse(FirstRunJourney.visibleSteps(for: .homeBasics).contains(.practiceOffer))

        for step in FirstRunJourney.visibleSteps(for: .homeBasics).dropLast() {
            XCTAssertEqual(state.currentStep, step)
            state.advanceTour()
            XCTAssertEqual(state.status, .inProgress)
        }
        state.advanceTour()
        XCTAssertEqual(state.completedChapters, [.homeBasics])
        XCTAssertNil(state.activeChapter)
        XCTAssertEqual(state.presentationState, .idle)
        XCTAssertFalse(state.isComplete)

        state.offerChapter(.farmTour)
        XCTAssertEqual(FirstRunJourney.number(for: state.currentStep, chapter: .farmTour), 1)
        XCTAssertEqual(FirstRunJourney.count(for: .farmTour), 4)
    }

    func testSkippingDoesNotGrantRewardsOrRepeatFarmActions() {
        var state = CountingSheepOrientationState.fresh
        state.skipCurrentLesson()
        XCTAssertTrue(state.skippedLessons.contains(.home))
        XCTAssertFalse(state.hasRecorded(.skippedShear))

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
        state.recordPracticeCompleted()
        XCTAssertTrue(state.milestones.contains(.practiceCompleted))
        XCTAssertEqual(state.currentStep, .home)

        XCTAssertFalse(state.practiceRewardRoutedToFarm)
        state.markPracticeRewardRoutedToFarm()
        state.markPracticeRewardRoutedToFarm()
        XCTAssertTrue(state.practiceRewardRoutedToFarm)
    }

    func testProfileGiftIsNotPartOfTheFarmChapter() {
        XCTAssertFalse(FirstRunJourney.visibleSteps(for: .farmTour).contains(.farmClaimWearable))
        XCTAssertFalse(FirstRunJourney.visibleSteps(for: .farmTour).contains(.farmEquipWearable))
    }

    func testSlumberPartyIsNotInTheUniversalJourney() {
        XCTAssertFalse(FirstRunJourney.visibleSteps(for: .homeBasics).contains(.slumberParty))
        XCTAssertFalse(FirstRunJourney.visibleSteps(for: .farmTour).contains(.slumberParty))
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
        state.dismiss()
        XCTAssertTrue(state.shouldShowContinueCard(isCoachMarkPresented: false))
        state.resume()
        XCTAssertEqual(state.currentStep, .start)
        XCTAssertFalse(state.shouldShowContinueCard(isCoachMarkPresented: true))
        XCTAssertEqual(state.status, .inProgress)
        XCTAssertEqual(state.currentStep, .start)
        XCTAssertFalse(state.continueCardDismissed)
        XCTAssertFalse(state.shouldShowContinueCard(isCoachMarkPresented: false))
    }

    func testResumeWhileInProgressKeepsTheCurrentLesson() {
        var state = CountingSheepOrientationState.fresh
        state.offerChapter(.farmTour)
        state.startOfferedChapter()
        state.currentStep = .farmShop
        state.dismiss()
        state.resume()
        XCTAssertEqual(state.status, .inProgress)
        XCTAssertEqual(state.currentStep, .farmShop)
        let destination = FirstRunJourney.resumeDestination(for: state)
        XCTAssertEqual(destination?.surface, .farm)
        XCTAssertFalse(destination?.presentPracticeOffer ?? true)

        state.currentStep = .practiceOffer
        XCTAssertEqual(FirstRunJourney.resumeDestination(for: state)?.presentPracticeOffer, true)
    }

    func testFarmTourIsOfferedBeforeItCanBeActive() {
        var state = CountingSheepOrientationState.fresh
        state.completeChapter(.homeBasics)
        state.offerChapter(.farmTour)
        XCTAssertEqual(state.presentationState, .offered)
        state.startOfferedChapter()
        XCTAssertEqual(state.presentationState, .active)
        XCTAssertEqual(state.currentStep, .farmMeetSheep)
    }

    func testEverySchemaFiveStepMigratesToARealChapterOrContextualDestination() throws {
        let legacySteps: [CountingSheepOrientationStep] = [
            .home, .start, .phoneAway, .practiceOffer, .practiceReward,
            .farmMeetSheep, .farmCapacity, .farmWool, .farmShear, .farmCurrency,
            .farmClaimWearable, .farmEquipWearable, .farmShop, .farmSearch,
            .slumberParty, .settings, .nights, .completion
        ]

        for step in legacySteps {
            let data = try JSONSerialization.data(withJSONObject: [
                "schemaVersion": 5,
                "status": "inProgress",
                "currentStep": step.rawValue,
                "milestones": []
            ])
            let state = try JSONDecoder().decode(CountingSheepOrientationState.self, from: data)
            XCTAssertEqual(state.schemaVersion, CountingSheepOrientationState.currentSchemaVersion, step.rawValue)
            if step == .completion {
                XCTAssertEqual(state.completedChapters, Set(FirstRunGuideChapter.allCases))
            } else {
                XCTAssertNotNil(FirstRunJourney.resumeDestination(for: state), step.rawValue)
            }
            if step == .farmClaimWearable || step == .farmEquipWearable {
                XCTAssertFalse(state.hasRecorded(.claimedWearable), step.rawValue)
                XCTAssertFalse(state.hasRecorded(.equippedWearable), step.rawValue)
            }
        }
    }

    func testResumeDestinationIncludesPresentationAndRootReset() {
        var state = CountingSheepOrientationState.fresh
        state.advanceTour()
        state.dismiss()
        let destination = try! XCTUnwrap(FirstRunJourney.resumeDestination(for: state))
        XCTAssertEqual(destination.surface, .home)
        XCTAssertTrue(destination.resetNavigation)
        XCTAssertEqual(destination.presentation, .coachMark)
        XCTAssertEqual(destination.chapter, .homeBasics)
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
