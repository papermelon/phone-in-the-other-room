import XCTest

final class ShieldingReadinessTests: XCTestCase {

    func testEarlyWakeSkipRemainsAvailableWhenNewMorningProtectionNeedsRepair() {
        XCTAssertTrue(EarlyWakeProtectionStartPolicy.canCommit(intent: .skipToday, readiness: .noSelection))
        XCTAssertFalse(EarlyWakeProtectionStartPolicy.canCommit(intent: .startNow, readiness: .noSelection))
        XCTAssertFalse(EarlyWakeProtectionStartPolicy.canCommit(intent: .deferToUsualTime, readiness: .revoked))
        XCTAssertTrue(EarlyWakeProtectionStartPolicy.canCommit(intent: .keepWindDownRunning, readiness: .denied))
    }
    func testReadyExplainsSelectedApps() {
        XCTAssertEqual(ShieldingReadiness.ready.title, "App protection is ready")
        XCTAssertTrue(ShieldingReadiness.ready.detail.contains("chosen apps and categories"))
    }

    func testMissingShieldingIntentDefaultsOnButExplicitFalseStaysOff() {
        XCTAssertTrue(QuietTimeShieldingIntentPolicy.savedIntent(nil))
        XCTAssertTrue(QuietTimeShieldingIntentPolicy.savedIntent(true))
        XCTAssertFalse(QuietTimeShieldingIntentPolicy.savedIntent(false))
    }

    func testNoSelectionIsActionable() {
        XCTAssertNotEqual(ShieldingReadiness.noSelection, .ready)
        XCTAssertTrue(ShieldingReadiness.noSelection.detail.contains("at least one"))
    }

    func testDeniedRequiresRepairInsteadOfFallback() {
        XCTAssertFalse(ShieldingReadiness.denied.canStartProtectedSession)
        XCTAssertFalse(ScreenTimeProtectionStartPolicy.canStart(.denied))
    }

    func testEveryUnavailableOrRuntimeStateBlocksNewProtectedStarts() {
        let blocked: [ShieldingReadiness] = [
            .authorizationRequired, .denied, .revoked, .unavailable, .noSelection, .runtimeFailure
        ]
        for readiness in blocked {
            XCTAssertFalse(readiness.canStartProtectedSession)
            XCTAssertFalse(ScreenTimeProtectionStartPolicy.canStart(readiness))
        }
    }

    func testHomeUsesOnlyARepairActionUntilProtectionIsReady() {
        XCTAssertEqual(
            HomeProtectionStartPresentation.resolve(
                readiness: .ready,
                selectionSummary: "2 apps, 1 category"
            ),
            .ready(selectionSummary: "2 apps, 1 category")
        )
        XCTAssertEqual(
            HomeProtectionStartPresentation.resolve(
                readiness: .noSelection,
                selectionSummary: "None selected"
            ),
            .repair(title: "Choose apps to pause", detail: ShieldingReadiness.noSelection.detail)
        )
        for readiness in [ShieldingReadiness.authorizationRequired, .denied, .revoked, .unavailable, .runtimeFailure] {
            XCTAssertEqual(
                HomeProtectionStartPresentation.resolve(readiness: readiness, selectionSummary: "2 apps"),
                .repair(title: "Set up app protection", detail: readiness.detail)
            )
        }
    }

    func testAutomaticWindDownRequiresCurrentProtectionReadiness() {
        XCTAssertEqual(AutomaticWindDownProtectionDecision.resolve(readiness: .ready), .schedule)
        for readiness in [ShieldingReadiness.authorizationRequired, .denied, .revoked, .unavailable, .noSelection, .runtimeFailure] {
            XCTAssertEqual(
                AutomaticWindDownProtectionDecision.resolve(readiness: readiness),
                .needsRepair(readiness)
            )
        }
    }

    func testOpaqueSelectionRequiresSelfConfirmationWithoutNamedVerification() {
        XCTAssertEqual(
            ScreenTimeSelectionPresentation.confirmation(appCount: 0, categoryCount: 0, userConfirmed: false),
            .needsSelection
        )
        XCTAssertEqual(
            ScreenTimeSelectionPresentation.confirmation(appCount: 2, categoryCount: 1, userConfirmed: false),
            .needsConfirmation(appCount: 2, categoryCount: 1)
        )
        XCTAssertEqual(
            ScreenTimeSelectionPresentation.confirmation(appCount: 2, categoryCount: 1, userConfirmed: true),
            .confirmed(appCount: 2, categoryCount: 1)
        )
        XCTAssertFalse(ScreenTimeSelectionSelfConfirmation.needsConfirmation(appCount: 1, categoryCount: 0).prompt.localizedCaseInsensitiveContains("verified"))
    }

    func testLegacyOnboardingDraftDoesNotGainASelectionConfirmation() throws {
        // Existing drafts encode `CountingSheepOnboardingStep` as its raw Int.
        // Omit the newly added confirmation field to model a real legacy draft.
        let data = Data("{\"step\":3,\"shieldingEnabled\":true}".utf8)
        let draft = try JSONDecoder().decode(OnboardingDraft.self, from: data)
        XCTAssertEqual(draft.step, .protection)
        XCTAssertFalse(draft.protectionSelectionSelfConfirmed)
    }

    func testPurposeCueClearsOnlyForMatchingOccurrenceIdentity() {
        let suiteName = "ShieldingReadinessTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return XCTFail("Expected defaults suite") }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let occurrence = UUID()
        let cue = QuietPurposeCueState(occurrenceID: occurrence, revision: 3, epoch: 7, cue: .read)
        QuietPurposeCueState.save(cue, to: defaults)
        QuietPurposeCueState.clear(occurrenceID: occurrence, revision: 3, epoch: 8, from: defaults)
        XCTAssertEqual(QuietPurposeCueState.load(from: defaults), cue)
        QuietPurposeCueState.clear(occurrenceID: occurrence, revision: 3, epoch: 7, from: defaults)
        XCTAssertNil(QuietPurposeCueState.load(from: defaults))
    }

    func testPurposeCueLoadRequiresTheCurrentRegistryIdentity() {
        let suiteName = "ShieldingReadinessTests.identity.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return XCTFail("Expected defaults suite") }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let occurrence = UUID()
        let cue = QuietPurposeCueState(occurrenceID: occurrence, revision: 4, epoch: 9, cue: .read)
        QuietPurposeCueState.save(cue, to: defaults)

        XCTAssertEqual(
            QuietPurposeCueState.load(
                matching: occurrence,
                revision: 4,
                epoch: 9,
                from: defaults
            ),
            cue
        )
        XCTAssertNil(
            QuietPurposeCueState.load(
                matching: occurrence,
                revision: 5,
                epoch: 9,
                from: defaults
            )
        )
    }

    func testPurposeCueHasShortActiveSessionLabels() {
        XCTAssertEqual(QuietPurposeCue.prepareForSleep.appFacingTitle, "Rest")
        XCTAssertEqual(QuietPurposeCue.read.appFacingTitle, "Reading")
        XCTAssertEqual(QuietPurposeCue.focusOnWork.appFacingTitle, "Work")
        XCTAssertEqual(QuietPurposeCue.somethingOffline.appFacingTitle, "Time offline")
    }

    func testRunRequestIsTheShieldingPolicyNotMutableFutureIntent() {
        let start = Date(timeIntervalSince1970: 1_000)
        let run = FocusRun(
            plannedDurationSeconds: 600,
            startedAt: start,
            state: .running,
            guardKind: .honorTimer,
            appShieldingRequested: true
        )

        XCTAssertTrue(QuietTimeShieldingPolicy.shouldShield(run: run, at: start.addingTimeInterval(60), isEnabled: true))
        XCTAssertTrue(QuietTimeShieldingPolicy.shouldShield(run: run, at: start.addingTimeInterval(60), isEnabled: false))
    }

    func testNFCOnlyGatesShieldingUntilAuthentication() {
        let start = Date(timeIntervalSince1970: 1_000)
        var run = FocusRun(
            plannedDurationSeconds: 600,
            startedAt: start,
            state: .placementGrace,
            guardKind: .nfcTag,
            appShieldingRequested: true
        )
        XCTAssertFalse(QuietTimeShieldingPolicy.shouldShield(run: run, at: start.addingTimeInterval(60), isEnabled: true))
        run.placementStatus = .confirmed
        run.state = .running
        XCTAssertTrue(QuietTimeShieldingPolicy.shouldShield(run: run, at: start.addingTimeInterval(60), isEnabled: true))
    }
}
