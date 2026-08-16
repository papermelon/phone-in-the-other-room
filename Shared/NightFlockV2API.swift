import CryptoKit
import Foundation

/// Schema two adds the shared-goal lobby while leaving schema one decodable for
/// already queued commands and older development clients.
enum NightFlockV2Command: Equatable, Sendable {
    case createParty(
        goal: NightFlockSharedGoal,
        identity: NightFlockIdentity,
        timeZoneIdentifier: String,
        idempotencyKey: String
    )
    case createInvite(idempotencyKey: String)
    case previewInvite(shortCode: String, idempotencyKey: String)
    case redeemInvite(shortCode: String, idempotencyKey: String)
    case acceptGoal(challengeID: UUID, idempotencyKey: String)
    case setLocalSetup(
        challengeID: UUID,
        setupReady: Bool,
        shieldingEvidence: NightFlockShieldingEvidence,
        idempotencyKey: String
    )
    case setSharingPreferences(
        shareGoalProgress: Bool,
        shareRoutineIdeas: Bool,
        idempotencyKey: String
    )
    case setRoutineIdeas(challengeID: UUID, guidanceIDs: [String], idempotencyKey: String)
    case startChallenge(challengeID: UUID, idempotencyKey: String)
    case publishProgress(
        challengeID: UUID,
        day: Int,
        status: NightFlockMemberNightStatus,
        shieldingEvidence: NightFlockShieldingEvidence,
        idempotencyKey: String
    )
}

struct NightFlockV2CommandRequest: Encodable, Equatable, Sendable {
    let schemaVersion = 2
    var command: NightFlockV2Command

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, command, goalKind, targetMinutes, appDisplayName, identity
        case timeZoneIdentifier, shortCode, challengeID, setupReady, shieldingEvidence
        case shareGoalProgress, shareRoutineIdeas, guidanceIDs, day, status, idempotencyKey
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        switch command {
        case let .createParty(goal, identity, timeZoneIdentifier, idempotencyKey):
            try container.encode("createParty", forKey: .command)
            try container.encode(goal.kind, forKey: .goalKind)
            try container.encode(goal.targetMinutes, forKey: .targetMinutes)
            try container.encode(goal.appDisplayName, forKey: .appDisplayName)
            try container.encode(identity, forKey: .identity)
            try container.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .createInvite(idempotencyKey):
            try container.encode("createInvite", forKey: .command)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .previewInvite(shortCode, idempotencyKey):
            try container.encode("previewInvite", forKey: .command)
            try container.encode(shortCode, forKey: .shortCode)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .redeemInvite(shortCode, idempotencyKey):
            try container.encode("redeemInvite", forKey: .command)
            try container.encode(shortCode, forKey: .shortCode)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .acceptGoal(challengeID, idempotencyKey):
            try container.encode("acceptGoal", forKey: .command)
            try container.encode(challengeID, forKey: .challengeID)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .setLocalSetup(challengeID, setupReady, shieldingEvidence, idempotencyKey):
            try container.encode("setLocalSetup", forKey: .command)
            try container.encode(challengeID, forKey: .challengeID)
            try container.encode(setupReady, forKey: .setupReady)
            try container.encode(shieldingEvidence, forKey: .shieldingEvidence)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .setSharingPreferences(progress, ideas, idempotencyKey):
            try container.encode("setSharingPreferences", forKey: .command)
            try container.encode(progress, forKey: .shareGoalProgress)
            try container.encode(ideas, forKey: .shareRoutineIdeas)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .setRoutineIdeas(challengeID, guidanceIDs, idempotencyKey):
            try container.encode("setRoutineIdeas", forKey: .command)
            try container.encode(challengeID, forKey: .challengeID)
            try container.encode(guidanceIDs, forKey: .guidanceIDs)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .startChallenge(challengeID, idempotencyKey):
            try container.encode("startChallenge", forKey: .command)
            try container.encode(challengeID, forKey: .challengeID)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .publishProgress(challengeID, day, status, shieldingEvidence, idempotencyKey):
            try container.encode("publishProgress", forKey: .command)
            try container.encode(challengeID, forKey: .challengeID)
            try container.encode(day, forKey: .day)
            try container.encode(status, forKey: .status)
            try container.encode(shieldingEvidence, forKey: .shieldingEvidence)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        }
    }
}

struct NightFlockV2StateRequest: Encodable, Equatable, Sendable {
    let schemaVersion = 2
}

struct NightFlockV2CommandResponse: Decodable, Equatable, Sendable {
    var schemaVersion: Int
    var accepted: Bool
    var inviteCode: String?
    var inviteID: UUID?
    var invitePreview: NightFlockInvitePreview?
    var snapshot: NightFlockSnapshot?
}

struct NightFlockV2StateResponse: Decodable, Equatable, Sendable {
    var schemaVersion: Int
    var snapshot: NightFlockSnapshot?
}

struct NightFlockV2OutboxRecord: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var challengeID: UUID
    var memberID: UUID
    var challengeDay: Int
    var runID: UUID
    var status: NightFlockMemberNightStatus
    var shieldingEvidence: NightFlockShieldingEvidence
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
        self.idempotencyKey = idempotencyKey
        self.createdAt = createdAt
        self.attemptCount = attemptCount
    }
}

enum NightFlockV2Idempotency {
    static func command(_ kind: String, seed: UUID = UUID()) -> String {
        let input = "night-flock-v2:\(kind):\(seed.uuidString.lowercased())"
        return SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
