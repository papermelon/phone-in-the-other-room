import CryptoKit
import Foundation

/// Schema three adds nightly shared metrics and server-authoritative Farm grants
/// without rewriting schema-one or schema-two commands.
enum NightFlockV3Command: Equatable, Sendable {
    case setSharingPreferences(NightFlockSharingPreferences, idempotencyKey: String)
    case publishNightMetrics(
        challengeID: UUID,
        day: Int,
        status: NightFlockMemberNightStatus,
        shieldingEvidence: NightFlockShieldingEvidence,
        windDownMinutes: Int,
        phoneAwayMinutes: Int,
        sleepDurationMinutes: Int?,
        restfulness: MorningRestfulness?,
        idempotencyKey: String
    )
    case acknowledgeGrant(grantID: UUID, idempotencyKey: String)
}

struct NightFlockV3CommandRequest: Encodable, Equatable, Sendable {
    let schemaVersion = 3
    var command: NightFlockV3Command

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, command, shareGoalProgress, shareWindDownCompletion
        case shareWindDownMinutes, sharePhoneAwayMinutes, sharePhoneTuckedAway
        case shareShieldingStatus, shareRoutineIdeas, shareSleepDuration, shareRestfulness
        case challengeID, day, status, shieldingEvidence, windDownMinutes, phoneAwayMinutes
        case sleepDurationMinutes, restfulness, grantID, idempotencyKey
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        switch command {
        case let .setSharingPreferences(sharing, idempotencyKey):
            try container.encode("setSharingPreferences", forKey: .command)
            try container.encode(sharing.shareGoalProgress, forKey: .shareGoalProgress)
            try container.encode(sharing.shareWindDownCompletion, forKey: .shareWindDownCompletion)
            try container.encode(sharing.shareWindDownMinutes, forKey: .shareWindDownMinutes)
            try container.encode(sharing.sharePhoneAwayMinutes, forKey: .sharePhoneAwayMinutes)
            try container.encode(sharing.sharePhoneTuckedAway, forKey: .sharePhoneTuckedAway)
            try container.encode(sharing.shareShieldingStatus, forKey: .shareShieldingStatus)
            try container.encode(sharing.shareRoutineIdeas, forKey: .shareRoutineIdeas)
            try container.encode(sharing.shareSleepDuration, forKey: .shareSleepDuration)
            try container.encode(sharing.shareRestfulness, forKey: .shareRestfulness)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .publishNightMetrics(
            challengeID, day, status, shieldingEvidence, windDownMinutes, phoneAwayMinutes,
            sleepDurationMinutes, restfulness, idempotencyKey
        ):
            try container.encode("publishNightMetrics", forKey: .command)
            try container.encode(challengeID, forKey: .challengeID)
            try container.encode(day, forKey: .day)
            try container.encode(status, forKey: .status)
            try container.encode(shieldingEvidence, forKey: .shieldingEvidence)
            try container.encode(windDownMinutes, forKey: .windDownMinutes)
            try container.encode(phoneAwayMinutes, forKey: .phoneAwayMinutes)
            try container.encode(sleepDurationMinutes, forKey: .sleepDurationMinutes)
            try container.encode(restfulness, forKey: .restfulness)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .acknowledgeGrant(grantID, idempotencyKey):
            try container.encode("acknowledgeGrant", forKey: .command)
            try container.encode(grantID, forKey: .grantID)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        }
    }
}

struct NightFlockV3StateRequest: Encodable, Equatable, Sendable {
    let schemaVersion = 3
}

struct NightFlockV3CommandResponse: Decodable, Equatable, Sendable {
    var schemaVersion: Int
    var accepted: Bool
    var snapshot: NightFlockSnapshot?
}

struct NightFlockV3StateResponse: Decodable, Equatable, Sendable {
    var schemaVersion: Int
    var snapshot: NightFlockSnapshot?
}

struct NightFlockV3OutboxRecord: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var challengeID: UUID
    var memberID: UUID
    var challengeDay: Int
    var runID: UUID
    var status: NightFlockMemberNightStatus
    var shieldingEvidence: NightFlockShieldingEvidence
    var windDownMinutes: Int
    var phoneAwayMinutes: Int
    var sleepDurationMinutes: Int?
    var restfulness: MorningRestfulness?
    var idempotencyKey: String
    var createdAt: Date
    var attemptCount: Int

    init(
        id: UUID = UUID(),
        challengeID: UUID,
        memberID: UUID,
        challengeDay: Int,
        runID: UUID,
        status: NightFlockMemberNightStatus,
        shieldingEvidence: NightFlockShieldingEvidence,
        windDownMinutes: Int,
        phoneAwayMinutes: Int,
        sleepDurationMinutes: Int? = nil,
        restfulness: MorningRestfulness? = nil,
        idempotencyKey: String,
        createdAt: Date = Date(),
        attemptCount: Int = 0
    ) {
        self.id = id
        self.challengeID = challengeID
        self.memberID = memberID
        self.challengeDay = challengeDay
        self.runID = runID
        self.status = status
        self.shieldingEvidence = shieldingEvidence
        self.windDownMinutes = NightFlockSharedMetricRules.roundWindDownMinutes(windDownMinutes) ?? 0
        self.phoneAwayMinutes = NightFlockSharedMetricRules.roundPhoneAwayMinutes(phoneAwayMinutes) ?? 0
        self.sleepDurationMinutes = sleepDurationMinutes.flatMap(NightFlockSharedMetricRules.roundSleepMinutes)
        self.restfulness = restfulness
        self.idempotencyKey = idempotencyKey
        self.createdAt = createdAt
        self.attemptCount = attemptCount
    }
}

enum NightFlockV3OutboxRules {
    static func merge(
        _ record: NightFlockV3OutboxRecord,
        into existing: [NightFlockV3OutboxRecord]
    ) -> [NightFlockV3OutboxRecord] {
        var result = existing
        if let index = result.firstIndex(where: {
            $0.challengeID == record.challengeID
                && $0.memberID == record.memberID
                && $0.challengeDay == record.challengeDay
        }) {
            var merged = result[index]
            merged.status = NightFlockProgressRules.monotonicStatus(
                current: merged.status,
                proposed: record.status
            )
            merged.windDownMinutes = max(merged.windDownMinutes, record.windDownMinutes)
            merged.phoneAwayMinutes = max(merged.phoneAwayMinutes, record.phoneAwayMinutes)
            merged.sleepDurationMinutes = maxOptional(
                merged.sleepDurationMinutes,
                record.sleepDurationMinutes
            )
            merged.restfulness = record.restfulness ?? merged.restfulness
            merged.shieldingEvidence = record.shieldingEvidence
            merged.idempotencyKey = record.idempotencyKey
            merged.runID = record.runID
            result[index] = merged
        } else {
            result.append(record)
        }
        return Array(result.sorted { $0.createdAt < $1.createdAt }.suffix(64))
    }

    private static func maxOptional(_ lhs: Int?, _ rhs: Int?) -> Int? {
        switch (lhs, rhs) {
        case let (left?, right?): return max(left, right)
        case let (left?, nil): return left
        case let (nil, right?): return right
        case (nil, nil): return nil
        }
    }
}

enum NightFlockV3Idempotency {
    static func command(_ kind: String, seed: UUID = UUID()) -> String {
        let input = "night-flock-v3:\(kind):\(seed.uuidString.lowercased())"
        return SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
