import XCTest

final class QuietTimeShieldScheduleRegistryTests: XCTestCase {
    func testNewerDeferredEntryRejectsStaleCallbackAndTombstoneRejectsItAfterRemoval() {
        let occurrenceID = UUID()
        let start = Date(timeIntervalSince1970: 1_000)
        let interval = DateInterval(start: start, end: start.addingTimeInterval(30 * 60))
        var registry = QuietTimeShieldScheduleRegistry()
        let first = registry.upsert(
            occurrenceID: occurrenceID, interval: interval, role: .primaryWindDown, at: start
        )
        let replacement = registry.upsert(
            occurrenceID: occurrenceID,
            interval: DateInterval(start: interval.end, end: interval.end.addingTimeInterval(30 * 60)),
            role: .primaryWindDown,
            at: start.addingTimeInterval(1)
        )
        XCTAssertFalse(registry.accepts(occurrenceID: occurrenceID, revision: first.revision, epoch: first.epoch))
        XCTAssertTrue(registry.accepts(occurrenceID: occurrenceID, revision: replacement.revision, epoch: replacement.epoch))

        registry.remove(occurrenceID: occurrenceID, at: start.addingTimeInterval(2))
        XCTAssertFalse(registry.accepts(occurrenceID: occurrenceID, revision: replacement.revision, epoch: replacement.epoch))
        XCTAssertEqual(registry.tombstones.first?.occurrenceID, occurrenceID)
    }

    func testMultipleWindowsCanCoexistAndDeferredGapClears() {
        let start = Date(timeIntervalSince1970: 1_000)
        let firstID = UUID()
        let secondID = UUID()
        var registry = QuietTimeShieldScheduleRegistry()
        let first = registry.upsert(
            occurrenceID: firstID,
            interval: DateInterval(start: start, end: start.addingTimeInterval(30 * 60)),
            role: .primaryWindDown,
            at: start
        )
        let second = registry.upsert(
            occurrenceID: secondID,
            interval: DateInterval(start: start.addingTimeInterval(60 * 60), end: start.addingTimeInterval(90 * 60)),
            role: .primaryWindDown,
            at: start
        )
        XCTAssertEqual(registry.entries.count, 2)
        XCTAssertEqual(
            QuietTimeShieldRegistryPolicy.reconciliation(
                registry: registry, occurrenceID: firstID, revision: first.revision, epoch: first.epoch,
                at: start.addingTimeInterval(15 * 60)
            ),
            .apply(first)
        )
        XCTAssertEqual(
            QuietTimeShieldRegistryPolicy.reconciliation(
                registry: registry, occurrenceID: secondID, revision: second.revision, epoch: second.epoch,
                at: start.addingTimeInterval(45 * 60)
            ),
            .clear
        )
    }

    func testTerminalRemovalClearsOnlyWhenNoOtherDesiredWindowIsActive() {
        let now = Date(timeIntervalSince1970: 1_000)
        let firstID = UUID()
        let secondID = UUID()
        var registry = QuietTimeShieldScheduleRegistry()
        _ = registry.upsert(
            occurrenceID: firstID,
            interval: DateInterval(start: now.addingTimeInterval(-60), end: now.addingTimeInterval(60)),
            role: .primaryWindDown,
            at: now
        )
        _ = registry.upsert(
            occurrenceID: secondID,
            interval: DateInterval(start: now.addingTimeInterval(-30), end: now.addingTimeInterval(30)),
            role: .screenFreeMorning,
            at: now
        )
        guard case .keepShielded(let remaining) = QuietTimeShieldRegistryCleanupPolicy.decision(
            registry: registry,
            removing: firstID,
            at: now
        ) else { return XCTFail("Expected overlapping Morning to keep shielding") }
        XCTAssertEqual(remaining.map(\.occurrenceID), [secondID])
        let snapshot = QuietTimeShieldRegistryCleanupPolicy.snapshot(for: remaining[0])
        XCTAssertEqual(snapshot.runID, secondID)
        XCTAssertEqual(snapshot.role, .screenFreeMorning)
        XCTAssertEqual(snapshot.registryRevision, remaining[0].revision)
        XCTAssertEqual(snapshot.registryEpoch, remaining[0].epoch)

        XCTAssertEqual(
            QuietTimeShieldRegistryCleanupPolicy.decision(
                registry: registry,
                removing: secondID,
                at: now.addingTimeInterval(90)
            ),
            .clearStore
        )
    }

    func testMissingOrTombstonedSnapshotRetainsAnotherActiveRegistryBarrier() {
        let now = Date(timeIntervalSince1970: 1_000)
        let retiredID = UUID()
        let activeID = UUID()
        var registry = QuietTimeShieldScheduleRegistry()
        _ = registry.upsert(
            occurrenceID: retiredID,
            interval: DateInterval(start: now.addingTimeInterval(-60), end: now.addingTimeInterval(60)),
            role: .primaryWindDown,
            at: now
        )
        _ = registry.upsert(
            occurrenceID: activeID,
            interval: DateInterval(start: now.addingTimeInterval(-30), end: now.addingTimeInterval(60)),
            role: .screenFreeMorning,
            at: now
        )
        registry.remove(occurrenceID: retiredID, at: now)

        XCTAssertTrue(QuietTimeShieldRegistryPolicy.retainsActiveBarrier(
            registry: registry, snapshotOccurrenceID: nil, at: now
        ))
        XCTAssertTrue(QuietTimeShieldRegistryPolicy.retainsActiveBarrier(
            registry: registry, snapshotOccurrenceID: retiredID, at: now
        ))
        XCTAssertFalse(QuietTimeShieldRegistryPolicy.retainsActiveBarrier(
            registry: registry, snapshotOccurrenceID: activeID, at: now
        ))
    }

    func testPruningBoundsOldNightsWhileRetainingActiveAndDeferredWindows() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        var registry = QuietTimeShieldScheduleRegistry()
        let activeID = UUID()
        let deferredID = UUID()
        _ = registry.upsert(
            occurrenceID: activeID,
            interval: DateInterval(start: now.addingTimeInterval(-60), end: now.addingTimeInterval(60)),
            role: .primaryWindDown,
            at: now
        )
        _ = registry.upsert(
            occurrenceID: deferredID,
            interval: DateInterval(start: now.addingTimeInterval(60), end: now.addingTimeInterval(120)),
            role: .screenFreeMorning,
            at: now
        )
        for offset in 1...70 {
            let end = now.addingTimeInterval(TimeInterval(-offset * 24 * 60 * 60))
            _ = registry.upsert(
                occurrenceID: UUID(),
                interval: DateInterval(start: end.addingTimeInterval(-60), end: end),
                role: .primaryWindDown,
                at: now
            )
        }
        registry.prune(at: now)

        XCTAssertNotNil(registry.entry(for: activeID))
        XCTAssertNotNil(registry.entry(for: deferredID))
        XCTAssertLessThanOrEqual(registry.entries.count, QuietTimeShieldScheduleRegistry.maximumEntryCount)
        XCTAssertLessThanOrEqual(registry.tombstones.count, QuietTimeShieldScheduleRegistry.maximumTombstoneCount)
    }

    func testLegacySnapshotMigratesToRegistryAndPurposeCueClearsOnlyMatchingState() throws {
        let suiteName = "QuietTimeShieldScheduleRegistryTests.\(UUID().uuidString)"
        guard let suite = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated defaults suite")
            return
        }
        defer { suite.removePersistentDomain(forName: suiteName) }
        let start = Date(timeIntervalSince1970: 1_000)
        let runID = UUID()
        let snapshot = QuietTimeShieldScheduleSnapshot(
            runID: runID, revision: 2, windDownInterval: DateInterval(start: start, end: start.addingTimeInterval(30 * 60)),
            morningQuietInterval: DateInterval(start: start.addingTimeInterval(8 * 60 * 60), end: start.addingTimeInterval(8.5 * 60 * 60)),
            updatedAt: start
        )
        suite.set(try JSONEncoder().encode(snapshot), forKey: QuietTimeShieldSharedStorage.scheduleKey)
        let registry = QuietTimeShieldScheduleRegistryStorage.load(from: suite)
        XCTAssertEqual(registry.entry(for: runID)?.role, .primaryWindDown)

        let cue = QuietPurposeCueState(occurrenceID: runID, revision: 1, epoch: 1, cue: .read)
        QuietPurposeCueState.save(cue, to: suite)
        QuietPurposeCueState.clear(occurrenceID: runID, revision: 2, epoch: 1, from: suite)
        XCTAssertEqual(QuietPurposeCueState.load(from: suite), cue)
        QuietPurposeCueState.clear(occurrenceID: runID, revision: 1, epoch: 1, from: suite)
        XCTAssertNil(QuietPurposeCueState.load(from: suite))
    }

    func testActivityIdentifiersRoundTripAndDiffOnlyTouchesChangedOccurrences() {
        let firstID = UUID()
        let secondID = UUID()
        let start = Date(timeIntervalSince1970: 1_000)
        var before = QuietTimeShieldScheduleRegistry()
        let old = before.upsert(
            occurrenceID: firstID, interval: DateInterval(start: start, end: start.addingTimeInterval(60)),
            role: .primaryWindDown, at: start
        )
        var after = before
        _ = after.upsert(
            occurrenceID: secondID, interval: DateInterval(start: start, end: start.addingTimeInterval(60)),
            role: .primaryWindDown, at: start
        )
        let revised = after.upsert(
            occurrenceID: firstID, interval: DateInterval(start: start.addingTimeInterval(60), end: start.addingTimeInterval(120)),
            role: .primaryWindDown, at: start.addingTimeInterval(1)
        )
        let oldActivity = QuietTimeShieldRegistryActivity(occurrenceID: old.occurrenceID, revision: old.revision, epoch: old.epoch)
        XCTAssertEqual(QuietTimeShieldRegistryActivity(identifier: oldActivity.identifier), oldActivity)
        let diff = QuietTimeShieldRegistryActivityDiff.make(previous: before, desired: after)
        XCTAssertTrue(diff.stop.contains(oldActivity))
        XCTAssertTrue(diff.register.contains(QuietTimeShieldRegistryActivity(occurrenceID: firstID, revision: revised.revision, epoch: revised.epoch)))
        XCTAssertEqual(diff.register.count, 2)
    }

    func testShieldActionRegistryWireContractUsesStableKeyAndIdentityFormat() throws {
        let occurrenceID = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        let activity = QuietTimeShieldRegistryActivity(
            occurrenceID: occurrenceID,
            revision: 4,
            epoch: 9
        )
        XCTAssertEqual(QuietTimeShieldScheduleRegistryStorage.key, "ollie.screenTime.shieldScheduleRegistry")
        XCTAssertEqual(
            activity.identifier,
            "ollie.quietTime.registry.00000000-0000-0000-0000-000000000123.r4.e9"
        )
        XCTAssertEqual(QuietTimeShieldRegistryActivity(identifier: activity.identifier), activity)

        var registry = QuietTimeShieldScheduleRegistry()
        _ = registry.upsert(
            occurrenceID: occurrenceID,
            interval: DateInterval(start: Date(timeIntervalSince1970: 1), duration: 60),
            role: .primaryWindDown,
            at: Date(timeIntervalSince1970: 1)
        )
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(registry)) as? [String: Any]
        XCTAssertNotNil(object?["entries"])
        XCTAssertNotNil(object?["tombstones"])
    }

    func testStaleCallbackCannotClearAnotherActiveOccurrence() {
        let start = Date(timeIntervalSince1970: 1_000)
        let staleID = UUID()
        let activeID = UUID()
        var registry = QuietTimeShieldScheduleRegistry()
        let stale = registry.upsert(
            occurrenceID: staleID,
            interval: DateInterval(start: start, end: start.addingTimeInterval(60)),
            role: .primaryWindDown,
            at: start
        )
        let active = registry.upsert(
            occurrenceID: activeID,
            interval: DateInterval(start: start, end: start.addingTimeInterval(30 * 60)),
            role: .additionalQuiet,
            at: start
        )
        _ = registry.upsert(
            occurrenceID: staleID,
            interval: DateInterval(start: start.addingTimeInterval(60), end: start.addingTimeInterval(120)),
            role: .primaryWindDown,
            at: start.addingTimeInterval(1)
        )

        XCTAssertEqual(
            QuietTimeShieldRegistryPolicy.reconciliation(
                registry: registry,
                occurrenceID: staleID,
                revision: stale.revision,
                epoch: stale.epoch,
                at: start.addingTimeInterval(10)
            ),
            .ignoreStale
        )
        XCTAssertEqual(registry.activeEntries(at: start.addingTimeInterval(10)), [active])
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.staleGrantAction(
                schedule: nil,
                at: start.addingTimeInterval(10),
                hasActiveRegistryProtection: true
            ),
            .reapplyCurrentShield
        )
    }

    func testOverlappingEntriesRetainBothRestoreTargets() {
        let start = Date(timeIntervalSince1970: 1_000)
        var registry = QuietTimeShieldScheduleRegistry()
        let windDown = registry.upsert(
            occurrenceID: UUID(),
            interval: DateInterval(start: start, end: start.addingTimeInterval(30 * 60)),
            role: .primaryWindDown,
            at: start
        )
        let morning = registry.upsert(
            occurrenceID: UUID(),
            interval: DateInterval(start: start.addingTimeInterval(10 * 60), end: start.addingTimeInterval(40 * 60)),
            role: .additionalQuiet,
            at: start
        )

        let activeIDs = Set(
            registry.activeEntries(at: start.addingTimeInterval(15 * 60)).map(\.occurrenceID)
        )
        XCTAssertEqual(activeIDs, Set([windDown.occurrenceID, morning.occurrenceID]))
        let diff = QuietTimeShieldRegistryActivityDiff.make(
            previous: QuietTimeShieldScheduleRegistry(),
            desired: registry
        )
        XCTAssertEqual(diff.register.count, 2)
        XCTAssertTrue(diff.stop.isEmpty)
    }
}
