import XCTest

final class OnboardingTests: XCTestCase {
    func testDefaultsLeadWithAppShieldingAndScheduledStart() {
        let draft = OnboardingDraft.defaults()

        XCTAssertEqual(draft.protectionChoice, .appShielding)
        XCTAssertEqual(draft.selectedGuardKind, .honorTimer)
        XCTAssertTrue(draft.shieldingEnabled)
        XCTAssertTrue(draft.automaticStartEnabled)
        XCTAssertTrue(draft.remindersEnabled)
        XCTAssertEqual(draft.windDownMinutes, 30)
        XCTAssertEqual(draft.morningQuietMinutes, 30)
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
}
