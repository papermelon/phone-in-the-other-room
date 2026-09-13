import Foundation

extension FarmSaveStore {
    func migrateAccountLocalValues(_ legacy: () throws -> [String: Data]) throws {
        try transaction {
            guard pending?.localValues == nil else { return }
            pending?.localValues = try legacy()
            let scope = pending?.effectiveScope
            pending?.accountScope = scope
            pending?.schemaVersion = FarmSaveDocument.currentSchemaVersion
        }
    }

    func setLocalData(_ data: Data?, for key: String) throws {
        try transaction {
            guard AccountFarmLocalKeys.all.contains(key), pending?.effectiveScope != .signedOut else {
                throw FarmSaveError.unavailable
            }
            if pending?.localValues == nil { pending?.localValues = [:] }
            pending?.localValues?[key] = data
        }
    }

    func finishCredentialRemoval() throws {
        try transaction { pending?.credentialsNeedRemoval = false }
    }

    func cachedAccount(_ owner: UUID) throws -> AccountFarmArchive? {
        try snapshot().accountArchives?[owner.uuidString.lowercased()]
    }

    /// Archive and activation share the same checksummed file commit. A crash
    /// cannot expose A's values beneath B's owner label.
    func activate(_ scope: AccountFarmScope, preservingGuest: Bool = false) throws {
        try transaction {
            guard var next = pending else { throw FarmSaveError.unavailable }
            guard scope != next.effectiveScope else { return }
            guard next.credentialsNeedRemoval != true || scope == .signedOut else { throw FarmSaveError.unavailable }
            var archives = next.accountArchives ?? [:]
            if let key = next.effectiveScope.archiveKey {
                archives[key] = AccountFarmArchive(lineageID: next.lineageID, values: next.values,
                    localValues: next.localValues ?? [:], backup: next.backup)
            }
            let restored = scope.archiveKey.flatMap { archives.removeValue(forKey: $0) }
            let guest = preservingGuest && next.effectiveScope == .guest && scope.ownerID != nil
            if guest { archives.removeValue(forKey: "guest") }
            next = FarmSaveDocument(lineageID: restored?.lineageID ?? (guest ? next.lineageID : UUID()),
                generation: next.generation, values: restored?.values ?? (guest ? next.values : [:]),
                backup: restored?.backup, accountScope: scope,
                localValues: restored?.localValues ?? (guest ? next.localValues : [:]), accountArchives: archives,
                credentialsNeedRemoval: scope == .signedOut ? true : nil)
            pending = next
        }
    }

    func deleteActiveAccount() throws {
        try transaction {
            let owner = pending?.effectiveScope.ownerID
            try activate(.signedOut)
            if let owner { pending?.accountArchives?.removeValue(forKey: owner.uuidString.lowercased()) }
        }
    }

    func purgeObsoleteAccountFiles() throws {
        let current = try snapshot()
        let filename = String(format: "generation-%020llu.json", current.generation)
        for file in try files.files(in: directory) {
            let name = file.lastPathComponent
            if name != filename && (name.hasPrefix("generation-") || name.hasPrefix("before-restore-") || name == "legacy-original.json") {
                try files.remove(file)
            }
        }
    }

    func removeAccountRecovery(_ owner: UUID) throws {
        try transaction {
            pending?.accountArchives?.removeValue(forKey: owner.uuidString.lowercased())
        }
    }
}
