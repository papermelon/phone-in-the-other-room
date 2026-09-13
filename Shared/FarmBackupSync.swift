import Foundation
import CryptoKit

/// Device-local account fence and retry identity, committed with the Farm.
struct FarmBackupSync: Codable, Equatable {
    var ownerID: UUID
    var enabled = false
    var generation: UUID
    var baseRevision: UUID?
    var confirmedDigest: String?
    var confirmedAt: Date?
    var pending: FarmBackupCommand?
    var conflictRevision: UUID?
    var pendingPresentation: FarmBackupPresentationRestore?
    var accountSyncVersion: Int?
}

struct FarmBackupPresentationRestore: Codable, Equatable {
    var pasture: PastureSceneSnapshot?
    var appearance: CountingSheepPublicPresentation?
}

struct FarmBackupCommand: Codable, Equatable {
    var action: String
    var generation: UUID?
    var baseRevision: UUID?
    var operationID: UUID?
    var payload: FarmBackupPayload?
    var revisionID: UUID?
}

struct FarmBackupRevision: Codable, Equatable, Identifiable {
    var id: UUID
    var payload: FarmBackupPayload?
    var digest: String
    var createdAt: Date
    var conflict: Bool
}

struct FarmBackupRevisionSummary: Codable, Equatable, Identifiable {
    var id: UUID
    var createdAt: Date
    var conflict: Bool
    var lineageID: UUID
}

struct FarmBackupLookup: Decodable {
    var capability: String
    var generation: UUID
    var head: FarmBackupRevision?
    var revisions: [FarmBackupRevisionSummary]
    var currentRevisionID: UUID?
}

struct FarmBackupReceipt: Decodable {
    var status: String
    var generation: UUID
    var revision: FarmBackupRevision?
}

extension FarmBackupPayload {
    func fingerprint() throws -> String {
        let object = try Self.canonicalObject(JSONEncoder().encode(self))
        let bytes = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    /// Wire saves must survive lossless decoding. Legacy domain decoders are
    /// intentionally forgiving locally; they cannot silently repair a backup.
    static func decodeRemote(_ data: Data) throws -> Self {
        let object = try JSONSerialization.jsonObject(with: data) as? NSDictionary
        guard let schema = object?["schemaVersion"] as? Int, schema == currentSchemaVersion,
              object?["economyVersion"] as? Int == 1 else { throw FarmSaveError.unsupportedSchema }
        for (key, version) in [("farm", FarmState.currentSchemaVersion),
                               ("search", SheepSearchState.currentSchemaVersion),
                               ("welcome", WelcomeRewardLedger.currentSchemaVersion),
                               ("socialRewards", NightFlockRewardLedger.currentSchemaVersion),
                               ("sunrise", SunriseTrailState.currentSchemaVersion)] {
            guard (object?[key] as? NSDictionary)?["schemaVersion"] as? Int == version else {
                throw FarmSaveError.unsupportedSchema
            }
        }
        let decoded = try JSONDecoder().decode(Self.self, from: data)
        guard try canonicalObject(data) == canonicalObject(JSONEncoder().encode(decoded)),
              decoded.farm.cumulativeCredit?.migrationCompleted == true,
              decoded.completedWindDownCount >= 0 else { throw FarmSaveError.corrupt }
        return decoded
    }

    private static func canonicalObject(_ data: Data) throws -> NSDictionary {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FarmSaveError.corrupt
        }
        // Codable represents UUID-keyed dictionaries as alternating arrays.
        // Their iteration order is not meaningful and changes after relaunch.
        if var farm = root["farm"] as? [String: Any],
           var credit = farm["cumulativeCredit"] as? [String: Any],
           let receipts = credit["receipts"] as? [Any] {
            guard receipts.count.isMultiple(of: 2) else { throw FarmSaveError.corrupt }
            var pairs: [(String, Any)] = []
            for index in stride(from: 0, to: receipts.count, by: 2) {
                guard let key = receipts[index] as? String else { throw FarmSaveError.corrupt }
                pairs.append((key, receipts[index + 1]))
            }
            guard Set(pairs.map(\.0)).count == pairs.count else { throw FarmSaveError.corrupt }
            credit["receipts"] = pairs.sorted { $0.0 < $1.0 }.flatMap { [$0.0, $0.1] }
            farm["cumulativeCredit"] = credit
            root["farm"] = farm
        }
        return root as NSDictionary
    }

    func restoredValues(preservingLocalProgress progress: UserProgress) throws -> [String: Data] {
        // Dates/daily receipts are device-local. This aggregate restores only
        // the lifetime counter already earned, without making up dated runs.
        var restoredProgress = progress
        restoredProgress.restoredFarmCompletedRuns = completedWindDownCount
        restoredProgress.ollieLevel = min(5, 1 + completedWindDownCount / 3)
        let journal = WindDownMorningSettlementJournal(sunriseTrail: sunrise,
            deliveredEffectIDs: deliveredEffectIDs, restoredDeliveredWindDownRunIDs: deliveredWindDownRunIDs)
        let rewards = keepsakes.map {
            RewardItem(id: $0.id, type: $0.type, rarity: $0.rarity, title: $0.title,
                       description: "", earnedAt: $0.earnedAt, runDurationMinutes: 0,
                       isDemoReward: $0.isDemoReward)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return [
            "ollie.farm.state": try encoder.encode(farm),
            "ollie.sheepSearch.state": try encoder.encode(search),
            WelcomeRewardLedger.storageKey: try encoder.encode(welcome),
            NightFlockRewardLedger.storageKey: try encoder.encode(socialRewards),
            "ollie.progress": try encoder.encode(restoredProgress),
            "ollie.rewards": try encoder.encode(rewards),
            WindDownMorningSettlementJournal.storageKey: try encoder.encode(journal)
        ]
    }
}
