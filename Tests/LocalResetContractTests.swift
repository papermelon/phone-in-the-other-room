import XCTest

final class LocalResetContractTests: XCTestCase {
    private var standardDefaults: UserDefaults!
    private var appGroupDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        standardDefaults = UserDefaults(suiteName: "counting-sheep-reset-tests.standard")!
        appGroupDefaults = UserDefaults(suiteName: "counting-sheep-reset-tests.group")!
        standardDefaults.removePersistentDomain(forName: "counting-sheep-reset-tests.standard")
        appGroupDefaults.removePersistentDomain(forName: "counting-sheep-reset-tests.group")
    }

    override func tearDown() {
        standardDefaults.removePersistentDomain(forName: "counting-sheep-reset-tests.standard")
        appGroupDefaults.removePersistentDomain(forName: "counting-sheep-reset-tests.group")
        standardDefaults = nil
        appGroupDefaults = nil
        super.tearDown()
    }

    func testResetRemovesOwnedStateButLeavesUnrelatedDefaultsAlone() {
        let unrelatedStandardKey = "another.app.setting"
        let unrelatedAppGroupKey = "another.extension.setting"
        standardDefaults.set("keep", forKey: unrelatedStandardKey)
        appGroupDefaults.set("keep", forKey: unrelatedAppGroupKey)

        CountingSheepOwnedStorage.standardKeys.forEach { standardDefaults.set(Data([1]), forKey: $0) }
        CountingSheepOwnedStorage.appGroupKeys.forEach { appGroupDefaults.set(Data([1]), forKey: $0) }

        CountingSheepOwnedStorage.clear(
            standardDefaults: standardDefaults,
            appGroupDefaults: appGroupDefaults
        )

        XCTAssertEqual(standardDefaults.string(forKey: unrelatedStandardKey), "keep")
        XCTAssertEqual(appGroupDefaults.string(forKey: unrelatedAppGroupKey), "keep")
        XCTAssertTrue(CountingSheepOwnedStorage.standardKeys.allSatisfy {
            standardDefaults.object(forKey: $0) == nil
        })
        XCTAssertTrue(CountingSheepOwnedStorage.appGroupKeys.allSatisfy {
            appGroupDefaults.object(forKey: $0) == nil
        })
    }

    func testResetRemovesOnlyOwnedDynamicSensitiveRunKeys() {
        let emergencyExitKey = "ollie.emergencyExit.reason.\(UUID().uuidString)"
        let similarlyNamedUnrelatedKey = "ollie.emergencyExit.reasoning.unrelated"
        standardDefaults.set("remove", forKey: emergencyExitKey)
        standardDefaults.set("keep", forKey: similarlyNamedUnrelatedKey)
        standardDefaults.set("keep", forKey: "ollie.installationID")

        CountingSheepOwnedStorage.clearStandardDefaults(standardDefaults)

        XCTAssertNil(standardDefaults.object(forKey: emergencyExitKey))
        XCTAssertEqual(standardDefaults.string(forKey: similarlyNamedUnrelatedKey), "keep")
        XCTAssertEqual(standardDefaults.string(forKey: "ollie.installationID"), "keep")
    }

    func testOnboardingAndOrientationResetToFreshState() throws {
        standardDefaults.set(CountingSheepOnboarding.currentVersion, forKey: CountingSheepOnboarding.versionKey)
        standardDefaults.set(
            try JSONEncoder().encode(OnboardingDraft(step: .protection)),
            forKey: CountingSheepOnboarding.draftKey
        )
        standardDefaults.set(
            try JSONEncoder().encode(CountingSheepOrientationState(
                status: .completed,
                milestones: Set(CountingSheepOrientationMilestone.allCases)
            )),
            forKey: "ollie.orientation.state"
        )

        CountingSheepOwnedStorage.clearStandardDefaults(standardDefaults)

        XCTAssertNil(standardDefaults.object(forKey: CountingSheepOnboarding.versionKey))
        XCTAssertNil(standardDefaults.object(forKey: CountingSheepOnboarding.draftKey))
        XCTAssertNil(standardDefaults.object(forKey: "ollie.orientation.state"))
        XCTAssertEqual(OnboardingDraft.defaults().step, .welcome)
        XCTAssertEqual(CountingSheepOrientationState.fresh.farmTutorialActions, [])
        XCTAssertFalse(CountingSheepOrientationState.fresh.continueCardDismissed)
    }

    func testFreshNightWatchDefaultsHaveNoSavedPlanOrSchedule() {
        XCTAssertFalse(NightWatchPreferences.defaults.isConfigured)
        XCTAssertTrue(WindDownScheduleState().routines.isEmpty)
        XCTAssertTrue(WindDownScheduleState().oneTimePeriods.isEmpty)
    }

    func testActiveRunCannotAwardProgressOrSearchThroughResetPath() throws {
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan(
            intendedBedtime: startedAt.addingTimeInterval(30 * 60),
            wakeTime: startedAt.addingTimeInterval(8 * 60 * 60),
            protectedUntil: startedAt.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let run = FocusRun(
            plannedDurationSeconds: plan.protectedUntil.timeIntervalSince(startedAt),
            startedAt: startedAt,
            state: .running,
            guardKind: .honorTimer,
            nightWatchPlan: plan
        )
        let current = UserProgress(
            totalCompletedRuns: 2,
            totalFocusMinutes: 120,
            currentStreak: 2,
            longestStreak: 2,
            rewardsCollected: 2,
            ollieLevel: 1
        )

        XCTAssertNil(RewardEngine().generateReward(for: run, progress: current))
        XCTAssertEqual(RewardEngine().updatedProgress(after: run, current: current, reward: nil), current)
    }

    func testRootRouterUsesFreshOnboardingAfterResetInTheSameProcess() {
        XCTAssertEqual(
            CountingSheepRootRoute.resolve(
                onboardingVersion: 0,
                currentOnboardingVersion: CountingSheepOnboarding.currentVersion,
                hasOnboardingDraft: false,
                hasConfiguredNightWatch: false,
                hasActiveRun: false
            ),
            .freshOnboarding
        )
        XCTAssertEqual(
            CountingSheepRootRoute.resolve(
                onboardingVersion: 0,
                currentOnboardingVersion: CountingSheepOnboarding.currentVersion,
                hasOnboardingDraft: true,
                hasConfiguredNightWatch: false,
                hasActiveRun: false
            ),
            .resumeOnboarding
        )
        XCTAssertEqual(
            CountingSheepRootRoute.resolve(
                onboardingVersion: CountingSheepOnboarding.currentVersion,
                currentOnboardingVersion: CountingSheepOnboarding.currentVersion,
                hasOnboardingDraft: true,
                hasConfiguredNightWatch: true,
                hasActiveRun: false
            ),
            .home
        )
    }

    func testResetContractIncludesNFCScreenTimeShieldHistoryAndAppearanceKeys() {
        let requiredStandardKeys = [
            "ollie.phoneBedNFCTag.registration",
            "ollie.phoneBedNFCTags.library",
            "ollie.screenTime.reportPreferences",
            "ollie.nightWatch.history",
            "ollie.sheepSearch.state",
            "ollie.farm.state",
            "ollie.welcome.rewards",
            "ollie.nightFlock.rewards",
            "ollie.nightFlock.expectedLinkedUserID",
            "ollie.nightFlock.stagedDestructiveEffect",
            "ollie.nightFlock.pendingDestructiveIntent",
            "ollie.nightFlock.pendingAccountDeletionIntent",
            "ollie.nightFlock.acceptedAccountDeletion",
            "ollie.windDown.profile",
            AppAppearancePreference.key
        ]
        let requiredAppGroupKeys = [
            QuietTimeShieldSharedStorage.scheduleKey,
            QuietTimeShieldSharedStorage.statusKey,
            QuietTimeShieldSharedStorage.statusHistoryKey,
            QuietTimeShieldSharedStorage.briefAccessStateKey,
            ScreenTimeSharedStorage.selectionKey(for: .bedtime)
        ]

        XCTAssertTrue(requiredStandardKeys.allSatisfy(CountingSheepOwnedStorage.standardKeys.contains))
        XCTAssertTrue(requiredAppGroupKeys.allSatisfy(CountingSheepOwnedStorage.appGroupKeys.contains))
    }

    func testTransportIdentityIsAuditedButNotProductResetState() {
        XCTAssertEqual(CountingSheepOwnedStorage.preservedTransportKeys, ["ollie.installationID"])
        XCTAssertFalse(CountingSheepOwnedStorage.standardKeys.contains("ollie.installationID"))
        XCTAssertEqual(
            CountingSheepOwnedStorage.dynamicStandardKeyPrefixes,
            ["ollie.emergencyExit.reason."]
        )
    }
}
