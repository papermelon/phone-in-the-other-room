import Foundation
import CryptoKit

enum FarmSaveError: Error, Equatable {
    case corrupt
    case unsupportedSchema
    case unavailable
    case invalidComponent(String)
}

/// Device-only transaction envelope. It deliberately has no network encoder:
/// the settlement journal contains private run data that is not a Farm backup.
struct FarmSaveDocument: Codable, Equatable {
    static let currentSchemaVersion = 3
    var schemaVersion = currentSchemaVersion
    var lineageID: UUID
    var generation: UInt64
    var values: [String: Data]
    var backup: FarmBackupSync?
    var accountScope: AccountFarmScope?
    var localValues: [String: Data]?
    var accountArchives: [String: AccountFarmArchive]?
    var credentialsNeedRemoval: Bool?

    var effectiveScope: AccountFarmScope { accountScope ?? backup.map { .account($0.ownerID) } ?? .guest }

    static let keys: Set<String> = [
        "ollie.progress", "ollie.rewards", "ollie.farm.state",
        "ollie.sheepSearch.state", WelcomeRewardLedger.storageKey,
        NightFlockRewardLedger.storageKey, WindDownMorningSettlementJournal.storageKey
    ]

    func validated() throws -> Self {
        guard schemaVersion <= Self.currentSchemaVersion else { throw FarmSaveError.unsupportedSchema }
        guard (1...Self.currentSchemaVersion).contains(schemaVersion),
              (schemaVersion >= 2 || backup == nil),
              Set(values.keys).isSubset(of: Self.keys) else { throw FarmSaveError.corrupt }
        guard schemaVersion >= 3 || (accountScope == nil && localValues == nil && accountArchives == nil && credentialsNeedRemoval == nil),
              backup == nil || effectiveScope.ownerID == backup?.ownerID,
              effectiveScope != .signedOut || (values.isEmpty && backup == nil && (localValues ?? [:]).isEmpty),
              Set((localValues ?? [:]).keys).isSubset(of: AccountFarmLocalKeys.all) else { throw FarmSaveError.corrupt }
        for (key, archive) in accountArchives ?? [:] {
            guard key == "guest" || UUID(uuidString: key) != nil,
                  archive.backup == nil || archive.backup?.ownerID.uuidString.lowercased() == key,
                  Set(archive.values.keys).isSubset(of: Self.keys),
                  Set(archive.localValues.keys).isSubset(of: AccountFarmLocalKeys.all) else { throw FarmSaveError.corrupt }
            for (key, data) in archive.values { try Self.validate(data, key: key) }
        }
        for (key, data) in values { try Self.validate(data, key: key) }
        return self
    }

    static func validate(_ data: Data, key: String) throws {
        let decoder = JSONDecoder()
        func decode<T: Decodable>(_ type: T.Type, version: Int? = nil) throws {
            if let version,
               let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let storedVersion = object["schemaVersion"] as? Int,
               storedVersion > version { throw FarmSaveError.unsupportedSchema }
            _ = try decoder.decode(type, from: data)
        }
        do {
            switch key {
            case "ollie.progress": try decode(UserProgress.self)
            case "ollie.rewards": try decode([RewardItem].self)
            case "ollie.farm.state": try decode(FarmState.self, version: FarmState.currentSchemaVersion)
            case "ollie.sheepSearch.state": try decode(SheepSearchState.self, version: SheepSearchState.currentSchemaVersion)
            case WelcomeRewardLedger.storageKey:
                try decode(WelcomeRewardLedger.self, version: WelcomeRewardLedger.currentSchemaVersion)
            case NightFlockRewardLedger.storageKey:
                try decode(NightFlockRewardLedger.self, version: NightFlockRewardLedger.currentSchemaVersion)
            case WindDownMorningSettlementJournal.storageKey:
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let nested = [(object?["sunriseTrail"] as? [String: Any], SunriseTrailState.currentSchemaVersion)]
                    + ((object?["morningOccurrences"] as? [[String: Any]]) ?? []).map { ($0, MorningQuietOccurrence.currentSchemaVersion) }
                    + ((object?["windDownBenefits"] as? [[String: Any]]) ?? []).map { ($0, WindDownBenefitSettlement.currentSchemaVersion) }
                for (value, maximum) in nested {
                    if let version = value?["schemaVersion"] as? Int, version > maximum {
                        throw FarmSaveError.unsupportedSchema
                    }
                }
                try decode(WindDownMorningSettlementJournal.self, version: WindDownMorningSettlementJournal.currentSchemaVersion)
            default: throw FarmSaveError.invalidComponent(key)
            }
        } catch FarmSaveError.unsupportedSchema {
            throw FarmSaveError.unsupportedSchema
        } catch {
            throw FarmSaveError.invalidComponent(key)
        }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(try validated())
        return try encoder.encode(FarmSaveChecksum(payload: payload, digest: Self.digest(payload)))
    }

    static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        let wrapper = try decoder.decode(FarmSaveChecksum.self, from: data)
        guard digest(wrapper.payload) == wrapper.digest else { throw FarmSaveError.corrupt }
        return try decoder.decode(Self.self, from: wrapper.payload).validated()
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct FarmSaveChecksum: Codable {
    var payload: Data
    var digest: String
}
