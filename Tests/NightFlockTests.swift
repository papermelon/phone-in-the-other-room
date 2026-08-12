import XCTest

final class NightFlockTests: XCTestCase {
    func testChallengeDayUsesLockedTimezoneAcrossUTCDateBoundary() throws {
        let challenge = NightFlockChallenge(
            id: UUID(),
            timeZoneIdentifier: "Asia/Singapore",
            startsOn: NightFlockLocalDate(year: 2026, month: 8, day: 12),
            status: .active
        )
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-11T16:30:00Z"))
        XCTAssertEqual(NightFlockChallengeDayRules.challengeDay(at: date, challenge: challenge), 1)
    }

    func testChallengeDayStopsAfterSevenLockedLocalDays() throws {
        let challenge = NightFlockChallenge(
            id: UUID(),
            timeZoneIdentifier: "America/Los_Angeles",
            startsOn: NightFlockLocalDate(year: 2026, month: 3, day: 6),
            status: .active
        )
        let formatter = ISO8601DateFormatter()
        let seventhDay = try XCTUnwrap(formatter.date(from: "2026-03-12T19:00:00Z"))
        let eighthDay = try XCTUnwrap(formatter.date(from: "2026-03-13T19:00:00Z"))
        XCTAssertEqual(NightFlockChallengeDayRules.challengeDay(at: seventhDay, challenge: challenge), 7)
        XCTAssertNil(NightFlockChallengeDayRules.challengeDay(at: eighthDay, challenge: challenge))
    }

    func testSmallFlockAggregateSuppressesRevealingCount() {
        let presentation = NightFlockAggregatePresentation.nighttime(
            positiveCount: 1,
            memberCount: 2
        )
        XCTAssertEqual(presentation.title, "Someone in the flock has tucked in.")
        XCTAssertFalse(presentation.title.contains("1"))
        XCTAssertFalse(presentation.detail.contains("missing"))
    }

    func testLargeFlockAggregateCountsOnlyPositiveStates() {
        let presentation = NightFlockAggregatePresentation.morning(
            positiveCount: 4,
            memberCount: 6
        )
        XCTAssertEqual(presentation.title, "4 quiet mornings reached the pasture.")
        XCTAssertFalse(presentation.title.contains("2"))
    }

    func testSmallFlockPastureSuppressesExactEntryCount() {
        let entries = (0..<3).map { _ in
            NightFlockPastureEntry(
                id: UUID(),
                state: .morningQuietCompleted,
                reactions: []
            )
        }
        XCTAssertEqual(
            NightFlockPrivacyPresentation.pastureEntries(entries, memberCount: 3).count,
            1
        )
        XCTAssertEqual(
            NightFlockPrivacyPresentation.pastureEntries(entries, memberCount: 4).count,
            3
        )
    }

    func testCheckInStateIsMonotonic() {
        XCTAssertLessThan(NightFlockCheckInState.none, .phoneTucked)
        XCTAssertLessThan(NightFlockCheckInState.phoneTucked, .morningQuietCompleted)
    }

    func testOutboxMergeUpgradesAndNeverDowngrades() {
        let challengeID = UUID()
        let memberID = UUID()
        let runID = UUID()
        let start = NightFlockOutboxRecord(
            challengeID: challengeID,
            memberID: memberID,
            challengeDay: 2,
            runID: runID,
            state: .phoneTucked,
            idempotencyKey: "start"
        )
        let completed = NightFlockOutboxRecord(
            challengeID: challengeID,
            memberID: memberID,
            challengeDay: 2,
            runID: runID,
            state: .morningQuietCompleted,
            idempotencyKey: "complete"
        )
        XCTAssertEqual(NightFlockOutboxRules.merge(completed, into: [start]).first?.state, .morningQuietCompleted)
        XCTAssertEqual(NightFlockOutboxRules.merge(start, into: [completed]).first?.state, .morningQuietCompleted)
    }

    func testPublishRequestCannotEncodeSensitiveRunFields() throws {
        let request = NightFlockCommandRequest(command: .publishCheckIn(
            challengeID: UUID(),
            day: 3,
            state: .phoneTucked,
            idempotencyKey: "opaque-key"
        ))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )
        let forbidden = [
            "runID", "startedAt", "endedAt", "bedtime", "wakeTime", "duration",
            "healthKit", "screenTime", "selectedApps", "nfc", "purpose", "cue",
            "notification", "farm", "sheep", "wool", "impactNights"
        ]
        for key in forbidden {
            XCTAssertNil(object[key], "Sensitive field \(key) must not be encodable")
        }
    }

    func testLegacySnapshotDecodesWithoutReactionRowsOrSharingFlag() throws {
        let json = """
        {
          "profile":{"alias":"Moss Lamb"},
          "flockID":"11111111-1111-1111-1111-111111111111",
          "identity":"moonlitMeadow",
          "myMemberID":"22222222-2222-2222-2222-222222222222",
          "members":[],
          "challenge":{
            "id":"33333333-3333-3333-3333-333333333333",
            "timeZoneIdentifier":"UTC",
            "startsOn":{"year":2026,"month":8,"day":12},
            "status":"active"
          },
          "days":[{
            "day":1,
            "phoneTuckedCount":1,
            "morningQuietCompletedCount":1,
            "pasture":[{
              "id":"44444444-4444-4444-8444-444444444444",
              "memberID":"55555555-5555-4555-8555-555555555555",
              "alias":"Old Robin",
              "state":"morningQuietCompleted"
            }]
          }]
        }
        """
        let decoded = try JSONDecoder().decode(NightFlockSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.profile.alias, "Moss Lamb")
        XCTAssertTrue(decoded.sharingEnabled)
        XCTAssertEqual(decoded.days.first?.pasture.first?.reactions, [])
    }

    func testLegacyRunShareContextDecodesBeforeQueuedMarkersExisted() throws {
        let json = """
        {
          "runID":"11111111-1111-4111-8111-111111111111",
          "challengeID":"22222222-2222-4222-8222-222222222222",
          "memberID":"33333333-3333-4333-8333-333333333333",
          "challengeDay":3,
          "createdAt":0
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(NightFlockRunShareContext.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.phoneTuckedQueued)
        XCTAssertFalse(decoded.morningQuietCompletedQueued)
    }
}
