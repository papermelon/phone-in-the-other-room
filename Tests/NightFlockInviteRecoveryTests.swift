import Foundation
import XCTest

final class NightFlockInviteRecoveryTests: XCTestCase {
    func testMutationOwnershipRequiresTransportAndCurrentLobbyAuthority() {
        let flock = UUID(), expected = UUID()
        func owns(
            generation: UInt64 = 4, epoch: UInt64 = 8, transport: Bool = true,
            linked: Bool = true, keeper: Bool = true, currentFlock: UUID? = flock,
            pending: Bool = true, activeInvite: UUID? = expected
        ) -> Bool {
            NightFlockInviteMutationOwnershipPolicy.owns(
                capturedGeneration: 4, capturedTransportEpoch: 8,
                currentGeneration: generation, currentTransportEpoch: epoch,
                transportPermitted: transport, accountLinked: linked,
                keeperAuthorized: keeper, capturedFlockID: flock, currentFlockID: currentFlock,
                challengePending: pending, capturedExpectedInviteID: expected,
                currentActiveInviteID: activeInvite
            )
        }
        XCTAssertTrue(owns())
        XCTAssertFalse(owns(generation: 5))
        XCTAssertFalse(owns(epoch: 9))
        XCTAssertFalse(owns(transport: false))
        XCTAssertFalse(owns(linked: false))
        XCTAssertFalse(owns(keeper: false))
        XCTAssertFalse(owns(currentFlock: UUID()))
        XCTAssertFalse(owns(pending: false))
        XCTAssertFalse(owns(activeInvite: UUID()))
    }

    func testPlaintextVisibilityQuiescesForEveryRecoveryAndDeletionAmbiguity() {
        XCTAssertFalse(NightFlockInvitePlaintextVisibilityPolicy.shouldHide(authenticationAction: .none))
        for action in [
            NightFlockAuthenticationAction.reauthenticateApple,
            .linkCurrentAnonymousApple,
            .failClosed,
        ] {
            XCTAssertTrue(NightFlockInvitePlaintextVisibilityPolicy.shouldHide(authenticationAction: action))
        }
        XCTAssertTrue(NightFlockInvitePlaintextVisibilityPolicy.shouldHide(
            authenticationAction: .none, deletionSignal: .accepted
        ))
        XCTAssertTrue(NightFlockInvitePlaintextVisibilityPolicy.shouldHide(
            authenticationAction: .none, deletionSignal: .ambiguous
        ))
    }

    func testReconciliationAuthorityRejectsStaleAuthDeletionAndSnapshotContinuations() {
        let account = UUID()
        let flock = UUID()
        let challenge = UUID()
        let member = UUID()
        let invite = UUID()
        let captured = NightFlockInviteReconciliationSnapshotToken.present(
            flockID: flock,
            challengeID: challenge,
            challengeStatus: .pending,
            activeInviteID: invite,
            myMemberID: member,
            keeperAuthorized: true
        )
        func owns(
            generation: UInt64 = 7,
            epoch: UInt64 = 11,
            transport: Bool = true,
            linked: Bool = true,
            currentAccount: UUID? = account,
            returnedAccount: UUID? = account,
            currentSnapshot: NightFlockInviteReconciliationSnapshotToken? = nil
        ) -> Bool {
            NightFlockInviteReconciliationAuthorityPolicy.owns(
                capturedGeneration: 7,
                capturedTransportEpoch: 11,
                currentGeneration: generation,
                currentTransportEpoch: epoch,
                transportPermitted: transport,
                accountLinked: linked,
                capturedLinkedAccountID: account,
                currentLinkedAccountID: currentAccount,
                returnedLinkedAccountID: returnedAccount,
                capturedSnapshot: captured,
                currentSnapshot: currentSnapshot ?? captured
            )
        }

        XCTAssertTrue(owns())
        XCTAssertFalse(owns(epoch: 12, transport: false), "auth recovery invalidates the continuation")
        XCTAssertFalse(owns(generation: 8, transport: false), "ambiguous deletion invalidates the continuation")
        XCTAssertFalse(owns(currentSnapshot: .present(
            flockID: flock, challengeID: UUID(), challengeStatus: .pending,
            activeInviteID: invite, myMemberID: member, keeperAuthorized: true
        )), "a newer challenge in the same flock invalidates the continuation")
        XCTAssertFalse(owns(currentSnapshot: .present(
            flockID: UUID(), challengeID: challenge, challengeStatus: .pending,
            activeInviteID: invite, myMemberID: member, keeperAuthorized: true
        )), "a different lobby invalidates the continuation")
        XCTAssertFalse(owns(currentSnapshot: .present(
            flockID: flock, challengeID: challenge, challengeStatus: .pending,
            activeInviteID: UUID(), myMemberID: member, keeperAuthorized: true
        )), "a newer active invite invalidates the continuation")
        XCTAssertFalse(owns(linked: false))
        XCTAssertFalse(owns(currentAccount: UUID()))
        XCTAssertFalse(owns(returnedAccount: UUID()))
        XCTAssertFalse(owns(currentSnapshot: .present(
            flockID: flock, challengeID: challenge, challengeStatus: .pending,
            activeInviteID: invite, myMemberID: member, keeperAuthorized: false
        )))
    }

    func testNilReconciliationCannotClearAfterNewLobbyArrives() {
        let account = UUID()
        let currentLobby = NightFlockInviteReconciliationSnapshotToken.present(
            flockID: UUID(), challengeID: UUID(), challengeStatus: .pending,
            activeInviteID: UUID(), myMemberID: UUID(), keeperAuthorized: true
        )
        func owns(current: NightFlockInviteReconciliationSnapshotToken) -> Bool {
            NightFlockInviteReconciliationAuthorityPolicy.owns(
                capturedGeneration: 3,
                capturedTransportEpoch: 5,
                currentGeneration: 3,
                currentTransportEpoch: 5,
                transportPermitted: true,
                accountLinked: true,
                capturedLinkedAccountID: account,
                currentLinkedAccountID: account,
                returnedLinkedAccountID: account,
                capturedSnapshot: .absent,
                currentSnapshot: current
            )
        }
        XCTAssertTrue(owns(current: .absent))
        XCTAssertFalse(owns(current: currentLobby))
    }

    func testUnresolvedAccountLookupHidesOnlyForCurrentContinuation() {
        XCTAssertEqual(
            NightFlockInviteUnresolvedLookupPolicy.action(continuationOwned: true),
            .hidePlaintextPreservingCredential
        )
        XCTAssertEqual(
            NightFlockInviteUnresolvedLookupPolicy.action(continuationOwned: false),
            .ignoreStaleContinuation
        )
        XCTAssertTrue(
            NightFlockInviteUnresolvedLookupPolicy.action(continuationOwned: true).preservesCredential
        )
        XCTAssertTrue(
            NightFlockInviteUnresolvedLookupPolicy.action(continuationOwned: false).preservesCredential
        )
        XCTAssertTrue(
            NightFlockInviteUnresolvedLookupPolicy.permitsLegacyResponsePresentation(
                identityValidated: true
            )
        )
        XCTAssertFalse(
            NightFlockInviteUnresolvedLookupPolicy.permitsLegacyResponsePresentation(
                identityValidated: false
            )
        )
    }

    func testUnresolvedLookupOwnershipCoversNilAndThrownCurrentVersusStale() {
        let account = UUID()
        let token = NightFlockInviteReconciliationSnapshotToken.present(
            flockID: UUID(), challengeID: UUID(), challengeStatus: .pending,
            activeInviteID: UUID(), myMemberID: UUID(), keeperAuthorized: true
        )
        func continuationOwned(
            generation: UInt64 = 2,
            epoch: UInt64 = 4,
            transport: Bool = true,
            currentSnapshot: NightFlockInviteReconciliationSnapshotToken? = nil
        ) -> Bool {
            NightFlockInviteReconciliationAuthorityPolicy.ownsContinuation(
                capturedGeneration: 2,
                capturedTransportEpoch: 4,
                currentGeneration: generation,
                currentTransportEpoch: epoch,
                transportPermitted: transport,
                accountLinked: true,
                capturedLinkedAccountID: account,
                currentLinkedAccountID: account,
                capturedSnapshot: token,
                currentSnapshot: currentSnapshot ?? token
            )
        }

        // Nil and thrown lookups share this decision: hide presentation while
        // preserving the credential journal when the continuation still owns state.
        XCTAssertEqual(
            NightFlockInviteUnresolvedLookupPolicy.action(
                continuationOwned: continuationOwned()
            ),
            .hidePlaintextPreservingCredential
        )
        XCTAssertEqual(
            NightFlockInviteUnresolvedLookupPolicy.action(
                continuationOwned: continuationOwned(epoch: 5, transport: false)
            ),
            .ignoreStaleContinuation
        )
        XCTAssertEqual(
            NightFlockInviteUnresolvedLookupPolicy.action(
                continuationOwned: continuationOwned(currentSnapshot: .absent)
            ),
            .ignoreStaleContinuation
        )
    }

    func testCodeShapeNormalizationAndDigest() {
        let code = NightFlockInviteCode.generate(randomByte: { 31 })
        XCTAssertEqual(code.count, 12)
        XCTAssertTrue(code.allSatisfy(NightFlockInviteCode.alphabet.contains))
        XCTAssertEqual(NightFlockInviteCode.normalize(" abcd-2345-6789 "), "ABCD23456789")
        XCTAssertEqual(NightFlockInviteCode.digest("abcd-2345-6789").count, 64)
        XCTAssertEqual(NightFlockInviteCode.digest("abcd-2345-6789"), NightFlockInviteCode.digest("ABCD23456789"))
    }

    func testCreateAndReplaceRequestsContainOnlyDigestCredential() throws {
        let inviteID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        let expected = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let digest = String(repeating: "c", count: 64)
        let key = String(repeating: "d", count: 64)
        let create = try encoded(.createInvite(inviteID: inviteID, inviteDigest: digest, idempotencyKey: key))
        XCTAssertEqual(create["inviteID"] as? String, inviteID.uuidString)
        XCTAssertEqual(create["inviteDigest"] as? String, digest)
        XCTAssertNil(create["shortCode"])
        let legacy = try encoded(.createInvite(idempotencyKey: key))
        XCTAssertNil(legacy["inviteID"])
        XCTAssertNil(legacy["inviteDigest"])
        let replace = try encoded(.replaceInvite(expectedInviteID: expected, inviteID: inviteID, inviteDigest: digest, idempotencyKey: key))
        XCTAssertEqual(replace["expectedInviteID"] as? String, expected.uuidString)
        XCTAssertNil(replace["shortCode"])
    }

    func testRecoveryPresentationCoversMatchingMissingPendingExpiryAndIdentity() {
        let account = UUID(), flock = UUID(), invite = UUID()
        let credential = NightFlockInviteCredential(
            boundAccountID: account, flockID: flock, inviteID: invite,
            plaintextCode: "ABCD23456789", idempotencyKey: String(repeating: "e", count: 64),
            createdAt: Date(), state: .pending
        )
        let active = NightFlockSnapshot.ActiveInvite(id: invite, expiresAt: .distantFuture)
        XCTAssertEqual(presentation(credential, active, account, flock, .pending), .code("ABCD23456789"))
        XCTAssertEqual(presentation(nil, active, account, flock, .pending), .replaceCode)
        XCTAssertEqual(presentation(credential, nil, account, flock, .pending), .finishCreating)
        XCTAssertEqual(presentation(credential, .init(id: invite, expiresAt: .distantPast), account, flock, .pending), .finishCreating)
        XCTAssertEqual(presentation(credential, active, UUID(), flock, .pending), .hidden)
        XCTAssertEqual(presentation(credential, active, account, flock, .active), .hidden)
    }

    func testSnapshotActiveInviteIsBackwardsCompatible() throws {
        let original = fixture(activeInvite: nil)
        let legacy = try JSONDecoder().decode(NightFlockSnapshot.self, from: JSONEncoder().encode(original))
        XCTAssertNil(legacy.activeInvite)
        let active = NightFlockSnapshot.ActiveInvite(id: UUID(), expiresAt: Date())
        let decoded = try JSONDecoder().decode(NightFlockSnapshot.self, from: JSONEncoder().encode(fixture(activeInvite: active)))
        XCTAssertEqual(decoded.activeInvite, active)
    }

    private func encoded(_ command: NightFlockV2Command) throws -> [String: Any] {
        let data = try JSONEncoder().encode(NightFlockV2CommandRequest(command: command))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func presentation(
        _ credential: NightFlockInviteCredential?, _ active: NightFlockSnapshot.ActiveInvite?,
        _ account: UUID?, _ flock: UUID?, _ status: NightFlockChallenge.Status
    ) -> NightFlockInviteRecoveryPresentation {
        NightFlockInviteRecoveryPolicy.presentation(
            credential: credential, activeInvite: active, accountID: account,
            flockID: flock, challengeStatus: status, now: Date()
        )
    }

    private func fixture(activeInvite: NightFlockSnapshot.ActiveInvite?) -> NightFlockSnapshot {
        let member = UUID()
        return NightFlockSnapshot(
            profile: .init(alias: "Moonlit Meadow"), flockID: UUID(), identity: .moonlitMeadow,
            myMemberID: member, members: [.init(id: member, alias: "Moonlit Meadow", role: .keeper)],
            challenge: .init(id: UUID(), timeZoneIdentifier: "UTC", startsOn: .init(year: 2026, month: 8, day: 24), status: .pending),
            days: [], sharingEnabled: true, activeInvite: activeInvite
        )
    }
}
