import XCTest

final class AccountFarmOwnershipTests: XCTestCase {
    func testUsernamesAreCanonicalAndDoNotAcceptEmailOrUnicodeLookalikes() {
        XCTAssertEqual(AccountUsername.normalized(" @Shepherd_12 "), "shepherd_12")
        for invalid in ["ab", "1abc", "a@b.com", "shep herd", "shеpherd", String(repeating: "a", count: 25)] {
            XCTAssertNil(AccountUsername.normalized(invalid), invalid)
        }
    }

    func testOnlyVerifiedPasswordOrAppleIdentitySupportsAccounts() {
        XCTAssertTrue(AccountIdentityEvidence.isSupported(isAnonymous: false, providers: ["email"], emailVerified: true))
        XCTAssertTrue(AccountIdentityEvidence.isSupported(isAnonymous: false, providers: ["apple"], emailVerified: false))
        XCTAssertFalse(AccountIdentityEvidence.isSupported(isAnonymous: false, providers: ["email"], emailVerified: false))
        XCTAssertFalse(AccountIdentityEvidence.isSupported(isAnonymous: true, providers: ["apple", "email"], emailVerified: true))
        XCTAssertFalse(AccountIdentityEvidence.isSupported(isAnonymous: false, providers: ["unknown"], emailVerified: true))
    }

    func testPasswordRecoveryIsBoundToTheExpectedUUID() {
        let a = UUID(), b = UUID()
        XCTAssertEqual(NightFlockAccountSessionPolicy.decide(observed: .passwordLinked(a), expectedIdentity: .valid(a), createAnonymousIfMissing: true), .returnLinked(adopting: nil))
        XCTAssertEqual(NightFlockAccountSessionPolicy.decide(observed: .passwordLinked(b), expectedIdentity: .valid(a), createAnonymousIfMissing: true), .failClosed(signOutLocalSession: true))
    }

    func testDocumentRejectsMismatchedOwnerAndExposedSignedOutValues() throws {
        let backup = FarmBackupSync(ownerID: UUID(), generation: UUID())
        XCTAssertThrowsError(try FarmSaveDocument(lineageID: UUID(), generation: 1, values: [:], backup: backup, accountScope: .account(UUID())).validated())
        XCTAssertThrowsError(try FarmSaveDocument(lineageID: UUID(), generation: 1,
            values: ["ollie.rewards": JSONEncoder().encode([RewardItem]())], accountScope: .signedOut).validated())
    }
}

extension AccountFarmOwnershipTests {
    func testAttachedSocialWorkRequiresMatchingCommittedFarmOwner() {
        let owner = UUID()
        XCTAssertFalse(FarmAccountSocialOwnerGate.permits(
            sharedFarmAttached: true, activeFarmOwner: nil, expectedIdentity: owner
        ))
        XCTAssertFalse(FarmAccountSocialOwnerGate.permits(
            sharedFarmAttached: true, activeFarmOwner: UUID(), expectedIdentity: owner
        ))
        XCTAssertTrue(FarmAccountSocialOwnerGate.permits(
            sharedFarmAttached: true, activeFarmOwner: owner, expectedIdentity: owner
        ))
        XCTAssertTrue(FarmAccountSocialOwnerGate.permits(
            sharedFarmAttached: false, activeFarmOwner: nil, expectedIdentity: nil
        ))
    }
}
