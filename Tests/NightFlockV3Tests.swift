import XCTest

final class NightFlockV3Tests: XCTestCase {
    func testMinuteRoundingStaysBoundedAndStepped() {
        XCTAssertEqual(NightFlockSharedMetricRules.roundWindDownMinutes(32), 30)
        XCTAssertEqual(NightFlockSharedMetricRules.roundWindDownMinutes(33), 35)
        XCTAssertNil(NightFlockSharedMetricRules.roundWindDownMinutes(400))
        XCTAssertEqual(NightFlockSharedMetricRules.roundPhoneAwayMinutes(12), 10)
        XCTAssertEqual(NightFlockSharedMetricRules.roundSleepMinutes(22), 15)
        XCTAssertNil(NightFlockSharedMetricRules.roundSleepMinutes(900))
        XCTAssertNil(NightFlockSharedMetricRules.roundWindDownMinutes(-4))
        XCTAssertEqual(NightFlockSharedMetricRules.roundWindDownMinutes(0), 0)
        XCTAssertEqual(NightFlockSharedMetricRules.roundWindDownMinutes(180), 180)
    }

    func testSharingDefaultsOnAfterJoinAndSleepStaysOptIn() {
        let defaults = NightFlockSharingPreferences.joinDefaults
        XCTAssertTrue(defaults.shareGoalProgress)
        XCTAssertTrue(defaults.shareWindDownCompletion)
        XCTAssertTrue(defaults.shareWindDownMinutes)
        XCTAssertTrue(defaults.sharePhoneAwayMinutes)
        XCTAssertTrue(defaults.sharePhoneTuckedAway)
        XCTAssertTrue(defaults.shareShieldingStatus)
        XCTAssertFalse(defaults.shareRoutineIdeas)
        XCTAssertFalse(defaults.shareSleepDuration)
        XCTAssertFalse(defaults.shareRestfulness)
    }

    func testLegacySharingPreferencesDecodeWithoutNewFields() throws {
        let json = #"{"shareGoalProgress":false,"shareRoutineIdeas":true}"#
        let decoded = try JSONDecoder().decode(
            NightFlockSharingPreferences.self,
            from: Data(json.utf8)
        )
        XCTAssertFalse(decoded.shareGoalProgress)
        XCTAssertTrue(decoded.shareRoutineIdeas)
        XCTAssertFalse(decoded.shareSleepDuration)
        XCTAssertFalse(decoded.shareWindDownMinutes)
    }

    func testHiddenSharingFieldsDoNotAppearInProjection() {
        let memberID = UUID()
        let progress = NightFlockMemberNightProgress(
            memberID: memberID,
            day: 1,
            status: .morningQuietCompleted,
            shieldingEvidence: .observed,
            windDownMinutes: 45,
            phoneAwayMinutes: 20,
            sleepDurationMinutes: 450,
            restfulness: .rested
        )
        let hiddenSleep = NightFlockSharingPreferences(shareSleepDuration: false, shareRestfulness: false)
        let projected = NightFlockProjectionRules.projectedProgress(progress, sharing: hiddenSleep)
        XCTAssertEqual(projected.status, .morningQuietCompleted)
        XCTAssertEqual(projected.windDownMinutes, 45)
        XCTAssertNil(projected.sleepDurationMinutes)
        XCTAssertNil(projected.restfulness)

        let hiddenGoal = NightFlockSharingPreferences(
            shareGoalProgress: false,
            shareWindDownCompletion: false,
            sharePhoneTuckedAway: false
        )
        XCTAssertEqual(
            NightFlockProjectionRules.projectedProgress(progress, sharing: hiddenGoal).status,
            .privateNoUpdate
        )
        let goalOnCompletionOff = NightFlockSharingPreferences(
            shareGoalProgress: true,
            shareWindDownCompletion: false,
            sharePhoneTuckedAway: true
        )
        XCTAssertEqual(
            NightFlockProjectionRules.projectedStatus(.morningQuietCompleted, sharing: goalOnCompletionOff),
            .phoneTuckedAway
        )
        let goalOnTuckedOff = NightFlockSharingPreferences(
            shareGoalProgress: true,
            shareWindDownCompletion: false,
            sharePhoneTuckedAway: false
        )
        XCTAssertEqual(
            NightFlockProjectionRules.projectedStatus(.morningQuietCompleted, sharing: goalOnTuckedOff),
            .privateNoUpdate
        )
        XCTAssertEqual(
            NightFlockProjectionRules.projectedStatus(.setupReady, sharing: goalOnTuckedOff),
            .setupReady
        )
        XCTAssertEqual(
            NightFlockMemberNightStatus.privateNoUpdate.title,
            "No update shared"
        )
        XCTAssertEqual(
            NightFlockShieldingEvidence.observed.title,
            "App shielding was observed"
        )
    }

    func testV3PublishRequestOmitsTokensAndExactTimes() throws {
        let request = NightFlockV3CommandRequest(command: .publishNightMetrics(
            challengeID: UUID(),
            day: 2,
            status: .morningQuietCompleted,
            shieldingEvidence: .observed,
            windDownMinutes: 32,
            phoneAwayMinutes: 18,
            sleepDurationMinutes: 450,
            restfulness: .somewhat,
            idempotencyKey: String(repeating: "b", count: 64)
        ))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )
        XCTAssertEqual(object["schemaVersion"] as? Int, 3)
        XCTAssertEqual(object["windDownMinutes"] as? Int, 32)
        for key in [
            "applicationTokens", "selectedApps", "familyActivitySelection", "healthKit",
            "runID", "bedtime", "wakeTime", "screenTime", "nfc", "impactNights"
        ] {
            XCTAssertNil(object[key], "Forbidden field \(key) leaked into schema three")
        }
    }

    func testV3OutboxMergesMinutesMonotonically() {
        let challengeID = UUID()
        let memberID = UUID()
        let first = NightFlockV3OutboxRecord(
            challengeID: challengeID,
            memberID: memberID,
            challengeDay: 1,
            runID: UUID(),
            status: .phoneTuckedAway,
            shieldingEvidence: .partial,
            windDownMinutes: 20,
            phoneAwayMinutes: 10,
            idempotencyKey: "one"
        )
        let second = NightFlockV3OutboxRecord(
            challengeID: challengeID,
            memberID: memberID,
            challengeDay: 1,
            runID: UUID(),
            status: .morningQuietCompleted,
            shieldingEvidence: .observed,
            windDownMinutes: 40,
            phoneAwayMinutes: 5,
            sleepDurationMinutes: 420,
            restfulness: .rested,
            idempotencyKey: "two"
        )
        let merged = NightFlockV3OutboxRules.merge(second, into: [first]).first
        XCTAssertEqual(merged?.status, .morningQuietCompleted)
        XCTAssertEqual(merged?.windDownMinutes, 40)
        XCTAssertEqual(merged?.phoneAwayMinutes, 10)
        XCTAssertEqual(merged?.sleepDurationMinutes, 420)
        let downgrade = NightFlockV3OutboxRules.merge(first, into: [second]).first
        XCTAssertEqual(downgrade?.status, .morningQuietCompleted)
        XCTAssertEqual(downgrade?.windDownMinutes, 40)
        let supplement = NightFlockV3OutboxRecord(
            challengeID: challengeID,
            memberID: memberID,
            challengeDay: 1,
            runID: UUID(),
            status: .privateNoUpdate,
            shieldingEvidence: .notRequested,
            windDownMinutes: 0,
            phoneAwayMinutes: 0,
            sleepDurationMinutes: 450,
            restfulness: .somewhat,
            idempotencyKey: "three"
        )
        let supplemented = NightFlockV3OutboxRules.merge(supplement, into: [second]).first
        XCTAssertEqual(supplemented?.status, .morningQuietCompleted)
        XCTAssertEqual(supplemented?.windDownMinutes, 40)
        XCTAssertEqual(supplemented?.sleepDurationMinutes, 450)
        XCTAssertEqual(supplemented?.restfulness, .somewhat)
    }

    func testProgressStatusDoesNotTreatPartialAsQualifying() {
        XCTAssertTrue(NightFlockProgressRules.isQualifying(.morningQuietCompleted))
        XCTAssertTrue(NightFlockProgressRules.isQualifying(.sharedGoalCompleted))
        XCTAssertFalse(NightFlockProgressRules.isQualifying(.partiallyCompleted))
        XCTAssertFalse(NightFlockProgressRules.isQualifying(.privateNoUpdate))
        XCTAssertEqual(
            NightFlockProgressRules.status(
                for: NightFlockSharedGoal(kind: .quietMinutes, targetMinutes: 30),
                tuckedAway: true,
                completedSuccessfully: true,
                quietMinutes: 20,
                shielding: .notRequested
            ),
            .partiallyCompleted
        )
    }

    func testMemberBoardKeepsNamedProgress() throws {
        let mine = UUID()
        let peer = UUID()
        let snapshot = NightFlockSnapshot(
            profile: NightFlockProfile(alias: "Moss"),
            flockID: UUID(),
            identity: .moonlitMeadow,
            myMemberID: mine,
            members: [
                NightFlockMember(id: mine, alias: "Moss", role: .keeper),
                NightFlockMember(id: peer, alias: "Clover", role: .member)
            ],
            challenge: NightFlockChallenge(
                id: UUID(),
                timeZoneIdentifier: "UTC",
                startsOn: NightFlockLocalDate(year: 2026, month: 8, day: 12),
                status: .active,
                sharedGoal: NightFlockSharedGoal(kind: .phoneAway)
            ),
            days: [
                NightFlockDaySummary(
                    day: 1,
                    phoneTuckedCount: 2,
                    morningQuietCompletedCount: 1,
                    pasture: [],
                    memberProgress: [
                        NightFlockMemberNightProgress(
                            memberID: mine,
                            day: 1,
                            status: .morningQuietCompleted,
                            shieldingEvidence: .observed,
                            windDownMinutes: 40
                        ),
                        NightFlockMemberNightProgress(
                            memberID: peer,
                            day: 1,
                            status: .partiallyCompleted,
                            shieldingEvidence: .partial,
                            windDownMinutes: 15
                        )
                    ]
                )
            ],
            sharingEnabled: true
        )
        let tonight = try XCTUnwrap(snapshot.challenge.startsOn.date(in: snapshot.challenge.timeZoneIdentifier))
        let rows = NightFlockMemberBoard.rows(from: snapshot, at: tonight)
        XCTAssertEqual(rows.map(\.alias), ["Moss", "Clover"])
        XCTAssertEqual(rows.first?.qualifyingNights, 1)
        XCTAssertEqual(rows.first?.tonightStatus, .morningQuietCompleted)
        XCTAssertEqual(rows.last?.tonightStatus, .partiallyCompleted)
        XCTAssertFalse(rows.contains { $0.alias.isEmpty })
    }

    func testV1AndV2RequestsRemainDecodableBesideSchemaThree() throws {
        let v1 = NightFlockCommandRequest(command: .setSharing(enabled: true, idempotencyKey: "k"))
        let v2 = NightFlockV2CommandRequest(command: .setSharingPreferences(
            shareGoalProgress: true,
            shareRoutineIdeas: false,
            idempotencyKey: String(repeating: "c", count: 64)
        ))
        let v1Object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(v1)) as? [String: Any]
        )
        XCTAssertEqual(v1Object["schemaVersion"] as? Int, 1)
        XCTAssertNil(v1Object["windDownMinutes"])
        let v2Object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(v2)) as? [String: Any]
        )
        XCTAssertEqual(v2Object["schemaVersion"] as? Int, 2)
        XCTAssertNil(v2Object["shareSleepDuration"])
        XCTAssertNil(v2Object["sleepDurationMinutes"])
    }

    func testJoinConsentNamesDefaultOnFieldsAndSleepOptIn() {
        let copy = NightFlockSharingConsentCopy.joinDisclosure
        XCTAssertTrue(copy.contains("Wind Down"))
        XCTAssertTrue(copy.contains("Phone Away"))
        XCTAssertTrue(copy.contains("tucked away"))
        XCTAssertTrue(copy.contains("Sleep duration"))
        XCTAssertTrue(copy.contains("stay off"))
    }

    func testRunShareContextPrefersMemoryThenPersisted() {
        let runID = UUID()
        let memory = NightFlockRunShareContext(
            runID: runID,
            challengeID: UUID(),
            memberID: UUID(),
            challengeDay: 2,
            createdAt: Date(),
            phoneTuckedQueued: true
        )
        let persisted = NightFlockRunShareContext(
            runID: runID,
            challengeID: memory.challengeID,
            memberID: memory.memberID,
            challengeDay: 1,
            createdAt: Date(),
            phoneTuckedQueued: false
        )
        XCTAssertEqual(
            NightFlockRunShareContextResolver.resolve(
                runID: runID,
                memory: [runID: memory],
                persisted: [persisted]
            )?.challengeDay,
            2
        )
        XCTAssertEqual(
            NightFlockRunShareContextResolver.resolve(
                runID: runID,
                memory: [:],
                persisted: [persisted]
            )?.challengeDay,
            1
        )
        XCTAssertNil(
            NightFlockRunShareContextResolver.resolve(
                runID: UUID(),
                memory: [runID: memory],
                persisted: [persisted]
            )
        )
    }
}
