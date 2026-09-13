#if FARM_SAVE_SERVICE_TESTS
import XCTest

final class FarmPersistenceAdapterTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private var directory: URL!

    override func setUpWithError() throws {
        suite = "farm-adapter-tests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suite)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    private func service(files: FarmSaveFileAccess = LocalFarmSaveFileAccess()) -> PersistenceService {
        PersistenceService(defaults: defaults, farmSaveDirectory: directory, farmSaveFiles: files)
    }

    func testAbsentHabitSupportIsNeutralWithoutCreatingAnswersOrChangingTheFarm() throws {
        let persistence = service()
        let original = try persistence.farmSaveStore.snapshot()

        XCTAssertEqual(try persistence.loadWindDownHabitPlan(), WindDownHabitPlan())
        XCTAssertTrue(try persistence.loadWindDownHabitReflections().entries.isEmpty)
        XCTAssertEqual(try persistence.farmSaveStore.snapshot(), original)
        XCTAssertNil(persistence.farmSaveStore.localData(for: WindDownHabitPlan.storageKey))
        XCTAssertNil(persistence.farmSaveStore.localData(for: WindDownHabitReflectionHistory.storageKey))
    }

    func testHabitPlanAndReflectionSurviveReopenAsPrivateLocalValues() throws {
        let persistence = service()
        let identity = try persistence.windDownHabitIdentity()
        var plan = WindDownHabitPlan(smallerActivity: "Read one paragraph", phonePlacement: .accessibleNearby)
        // Editing retains raw spaces; the persistence boundary normalizes the saved invitation.
        plan.cue = "  After brushing my teeth  "
        plan.preparation = "  Put my book beside the chair  "
        plan.useSmallerVersionNextTime = true
        plan = plan.normalized()
        let history = habitHistory(ease: .mixed, obstacle: .tooMuch)

        try persistence.saveWindDownHabitPlan(plan, identity: identity)
        try persistence.saveWindDownHabitReflections(history, identity: identity)

        let reopened = service()
        XCTAssertEqual(try reopened.windDownHabitIdentity(), identity)
        XCTAssertEqual(try reopened.loadWindDownHabitPlan(), plan.normalized())
        XCTAssertEqual(try reopened.loadWindDownHabitReflections(), history)
        let document = try reopened.farmSaveStore.snapshot()
        XCTAssertNotNil(document.localValues?[WindDownHabitPlan.storageKey])
        XCTAssertNotNil(document.localValues?[WindDownHabitReflectionHistory.storageKey])
        XCTAssertNil(document.values[WindDownHabitPlan.storageKey])
        XCTAssertNil(document.values[WindDownHabitReflectionHistory.storageKey])
        XCTAssertNil(defaults.data(forKey: WindDownHabitPlan.storageKey))
        XCTAssertNil(defaults.data(forKey: WindDownHabitReflectionHistory.storageKey))
    }

    func testHabitSupportFollowsAccountAndRejectsSignedOutOrAnotherOwnerDrafts() throws {
        let persistence = service()
        let ownerA = UUID(), ownerB = UUID()
        try persistence.farmSaveStore.activate(.account(ownerA))
        let identityA = try persistence.windDownHabitIdentity()
        let planA = WindDownHabitPlan(cue: "After dinner", smallerActivity: "Read one paragraph")
        let historyA = habitHistory(ease: .easy)
        try persistence.saveWindDownHabitPlan(planA, identity: identityA)
        try persistence.saveWindDownHabitReflections(historyA, identity: identityA)

        try persistence.farmSaveStore.activate(.signedOut)
        XCTAssertThrowsError(try persistence.windDownHabitIdentity())
        XCTAssertThrowsError(try persistence.loadWindDownHabitPlan())
        XCTAssertThrowsError(try persistence.loadWindDownHabitReflections())
        XCTAssertThrowsError(try persistence.saveWindDownHabitPlan(planA, identity: identityA))
        XCTAssertThrowsError(try persistence.saveWindDownHabitReflections(historyA, identity: identityA))
        try persistence.farmSaveStore.finishCredentialRemoval()
        try persistence.farmSaveStore.activate(.account(ownerB))
        XCTAssertEqual(try persistence.loadWindDownHabitPlan(), WindDownHabitPlan())
        XCTAssertTrue(try persistence.loadWindDownHabitReflections().entries.isEmpty)

        let identityB = try persistence.windDownHabitIdentity()
        let planB = WindDownHabitPlan(preparation: "Sketchbook by my chair", phonePlacement: .accessibleNearby)
        let historyB = habitHistory(ease: .hard, obstacle: .neededPhone)
        try persistence.saveWindDownHabitPlan(planB, identity: identityB)
        try persistence.saveWindDownHabitReflections(historyB, identity: identityB)
        XCTAssertThrowsError(try persistence.saveWindDownHabitPlan(planA, identity: identityA))
        XCTAssertThrowsError(try persistence.saveWindDownHabitReflections(historyA, identity: identityA))
        XCTAssertEqual(try persistence.loadWindDownHabitPlan(), planB)
        XCTAssertEqual(try persistence.loadWindDownHabitReflections(), historyB)

        try persistence.farmSaveStore.activate(.account(ownerA))
        XCTAssertEqual(try persistence.windDownHabitIdentity(), identityA)
        XCTAssertEqual(try persistence.loadWindDownHabitPlan(), planA)
        XCTAssertEqual(try persistence.loadWindDownHabitReflections(), historyA)
        XCTAssertThrowsError(try persistence.saveWindDownHabitPlan(planB, identity: identityB))
        try persistence.farmSaveStore.activate(.account(ownerB))
        XCTAssertEqual(try service().loadWindDownHabitPlan(), planB)
        XCTAssertEqual(try service().loadWindDownHabitReflections(), historyB)
    }

    func testMalformedHabitValuesThrowWithoutReplacingTheStoredBytes() throws {
        let persistence = service()
        let identity = try persistence.windDownHabitIdentity()
        let history = habitHistory(ease: .notSure)
        try persistence.saveWindDownHabitReflections(history, identity: identity)
        let invalidPlan = Data("{\"cue\":42}".utf8)
        try persistence.farmSaveStore.setLocalData(invalidPlan, for: WindDownHabitPlan.storageKey)
        XCTAssertThrowsError(try persistence.loadWindDownHabitPlan())
        XCTAssertEqual(try persistence.loadWindDownHabitReflections(), history)

        let invalidHistory = Data("not a reflection document".utf8)
        try persistence.farmSaveStore.setLocalData(invalidHistory, for: WindDownHabitReflectionHistory.storageKey)
        let reopened = service()
        XCTAssertThrowsError(try reopened.loadWindDownHabitPlan())
        XCTAssertThrowsError(try reopened.loadWindDownHabitReflections())
        XCTAssertEqual(reopened.farmSaveStore.localData(for: WindDownHabitPlan.storageKey), invalidPlan)
        XCTAssertEqual(reopened.farmSaveStore.localData(for: WindDownHabitReflectionHistory.storageKey), invalidHistory)
    }

    func testHabitSaveRejectsOwnerChangeStagedInsideAnOuterTransaction() throws {
        let persistence = service()
        let ownerA = UUID(), ownerB = UUID()
        try persistence.farmSaveStore.activate(.account(ownerA))
        let identityA = try persistence.windDownHabitIdentity()
        let planA = WindDownHabitPlan(cue: "A private cue")
        try persistence.saveWindDownHabitPlan(planA, identity: identityA)

        XCTAssertThrowsError(try persistence.farmSaveStore.transaction {
            try persistence.farmSaveStore.activate(.account(ownerB))
            try persistence.saveWindDownHabitPlan(planA, identity: identityA)
        })
        XCTAssertEqual(try persistence.windDownHabitIdentity(), identityA)
        XCTAssertEqual(try persistence.loadWindDownHabitPlan(), planA)
        try persistence.farmSaveStore.activate(.account(ownerB))
        XCTAssertEqual(try persistence.loadWindDownHabitPlan(), WindDownHabitPlan())
    }

    func testResetClearsHabitValuesAndRejectsAnOldLineageForTheSameAccount() throws {
        let persistence = service()
        let owner = UUID()
        try persistence.farmSaveStore.activate(.account(owner))
        let oldIdentity = try persistence.windDownHabitIdentity()
        let plan = WindDownHabitPlan(cue: "After dinner")
        let history = habitHistory(ease: .mixed)
        try persistence.saveWindDownHabitPlan(plan, identity: oldIdentity)
        try persistence.saveWindDownHabitReflections(history, identity: oldIdentity)
        defaults.set(try JSONEncoder().encode(plan), forKey: WindDownHabitPlan.storageKey)
        defaults.set(try JSONEncoder().encode(history), forKey: WindDownHabitReflectionHistory.storageKey)

        XCTAssertTrue(persistence.resetLocalProductData())
        XCTAssertNil(defaults.data(forKey: WindDownHabitPlan.storageKey))
        XCTAssertNil(defaults.data(forKey: WindDownHabitReflectionHistory.storageKey))
        XCTAssertEqual(try persistence.loadWindDownHabitPlan(), WindDownHabitPlan())
        XCTAssertTrue(try persistence.loadWindDownHabitReflections().entries.isEmpty)
        try persistence.farmSaveStore.activate(.account(owner))
        let newIdentity = try persistence.windDownHabitIdentity()
        XCTAssertEqual(newIdentity.scope, oldIdentity.scope)
        XCTAssertNotEqual(newIdentity.lineageID, oldIdentity.lineageID)
        XCTAssertThrowsError(try persistence.saveWindDownHabitPlan(plan, identity: oldIdentity))
        XCTAssertThrowsError(try persistence.saveWindDownHabitReflections(history, identity: oldIdentity))
        XCTAssertEqual(try service().loadWindDownHabitPlan(), WindDownHabitPlan())
        XCTAssertTrue(try service().loadWindDownHabitReflections().entries.isEmpty)
    }

    func testHabitDiskWriteFailurePreservesLastConfirmedValuesAndCanRetry() throws {
        let files = HabitFailingFiles()
        let persistence = service(files: files)
        let identity = try persistence.windDownHabitIdentity()
        let original = WindDownHabitPlan(cue: "After dinner")
        let originalHistory = habitHistory(ease: .easy)
        try persistence.saveWindDownHabitPlan(original, identity: identity)
        try persistence.saveWindDownHabitReflections(originalHistory, identity: identity)
        let next = WindDownHabitPlan(cue: "After brushing my teeth", smallerActivity: "Read one paragraph")
        let nextHistory = habitHistory(ease: .hard, obstacle: .tooMuch)

        files.failWrites = true
        XCTAssertThrowsError(try persistence.saveWindDownHabitPlan(next, identity: identity))
        XCTAssertThrowsError(try persistence.saveWindDownHabitReflections(nextHistory, identity: identity))
        XCTAssertEqual(try persistence.loadWindDownHabitPlan(), original)
        XCTAssertEqual(try persistence.loadWindDownHabitReflections(), originalHistory)
        XCTAssertEqual(try service().loadWindDownHabitPlan(), original)
        XCTAssertEqual(try service().loadWindDownHabitReflections(), originalHistory)

        files.failWrites = false
        try persistence.saveWindDownHabitPlan(next, identity: identity)
        try persistence.saveWindDownHabitReflections(nextHistory, identity: identity)
        XCTAssertEqual(try service().loadWindDownHabitPlan(), next)
        XCTAssertEqual(try service().loadWindDownHabitReflections(), nextHistory)
    }

    private func habitHistory(ease: WindDownStartingEase, obstacle: WindDownObstacle? = nil) -> WindDownHabitReflectionHistory {
        WindDownHabitReflectionHistory(entries: [
            WindDownHabitReflection(day: Date(timeIntervalSince1970: 1_783_584_000), ease: ease, obstacle: obstacle)
        ])
    }

    func testUnreadableLegacyFarmNeverBecomesSavedStarterFarm() throws {
        let original = Data("unreadable".utf8)
        defaults.set(original, forKey: "ollie.farm.state")
        let persistence = service()
        _ = persistence.farmState
        persistence.farmState = .empty
        XCTAssertEqual(defaults.data(forKey: "ollie.farm.state"), original)
        XCTAssertFalse(persistence.farmSaveStore.hasReadableSave)
        XCTAssertEqual(persistence.farmSaveStore.failure, .invalidComponent("ollie.farm.state"))
    }

    func testCaughtEncoderFailureAbortsOtherStagedWrites() throws {
        let persistence = service()
        let original = persistence.farmState
        var invalid = original
        invalid.cumulativeCredit = CumulativeFarmCredit()
        invalid.cumulativeCredit?.windDownSeconds = .nan
        var progress = persistence.progress
        progress.totalCompletedRuns = 100
        XCTAssertThrowsError(try persistence.farmSaveStore.transaction {
            persistence.progress = progress
            persistence.farmState = invalid
        })
        XCTAssertEqual(service().farmState, original)
        XCTAssertEqual(service().progress.totalCompletedRuns, 0)
    }

    func testMissingFilesAfterMigrationDoNotReimportStaleDefaults() throws {
        var old = FarmState.empty
        old.woolBalance = 99
        defaults.set(try JSONEncoder().encode(old), forKey: "ollie.farm.state")
        let persistence = service()
        var current = persistence.farmState
        current.woolBalance = 4
        persistence.farmState = current
        XCTAssertTrue(defaults.bool(forKey: "ollie.farm.saveMigrated"))
        try FileManager.default.removeItem(at: directory)
        let reopened = service()
        _ = reopened.farmState
        XCTAssertFalse(reopened.farmSaveStore.hasReadableSave)
        XCTAssertEqual(reopened.farmSaveStore.failure, .unavailable)
    }

    func testResetRemovesLegacyDataAndFileRecoveryCopies() throws {
        let persistence = service()
        var farm = persistence.farmState
        farm.woolBalance = 27
        persistence.farmState = farm
        defaults.set(try JSONEncoder().encode(farm), forKey: "ollie.farm.state")
        XCTAssertTrue(persistence.resetLocalProductData())
        XCTAssertNil(defaults.data(forKey: "ollie.farm.state"))
        XCTAssertEqual(service().farmState.woolBalance, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("legacy-original.json").path))
    }

    func testImpactDeletionClearsOnlyTheActiveAccountLedger() throws {
        let persistence = service()
        let firstOwner = UUID()
        let secondOwner = UUID()
        let firstRecord = impactRecord(relativeNight: 1)
        let secondRecord = impactRecord(relativeNight: 2)

        try persistence.farmSaveStore.activate(.account(firstOwner), preservingGuest: true)
        let firstDocument = try persistence.farmSaveStore.snapshot()
        persistence.impactSharingPreferences = ImpactSharingPreferences(isEnabled: true, consentedAt: Date())
        persistence.impactUploadRecords = [firstRecord]

        try persistence.farmSaveStore.activate(.account(secondOwner))
        persistence.impactSharingPreferences = ImpactSharingPreferences(isEnabled: true, consentedAt: Date())
        persistence.impactUploadRecords = [secondRecord]

        XCTAssertFalse(persistence.deleteSharedImpactData(
            expectedScope: firstDocument.effectiveScope,
            expectedLineageID: firstDocument.lineageID
        ))
        XCTAssertEqual(persistence.impactUploadRecords, [secondRecord])

        try persistence.farmSaveStore.activate(.account(firstOwner))
        XCTAssertEqual(persistence.impactUploadRecords, [firstRecord])
        XCTAssertTrue(persistence.deleteSharedImpactData(
            expectedScope: firstDocument.effectiveScope,
            expectedLineageID: firstDocument.lineageID
        ))
        XCTAssertTrue(persistence.impactUploadRecords.isEmpty)
        XCTAssertEqual(persistence.impactSharingPreferences, ImpactSharingPreferences())

        try persistence.farmSaveStore.activate(.account(secondOwner))
        XCTAssertEqual(persistence.impactUploadRecords, [secondRecord])
        XCTAssertTrue(persistence.impactSharingPreferences.isEnabled)
    }

    private func impactRecord(relativeNight: Int) -> ImpactUploadRecord {
        ImpactUploadRecord(
            relativeNight: relativeNight,
            sample: NightImpactSample(
                nightEndingDate: Date(), plannedQuietMinutes: 10, quietMinutes: 10,
                completedRitual: true, startMethod: nil, shieldEvidence: .observed,
                sleepMinutes: nil, coreSleepMinutes: nil, deepSleepMinutes: nil,
                remSleepMinutes: nil, restfulness: nil
            ),
            appVersion: "test"
        )
    }
}

private final class HabitFailingFiles: FarmSaveFileAccess {
    var failWrites = false
    private let local = LocalFarmSaveFileAccess()
    func files(in directory: URL) throws -> [URL] { try local.files(in: directory) }
    func read(_ url: URL) throws -> Data { try local.read(url) }
    func remove(_ url: URL) throws { try local.remove(url) }
    func write(_ data: Data, to url: URL) throws {
        if failWrites { throw FarmSaveError.unavailable }
        try local.write(data, to: url)
    }
}
#endif
