#if FARM_SAVE_SERVICE_TESTS
import XCTest
import CryptoKit

final class FarmSaveStoreTests: XCTestCase {
    private var directory: URL!
    private let key = "ollie.farm.state"

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    private func bytes(_ balance: Int) throws -> Data {
        var farm = FarmState.empty
        farm.woolBalance = balance
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(farm)
    }

    private func store(files: FarmSaveFileAccess = LocalFarmSaveFileAccess(),
                       legacy: [String: Data] = [:]) -> FarmSaveStore {
        FarmSaveStore(directory: directory, files: files, legacy: { legacy })
    }

    func testMigrationAndRelaunchNeverReadStaleLegacyAfterCommit() throws {
        let original = try bytes(14)
        let first = store(legacy: [key: original])
        XCTAssertEqual(first.data(for: key), original)
        try first.set(bytes(9), for: key)
        XCTAssertEqual(store(legacy: [key: original]).data(for: key), try bytes(9))
        let preserved = try Data(contentsOf: directory.appendingPathComponent("legacy-original.json"))
        XCTAssertEqual(try JSONDecoder().decode([String: Data].self, from: preserved)[key], original)
    }

    func testAccountMetadataAndBalanceCommitTogetherAndResetCannotUploadEmptyFarm() throws {
        let io = FailingFarmFiles()
        let save = store(files: io, legacy: [key: try bytes(14)])
        let original = try save.snapshot()
        io.failWrite = true
        XCTAssertThrowsError(try save.transaction {
            try save.set(bytes(8), for: key)
            try save.updateBackup { $0 = FarmBackupSync(ownerID: UUID(), enabled: true, generation: UUID()) }
        })
        XCTAssertEqual(try save.snapshot(), original)
        io.failWrite = false
        try save.updateBackup { $0 = FarmBackupSync(ownerID: UUID(), enabled: true, generation: UUID()) }
        XCTAssertNotNil(try store().snapshot().backup)
        try save.reset()
        XCTAssertNil(try save.snapshot().backup)
        XCTAssertNotEqual(try save.snapshot().lineageID, original.lineageID)
    }

    func testRestoreRejectsConcurrentChangesAndKeepsUnselectedLocalBranch() throws {
        let save = store(legacy: [key: try bytes(14)])
        let original = try save.snapshot()
        var farm = FarmState.empty
        farm.woolBalance = 300
        farm.migrateCumulativeCredit(records: [], searchState: .empty, protectedNightCount: 0)
        let remote = FarmSaveDocument(lineageID: UUID(), generation: 12,
            values: [key: try JSONEncoder().encode(farm)])
        let payload = try FarmBackupPayload(document: remote)
        let backup = FarmBackupSync(ownerID: UUID(), generation: UUID())
        try save.set(bytes(15), for: key)
        XCTAssertThrowsError(try save.restore(payload, backup: backup, expectedGeneration: original.generation))
        let current = try save.snapshot()
        try save.restore(payload, backup: backup, expectedGeneration: current.generation)
        XCTAssertEqual(try save.snapshot().lineageID, remote.lineageID)
        let archive = directory.appendingPathComponent("before-restore-\(current.lineageID)-\(current.generation).json")
        XCTAssertEqual(try FarmSaveDocument.decode(Data(contentsOf: archive)), current)
    }

    func testFailedCommitRollsBackAllFieldsAndRetryCommitsTogether() throws {
        let io = FailingFarmFiles()
        let save = store(files: io, legacy: [key: try bytes(14)])
        _ = save.data(for: key)
        io.failWrite = true
        XCTAssertThrowsError(try save.transaction {
            try save.set(bytes(8), for: key)
            try save.set(JSONEncoder().encode(WelcomeRewardLedger.empty), for: WelcomeRewardLedger.storageKey)
        })
        XCTAssertEqual(save.data(for: key), try bytes(14))
        XCTAssertNil(save.data(for: WelcomeRewardLedger.storageKey))
        XCTAssertEqual(store().data(for: key), try bytes(14))
        io.failWrite = false
        try save.transaction {
            try save.set(bytes(8), for: key)
            try save.set(JSONEncoder().encode(WelcomeRewardLedger.empty), for: WelcomeRewardLedger.storageKey)
        }
        let restored = store()
        XCTAssertEqual(restored.data(for: key), try bytes(8))
        XCTAssertNotNil(restored.data(for: WelcomeRewardLedger.storageKey))
    }

    func testCaughtInnerFailureStillAbortsOuterTransaction() throws {
        let save = store(legacy: [key: try bytes(14)])
        XCTAssertThrowsError(try save.transaction {
            try save.set(bytes(8), for: key)
            try? save.set(Data("invalid".utf8), for: WelcomeRewardLedger.storageKey)
        })
        XCTAssertEqual(save.data(for: key), try bytes(14))
    }

    func testCorruptNewestGenerationRecoversPreviousWithoutErasingOriginal() throws {
        let save = store(legacy: [key: try bytes(14)])
        try save.set(bytes(8), for: key)
        let latest = try generationFiles().last!
        let broken = Data("broken".utf8)
        try broken.write(to: latest)
        let recovered = store()
        XCTAssertEqual(recovered.data(for: key), try bytes(14))
        XCTAssertTrue(recovered.recoveredPreviousGeneration)
        try recovered.set(bytes(13), for: key)
        XCTAssertEqual(try Data(contentsOf: latest), broken)
        XCTAssertEqual(store().data(for: key), try bytes(13))
    }

    func testAllCorruptGenerationsBlockWritesInsteadOfMigratingOldDefaults() throws {
        let save = store(legacy: [key: try bytes(14)])
        _ = save.data(for: key)
        for url in try generationFiles() { try Data("broken".utf8).write(to: url) }
        let blocked = store(legacy: [key: try bytes(99)])
        XCTAssertNil(blocked.data(for: key))
        XCTAssertEqual(blocked.failure, .corrupt)
        XCTAssertThrowsError(try blocked.set(bytes(0), for: key))
        XCTAssertEqual(try generationFiles().count, 1)
    }

    func testMalformedLegacyBytesRemainUntouchedAndNoEmptyGenerationCreated() throws {
        let save = store(legacy: [key: Data("broken".utf8)])
        XCTAssertNil(save.data(for: key))
        XCTAssertThrowsError(try save.set(bytes(0), for: key))
        XCTAssertEqual(try generationFiles().count, 0)
    }

    func testResetBeforeReadCannotReviveOldGenerationsOrLegacy() throws {
        let save = store(legacy: [key: try bytes(14)])
        try save.set(bytes(8), for: key)
        try store().reset()
        XCTAssertNil(store(legacy: [key: try bytes(14)]).data(for: key))
        XCTAssertEqual(try generationFiles().count, 1)
    }

    func testPrunesOnlyOlderValidGenerationsAndPreservesMigrationOriginal() throws {
        let save = store(legacy: [key: try bytes(14)])
        for balance in 1...8 { try save.set(bytes(balance), for: key) }
        XCTAssertEqual(try generationFiles().count, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("legacy-original.json").path))
        XCTAssertEqual(store().data(for: key), try bytes(8))
    }

    func testNewerEnvelopeNeverFallsBackToEarlierValidSave() throws {
        let save = store(legacy: [key: try bytes(14)])
        try save.set(bytes(8), for: key)
        let latest = try XCTUnwrap(generationFiles().last)
        let future = FarmSaveDocument(schemaVersion: 99, lineageID: UUID(), generation: 2, values: [:])
        let payload = try JSONEncoder().encode(future)
        let digest = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        let raw = try JSONSerialization.data(withJSONObject: ["payload": payload.base64EncodedString(), "digest": digest])
        try raw.write(to: latest)
        let blocked = store()
        XCTAssertNil(blocked.data(for: key))
        XCTAssertEqual(blocked.failure, .unsupportedSchema)
        XCTAssertThrowsError(try blocked.set(bytes(0), for: key))
        XCTAssertEqual(try Data(contentsOf: latest), raw)
    }

    func testErrorAfterPublicationAcknowledgesOnlyExactReadback() throws {
        let io = FailingFarmFiles()
        let save = store(files: io, legacy: [key: try bytes(14)])
        _ = save.data(for: key)
        io.failAfterWrite = true
        try save.set(bytes(8), for: key)
        XCTAssertEqual(save.data(for: key), try bytes(8))
        XCTAssertEqual(store().data(for: key), try bytes(8))
    }

    func testFailedResetDoesNotRemoveExistingSave() throws {
        let io = FailingFarmFiles()
        let save = store(files: io, legacy: [key: try bytes(14)])
        _ = save.data(for: key)
        io.failWrite = true
        XCTAssertThrowsError(try save.reset())
        XCTAssertEqual(store().data(for: key), try bytes(14))
    }

    private func generationFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("generation-") }.sorted { $0.path < $1.path }
    }
}

private final class FailingFarmFiles: FarmSaveFileAccess {
    var failWrite = false
    var failAfterWrite = false
    private let local = LocalFarmSaveFileAccess()
    func files(in directory: URL) throws -> [URL] { try local.files(in: directory) }
    func read(_ url: URL) throws -> Data { try local.read(url) }
    func remove(_ url: URL) throws { try local.remove(url) }
    func write(_ data: Data, to url: URL) throws {
        if failWrite { throw FarmSaveError.unavailable }
        try local.write(data, to: url)
        if failAfterWrite { throw FarmSaveError.unavailable }
    }
}
#endif
