import Foundation

/// Login identifiers can change; this scope is always the authenticated UUID.
enum AccountFarmScope: Codable, Equatable {
    case guest
    case account(UUID)
    case signedOut

    var archiveKey: String? {
        switch self {
        case .guest: return "guest"
        case .account(let id): return id.uuidString.lowercased()
        case .signedOut: return nil
        }
    }

    var ownerID: UUID? {
        if case .account(let id) = self { return id }
        return nil
    }
}

struct AccountFarmArchive: Codable, Equatable {
    var lineageID: UUID
    var values: [String: Data]
    var localValues: [String: Data]
    var backup: FarmBackupSync?
}

/// These values stay on this device, but switch with the person using it.
/// They are never projected into FarmBackupPayload.
enum AccountFarmLocalKeys {
    static let all: Set<String> = [
        "ollie.userProfile", "ollie.userProfile.socialAvatar.isExplicit",
        "ollie.farm.pastureScene", "ollie.analytics.manualEntries",
        "ollie.morningCheckIns", "ollie.nightWatch.history", "ollie.lastRun",
        "ollie.impactSharing.preferences", "ollie.impactSharing.records",
        WindDownProfileRecord.storageKey, WindDownHabitPlan.storageKey, WindDownHabitReflectionHistory.storageKey, RitualPersonalisation.storageKey, PersonalShieldSession.storageKey
    ]
}

enum AccountUsername {
    static func normalized(_ raw: String) -> String? {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if name.hasPrefix("@") { name.removeFirst() }
        guard name.range(of: "^[a-z][a-z0-9_]{2,23}$", options: .regularExpression) != nil else { return nil }
        return name
    }
}

enum AccountIdentityEvidence {
    static func isSupported(isAnonymous: Bool, providers: [String], emailVerified: Bool) -> Bool {
        !isAnonymous && (providers.contains("apple") || (providers.contains("email") && emailVerified))
    }
}

/// A damaged latest file may recover only within the last committed owner
/// transition, never by reopening a previous person's generation.
struct AccountFarmScopeFence: Codable {
    let minimumGeneration: UInt64
    let scope: AccountFarmScope
}
