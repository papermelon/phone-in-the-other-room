import Foundation
import CryptoKit

/// Additive v4 projection. Omitted on an older server; never inferred from a
/// successful sign-in or from the prototype's simulated arrangement.
struct SharedPastureState: Codable, Equatable, Sendable {
    var version: Int = 1
    var sceneRevision: Int = 1
    var memberEpochID: UUID
    var entities: [SharedPastureEntity]
    var visits: [SharedPastureVisit]
    var lantern: SharedPastureLantern
    var campfire: CampfireState? = nil

    var isSupported: Bool { version == 1 && sceneRevision == 1 }
    var arrangement: SharedMeadowArrangement {
        var result = SharedMeadowArrangement()
        for entity in entities where entity.point.x.isFinite && entity.point.y.isFinite {
            if let occupant = entity.occupant { result.positions[occupant.key] = entity.point }
        }
        return result
    }
}

struct SharedPastureEntity: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var kind: String
    var referenceID: UUID
    var revision: Int
    var x: Double
    var y: Double
    var point: PastureScenePoint { .init(x: x, y: y) }
    var occupant: SharedMeadowOccupant? {
        switch kind {
        case "shepherd": return .member(referenceID)
        case "sheep": return .visitor(referenceID)
        case "lantern": return .lantern(referenceID)
        default: return nil
        }
    }
}

struct SharedPastureVisit: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var memberID: UUID
    var sheepDefinitionID: String
    var sheepDisplayName: String
    var sentAt: Date
    /// Included only in the owner's projection. Other members use the visit ID.
    var ownedSheepID: UUID? = nil
}

struct SharedPastureLantern: Codable, Equatable, Sendable {
    var contributions: Int
    var requiredContributions: Int
    var completedAt: Date? = nil
    var isComplete: Bool { completedAt != nil }
}

enum SharedPastureRules {
    static let lanternContributions = 12

    /// Ground anchors are feet, independent of the artwork's bounce or height.
    /// The rear scenery and the foreground gate stay clear.
    static func isWalkable(_ point: PastureScenePoint) -> Bool {
        point.x.isFinite && point.y.isFinite
            && (0.08...0.92).contains(point.x) && (0.43...0.89).contains(point.y)
            && !(point.x < 0.28 && point.y > 0.80)
    }

    static func bounded(_ point: PastureScenePoint) -> PastureScenePoint {
        guard point.x.isFinite, point.y.isFinite else { return .init(x: 0.5, y: 0.7) }
        var result = PastureScenePoint(x: min(0.92, max(0.08, point.x)), y: min(0.89, max(0.43, point.y)))
        if result.x < 0.28 && result.y > 0.80 { result.y = 0.80 }
        return result
    }

    static func changedEntities(in arrangement: SharedMeadowArrangement, from state: SharedPastureState) -> [SharedPastureEntity] {
        state.entities.compactMap { entity in
            guard let key = entity.occupant?.key, let proposed = arrangement.positions[key],
                  proposed.distance(to: entity.point) > 0.001 else { return nil }
            var changed = entity
            let point = bounded(proposed)
            changed.x = point.x; changed.y = point.y
            return changed
        }
    }
}

/// The final placement alone travels, with its original entity and membership
/// revisions. A retry must never manufacture a newer base revision.
struct SharedPastureCommand: Codable, Equatable, Identifiable, Sendable {
    var schemaVersion = 4
    var command: String
    var partyID: UUID
    var memberEpochID: UUID
    var sceneRevision = 1
    var entityID: String?
    var expectedRevision: Int?
    var x: Double?
    var y: Double?
    var sheepID: UUID?
    var visitID: UUID?
    var consentVersion: Int?
    var enabled: Bool?
    var agreementID: UUID?
    var sourceID: UUID?
    var kind: NightFlockV4ActivityKind?
    var activity: CampfireActivity?
    var startedAt: Date?
    var observedAt: Date?
    var expiresAt: Date?
    var ended: Bool?
    var revision: Int?
    var idempotencyKey: String
    var id: String { idempotencyKey }

    init(command: String, partyID: UUID, memberEpochID: UUID, nonce: UUID = UUID()) {
        self.command = command; self.partyID = partyID; self.memberEpochID = memberEpochID
        idempotencyKey = SHA256.hash(data: Data("pasture-v1:\(nonce.uuidString)".utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}

struct SharedPastureCommandResponse: Decodable {
    var accepted: Bool
    var conflict: Bool?
}
