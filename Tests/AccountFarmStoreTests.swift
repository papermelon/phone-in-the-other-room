#if FARM_SAVE_SERVICE_TESTS
import XCTest

final class AccountFarmStoreTests: XCTestCase {
    func testBedtimeBonusSurvivesAccountArchiveAndDiskReload() throws {
        try withStore { store, directory in
            try store.migrateAccountLocalValues { [:] }
            let owner = UUID(), other = UUID()
            try store.activate(.account(owner), preservingGuest: true)
            var farm = FarmState.empty
            farm.migrateCumulativeCredit(records: [], searchState: .empty, protectedNightCount: 0)
            farm.cumulativeCredit?.bedtimeBonus = BedtimeSearchBonus(
                remainingSearchSeconds: 5040, grantedNights: ["2026-9-20": UUID()])
            try store.set(JSONEncoder().encode(farm), for: "ollie.farm.state")
            try store.activate(.account(other))
            XCTAssertNil(try store.snapshot().values["ollie.farm.state"])
            let reopened = FarmSaveStore(directory: directory, legacy: { [:] })
            try reopened.activate(.account(owner))
            let bytes = try XCTUnwrap(reopened.snapshot().values["ollie.farm.state"])
            XCTAssertEqual(try JSONDecoder().decode(FarmState.self, from: bytes), farm)
        }
    }

    func testAccountRoundTripKeepsFarmAndPrivateContextTogether() throws {
        try withStore { store, directory in
            try store.migrateAccountLocalValues { ["ollie.userProfile": Data("{\"displayName\":\"guest\"}".utf8)] }
            let a = UUID(), b = UUID()
            try store.activate(.account(a), preservingGuest: true)
            let rewards = try JSONEncoder().encode([RewardItem]())
            try store.set(rewards, for: "ollie.rewards")
            try store.setLocalData(Data("{\"displayName\":\"A\"}".utf8), for: "ollie.userProfile")
            let original = try store.snapshot()
            try store.activate(.signedOut)
            XCTAssertTrue(try store.snapshot().values.isEmpty)
            XCTAssertNil(store.localData(for: "ollie.userProfile"))
            XCTAssertThrowsError(try store.set(rewards, for: "ollie.rewards"))
            XCTAssertThrowsError(try store.activate(.guest))
            let reopened = FarmSaveStore(directory: directory, legacy: { XCTFail("must not reimport"); return [:] })
            XCTAssertEqual(try reopened.snapshot().effectiveScope, .signedOut)
            try reopened.finishCredentialRemoval()
            try reopened.activate(.account(b))
            XCTAssertTrue(try reopened.snapshot().values.isEmpty)
            XCTAssertNil(reopened.localData(for: "ollie.userProfile"))
            try reopened.activate(.account(a))
            XCTAssertEqual(try reopened.snapshot().values, original.values)
            XCTAssertEqual(try reopened.snapshot().localValues, original.localValues)
            XCTAssertEqual(try reopened.snapshot().lineageID, original.lineageID)
        }
    }

    func testFailedOwnerActivationLeavesOriginalValuesAndOwner() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = AccountFailingFiles()
        let store = FarmSaveStore(directory: directory, files: files, legacy: { [:] })
        try store.migrateAccountLocalValues { [:] }
        let owner = UUID()
        try store.activate(.account(owner))
        files.fail = true
        XCTAssertThrowsError(try store.activate(.signedOut))
        XCTAssertEqual(try store.snapshot().effectiveScope, .account(owner))
        files.fail = false
        let reopened = FarmSaveStore(directory: directory, legacy: { [:] })
        XCTAssertEqual(try reopened.snapshot().effectiveScope, .account(owner))
    }

    func testCorruptSignedOutGenerationsNeverReopenPreviousAccount() throws {
        try withStore { store, directory in
            try store.migrateAccountLocalValues { [:] }
            let owner = UUID()
            try store.activate(.account(owner))
            try store.activate(.signedOut)
            try store.finishCredentialRemoval()
            var corruptedGenerations = 0
            for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                where file.lastPathComponent.hasPrefix("generation-") {
                if let saved = try? FarmSaveDocument.decode(Data(contentsOf: file)), saved.effectiveScope == .signedOut {
                    try Data("corrupt".utf8).write(to: file)
                    corruptedGenerations += 1
                }
            }
            XCTAssertGreaterThan(corruptedGenerations, 0)
            let reopened = FarmSaveStore(directory: directory, legacy: { [:] })
            XCTAssertThrowsError(try reopened.snapshot())
            XCTAssertFalse(reopened.hasReadableSave)
        }
    }

    func testGuestCannotReadAccountRecoveryAndAccountDeletionKeepsGuest() throws {
        try withStore { store, _ in
            try store.migrateAccountLocalValues { [:] }
            let guest = try store.snapshot().lineageID, owner = UUID()
            try store.activate(.account(owner))
            try store.activate(.signedOut)
            try store.removeAccountRecovery(owner)
            XCTAssertNil(try store.cachedAccount(owner))
            try store.finishCredentialRemoval()
            try store.activate(.guest)
            XCTAssertEqual(try store.snapshot().lineageID, guest)
        }
    }

    private func withStore(_ work: (FarmSaveStore, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try work(FarmSaveStore(directory: directory, legacy: { [:] }), directory)
    }
}

private final class AccountFailingFiles: FarmSaveFileAccess {
    var fail = false
    private let local = LocalFarmSaveFileAccess()
    func files(in directory: URL) throws -> [URL] { try local.files(in: directory) }
    func read(_ url: URL) throws -> Data { try local.read(url) }
    func remove(_ url: URL) throws { try local.remove(url) }
    func write(_ data: Data, to url: URL) throws {
        if fail { throw FarmSaveError.unavailable }
        try local.write(data, to: url)
    }
}
#endif
