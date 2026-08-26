import Foundation
import XCTest

final class NightFlockRemoteErrorTests: XCTestCase {
    func testRecoverableInviteCodeAndV2WireContract() throws {
        let code = NightFlockInviteCode.generate(randomByte: { 31 })
        XCTAssertEqual(code.count, 12)
        XCTAssertTrue(code.allSatisfy(NightFlockInviteCode.alphabet.contains))
        XCTAssertEqual(NightFlockInviteCode.normalize(" abcd-2345-6789 "), "ABCD23456789")
        XCTAssertEqual(NightFlockInviteCode.digest("ABCD23456789").count, 64)

        let inviteID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        let digest = String(repeating: "c", count: 64)
        let key = String(repeating: "d", count: 64)
        let data = try JSONEncoder().encode(NightFlockV2CommandRequest(command: .createInvite(
            inviteID: inviteID, inviteDigest: digest, idempotencyKey: key
        )))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["inviteID"] as? String, inviteID.uuidString)
        XCTAssertEqual(object["inviteDigest"] as? String, digest)
        XCTAssertNil(object["shortCode"])

        let legacyData = try JSONEncoder().encode(NightFlockV2CommandRequest(command: .createInvite(idempotencyKey: key)))
        let legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: legacyData) as? [String: Any])
        XCTAssertNil(legacy["inviteID"])
        XCTAssertNil(legacy["inviteDigest"])
    }

    func testInviteRecoveryReducerHidesWrongIdentityAndDistinguishesRecoveryActions() {
        let account = UUID(), flock = UUID(), invite = UUID()
        let credential = NightFlockInviteCredential(
            boundAccountID: account, flockID: flock, inviteID: invite,
            plaintextCode: "ABCD23456789", idempotencyKey: String(repeating: "e", count: 64),
            createdAt: Date(), state: .pending
        )
        let active = NightFlockSnapshot.ActiveInvite(id: invite, expiresAt: .distantFuture)
        func result(
            _ credential: NightFlockInviteCredential?, _ active: NightFlockSnapshot.ActiveInvite?,
            accountID: UUID? = account, status: NightFlockChallenge.Status = .pending
        ) -> NightFlockInviteRecoveryPresentation {
            NightFlockInviteRecoveryPolicy.presentation(
                credential: credential, activeInvite: active, accountID: accountID,
                flockID: flock, challengeStatus: status
            )
        }
        XCTAssertEqual(result(credential, active), .code("ABCD23456789"))
        XCTAssertEqual(result(nil, active), .replaceCode)
        XCTAssertEqual(result(credential, nil), .finishCreating)
        XCTAssertEqual(result(credential, active, accountID: UUID()), .hidden)
        XCTAssertEqual(result(credential, active, status: .active), .hidden)
    }

    func testActiveInviteConflictSupportsTypedAndLegacyEnvelopes() {
        let typed = NightFlockRemoteError.decode(
            statusCode: 409,
            data: Data(#"{"code":"active_invite_exists","error":"safe"}"#.utf8)
        )
        XCTAssertEqual(typed.code, .activeInviteExists)
        XCTAssertEqual(typed.recovery, .reconcile)
        XCTAssertFalse(typed.retryable)
        let legacy = NightFlockRemoteError.decode(
            statusCode: 500,
            data: Data(#"{"error":"A reusable invitation already exists"}"#.utf8)
        )
        XCTAssertEqual(legacy.code, .activeInviteExists)
        XCTAssertFalse(legacy.errorDescription?.contains("reusable invitation") == true)
    }

    func testTypedEnvelopeMapsActiveMembershipAndReconcile() {
        let id = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        let data = Data(#"{"error":"safe","code":"active_membership_exists","requestID":"AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA","retryable":false,"recovery":"reconcileMembership"}"#.utf8)
        let error = NightFlockRemoteError.decode(statusCode: 409, data: data)
        XCTAssertEqual(error.code, .activeMembershipExists)
        XCTAssertEqual(error.requestID, id)
        XCTAssertTrue(error.shouldReconcileMembership)
        XCTAssertFalse(error.retryable)
    }

    func testLegacyErrorStringIsBoundedAndRedactsDetail() {
        let secret = "apple-token=secret selectedApps=private"
        let data = Data((#"{"error":""# + secret + #""}"#).utf8)
        let error = NightFlockRemoteError.decode(statusCode: 500, data: data, headerRequestID: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        XCTAssertEqual(error.code, .serviceUnavailable)
        XCTAssertEqual(error.errorDescription, "Slumber Party is resting offline. Please try again.")
        XCTAssertFalse(error.errorDescription?.contains("apple-token") == true)
        XCTAssertFalse(error.errorDescription?.contains("selectedApps") == true)
    }

    func testUnsupportedSchemaIsOnlyFallbackCase() {
        let data = Data(#"{"error":"Unsupported schema","code":"unsupported_schema","requestID":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","recovery":"fallbackSchema"}"#.utf8)
        let error = NightFlockRemoteError.decode(statusCode: 400, data: data)
        XCTAssertTrue(error.allowsSchemaFallback)
        XCTAssertFalse(error.retryable)

        let auth = NightFlockRemoteError.decode(statusCode: 401, data: Data(#"{"error":"Unauthorized","code":"unauthorized"}"#.utf8))
        XCTAssertFalse(auth.allowsSchemaFallback)
        let server = NightFlockRemoteError.decode(statusCode: 503, data: Data(#"{"error":"retry","code":"service_unavailable"}"#.utf8))
        XCTAssertFalse(server.allowsSchemaFallback)
        XCTAssertTrue(server.retryable)
    }

    func testNetworkPolicyIsRetryable() {
        let error = NightFlockRemoteError.network(requestID: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")
        XCTAssertEqual(error.code, .serviceUnavailable)
        XCTAssertTrue(error.retryable)
        XCTAssertEqual(error.statusCode, 0)
    }

    func testDiagnosticsHaveOnlyAllowlistedFields() {
        let error = NightFlockRemoteError.decode(statusCode: 409, data: Data(#"{"code":"active_membership_exists","requestID":"eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee","error":"do not log"}"#.utf8))
        let record = NightFlockDiagnosticRecord(
            requestID: error.requestID,
            code: error.code.rawValue,
            operation: "redeemInvite",
            status: error.statusCode
        )
        XCTAssertEqual(Set(record.fields.keys), ["requestID", "code", "operation", "status"])
        XCTAssertFalse(record.fields.values.contains(where: { $0.contains("do not log") }))
    }

    func testInvalidRequestIDsAreReplacedAndNotEchoed() {
        let data = Data(#"{"code":"invalid_request","requestID":"not-a-uuid","error":"secret"}"#.utf8)
        let error = NightFlockRemoteError.decode(statusCode: 400, data: data, headerRequestID: "also-invalid")
        XCTAssertNotEqual(error.requestID, "not-a-uuid")
        XCTAssertNotEqual(error.requestID, "also-invalid")
        XCTAssertNotNil(UUID(uuidString: error.requestID))
    }

    func testSupportReferenceCanonicalizesAndRedacts() {
        XCTAssertEqual(
            NightFlockSupportReference.format(requestID: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"),
            "Request ID: aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        )
        XCTAssertNil(NightFlockSupportReference.format(requestID: "raw backend detail"))
        XCTAssertNil(NightFlockSupportReference.format(requestID: "user=secret token=secret"))
    }

    func testNewConstraintAndSnapshotCodesAreSafeAndTyped() {
        let alias = NightFlockRemoteError.decode(
            statusCode: 409,
            data: Data(#"{"code":"alias_conflict","requestID":"ffffffff-ffff-4fff-8fff-ffffffffffff"}"#.utf8)
        )
        XCTAssertEqual(alias.code, .aliasConflict)
        XCTAssertNil(alias.recovery)
        XCTAssertFalse(alias.shouldReconcileMembership)
        XCTAssertEqual(alias.errorDescription, "Ollie couldn’t choose a unique alias for this lobby.")

        let snapshot = NightFlockRemoteError.decode(
            statusCode: 500,
            data: Data(#"{"code":"snapshot_construction_failed","requestID":"11111111-1111-4111-8111-111111111111"}"#.utf8)
        )
        XCTAssertEqual(snapshot.code, .snapshotConstructionFailed)
        XCTAssertTrue(snapshot.retryable)
        XCTAssertEqual(snapshot.recovery, .retry)
    }

    func testAuthAndAccountRecoveryPoliciesDoNotReconcile() {
        let linked = NightFlockRemoteError.decode(statusCode: 403, data: Data(#"{"code":"linked_account_required"}"#.utf8))
        XCTAssertEqual(linked.recovery, .linkAccount)
        XCTAssertFalse(linked.shouldReconcileMembership)

        let unauthorized = NightFlockRemoteError.decode(statusCode: 401, data: Data(#"{"code":"unauthorized"}"#.utf8))
        XCTAssertEqual(unauthorized.recovery, .authenticate)
        XCTAssertFalse(unauthorized.shouldReconcileMembership)

        let account = NightFlockRemoteError.decode(statusCode: 403, data: Data(#"{"code":"account_unavailable"}"#.utf8))
        XCTAssertNil(account.recovery)
    }

    func testAuthenticationPolicyPreservesEveryLocalLane() {
        let lanes: [NightFlockRecoveryLane] = [
            .snapshot(schema: 1), .snapshot(schema: 2), .snapshot(schema: 3),
            .directCommand(schema: 1), .directCommand(schema: 2), .directCommand(schema: 3),
            .outbox(schema: 1), .outbox(schema: 2), .outbox(schema: 3)
        ]
        for lane in lanes {
            let reauth = NightFlockAuthenticationRecoveryPolicy.decide(
                remoteCode: .unauthorized, lane: lane, session: .linked,
                expectedIdentity: .valid(UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!)
            )
            XCTAssertEqual(reauth.action, .reauthenticateApple)
            XCTAssertTrue(reauth.preservesSnapshot)
            XCTAssertTrue(reauth.preservesRunContexts)
            XCTAssertTrue(reauth.preservesAllOutboxes)
            XCTAssertTrue(reauth.refreshAfterValidation)
            XCTAssertTrue(reauth.mayFlushOutboxAfterValidation)
        }
    }

    func testLinkedAccountRecoveryIsAnonymousOnlyAndUnknownIdentityFailsClosed() {
        let link = NightFlockAuthenticationRecoveryPolicy.decide(
            remoteCode: .linkedAccountRequired, lane: .directCommand(schema: 2),
            session: .anonymous, expectedIdentity: .absent
        )
        XCTAssertEqual(link.action, .linkCurrentAnonymousApple)
        XCTAssertEqual(
            NightFlockAuthenticationRecoveryPolicy.decide(
                    remoteCode: .linkedAccountRequired, lane: .directCommand(schema: 1),
                session: .anonymous,
                expectedIdentity: .valid(UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!)
            ).action,
            .failClosed
        )
        for session in [NightFlockRecoverySession.missing, .linked, .unknown] {
            XCTAssertEqual(
                NightFlockAuthenticationRecoveryPolicy.decide(
                    remoteCode: .linkedAccountRequired, lane: .outbox(schema: 3),
                    session: session,
                    expectedIdentity: .valid(UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!)
                ).action,
                .failClosed
            )
        }
        XCTAssertEqual(
            NightFlockAuthenticationRecoveryPolicy.decide(
                remoteCode: .unauthorized, lane: .snapshot(schema: 1),
                session: .missing, expectedIdentity: .absent
            ).action,
            .failClosed
        )
    }

    func testEveryDirectCommandSchemaUsesTheSameNoReplayRecoveryLane() {
        let id = UUID()
        let v1: [NightFlockCommand] = [
            .createFlock(identity: .moonlitMeadow, timeZoneIdentifier: "UTC", idempotencyKey: "k"),
            .createInvite(idempotencyKey: "k"), .revokeInvite(inviteID: id, idempotencyKey: "k"),
            .join(shortCode: "SHEEP", idempotencyKey: "k"), .leave(idempotencyKey: "k"),
            .setSharing(enabled: true, idempotencyKey: "k"), .block(memberID: id, idempotencyKey: "k"),
            .report(memberID: id, reason: NightFlockReportReason.allCases[0], idempotencyKey: "k"),
            .publishCheckIn(challengeID: id, day: 1, state: .phoneTucked, idempotencyKey: "k"),
            .react(checkInID: id, reaction: .warmWave, idempotencyKey: "k"),
            .deleteNightFlockData(idempotencyKey: "k"), .deleteAccount(idempotencyKey: "k")
        ]
        let v2: [NightFlockV2Command] = [
            .createParty(goal: NightFlockSharedGoal(kind: .phoneAway), identity: .moonlitMeadow, timeZoneIdentifier: "UTC", idempotencyKey: "k"),
            .createInvite(idempotencyKey: "k"), .previewInvite(shortCode: "SHEEP", idempotencyKey: "k"),
            .redeemInvite(shortCode: "SHEEP", idempotencyKey: "k"), .acceptGoal(challengeID: id, idempotencyKey: "k"),
            .setLocalSetup(challengeID: id, setupReady: true, shieldingEvidence: .notRequested, idempotencyKey: "k"),
            .setSharingPreferences(shareGoalProgress: true, shareRoutineIdeas: false, idempotencyKey: "k"),
            .setRoutineIdeas(challengeID: id, guidanceIDs: [], idempotencyKey: "k"),
            .startChallenge(challengeID: id, idempotencyKey: "k"),
            .publishProgress(challengeID: id, day: 1, status: .phoneTuckedAway, shieldingEvidence: .notRequested, idempotencyKey: "k")
        ]
        let v3: [NightFlockV3Command] = [
            .setSharingPreferences(NightFlockSharingPreferences(), idempotencyKey: "k"),
            .publishNightMetrics(challengeID: id, day: 1, status: .phoneTuckedAway, shieldingEvidence: .notRequested, windDownMinutes: 0, phoneAwayMinutes: 0, sleepDurationMinutes: nil, restfulness: nil, idempotencyKey: "k"),
            .acknowledgeGrant(grantID: id, idempotencyKey: "k")
        ]

        XCTAssertEqual(v1.count, 12)
        XCTAssertEqual(v2.count, 10)
        XCTAssertEqual(v3.count, 3)
        let expected = NightFlockExpectedIdentity.valid(
            UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        )
        for _ in v1 {
            let decision = NightFlockAuthenticationRecoveryPolicy.decide(
                remoteCode: .unauthorized, lane: .directCommand(schema: 1),
                session: .linked, expectedIdentity: expected
            )
            XCTAssertEqual(decision.action, .reauthenticateApple)
            XCTAssertTrue(decision.refreshAfterValidation)
        }
        for _ in v2 {
            XCTAssertEqual(
                NightFlockAuthenticationRecoveryPolicy.decide(
                    remoteCode: .unauthorized, lane: .directCommand(schema: 2),
                    session: .linked, expectedIdentity: expected
                ).action,
                .reauthenticateApple
            )
        }
        for _ in v3 {
            XCTAssertEqual(
                NightFlockAuthenticationRecoveryPolicy.decide(
                    remoteCode: .unauthorized, lane: .directCommand(schema: 3),
                    session: .linked, expectedIdentity: expected
                ).action,
                .reauthenticateApple
            )
        }
    }

    func testBindingClassifierKeepsInvalidDistinctFromAbsent() {
        let id = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        XCTAssertEqual(NightFlockExpectedIdentityBinding.classify(nil), .absent)
        XCTAssertEqual(NightFlockExpectedIdentityBinding.classify(id.uuidString), .valid(id))
        XCTAssertEqual(NightFlockExpectedIdentityBinding.classify("not-a-uuid"), .invalid)

        XCTAssertEqual(
            NightFlockAuthenticationRecoveryPolicy.decide(
                remoteCode: .linkedAccountRequired, lane: .snapshot(schema: 3),
                session: .anonymous, expectedIdentity: .invalid
            ).action,
            .failClosed
        )
        XCTAssertEqual(
            NightFlockAuthenticationRecoveryPolicy.decide(
                remoteCode: .unauthorized, lane: .outbox(schema: 2),
                session: .linked, expectedIdentity: .invalid
            ).action,
            .failClosed
        )
    }

    func testAuthenticationRecoveryStateMergeIsMonotonicAndFailClosedAbsorbing() {
        let actions: [NightFlockAuthenticationAction] = [
            .none, .reauthenticateApple, .linkCurrentAnonymousApple, .failClosed
        ]
        for current in actions {
            for incoming in actions {
                let expected: NightFlockAuthenticationAction
                if current == .failClosed || incoming == .failClosed {
                    expected = .failClosed
                } else if current == .none {
                    expected = incoming
                } else {
                    expected = current
                }
                XCTAssertEqual(
                    NightFlockAuthenticationRecoveryStatePolicy.merge(
                        current: current,
                        incoming: incoming
                    ),
                    expected,
                    "current \(current), incoming \(incoming)"
                )
            }
        }

        XCTAssertEqual(
            NightFlockAuthenticationRecoveryStatePolicy.merge(
                current: .failClosed,
                incoming: .reauthenticateApple
            ),
            .failClosed
        )
        XCTAssertEqual(
            NightFlockAuthenticationRecoveryStatePolicy.merge(
                current: .failClosed,
                incoming: .linkCurrentAnonymousApple
            ),
            .failClosed
        )
        XCTAssertEqual(
            NightFlockAuthenticationRecoveryStatePolicy.merge(
                current: .reauthenticateApple,
                incoming: .linkCurrentAnonymousApple
            ),
            .reauthenticateApple
        )
        XCTAssertEqual(
            NightFlockAuthenticationRecoveryStatePolicy.merge(
                current: .linkCurrentAnonymousApple,
                incoming: .reauthenticateApple
            ),
            .linkCurrentAnonymousApple
        )
        XCTAssertEqual(
            NightFlockAuthenticationRecoveryStatePolicy.merge(
                current: .reauthenticateApple,
                incoming: .failClosed
            ),
            .failClosed
        )
        XCTAssertEqual(
            NightFlockAuthenticationRecoveryStatePolicy.merge(
                current: .none,
                incoming: .reauthenticateApple
            ),
            .reauthenticateApple
        )
        XCTAssertEqual(
            NightFlockAuthenticationRecoveryStatePolicy.merge(
                current: .none,
                incoming: .none
            ),
            .none
        )
        XCTAssertEqual(
            NightFlockAuthenticationRecoveryStatePolicy.merge(
                current: .linkCurrentAnonymousApple,
                incoming: .none
            ),
            .linkCurrentAnonymousApple
        )
    }

    func testAppleCompletionAcceptsOnlyItsExactCurrentRecoveryAction() {
        let actions: [NightFlockAuthenticationAction] = [
            .none, .reauthenticateApple, .linkCurrentAnonymousApple, .failClosed
        ]
        for captured in actions {
            for current in actions {
                XCTAssertEqual(
                    NightFlockAuthenticationRecoveryCompletionPolicy.ownsCallback(
                        captured: captured,
                        current: current
                    ),
                    captured != .failClosed && captured == current,
                    "captured \(captured), current \(current)"
                )
            }
        }

        XCTAssertFalse(
            NightFlockAuthenticationRecoveryCompletionPolicy.ownsCallback(
                captured: .reauthenticateApple,
                current: .failClosed
            )
        )
        XCTAssertFalse(
            NightFlockAuthenticationRecoveryCompletionPolicy.ownsCallback(
                captured: .linkCurrentAnonymousApple,
                current: .failClosed
            )
        )
        XCTAssertFalse(
            NightFlockAuthenticationRecoveryCompletionPolicy.ownsCallback(
                captured: .none,
                current: .reauthenticateApple
            )
        )
        XCTAssertTrue(
            NightFlockAuthenticationRecoveryCompletionPolicy.ownsCallback(
                captured: .none,
                current: .none
            )
        )
        XCTAssertTrue(
            NightFlockAuthenticationRecoveryCompletionPolicy.ownsCallback(
                captured: .reauthenticateApple,
                current: .reauthenticateApple
            )
        )
        XCTAssertTrue(
            NightFlockAuthenticationRecoveryCompletionPolicy.ownsCallback(
                captured: .linkCurrentAnonymousApple,
                current: .linkCurrentAnonymousApple
            )
        )
        XCTAssertFalse(
            NightFlockAuthenticationRecoveryCompletionPolicy.ownsCallback(
                captured: .reauthenticateApple,
                current: .linkCurrentAnonymousApple
            )
        )
        XCTAssertFalse(
            NightFlockAuthenticationRecoveryCompletionPolicy.ownsCallback(
                captured: .linkCurrentAnonymousApple,
                current: .reauthenticateApple
            )
        )
    }

    func testRecoveryPresentationCannotDowngradeAnyNewerRecoveryOwner() {
        let actions: [NightFlockAuthenticationAction] = [
            .none, .reauthenticateApple, .linkCurrentAnonymousApple, .failClosed
        ]
        for current in actions {
            for incoming in actions {
                let decision = NightFlockAuthenticationRecoveryPresentationPolicy.decide(
                    current: current,
                    incoming: incoming
                )
                XCTAssertEqual(
                    decision.action,
                    NightFlockAuthenticationRecoveryStatePolicy.merge(
                        current: current,
                        incoming: incoming
                    )
                )
                let expectedPresentation = current != .failClosed
                    && (incoming == .failClosed || current == .none)
                XCTAssertEqual(
                    decision.shouldUpdatePresentation,
                    expectedPresentation,
                    "current \(current), incoming \(incoming)"
                )
            }
        }
        XCTAssertFalse(
            NightFlockAuthenticationRecoveryPresentationPolicy.decide(
                current: .failClosed,
                incoming: .reauthenticateApple
            ).shouldUpdatePresentation
        )
        XCTAssertFalse(
            NightFlockAuthenticationRecoveryPresentationPolicy.decide(
                current: .linkCurrentAnonymousApple,
                incoming: .none
            ).shouldUpdatePresentation
        )
        XCTAssertTrue(
            NightFlockAuthenticationRecoveryPresentationPolicy.decide(
                current: .reauthenticateApple,
                incoming: .failClosed
            ).shouldUpdatePresentation
        )
    }

    func testRecoveryQuiescesEveryDirectAndOutboxTransportLane() {
        let lanes: [NightFlockRecoveryLane] = [
            .directCommand(schema: 1), .directCommand(schema: 2), .directCommand(schema: 3),
            .outbox(schema: 1), .outbox(schema: 2), .outbox(schema: 3)
        ]
        for lane in lanes {
            for recovery in [
                NightFlockAuthenticationAction.reauthenticateApple,
                .linkCurrentAnonymousApple,
                .failClosed
            ] {
                XCTAssertFalse(NightFlockTransportRecoveryPolicy.permitsNetwork(recovery: recovery), "\(lane) must be quiet")
                XCTAssertFalse(
                    NightFlockTransportRecoveryPolicy.permitsAccountSessionInspection(recovery: recovery),
                    "\(lane) must not bootstrap or inspect an account"
                )
            }
        }
        XCTAssertTrue(NightFlockTransportRecoveryPolicy.permitsNetwork(recovery: .none))
        XCTAssertTrue(NightFlockTransportRecoveryPolicy.shouldStopOutboxFlush(remoteCode: .unauthorized, recovery: .none))
        XCTAssertTrue(NightFlockTransportRecoveryPolicy.shouldStopOutboxFlush(remoteCode: .linkedAccountRequired, recovery: .none))
    }

    func testAccountSessionTransitionMatrixPreservesBoundIdentitySafety() {
        let id = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        let otherID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let bindings: [NightFlockExpectedIdentity] = [.absent, .valid(id), .invalid]

        for createAnonymous in [false, true] {
            XCTAssertEqual(
                NightFlockAccountSessionPolicy.decide(
                    observed: .missing,
                    expectedIdentity: .absent,
                    createAnonymousIfMissing: createAnonymous
                ),
                createAnonymous ? .createAnonymous : .returnAnonymous
            )
            XCTAssertEqual(
                NightFlockAccountSessionPolicy.decide(
                    observed: .missing,
                    expectedIdentity: .valid(id),
                    createAnonymousIfMissing: createAnonymous
                ),
                .reauthenticateApple(signOutLocalSession: false)
            )
            XCTAssertEqual(
                NightFlockAccountSessionPolicy.decide(
                    observed: .missing,
                    expectedIdentity: .invalid,
                    createAnonymousIfMissing: createAnonymous
                ),
                .failClosed(signOutLocalSession: false)
            )

            XCTAssertEqual(
                NightFlockAccountSessionPolicy.decide(
                    observed: .anonymous,
                    expectedIdentity: .absent,
                    createAnonymousIfMissing: createAnonymous
                ),
                .returnAnonymous
            )
            XCTAssertEqual(
                NightFlockAccountSessionPolicy.decide(
                    observed: .anonymous,
                    expectedIdentity: .valid(id),
                    createAnonymousIfMissing: createAnonymous
                ),
                .reauthenticateApple(signOutLocalSession: true)
            )
            XCTAssertEqual(
                NightFlockAccountSessionPolicy.decide(
                    observed: .anonymous,
                    expectedIdentity: .invalid,
                    createAnonymousIfMissing: createAnonymous
                ),
                .failClosed(signOutLocalSession: true)
            )

            XCTAssertEqual(
                NightFlockAccountSessionPolicy.decide(
                    observed: .appleLinked(id),
                    expectedIdentity: .absent,
                    createAnonymousIfMissing: createAnonymous
                ),
                .returnLinked(adopting: id)
            )
            XCTAssertEqual(
                NightFlockAccountSessionPolicy.decide(
                    observed: .appleLinked(id),
                    expectedIdentity: .valid(id),
                    createAnonymousIfMissing: createAnonymous
                ),
                .returnLinked(adopting: nil)
            )
            XCTAssertEqual(
                NightFlockAccountSessionPolicy.decide(
                    observed: .appleLinked(otherID),
                    expectedIdentity: .valid(id),
                    createAnonymousIfMissing: createAnonymous
                ),
                .failClosed(signOutLocalSession: true)
            )
            XCTAssertEqual(
                NightFlockAccountSessionPolicy.decide(
                    observed: .appleLinked(id),
                    expectedIdentity: .invalid,
                    createAnonymousIfMissing: createAnonymous
                ),
                .failClosed(signOutLocalSession: true)
            )

            for binding in bindings {
                XCTAssertEqual(
                    NightFlockAccountSessionPolicy.decide(
                        observed: .unsupported,
                        expectedIdentity: binding,
                        createAnonymousIfMissing: createAnonymous
                    ),
                    .failClosed(signOutLocalSession: true)
                )
            }
        }
    }

    func testOnlyUnboundAnonymousSessionMayLinkAppleIdentityInPlace() {
        let id = UUID()
        XCTAssertTrue(
            NightFlockAccountSessionPolicy.mayLinkAppleIdentity(
                observed: .anonymous,
                expectedIdentity: .absent
            )
        )
        for observed in [
            NightFlockObservedAccountSession.missing,
            .appleLinked(id),
            .unsupported
        ] {
            XCTAssertFalse(
                NightFlockAccountSessionPolicy.mayLinkAppleIdentity(
                    observed: observed,
                    expectedIdentity: .absent
                )
            )
        }
        XCTAssertFalse(
            NightFlockAccountSessionPolicy.mayLinkAppleIdentity(
                observed: .anonymous,
                expectedIdentity: .valid(id)
            )
        )
        XCTAssertFalse(
            NightFlockAccountSessionPolicy.mayLinkAppleIdentity(
                observed: .anonymous,
                expectedIdentity: .invalid
            )
        )
    }

    func testAppleIdentityEvidenceAcceptsServerMetadataWhenExpandedIdentitiesAreMissing() {
        XCTAssertTrue(NightFlockAppleIdentityEvidence.isLinked(
            isAnonymous: false,
            identityProviders: [],
            primaryProvider: "apple",
            providers: []
        ))
        XCTAssertTrue(NightFlockAppleIdentityEvidence.isLinked(
            isAnonymous: false,
            identityProviders: [],
            primaryProvider: nil,
            providers: ["apple"]
        ))
        XCTAssertTrue(NightFlockAppleIdentityEvidence.isLinked(
            isAnonymous: false,
            identityProviders: ["apple"],
            primaryProvider: nil,
            providers: []
        ))
    }

    func testAppleIdentityEvidenceNeverUpgradesAnonymousOrDifferentAccount() {
        let original = UUID()
        XCTAssertFalse(NightFlockAppleIdentityEvidence.isLinked(
            isAnonymous: true,
            identityProviders: ["apple"],
            primaryProvider: "apple",
            providers: ["apple"]
        ))
        XCTAssertTrue(NightFlockAppleIdentityEvidence.preservesOriginalAccount(
            originalUserID: original,
            recoveredUserID: original,
            hasAppleIdentity: true
        ))
        XCTAssertFalse(NightFlockAppleIdentityEvidence.preservesOriginalAccount(
            originalUserID: original,
            recoveredUserID: UUID(),
            hasAppleIdentity: true
        ))
        XCTAssertFalse(NightFlockAppleIdentityEvidence.preservesOriginalAccount(
            originalUserID: original,
            recoveredUserID: original,
            hasAppleIdentity: false
        ))
    }

    func testAppleRecoveryIdentityFailuresAreFailClosedAndDoNotAuthorizeOverwrite() {
        XCTAssertEqual(
            NightFlockAppleRecoveryFailurePolicy.nextAction(
                recovery: .linkCurrentAnonymousApple,
                failure: .identityAlreadyExists
            ),
            .failClosed
        )
        XCTAssertEqual(
            NightFlockAppleRecoveryFailurePolicy.nextAction(
                recovery: .reauthenticateApple,
                failure: .identityValidationFailed
            ),
            .failClosed
        )
        XCTAssertEqual(
            NightFlockAppleRecoveryFailurePolicy.nextAction(
                recovery: .reauthenticateApple,
                failure: .cancellationOrNetwork
            ),
            .reauthenticateApple
        )
        XCTAssertEqual(
            NightFlockAppleRecoveryFailurePolicy.nextAction(
                recovery: .failClosed,
                failure: .other
            ),
            .failClosed
        )
    }

    func testDestructiveLocalEffectsStayStagedUntilValidatedSnapshotOrReconciliation() {
        let id = UUID()
        let destructive: [NightFlockCommand] = [
            .leave(idempotencyKey: "k"),
            .block(memberID: id, idempotencyKey: "k"),
            .deleteNightFlockData(idempotencyKey: "k"),
            .setSharing(enabled: false, idempotencyKey: "k")
        ]
        for command in destructive {
            let effect = NightFlockDirectCommandCommitPolicy.localEffect(for: command)
            XCTAssertEqual(effect, .clearOutboxesAndRunContexts)
            XCTAssertFalse(NightFlockDirectCommandCommitPolicy.shouldCommit(effect, at: .awaitingValidatedSnapshot))
            XCTAssertTrue(NightFlockDirectCommandCommitPolicy.shouldCommit(effect, at: .validatedResponseSnapshot))
            XCTAssertTrue(NightFlockDirectCommandCommitPolicy.shouldCommit(effect, at: .validatedStateReconciliation))
        }
        XCTAssertFalse(
            NightFlockDirectCommandCommitPolicy.shouldCommit(
                .none,
                at: .validatedStateReconciliation
            )
        )

        // An accepted response without state stages once; retry/auth recovery
        // leaves it present until a later authoritative state commits it.
        let staged = NightFlockStagedDestructiveCommitPolicy.stage(
            existing: .none,
            incoming: .clearOutboxesAndRunContexts
        )
        XCTAssertEqual(staged, .clearOutboxesAndRunContexts)
        let encodedMarker = try? JSONEncoder().encode(staged)
        XCTAssertEqual(
            encodedMarker.flatMap { try? JSONDecoder().decode(NightFlockDestructiveLocalEffect.self, from: $0) },
            staged
        )
        XCTAssertEqual(
            NightFlockStagedDestructiveCommitPolicy.preserveAfterUnvalidatedReconciliation(staged: staged),
            .clearOutboxesAndRunContexts
        )
        let authoritative = NightFlockStagedDestructiveCommitPolicy.consumeAfterAuthoritativeState(
            staged: staged
        )
        XCTAssertEqual(authoritative.effectToCommit, .clearOutboxesAndRunContexts)
        XCTAssertEqual(authoritative.remaining, .none)
        let secondAuthoritative = NightFlockStagedDestructiveCommitPolicy.consumeAfterAuthoritativeState(
            staged: authoritative.remaining
        )
        XCTAssertEqual(secondAuthoritative.effectToCommit, .none)
        XCTAssertEqual(secondAuthoritative.remaining, .none)
        XCTAssertTrue(NightFlockRelaunchReconciliationPolicy.requiresAuthoritativeReconciliation(staged: staged))
        XCTAssertFalse(NightFlockRelaunchReconciliationPolicy.permitsOutboxFlush(staged: staged))
        XCTAssertTrue(NightFlockRelaunchReconciliationPolicy.permitsOutboxFlush(staged: authoritative.remaining))
        XCTAssertEqual(
            NightFlockStagedDestructiveCommitPolicy.stage(existing: staged, incoming: .clearOutboxesAndRunContexts),
            .clearOutboxesAndRunContexts
        )
    }

    func testOutboxEpochAdmissionRejectsPreAndDuringClearMutationsAcrossAllLanes() {
        let initial: UInt64 = 4
        let requested: UInt64 = 5
        let postClear = NightFlockOutboxEpochPolicy.advancingClear(
            acceptedEpoch: initial,
            requestedEpoch: requested
        )
        XCTAssertEqual(postClear, 6)
        let mutationLanes = ["v1", "v2", "v3", "context", "combined", "remove", "mark"]
        for _ in mutationLanes {
            XCTAssertFalse(NightFlockOutboxEpochPolicy.admits(callerEpoch: initial, acceptedEpoch: postClear))
            XCTAssertFalse(NightFlockOutboxEpochPolicy.admits(callerEpoch: requested, acceptedEpoch: postClear))
            XCTAssertTrue(NightFlockOutboxEpochPolicy.admits(callerEpoch: postClear, acceptedEpoch: postClear))
        }
        let consecutive = NightFlockOutboxEpochPolicy.advancingClear(
            acceptedEpoch: postClear,
            requestedEpoch: postClear &+ 1
        )
        XCTAssertEqual(consecutive, 8)
        XCTAssertFalse(NightFlockOutboxEpochPolicy.admits(callerEpoch: postClear, acceptedEpoch: consecutive))
        XCTAssertTrue(NightFlockOutboxEpochPolicy.admits(callerEpoch: consecutive, acceptedEpoch: consecutive))
        XCTAssertFalse(
            NightFlockOutboxEpochPolicy.admitsClear(requestedEpoch: postClear, acceptedEpoch: consecutive)
        )
        XCTAssertFalse(
            NightFlockOutboxEpochPolicy.admitsClear(requestedEpoch: consecutive, acceptedEpoch: consecutive)
        )
        XCTAssertTrue(
            NightFlockOutboxEpochPolicy.admitsClear(requestedEpoch: consecutive &+ 1, acceptedEpoch: consecutive)
        )
        XCTAssertFalse(
            NightFlockOutboxEpochPolicy.mayAdoptClearCompletion(
                currentEpoch: consecutive,
                returnedEpoch: postClear
            )
        )
        XCTAssertTrue(
            NightFlockOutboxEpochPolicy.mayAdoptClearCompletion(
                currentEpoch: postClear,
                returnedEpoch: consecutive
            )
        )
        let unchangedAfterFailedDeletion = NightFlockAccountDeletionIntentPolicy.epochAfterResponse(
            currentEpoch: consecutive,
            accepted: false
        )
        XCTAssertEqual(unchangedAfterFailedDeletion, consecutive)
        for _ in ["v1-enqueue/remove/mark", "v2-enqueue/remove/mark", "v3-enqueue/remove/mark", "context-save/remove"] {
            XCTAssertTrue(NightFlockOutboxEpochPolicy.admits(
                callerEpoch: unchangedAfterFailedDeletion,
                acceptedEpoch: consecutive
            ))
        }
        let deletionEpoch = NightFlockAcceptedDeletionPolicy.closedEpoch(
            acceptedEpoch: consecutive,
            requestedEpoch: postClear
        )
        XCTAssertGreaterThan(deletionEpoch, consecutive)
        XCTAssertEqual(
            NightFlockAcceptedDeletionPolicy.recoveryAction(tombstonePresent: true),
            .finalizeLocally
        )
        XCTAssertEqual(
            NightFlockAcceptedDeletionPolicy.recoveryAction(tombstonePresent: false),
            .none
        )
        XCTAssertEqual(
            NightFlockAcceptedDeletionPolicy.finalizationSteps(tombstonePresent: true),
            [.clearLanes, .clearInviteCredential, .clearIdentityAndSignOut, .removeTombstone, .resetPresentation]
        )
        XCTAssertEqual(NightFlockAcceptedDeletionPolicy.finalizationSteps(tombstonePresent: false), [])
        XCTAssertFalse(NightFlockAcceptedDeletionPolicy.mayCompleteFinalization(
            inviteCredentialCleared: false, verifiedLocalSignOut: true
        ))
        XCTAssertFalse(NightFlockAcceptedDeletionPolicy.mayCompleteFinalization(
            inviteCredentialCleared: true, verifiedLocalSignOut: false
        ))
        XCTAssertTrue(NightFlockAcceptedDeletionPolicy.mayCompleteFinalization(
            inviteCredentialCleared: true, verifiedLocalSignOut: true
        ))
        for _ in ["v1 enqueue/remove/mark", "v2 enqueue/remove/mark", "v3 enqueue/remove/mark", "context save/remove"] {
            XCTAssertFalse(NightFlockOutboxEpochPolicy.admits(callerEpoch: initial, acceptedEpoch: deletionEpoch))
            XCTAssertFalse(NightFlockAcceptedDeletionPolicy.permitsLocalMutation(tombstonePresent: true))
            XCTAssertFalse(NightFlockAcceptedDeletionPolicy.permitsActorMutation(
                tombstonePresent: true, callerEpoch: initial, acceptedEpoch: deletionEpoch
            ))
            XCTAssertFalse(NightFlockAcceptedDeletionPolicy.permitsActorMutation(
                tombstonePresent: true, callerEpoch: deletionEpoch, acceptedEpoch: deletionEpoch
            ))
            XCTAssertFalse(NightFlockAcceptedDeletionPolicy.permitsOrdinaryClear(
                tombstonePresent: true, callerEpoch: deletionEpoch &+ 1, acceptedEpoch: deletionEpoch
            ))
        }
    }

    func testPendingAccountDeletionIntentIsFailClosedUntilAcceptedFinalizationCompletes() {
        let epoch: UInt64 = 12
        let cases: [(pending: Bool, tombstone: Bool, phase: NightFlockAccountDeletionIntentPolicy.Phase, action: NightFlockAccountDeletionIntentPolicy.RecoveryAction)] = [
            (false, false, .complete, .none),
            (true, false, .pendingPreflight, .failClosedNoNetworkNoReplay),
            (true, true, .acceptedTombstone, .finalizeLocally),
            (false, true, .acceptedTombstone, .finalizeLocally)
        ]
        for test in cases {
            let phase = NightFlockAccountDeletionIntentPolicy.phase(
                pendingIntentPresent: test.pending,
                tombstonePresent: test.tombstone
            )
            XCTAssertEqual(phase, test.phase)
            XCTAssertEqual(NightFlockAccountDeletionIntentPolicy.recoveryAction(phase: phase), test.action)
        }

        // Restart checkpoints: before a response remains pending/no-network;
        // tombstone write dominates a pending key until local finalization.
        for _ in ["after preflight", "during send", "server committed before response"] {
            XCTAssertEqual(
                NightFlockAccountDeletionIntentPolicy.recoveryAction(phase: .pendingPreflight),
                .failClosedNoNetworkNoReplay
            )
            XCTAssertFalse(NightFlockAccountDeletionIntentPolicy.permitsAdmission(phase: .pendingPreflight))
        }
        for _ in ["after tombstone before pending removal", "after lane clear", "after sign-out", "before tombstone removal"] {
            XCTAssertEqual(
                NightFlockAccountDeletionIntentPolicy.recoveryAction(phase: .acceptedTombstone),
                .finalizeLocally
            )
            XCTAssertFalse(NightFlockAccountDeletionIntentPolicy.permitsAdmission(phase: .acceptedTombstone))
        }

        let lanes = ["v1 enqueue/remove/mark", "v2 enqueue/remove/mark", "v3 enqueue/remove/mark", "context save/remove"]
        for _ in lanes {
            XCTAssertFalse(NightFlockAccountDeletionIntentPolicy.permitsActorMutation(
                phase: .pendingPreflight, callerEpoch: epoch, acceptedEpoch: epoch
            ))
            XCTAssertFalse(NightFlockAccountDeletionIntentPolicy.permitsOrdinaryClear(
                phase: .pendingPreflight, callerEpoch: epoch &+ 1, acceptedEpoch: epoch
            ))
            XCTAssertFalse(NightFlockAccountDeletionIntentPolicy.permitsActorMutation(
                phase: .acceptedTombstone, callerEpoch: epoch, acceptedEpoch: epoch
            ))
            XCTAssertTrue(NightFlockAccountDeletionIntentPolicy.permitsActorMutation(
                phase: .complete, callerEpoch: epoch, acceptedEpoch: epoch
            ))
        }

        XCTAssertEqual(
            NightFlockAccountDeletionIntentPolicy.epochAfterResponse(currentEpoch: epoch, accepted: false),
            epoch,
            "definitive rejection reopens the same actor epoch"
        )
        XCTAssertGreaterThan(
            NightFlockAccountDeletionIntentPolicy.epochAfterResponse(currentEpoch: epoch, accepted: true),
            epoch
        )
        XCTAssertFalse(NightFlockAccountDeletionIntentPolicy.mayRemoveTombstone(verifiedLocalSignOut: false))
        XCTAssertTrue(NightFlockAccountDeletionIntentPolicy.mayRemoveTombstone(verifiedLocalSignOut: true))
    }

    func testAccountDeletionPreflightAcquisitionIsExclusiveAndEpochBound() {
        let epoch: UInt64 = 12
        XCTAssertTrue(
            NightFlockAccountDeletionIntentPolicy.permitsExclusivePreflightAcquisition(
                phase: .complete,
                ordinaryIntentPresent: false,
                stagedOrdinaryEffect: .none,
                callerEpoch: epoch,
                acceptedEpoch: epoch
            ),
            "the first actor caller alone may move complete to pending"
        )
        XCTAssertFalse(
            NightFlockAccountDeletionIntentPolicy.permitsExclusivePreflightAcquisition(
                phase: .pendingPreflight,
                ordinaryIntentPresent: false,
                stagedOrdinaryEffect: .none,
                callerEpoch: epoch,
                acceptedEpoch: epoch
            ),
            "a rapid second tap sees the durable pending journal and cannot send"
        )
        XCTAssertFalse(
            NightFlockAccountDeletionIntentPolicy.permitsExclusivePreflightAcquisition(
                phase: .acceptedTombstone,
                ordinaryIntentPresent: false,
                stagedOrdinaryEffect: .none,
                callerEpoch: epoch,
                acceptedEpoch: epoch
            )
        )
        XCTAssertFalse(
            NightFlockAccountDeletionIntentPolicy.permitsExclusivePreflightAcquisition(
                phase: .complete,
                ordinaryIntentPresent: false,
                stagedOrdinaryEffect: .none,
                callerEpoch: epoch &- 1,
                acceptedEpoch: epoch
            )
        )
        XCTAssertFalse(
            NightFlockAccountDeletionIntentPolicy.permitsExclusivePreflightAcquisition(
                phase: .complete,
                ordinaryIntentPresent: false,
                stagedOrdinaryEffect: .none,
                callerEpoch: epoch &+ 1,
                acceptedEpoch: epoch
            )
        )
        XCTAssertTrue(
            NightFlockAccountDeletionIntentPolicy.permitsExclusivePreflightAcquisition(
                phase: .complete,
                ordinaryIntentPresent: false,
                stagedOrdinaryEffect: .none,
                callerEpoch: epoch,
                acceptedEpoch: epoch
            ),
            "a definitive rejection reopens the same epoch for a later, new request"
        )
    }

    func testAccountDeletionPreflightAndOrdinaryJournalAreMutuallyExclusive() {
        let epoch: UInt64 = 12
        XCTAssertFalse(
            NightFlockAccountDeletionIntentPolicy.permitsExclusivePreflightAcquisition(
                phase: .complete,
                ordinaryIntentPresent: true,
                stagedOrdinaryEffect: .none,
                callerEpoch: epoch,
                acceptedEpoch: epoch
            ),
            "ordinary-first leaves its durable preflight as the sole journal owner"
        )
        XCTAssertFalse(
            NightFlockAccountDeletionIntentPolicy.permitsExclusivePreflightAcquisition(
                phase: .complete,
                ordinaryIntentPresent: false,
                stagedOrdinaryEffect: .clearOutboxesAndRunContexts,
                callerEpoch: epoch,
                acceptedEpoch: epoch
            ),
            "an accepted ordinary marker remains the sole reconciliation owner"
        )
        for phase in [NightFlockAccountDeletionIntentPolicy.Phase.pendingPreflight, .acceptedTombstone] {
            XCTAssertFalse(
                NightFlockAccountDeletionIntentPolicy.permitsExclusivePreflightAcquisition(
                    phase: phase,
                    ordinaryIntentPresent: false,
                    stagedOrdinaryEffect: .none,
                    callerEpoch: epoch,
                    acceptedEpoch: epoch
                )
            )
            XCTAssertFalse(
                NightFlockAccountDeletionIntentPolicy.permitsOrdinaryIntentTransition(
                    phase: phase,
                    callerEpoch: epoch,
                    acceptedEpoch: epoch
                ),
                "deletion-first keeps a pre-existing ordinary journal untouched"
            )
        }
        XCTAssertTrue(
            NightFlockAccountDeletionIntentPolicy.permitsOrdinaryIntentTransition(
                phase: .complete,
                callerEpoch: epoch,
                acceptedEpoch: epoch
            )
        )
    }

    func testTransportRecoveryEpochInvalidatesOnlyStaleTransportResults() {
        let initial: UInt64 = 9
        XCTAssertTrue(NightFlockTransportEpochPolicy.isCurrent(captured: initial, current: initial))
        let recovery = NightFlockTransportEpochPolicy.advancing(initial)
        XCTAssertFalse(NightFlockTransportEpochPolicy.isCurrent(captured: initial, current: recovery))
        XCTAssertTrue(NightFlockTransportEpochPolicy.isCurrent(captured: recovery, current: recovery))
        let completedRecovery = NightFlockTransportEpochPolicy.advancing(recovery)
        XCTAssertFalse(NightFlockTransportEpochPolicy.isCurrent(captured: recovery, current: completedRecovery))
        XCTAssertTrue(NightFlockTransportEpochPolicy.isCurrent(captured: completedRecovery, current: completedRecovery))
    }

    func testDestructivePreflightEpochGivesOnlyTheJournalOwnerAValidTransportToken() {
        let beforePreflight: UInt64 = 47
        XCTAssertTrue(NightFlockTransportEpochPolicy.isCurrent(
            captured: beforePreflight,
            current: beforePreflight
        ))

        let ordinaryIntentOwner = NightFlockTransportEpochPolicy.advancing(beforePreflight)
        XCTAssertFalse(NightFlockTransportEpochPolicy.isCurrent(
            captured: beforePreflight,
            current: ordinaryIntentOwner
        ), "a stale linked_account_required/error cannot present during an ordinary journal")
        XCTAssertTrue(NightFlockTransportEpochPolicy.isCurrent(
            captured: ordinaryIntentOwner,
            current: ordinaryIntentOwner
        ))

        let accountDeletionOwner = NightFlockTransportEpochPolicy.advancing(ordinaryIntentOwner)
        XCTAssertFalse(NightFlockTransportEpochPolicy.isCurrent(
            captured: ordinaryIntentOwner,
            current: accountDeletionOwner
        ), "a pre-deletion task cannot mutate the closed deletion presentation")
        XCTAssertTrue(NightFlockTransportEpochPolicy.isCurrent(
            captured: accountDeletionOwner,
            current: accountDeletionOwner
        ))
    }

    func testTransportEpochRejectsDelayedAnonymousAuthSignalAfterRecoveryAndPreservesCallbackOwnership() {
        let anonymousRequestEpoch: UInt64 = 31
        let reconnectEpoch = NightFlockTransportEpochPolicy.advancing(anonymousRequestEpoch)

        // A delayed linked_account_required from the old anonymous request
        // cannot establish a new recovery after the reconnect request starts.
        XCTAssertFalse(
            NightFlockTransportEpochPolicy.isCurrent(
                captured: anonymousRequestEpoch,
                current: reconnectEpoch
            )
        )
        XCTAssertTrue(
            NightFlockTransportEpochPolicy.isCurrent(
                captured: reconnectEpoch,
                current: reconnectEpoch
            )
        )
        XCTAssertTrue(
            NightFlockAuthenticationRecoveryCompletionPolicy.ownsCallback(
                captured: .reauthenticateApple,
                current: .reauthenticateApple
            )
        )
        XCTAssertFalse(
            NightFlockAuthenticationRecoveryCompletionPolicy.ownsCallback(
                captured: .reauthenticateApple,
                current: .failClosed
            )
        )

        let completedEpoch = NightFlockTransportEpochPolicy.advancing(reconnectEpoch)
        XCTAssertFalse(
            NightFlockTransportEpochPolicy.isCurrent(
                captured: reconnectEpoch,
                current: completedEpoch
            )
        )
    }

    func testPendingDestructiveIntentCodableResolutionAndNoReplayDisposition() throws {
        let blockedMember = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        let otherMember = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let intents: [NightFlockPendingDestructiveIntent] = [
            .leave,
            .block(memberID: blockedMember),
            .deleteNightFlockData,
            .sharingOff
        ]
        for intent in intents {
            let encoded = try JSONEncoder().encode(intent)
            XCTAssertEqual(try JSONDecoder().decode(NightFlockPendingDestructiveIntent.self, from: encoded), intent)
        }

        let sharingOn = pendingIntentSnapshot(sharingEnabled: true, members: [
            NightFlockMember(id: blockedMember, alias: "Rowan", role: .member)
        ])
        let sharingOff = pendingIntentSnapshot(sharingEnabled: false, members: [
            NightFlockMember(id: otherMember, alias: "Wren", role: .member)
        ])

        XCTAssertEqual(NightFlockPendingIntentPolicy.resolve(intent: .leave, snapshot: nil), .applied)
        XCTAssertEqual(NightFlockPendingIntentPolicy.resolve(intent: .leave, snapshot: sharingOn), .notApplied)
        XCTAssertEqual(NightFlockPendingIntentPolicy.resolve(intent: .deleteNightFlockData, snapshot: nil), .applied)
        XCTAssertEqual(NightFlockPendingIntentPolicy.resolve(intent: .deleteNightFlockData, snapshot: sharingOn), .notApplied)
        XCTAssertEqual(NightFlockPendingIntentPolicy.resolve(intent: .sharingOff, snapshot: sharingOff), .applied)
        XCTAssertEqual(NightFlockPendingIntentPolicy.resolve(intent: .sharingOff, snapshot: sharingOn), .notApplied)
        XCTAssertEqual(NightFlockPendingIntentPolicy.resolve(intent: .sharingOff, snapshot: nil), .applied)
        XCTAssertEqual(NightFlockPendingIntentPolicy.resolve(intent: .block(memberID: blockedMember), snapshot: sharingOn), .notApplied)
        XCTAssertEqual(NightFlockPendingIntentPolicy.resolve(intent: .block(memberID: blockedMember), snapshot: sharingOff), .applied)
        XCTAssertEqual(NightFlockPendingIntentPolicy.resolve(intent: .block(memberID: blockedMember), snapshot: nil), .applied)

        XCTAssertFalse(NightFlockPendingIntentPolicy.permitsFlush(intentPresent: true))
        XCTAssertTrue(NightFlockPendingIntentPolicy.permitsFlush(intentPresent: false))
        XCTAssertEqual(
            NightFlockPendingIntentPolicy.disposition(for: .applied),
            .commitDestructiveClear
        )
        for resolution in [NightFlockPendingIntentPolicy.Resolution.notApplied, .unknown] {
            for lane in ["v1", "v2", "v3", "context"] {
                XCTAssertNotEqual(
                    NightFlockPendingIntentPolicy.disposition(for: resolution),
                    .commitDestructiveClear,
                    "\(resolution) preserves the \(lane) lane"
                )
            }
        }
    }

    func testPendingDestructiveIntentTransitionIsMarkerFirstAndFailureClassificationIsConservative() {
        let markerFirst = NightFlockPendingIntentTransitionPolicy.afterAcceptedMarkerWrite(
            effect: .clearOutboxesAndRunContexts
        )
        XCTAssertEqual(markerFirst.stagedEffect, .clearOutboxesAndRunContexts)
        XCTAssertTrue(markerFirst.pendingIntentPresent, "termination after marker write must reconcile, never replay")
        XCTAssertEqual(
            NightFlockPendingIntentTransitionPolicy.relaunchResolution(
                stagedEffect: markerFirst.stagedEffect,
                pendingIntentPresent: markerFirst.pendingIntentPresent
            ),
            .commitAcceptedMarkerThenRemoveIntent,
            "the accepted marker dominates an eventually-consistent intent resolver"
        )
        let completed = NightFlockPendingIntentTransitionPolicy.afterAcceptedTransition(
            effect: .clearOutboxesAndRunContexts
        )
        XCTAssertEqual(completed.stagedEffect, .clearOutboxesAndRunContexts)
        XCTAssertFalse(completed.pendingIntentPresent)
        XCTAssertEqual(
            NightFlockPendingIntentTransitionPolicy.relaunchResolution(
                stagedEffect: .none,
                pendingIntentPresent: true
            ),
            .resolvePendingIntent
        )
        XCTAssertEqual(
            NightFlockPendingIntentTransitionPolicy.afterDefinitiveRejection(),
            .init(stagedEffect: .none, pendingIntentPresent: false)
        )

        let rejection = NightFlockRemoteError.decode(
            statusCode: 400,
            data: Data(#"{"code":"invalid_request"}"#.utf8)
        )
        let ambiguous = NightFlockRemoteError.decode(
            statusCode: 503,
            data: Data(#"{"code":"service_unavailable"}"#.utf8)
        )
        XCTAssertTrue(NightFlockPendingIntentPolicy.definitiveRejection(rejection))
        XCTAssertFalse(NightFlockPendingIntentPolicy.definitiveRejection(ambiguous))
        XCTAssertFalse(NightFlockPendingIntentPolicy.definitiveRejection(nil))
    }

    func testDestructiveIntentAuthenticationFailuresPresentRecoveryWhileAmbiguityRetainsJournal() {
        XCTAssertEqual(
            NightFlockPendingIntentPolicy.failureDisposition(remoteCode: .unauthorized),
            .presentAuthenticationRecovery
        )
        XCTAssertEqual(
            NightFlockPendingIntentPolicy.failureDisposition(remoteCode: .linkedAccountRequired),
            .presentAuthenticationRecovery
        )
        XCTAssertEqual(
            NightFlockPendingIntentPolicy.failureDisposition(remoteCode: .serviceUnavailable),
            .retainAmbiguousJournal
        )
        XCTAssertEqual(
            NightFlockPendingIntentPolicy.failureDisposition(remoteCode: nil),
            .retainAmbiguousJournal,
            "a timeout has no typed remote envelope and remains ambiguous"
        )

        let expected = NightFlockExpectedIdentity.valid(
            UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        )
        for lane in [
            NightFlockRecoveryLane.directCommand(schema: 1),
            .directCommand(schema: 2),
            .directCommand(schema: 3)
        ] {
            XCTAssertEqual(
                NightFlockAuthenticationRecoveryPolicy.decide(
                    remoteCode: .unauthorized,
                    lane: lane,
                    session: .linked,
                    expectedIdentity: expected
                ).action,
                .reauthenticateApple,
                "401 during \(lane) keeps the destructive journal and reconnects"
            )
            XCTAssertEqual(
                NightFlockAuthenticationRecoveryPolicy.decide(
                    remoteCode: .linkedAccountRequired,
                    lane: lane,
                    session: .linked,
                    expectedIdentity: expected
                ).action,
                .failClosed,
                "linked_account_required never swaps an already bound account"
            )
        }
        // The same classifier covers an accepted marker's follow-up state()
        // load: the marker remains durable while this auth UI is presented.
        XCTAssertEqual(
            NightFlockPendingIntentPolicy.failureDisposition(remoteCode: .unauthorized),
            .presentAuthenticationRecovery
        )
    }

    func testPendingOrStagedDestructiveJournalClosesInMemorySocialProducers() {
        XCTAssertFalse(NightFlockPendingIntentPolicy.permitsLocalMutation(
            intentPresent: true,
            stagedEffect: .none,
            authenticationTransportPermitted: true
        ))
        XCTAssertFalse(NightFlockPendingIntentPolicy.permitsLocalMutation(
            intentPresent: false,
            stagedEffect: .clearOutboxesAndRunContexts,
            authenticationTransportPermitted: true
        ))
        XCTAssertFalse(NightFlockPendingIntentPolicy.permitsLocalMutation(
            intentPresent: false,
            stagedEffect: .none,
            authenticationTransportPermitted: false
        ))
        XCTAssertTrue(NightFlockPendingIntentPolicy.permitsLocalMutation(
            intentPresent: false,
            stagedEffect: .none,
            authenticationTransportPermitted: true
        ), "authoritative notApplied or completed same-account recovery reopens only with no journal")
    }

    private func pendingIntentSnapshot(
        sharingEnabled: Bool,
        members: [NightFlockMember]
    ) -> NightFlockSnapshot {
        let mine = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!
        return NightFlockSnapshot(
            profile: NightFlockProfile(alias: "Moss"),
            flockID: UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!,
            identity: .moonlitMeadow,
            myMemberID: mine,
            members: members,
            challenge: NightFlockChallenge(
                id: UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")!,
                timeZoneIdentifier: "UTC",
                startsOn: NightFlockLocalDate(year: 2026, month: 8, day: 23),
                status: .active
            ),
            days: [],
            sharingEnabled: sharingEnabled
        )
    }
}
