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
    case createInvite(
        inviteID: UUID? = nil,
        inviteDigest: String? = nil,
        idempotencyKey: String
    )
    case replaceInvite(
        expectedInviteID: UUID,
        inviteID: UUID,
        inviteDigest: String,
        idempotencyKey: String
    )
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
        case inviteID, inviteDigest, expectedInviteID
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
        case let .createInvite(inviteID, inviteDigest, idempotencyKey):
            try container.encode("createInvite", forKey: .command)
            try container.encodeIfPresent(inviteID, forKey: .inviteID)
            try container.encodeIfPresent(inviteDigest, forKey: .inviteDigest)
            try container.encode(idempotencyKey, forKey: .idempotencyKey)
        case let .replaceInvite(expectedInviteID, inviteID, inviteDigest, idempotencyKey):
            try container.encode("replaceInvite", forKey: .command)
            try container.encode(expectedInviteID, forKey: .expectedInviteID)
            try container.encode(inviteID, forKey: .inviteID)
            try container.encode(inviteDigest, forKey: .inviteDigest)
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

struct NightFlockInviteCredential: Codable, Equatable, Sendable {
    enum State: String, Codable, Sendable { case pending, confirmed }
    var boundAccountID: UUID
    var flockID: UUID
    var inviteID: UUID
    var plaintextCode: String
    var idempotencyKey: String
    var createdAt: Date
    var state: State
    var inviteDigest: String { NightFlockInviteCode.digest(plaintextCode) }
}

enum NightFlockInviteCode {
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let length = 12
    static func generate(randomByte: () -> UInt8 = { UInt8.random(in: .min ... .max) }) -> String {
        String((0 ..< length).map { _ in alphabet[Int(randomByte()) % alphabet.count] })
    }
    static func normalize(_ value: String) -> String {
        value.uppercased().filter { alphabet.contains($0) }
    }
    static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(normalize(value).utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func makeCredential(accountID: UUID, flockID: UUID, now: Date = Date()) -> NightFlockInviteCredential {
        NightFlockInviteCredential(
            boundAccountID: accountID, flockID: flockID, inviteID: UUID(),
            plaintextCode: generate(), idempotencyKey: NightFlockV2Idempotency.command("invite-credential"),
            createdAt: now, state: .pending
        )
    }
}

enum NightFlockInviteRecoveryPresentation: Equatable, Sendable {
    case hidden, finishCreating, replaceCode
    case code(String)
}

enum NightFlockInviteRecoveryPolicy {
    static func presentation(
        credential: NightFlockInviteCredential?, activeInvite: NightFlockSnapshot.ActiveInvite?,
        accountID: UUID?, flockID: UUID?, challengeStatus: NightFlockChallenge.Status,
        now: Date = Date()
    ) -> NightFlockInviteRecoveryPresentation {
        guard challengeStatus == .pending, let accountID, let flockID else { return .hidden }
        if let credential,
           credential.boundAccountID != accountID || credential.flockID != flockID {
            return .hidden
        }
        let matching = credential.flatMap { $0.boundAccountID == accountID && $0.flockID == flockID ? $0 : nil }
        guard let activeInvite, activeInvite.expiresAt > now else {
            guard let matching, matching.createdAt.addingTimeInterval(7 * 24 * 60 * 60) > now else {
                return .hidden
            }
            return matching.state == .pending ? .finishCreating : .hidden
        }
        guard let matching, matching.inviteID == activeInvite.id else { return .replaceCode }
        return .code(matching.plaintextCode)
    }
    static func shouldClear(
        credential: NightFlockInviteCredential, snapshot: NightFlockSnapshot?,
        accountID: UUID?, now: Date = Date()
    ) -> Bool {
        if credential.createdAt.addingTimeInterval(7 * 24 * 60 * 60) <= now { return true }
        guard let snapshot, accountID == credential.boundAccountID else { return false }
        guard snapshot.flockID == credential.flockID else { return true }
        guard snapshot.challenge.status == .pending else { return true }
        if let active = snapshot.activeInvite {
            return active.expiresAt <= now || (credential.state == .confirmed && active.id != credential.inviteID)
        }
        return credential.state == .confirmed
    }
}

enum NightFlockInviteMutationOwnershipPolicy {
    static func owns(
        capturedGeneration: UInt64,
        capturedTransportEpoch: UInt64,
        currentGeneration: UInt64,
        currentTransportEpoch: UInt64,
        transportPermitted: Bool,
        accountLinked: Bool,
        keeperAuthorized: Bool,
        capturedFlockID: UUID,
        currentFlockID: UUID?,
        challengePending: Bool,
        capturedExpectedInviteID: UUID?,
        currentActiveInviteID: UUID?
    ) -> Bool {
        transportPermitted
            && capturedGeneration == currentGeneration
            && capturedTransportEpoch == currentTransportEpoch
            && accountLinked
            && keeperAuthorized
            && capturedFlockID == currentFlockID
            && challengePending
            && capturedExpectedInviteID == currentActiveInviteID
    }
}

enum NightFlockInviteReconciliationSnapshotToken: Equatable, Sendable {
    case absent
    case present(
        flockID: UUID,
        challengeID: UUID,
        challengeStatus: NightFlockChallenge.Status,
        activeInviteID: UUID?,
        myMemberID: UUID,
        keeperAuthorized: Bool
    )

    init(snapshot: NightFlockSnapshot?) {
        guard let snapshot else {
            self = .absent
            return
        }
        self = .present(
            flockID: snapshot.flockID,
            challengeID: snapshot.challenge.id,
            challengeStatus: snapshot.challenge.status,
            activeInviteID: snapshot.activeInvite?.id,
            myMemberID: snapshot.myMemberID,
            keeperAuthorized: snapshot.members.first(where: { $0.id == snapshot.myMemberID })?.role == .keeper
        )
    }

    var keeperAuthorized: Bool {
        switch self {
        case .absent:
            return true
        case let .present(_, _, _, _, _, keeperAuthorized):
            return keeperAuthorized
        }
    }
}

enum NightFlockInviteReconciliationAuthorityPolicy {
    static func ownsContinuation(
        capturedGeneration: UInt64,
        capturedTransportEpoch: UInt64,
        currentGeneration: UInt64,
        currentTransportEpoch: UInt64,
        transportPermitted: Bool,
        accountLinked: Bool,
        capturedLinkedAccountID: UUID?,
        currentLinkedAccountID: UUID?,
        capturedSnapshot: NightFlockInviteReconciliationSnapshotToken,
        currentSnapshot: NightFlockInviteReconciliationSnapshotToken
    ) -> Bool {
        transportPermitted
            && accountLinked
            && capturedGeneration == currentGeneration
            && capturedTransportEpoch == currentTransportEpoch
            && capturedLinkedAccountID == currentLinkedAccountID
            && capturedSnapshot == currentSnapshot
            && currentSnapshot.keeperAuthorized
    }

    static func owns(
        capturedGeneration: UInt64,
        capturedTransportEpoch: UInt64,
        currentGeneration: UInt64,
        currentTransportEpoch: UInt64,
        transportPermitted: Bool,
        accountLinked: Bool,
        capturedLinkedAccountID: UUID?,
        currentLinkedAccountID: UUID?,
        returnedLinkedAccountID: UUID?,
        capturedSnapshot: NightFlockInviteReconciliationSnapshotToken,
        currentSnapshot: NightFlockInviteReconciliationSnapshotToken
    ) -> Bool {
        guard ownsContinuation(
                capturedGeneration: capturedGeneration,
                capturedTransportEpoch: capturedTransportEpoch,
                currentGeneration: currentGeneration,
                currentTransportEpoch: currentTransportEpoch,
                transportPermitted: transportPermitted,
                accountLinked: accountLinked,
                capturedLinkedAccountID: capturedLinkedAccountID,
                currentLinkedAccountID: currentLinkedAccountID,
                capturedSnapshot: capturedSnapshot,
                currentSnapshot: currentSnapshot
              ),
              let returnedLinkedAccountID,
              capturedLinkedAccountID == nil || capturedLinkedAccountID == returnedLinkedAccountID
        else { return false }
        return true
    }
}

enum NightFlockInviteUnresolvedLookupAction: Equatable, Sendable {
    case hidePlaintextPreservingCredential
    case ignoreStaleContinuation

    var preservesCredential: Bool { true }
}

enum NightFlockInviteUnresolvedLookupPolicy {
    static func action(continuationOwned: Bool) -> NightFlockInviteUnresolvedLookupAction {
        continuationOwned ? .hidePlaintextPreservingCredential : .ignoreStaleContinuation
    }

    static func permitsLegacyResponsePresentation(identityValidated: Bool) -> Bool {
        identityValidated
    }
}

enum NightFlockInviteDeletionSignal: Equatable, Sendable {
    case none
    case accepted
    case ambiguous
}

enum NightFlockInvitePlaintextVisibilityPolicy {
    static func shouldHide(
        authenticationAction: NightFlockAuthenticationAction,
        deletionSignal: NightFlockInviteDeletionSignal = .none
    ) -> Bool {
        authenticationAction != .none || deletionSignal != .none
    }
}
