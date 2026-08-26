import XCTest

final class NightWatchHistoryTests: XCTestCase {
    func testPhoneBedRegistrationMatchesOnlyItsRegisteredTag() {
        let registration = PhoneBedTagRegistration(
            id: UUID(),
            tokenDigest: "registered-tag",
            registeredAt: Date()
        )

        XCTAssertTrue(registration.matches(scannedDigest: "registered-tag"))
        XCTAssertFalse(registration.matches(scannedDigest: "another-tag"))
    }

    func testPhoneBedTagLibraryAuthenticatesPrimaryOrBackupOnlyForAssignedPurpose() {
        let primary = makeNamedTag(
            name: "Fridge",
            digest: "primary",
            role: .primary,
            purposes: [.windDown]
        )
        let backup = makeNamedTag(
            name: "Living Room",
            digest: "backup",
            role: .backup,
            purposes: [.windDown, .phoneAway]
        )
        let library = PhoneBedTagLibrary(tags: [backup, primary])

        XCTAssertEqual(
            library.authenticatingTag(digest: "primary", purpose: .windDown)?.name,
            "Fridge"
        )
        XCTAssertNil(library.authenticatingTag(digest: "primary", purpose: .phoneAway))
        XCTAssertEqual(
            library.authenticatingTag(digest: "backup", purpose: .phoneAway)?.name,
            "Living Room"
        )
        XCTAssertNil(library.authenticatingTag(digest: "unknown", purpose: .windDown))
    }

    func testPhoneBedTagLibraryMigratesLegacyRegistrationToPrimaryForBothUses() throws {
        let registeredAt = Date(timeIntervalSince1970: 1_800_000_000)
        let legacy = PhoneBedTagRegistration(
            id: UUID(),
            tokenDigest: "legacy-digest",
            registeredAt: registeredAt
        )
        let library = try XCTUnwrap(
            PhoneBedTagLibrary.migrated(from: legacy, legacyDigest: nil)
        )

        XCTAssertEqual(library.tags.count, 1)
        XCTAssertEqual(library.primary?.name, "Wind Down tag")
        XCTAssertNotEqual(library.primary?.id, legacy.id)
        XCTAssertEqual(library.primary?.tokenDigest, "legacy-digest")
        XCTAssertEqual(library.primary?.purposes, Set(PhoneBedTagPurpose.allCases))
        XCTAssertNil(library.backup)
    }

    func testPhoneBedTagReplacementKeepsStableSlotIDAndDropsOldCredential() {
        let slotID = UUID()
        var library = PhoneBedTagLibrary(tags: [
            makeNamedTag(
                id: slotID,
                name: "Fridge",
                digest: "old",
                role: .primary,
                purposes: [.windDown]
            )
        ])
        library.replace(
            role: .primary,
            with: makeNamedTag(
                id: slotID,
                name: "Kitchen",
                digest: "new",
                role: .primary,
                purposes: [.windDown, .phoneAway]
            )
        )

        XCTAssertEqual(library.primary?.id, slotID)
        XCTAssertEqual(library.primary?.tokenDigest, "new")
        XCTAssertNil(library.tag(matching: "old"))
        XCTAssertTrue(library.wasPreviouslyPaired(digest: "old"))
        XCTAssertNotNil(library.authenticatingTag(digest: "new", purpose: .phoneAway))
    }

    func testLibraryReplacementKeepsTheSlotAndRetiresTheOldDigest() {
        let slotID = UUID()
        var library = PhoneBedTagLibrary(tags: [
            makeNamedTag(id: slotID, name: "Fridge", digest: "active", role: .primary, purposes: [.windDown, .phoneAway])
        ])
        library.replace(
            role: .primary,
            with: makeNamedTag(id: slotID, name: "Fridge", digest: "fresh", role: .primary, purposes: [.windDown, .phoneAway])
        )

        XCTAssertEqual(library.primary?.id, slotID)
        XCTAssertEqual(library.primary?.name, "Fridge")
        XCTAssertTrue(library.wasPreviouslyPaired(digest: "active"))
        XCTAssertFalse(library.wasPreviouslyPaired(digest: "fresh"))
    }

    func testBackupRecoveryKeepsItsSlotIdentityPurposesAndRetiresOldCredential() {
        let primaryID = UUID()
        let backupID = UUID()
        var library = PhoneBedTagLibrary(tags: [
            makeNamedTag(
                id: primaryID,
                name: "Bedroom",
                digest: "primary",
                role: .primary,
                purposes: [.windDown]
            ),
            makeNamedTag(
                id: backupID,
                name: "Travel pouch",
                digest: "old-backup",
                role: .backup,
                purposes: [.phoneAway]
            )
        ])

        library.retireCredential("unknown-old-credential")
        library.replace(
            role: .backup,
            with: makeNamedTag(
                id: backupID,
                name: "Travel pouch",
                digest: "new-backup",
                role: .backup,
                purposes: [.phoneAway]
            )
        )

        XCTAssertEqual(library.backup?.id, backupID)
        XCTAssertEqual(library.backup?.name, "Travel pouch")
        XCTAssertEqual(library.backup?.purposes, [.phoneAway])
        XCTAssertEqual(library.backup?.tokenDigest, "new-backup")
        XCTAssertTrue(library.wasPreviouslyPaired(digest: "old-backup"))
        XCTAssertTrue(library.wasPreviouslyPaired(digest: "unknown-old-credential"))
    }

    func testPhoneBedTagLibraryPersistsPreviousCredentialsWithoutRawTokens() throws {
        var library = PhoneBedTagLibrary(tags: [
            makeNamedTag(name: "Fridge", digest: "old", role: .primary, purposes: [.windDown])
        ])
        library.replace(
            role: .primary,
            with: makeNamedTag(name: "Shelf", digest: "new", role: .primary, purposes: [.windDown])
        )

        let data = try JSONEncoder().encode(library)
        let restored = try JSONDecoder().decode(PhoneBedTagLibrary.self, from: data)
        XCTAssertTrue(restored.wasPreviouslyPaired(digest: "old"))
        XCTAssertFalse(restored.wasPreviouslyPaired(digest: "new"))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("raw-token"))
    }

    func testPhoneBedTagLibraryNormalizesDuplicateCredentialAndPromotesBackup() {
        let duplicatePrimary = makeNamedTag(
            name: "Primary",
            digest: "same",
            role: .primary,
            purposes: [.windDown]
        )
        let duplicateBackup = makeNamedTag(
            name: "Backup",
            digest: "same",
            role: .backup,
            purposes: [.phoneAway]
        )
        var library = PhoneBedTagLibrary(tags: [duplicateBackup, duplicatePrimary])

        XCTAssertEqual(library.tags.count, 1)
        XCTAssertEqual(library.primary?.name, "Primary")

        library.forget(id: duplicatePrimary.id)
        XCTAssertTrue(library.tags.isEmpty)

        var backupOnly = PhoneBedTagLibrary(tags: [
            makeNamedTag(
                name: "Spare",
                digest: "spare",
                role: .backup,
                purposes: [.phoneAway]
            )
        ])
        XCTAssertEqual(backupOnly.primary?.name, "Spare")
        XCTAssertNil(backupOnly.backup)
        if let promotedID = backupOnly.primary?.id {
            backupOnly.forget(id: promotedID)
        }
        XCTAssertTrue(backupOnly.tags.isEmpty)
    }

    func testPhoneBedTagTestVerificationUpdatesOnlyRecognizedTag() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var library = PhoneBedTagLibrary(tags: [
            makeNamedTag(
                name: "Fridge",
                digest: "known",
                role: .primary,
                purposes: [.windDown],
                registeredAt: start
            )
        ])
        let verifiedAt = start.addingTimeInterval(60)

        XCTAssertNil(library.markVerified(digest: "unknown", at: verifiedAt))
        XCTAssertNil(library.primary?.lastVerifiedAt)
        XCTAssertNotNil(library.markVerified(digest: "known", at: verifiedAt))
        XCTAssertEqual(library.primary?.lastVerifiedAt, verifiedAt)
    }

    func testPhoneBedTagNamesAreTrimmedUnicodeSafeAndNonEmpty() {
        let longName = "  🐑" + String(repeating: "é", count: 60) + "  "
        let normalized = NamedPhoneBedTagRegistration.normalizedName(longName)

        XCTAssertEqual(normalized.count, NamedPhoneBedTagRegistration.maximumNameLength)
        XCTAssertTrue(normalized.hasPrefix("🐑"))
        XCTAssertEqual(
            NamedPhoneBedTagRegistration.normalizedName("   \n"),
            NamedPhoneBedTagRegistration.defaultName
        )
    }

    func testHistoryDeduplicatesIdempotentEventsAndOrdersByOccurrence() {
        let runID = UUID()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var history = NightWatchHistory(now: start)

        history.append(
            RitualEvent(
                runID: runID,
                occurredAt: start.addingTimeInterval(30),
                recordedAt: start.addingTimeInterval(31),
                kind: .placementConfirmed,
                source: .observed,
                idempotencyKey: "\(runID):placement"
            ),
            now: start
        )
        history.append(
            RitualEvent(
                runID: runID,
                occurredAt: start,
                recordedAt: start.addingTimeInterval(32),
                kind: .sessionStarted,
                source: .observed,
                idempotencyKey: "\(runID):start"
            ),
            now: start
        )
        history.append(
            RitualEvent(
                runID: runID,
                occurredAt: start.addingTimeInterval(35),
                recordedAt: start.addingTimeInterval(36),
                kind: .placementConfirmed,
                source: .observed,
                idempotencyKey: "\(runID):placement"
            ),
            now: start
        )

        XCTAssertEqual(history.events(for: runID).map(\.kind), [.sessionStarted, .placementConfirmed])
    }

    func testHistoryUpsertsLatestRecordForRun() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let run = makeRun(startedAt: start)
        var history = NightWatchHistory(now: start)
        let active = run.nightWatchRecord(updatedAt: start)!
        var completed = active
        completed.outcome = .completed
        completed.endedAt = active.plan.protectedUntil
        completed.creditedWindDownMinutes = 30
        completed.creditedMorningQuietMinutes = 30
        completed.updatedAt = active.plan.protectedUntil

        history.upsert(active, now: start)
        history.upsert(completed, now: active.plan.protectedUntil)

        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(history.record(for: run.id)?.outcome, .completed)
        XCTAssertEqual(history.record(for: run.id)?.creditedWindDownMinutes, 30)
    }

    func testHistoryDropsDetailedDataOlderThanRetentionWindow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let oldDate = now.addingTimeInterval(-TimeInterval(100 * 24 * 60 * 60))
        let oldRun = makeRun(startedAt: oldDate)
        let recentRun = makeRun(startedAt: now)
        let history = NightWatchHistory(
            records: [
                oldRun.nightWatchRecord(updatedAt: oldDate)!,
                recentRun.nightWatchRecord(updatedAt: now)!
            ],
            events: [
                RitualEvent(
                    runID: oldRun.id,
                    occurredAt: oldDate,
                    recordedAt: oldDate,
                    kind: .sessionStarted,
                    source: .observed
                ),
                RitualEvent(
                    runID: recentRun.id,
                    occurredAt: now,
                    recordedAt: now,
                    kind: .sessionStarted,
                    source: .observed
                )
            ],
            now: now
        )

        XCTAssertNil(history.record(for: oldRun.id))
        XCTAssertNotNil(history.record(for: recentRun.id))
        XCTAssertTrue(history.events(for: oldRun.id).isEmpty)
    }

    func testNightWatchRecordLegacyDecodeDefaultsNewProtectionFields() throws {
        let run = makeRun(startedAt: Date(timeIntervalSince1970: 1_800_000_000))
        let record = run.nightWatchRecord()!
        let encoded = try JSONEncoder().encode(record)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "shieldedWindDownMinutes")
        object.removeValue(forKey: "shieldedMorningQuietMinutes")
        object.removeValue(forKey: "shieldProtectionEvidence")
        object.removeValue(forKey: "briefAccessUseCount")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(NightWatchRecord.self, from: legacyData)

        XCTAssertEqual(decoded.shieldedWindDownMinutes, 0)
        XCTAssertEqual(decoded.shieldedMorningQuietMinutes, 0)
        XCTAssertEqual(decoded.shieldProtectionEvidence, .notRequested)
        XCTAssertEqual(decoded.briefAccessUseCount, 0)
    }

    private func makeRun(startedAt: Date) -> FocusRun {
        let plan = NightWatchPlan(
            intendedBedtime: startedAt.addingTimeInterval(30 * 60),
            wakeTime: startedAt.addingTimeInterval(8 * 60 * 60),
            protectedUntil: startedAt.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        return FocusRun(
            plannedDurationSeconds: plan.protectedUntil.timeIntervalSince(startedAt),
            startedAt: startedAt,
            state: .running,
            guardKind: .nfcTag,
            nightWatchPlan: plan
        )
    }

    private func makeNamedTag(
        id: UUID = UUID(),
        name: String,
        digest: String,
        role: PhoneBedTagRole,
        purposes: Set<PhoneBedTagPurpose>,
        registeredAt: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) -> NamedPhoneBedTagRegistration {
        NamedPhoneBedTagRegistration(
            id: id,
            name: name,
            tokenDigest: digest,
            registeredAt: registeredAt,
            role: role,
            purposes: purposes
        )
    }
}
