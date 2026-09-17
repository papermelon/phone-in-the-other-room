import Foundation

protocol FarmSaveFileAccess {
    func files(in directory: URL) throws -> [URL]
    func read(_ url: URL) throws -> Data
    func write(_ data: Data, to url: URL) throws
    func remove(_ url: URL) throws
}

struct LocalFarmSaveFileAccess: FarmSaveFileAccess {
    func files(in directory: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    }

    func read(_ url: URL) throws -> Data { try Data(contentsOf: url) }

    func write(_ data: Data, to url: URL) throws {
#if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
#else
        try data.write(to: url, options: .atomic)
#endif
    }

    func remove(_ url: URL) throws { try FileManager.default.removeItem(at: url) }
}

/// Serializes callers and keeps each published generation immutable. A failed
/// staged write cannot damage the previous committed inventory/claim ledger.
final class FarmSaveStore {
    let directory: URL
    let files: FarmSaveFileAccess
    private let legacy: () throws -> [String: Data]
    private let didCommit: () -> Void
    private let lock = NSRecursiveLock()
    private var document: FarmSaveDocument?
    var pending: FarmSaveDocument?
    private var transactionDepth = 0
    private var transactionError: Error?
    private var highestGeneration: UInt64 = 0
    private(set) var failure: FarmSaveError?
    private(set) var recoveredPreviousGeneration = false

    var hasReadableSave: Bool {
        lock.lock(); defer { lock.unlock() }
        return document != nil
    }

    init(directory: URL, files: FarmSaveFileAccess = LocalFarmSaveFileAccess(),
         didCommit: @escaping () -> Void = {},
         legacy: @escaping () throws -> [String: Data]) {
        self.directory = directory
        self.files = files
        self.legacy = legacy
        self.didCommit = didCommit
    }

    func data(for key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        do {
            try openIfNeeded()
            return (pending ?? document)?.values[key]
        } catch {
            record(error)
            return nil
        }
    }

    func set(_ data: Data?, for key: String) throws {
        try transaction {
            guard pending?.effectiveScope != .signedOut else { throw FarmSaveError.unavailable }
            if let data { try FarmSaveDocument.validate(data, key: key) }
            pending?.values[key] = data
        }
    }

    func transaction<T>(_ body: () throws -> T) throws -> T {
        lock.lock(); defer { lock.unlock() }
        do {
            try openIfNeeded()
            let outermost = transactionDepth == 0
            if outermost { pending = document; transactionError = nil }
            transactionDepth += 1
            let result: T
            do { result = try body() } catch {
                transactionDepth -= 1
                transactionError = error
                if outermost { pending = nil }
                throw error
            }
            transactionDepth -= 1
            if outermost {
                defer { pending = nil; transactionError = nil }
                if let transactionError { throw transactionError }
                guard var next = pending else { throw FarmSaveError.unavailable }
                if next != document {
                    guard highestGeneration < UInt64.max else { throw FarmSaveError.unsupportedSchema }
                    next.generation = highestGeneration + 1
                    try commit(next)
                }
            }
            failure = nil
            return result
        } catch {
            record(error)
            throw error
        }
    }

    /// A nonthrowing compatibility setter must still poison its containing
    /// transaction; otherwise a failed field could commit the other half.
    func reject(_ error: Error) {
        lock.lock(); defer { lock.unlock() }
        if transactionDepth > 0 { transactionError = error }
        record(error)
    }

    func snapshot() throws -> FarmSaveDocument {
        lock.lock(); defer { lock.unlock() }
        try openIfNeeded()
        guard let document else { throw FarmSaveError.unavailable }
        return document
    }

    func localData(for key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        do { try openIfNeeded(); return (pending ?? document)?.localValues?[key] }
        catch { record(error); return nil }
    }

    func updateBackup(_ update: (inout FarmBackupSync?) throws -> Void) throws {
        try transaction {
            guard var next = pending else { throw FarmSaveError.unavailable }
            next.schemaVersion = FarmSaveDocument.currentSchemaVersion
            try update(&next.backup)
            if let owner = next.backup?.ownerID, next.effectiveScope == .guest {
                next.accountScope = .account(owner)
            }
            pending = next
        }
    }

    func restore(_ payload: FarmBackupPayload, backup: FarmBackupSync,
                 expectedGeneration: UInt64) throws {
        try transaction {
            guard let current = pending, current.generation == expectedGeneration else {
                throw FarmSaveError.unavailable
            }
            // Preserve the entire unselected local branch before publication.
            try files.write(current.encoded(), to: directory.appendingPathComponent(
                "before-restore-\(current.lineageID)-\(current.generation).json"))
            let progress = try current.values["ollie.progress"].map {
                try JSONDecoder().decode(UserProgress.self, from: $0)
            } ?? .empty
            pending = FarmSaveDocument(lineageID: payload.lineageID, generation: current.generation,
                values: try payload.restoredValues(preservingLocalProgress: progress), backup: backup,
                accountScope: .account(backup.ownerID), localValues: current.localValues,
                accountArchives: current.accountArchives)
        }
    }

    func reset() throws {
        lock.lock(); defer { lock.unlock() }
        guard transactionDepth == 0 else { throw FarmSaveError.unavailable }
        // The empty generation is the reset commit. Removing older files first
        // would risk reviving a partial Farm if deletion were interrupted.
        let existing = try files.files(in: directory)
        highestGeneration = max(highestGeneration, existing.compactMap {
            UInt64($0.deletingPathExtension().lastPathComponent.dropFirst("generation-".count))
        }.max() ?? 0)
        guard highestGeneration < UInt64.max else { throw FarmSaveError.unsupportedSchema }
        let next = FarmSaveDocument(lineageID: UUID(), generation: highestGeneration + 1, values: [:])
        try commit(next)
        for url in try files.files(in: directory) where url.lastPathComponent != name(next.generation) && url.lastPathComponent != "account-scope-fence.json" {
            try files.remove(url)
        }
        failure = nil
        recoveredPreviousGeneration = false
    }

    private func openIfNeeded() throws {
        if document != nil { return }
        let entries = try files.files(in: directory)
        // FileManager may standardize a temporary-directory URL differently
        // from a URL assembled by the caller. Read the enumerated entry so a
        // signed-out scope fence cannot be skipped and revive an older account.
        let fence = try entries.first { $0.lastPathComponent == "account-scope-fence.json" }.map {
            try JSONDecoder().decode(AccountFarmScopeFence.self, from: files.read($0))
        }
        let candidates = entries
            .filter { $0.lastPathComponent.hasPrefix("generation-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        highestGeneration = candidates.compactMap {
            UInt64($0.deletingPathExtension().lastPathComponent.dropFirst("generation-".count))
        }.max() ?? 0
        for url in candidates {
            let bytes = try files.read(url)
            do {
                let loaded = try FarmSaveDocument.decode(bytes)
                guard url.lastPathComponent == name(loaded.generation) else { throw FarmSaveError.corrupt }
                if let fence {
                    guard loaded.generation >= fence.minimumGeneration, loaded.effectiveScope == fence.scope else {
                        continue
                    }
                }
                document = loaded
                recoveredPreviousGeneration = url != candidates.first
                return
            } catch FarmSaveError.unsupportedSchema {
                // A newer app's save is not corruption and must never roll back.
                throw FarmSaveError.unsupportedSchema
            } catch {
                // Keep invalid bytes in place for diagnosis/recovery.
                continue
            }
        }
        guard candidates.isEmpty, fence == nil else { throw FarmSaveError.corrupt }
        let original = try legacy()
        let next = FarmSaveDocument(lineageID: UUID(), generation: 1, values: original)
        _ = try next.validated()
        // Original defaults remain untouched. This file is an additional copy.
        let originalURL = directory.appendingPathComponent("legacy-original.json")
        if !(try files.files(in: directory)).contains(originalURL) {
            try files.write(JSONEncoder().encode(original), to: originalURL)
        }
        try commit(next)
    }

    private func commit(_ next: FarmSaveDocument) throws {
        let data = try next.encoded()
        if document?.effectiveScope != next.effectiveScope || document?.accountArchives != next.accountArchives {
            let fence = AccountFarmScopeFence(minimumGeneration: next.generation, scope: next.effectiveScope)
            try files.write(JSONEncoder().encode(fence), to: directory.appendingPathComponent("account-scope-fence.json"))
        }
        let url = directory.appendingPathComponent(name(next.generation))
        highestGeneration = max(highestGeneration, next.generation)
        do {
            try files.write(data, to: url)
        } catch {
            // A filesystem may report an error after publishing the file. Only
            // exact readback can acknowledge that uncertain commit; otherwise
            // reserve its generation and retain the last confirmed document.
            guard (try? files.read(url)) == data else { throw error }
        }
        document = next
        didCommit()
        NotificationCenter.default.post(name: .farmSaveDidCommit, object: self)
        // Retain three validated generations. Never prune corrupt originals.
        if let candidates = try? files.files(in: directory) {
            let valid = candidates.filter { $0.lastPathComponent.hasPrefix("generation-") }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
                .filter { url in
                    guard let data = try? files.read(url) else { return false }
                    return (try? FarmSaveDocument.decode(data)) != nil
                }
            for old in valid.dropFirst(3) { try? files.remove(old) }
        }
    }

    private func name(_ generation: UInt64) -> String {
        String(format: "generation-%020llu.json", generation)
    }

    private func record(_ error: Error) {
        failure = (error as? FarmSaveError) ?? .unavailable
    }
}

extension Notification.Name {
    static let farmSaveDidCommit = Notification.Name("ollie.farm.save.didCommit")
}
