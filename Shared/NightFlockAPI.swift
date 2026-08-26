import CryptoKit
import Foundation

enum NightFlockCommand: Equatable, Sendable {
    case createFlock(identity: NightFlockIdentity, timeZoneIdentifier: String, idempotencyKey: String)
    case createInvite(idempotencyKey: String)
    case revokeInvite(inviteID: UUID, idempotencyKey: String)
    case join(shortCode: String, idempotencyKey: String)
    case leave(idempotencyKey: String)
    case setSharing(enabled: Bool, idempotencyKey: String)
    case block(memberID: UUID, idempotencyKey: String)
    case report(memberID: UUID, reason: NightFlockReportReason, idempotencyKey: String)
    case publishCheckIn(challengeID: UUID, day: Int, state: NightFlockCheckInState, idempotencyKey: String)
    case react(checkInID: UUID, reaction: NightFlockReactionKind, idempotencyKey: String)
    case deleteNightFlockData(idempotencyKey: String)
    case deleteAccount(idempotencyKey: String)
}

struct NightFlockCommandRequest: Encodable, Equatable, Sendable {
    let schemaVersion = 1
    var command: NightFlockCommand

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case command
        case identity
        case timeZoneIdentifier
        case shortCode
        case inviteID
        case memberID
        case reason
        case challengeID
        case day
        case state
        case enabled
        case checkInID
        case reaction
        case idempotencyKey
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        switch command {
        case let .createFlock(identity, timeZoneIdentifier, idempotencyKey):
            try container.encode("createFlock", forKey: .command)
            try container.encode(identity, forKey: .identity)
            try container.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .createInvite(idempotencyKey):
            try container.encode("createInvite", forKey: .command)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .revokeInvite(inviteID, idempotencyKey):
            try container.encode("revokeInvite", forKey: .command)
            try container.encode(inviteID, forKey: .inviteID)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .join(shortCode, idempotencyKey):
            try container.encode("join", forKey: .command)
            try container.encode(shortCode, forKey: .shortCode)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .leave(idempotencyKey):
            try container.encode("leave", forKey: .command)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .setSharing(enabled, idempotencyKey):
            try container.encode("setSharing", forKey: .command)
            try container.encode(enabled, forKey: .enabled)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .block(memberID, idempotencyKey):
            try container.encode("block", forKey: .command)
            try container.encode(memberID, forKey: .memberID)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .report(memberID, reason, idempotencyKey):
            try container.encode("report", forKey: .command)
            try container.encode(memberID, forKey: .memberID)
            try container.encode(reason, forKey: .reason)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .publishCheckIn(challengeID, day, state, idempotencyKey):
            try container.encode("publishCheckIn", forKey: .command)
            try container.encode(challengeID, forKey: .challengeID)
            try container.encode(day, forKey: .day)
            try container.encode(state, forKey: .state)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .react(checkInID, reaction, idempotencyKey):
            try container.encode("react", forKey: .command)
            try container.encode(checkInID, forKey: .checkInID)
            try container.encode(reaction, forKey: .reaction)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .deleteNightFlockData(idempotencyKey):
            try container.encode("deleteNightFlockData", forKey: .command)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .deleteAccount(idempotencyKey):
            try container.encode("deleteAccount", forKey: .command)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        }
    }
}

struct NightFlockStateRequest: Encodable, Equatable, Sendable {
    let schemaVersion = 1
}

struct NightFlockCommandResponse: Decodable, Equatable, Sendable {
    var schemaVersion: Int
    var accepted: Bool
    var inviteCode: String?
    var inviteID: UUID?
    var snapshot: NightFlockSnapshot?
}

struct NightFlockStateResponse: Decodable, Equatable, Sendable {
    var schemaVersion: Int
    var snapshot: NightFlockSnapshot?
}

struct NightFlockOutboxRecord: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var challengeID: UUID
    var memberID: UUID
    var challengeDay: Int
    var runID: UUID
    var state: NightFlockCheckInState
    var idempotencyKey: String
    var createdAt: Date
    var attemptCount: Int

    init(
        id: UUID = UUID(),
        challengeID: UUID,
        memberID: UUID,
        challengeDay: Int,
        runID: UUID,
        state: NightFlockCheckInState,
        idempotencyKey: String,
        createdAt: Date = Date(),
        attemptCount: Int = 0
    ) {
        self.id = id
        self.challengeID = challengeID
        self.memberID = memberID
        self.challengeDay = challengeDay
        self.runID = runID
        self.state = state
        self.idempotencyKey = idempotencyKey
        self.createdAt = createdAt
        self.attemptCount = attemptCount
    }
}

struct NightFlockRunShareContext: Identifiable, Codable, Equatable, Sendable {
    var runID: UUID
    var challengeID: UUID
    var memberID: UUID
    var challengeDay: Int
    var createdAt: Date
    var phoneTuckedQueued: Bool
    var morningQuietCompletedQueued: Bool

    var id: UUID { runID }

    init(
        runID: UUID,
        challengeID: UUID,
        memberID: UUID,
        challengeDay: Int,
        createdAt: Date,
        phoneTuckedQueued: Bool = false,
        morningQuietCompletedQueued: Bool = false
    ) {
        self.runID = runID
        self.challengeID = challengeID
        self.memberID = memberID
        self.challengeDay = challengeDay
        self.createdAt = createdAt
        self.phoneTuckedQueued = phoneTuckedQueued
        self.morningQuietCompletedQueued = morningQuietCompletedQueued
    }

    private enum CodingKeys: String, CodingKey {
        case runID
        case challengeID
        case memberID
        case challengeDay
        case createdAt
        case phoneTuckedQueued
        case morningQuietCompletedQueued
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runID = try container.decode(UUID.self, forKey: .runID)
        challengeID = try container.decode(UUID.self, forKey: .challengeID)
        memberID = try container.decode(UUID.self, forKey: .memberID)
        challengeDay = try container.decode(Int.self, forKey: .challengeDay)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        phoneTuckedQueued = try container.decodeIfPresent(Bool.self, forKey: .phoneTuckedQueued) ?? false
        morningQuietCompletedQueued = try container.decodeIfPresent(
            Bool.self,
            forKey: .morningQuietCompletedQueued
        ) ?? false
    }
}

enum NightFlockOutboxRules {
    static func merge(
        _ record: NightFlockOutboxRecord,
        into existing: [NightFlockOutboxRecord]
    ) -> [NightFlockOutboxRecord] {
        var result = existing
        if let index = result.firstIndex(where: {
            $0.challengeID == record.challengeID
                && $0.memberID == record.memberID
                && $0.challengeDay == record.challengeDay
                && $0.runID == record.runID
        }) {
            guard record.state > result[index].state else { return result }
            result[index] = record
        } else {
            result.append(record)
        }
        return result.sorted { $0.createdAt < $1.createdAt }
    }
}

enum NightFlockIdempotency {
    static func checkIn(
        challengeID: UUID,
        memberID: UUID,
        day: Int,
        runID: UUID,
        state: NightFlockCheckInState
    ) -> String {
        digest([
            "night-flock-v1",
            challengeID.uuidString.lowercased(),
            memberID.uuidString.lowercased(),
            String(day),
            runID.uuidString.lowercased(),
            state.rawValue
        ].joined(separator: ":"))
    }

    static func command(_ kind: String, seed: UUID = UUID()) -> String {
        digest("night-flock-v1:\(kind):\(seed.uuidString.lowercased())")
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
