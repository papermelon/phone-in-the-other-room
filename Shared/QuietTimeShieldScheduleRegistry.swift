import Foundation

enum QuietTimeShieldScheduleRegistryStorage {
    static let key = "ollie.screenTime.shieldScheduleRegistry"

    static func load(from defaults: UserDefaults) -> QuietTimeShieldScheduleRegistry {
        guard let data = defaults.data(forKey: key) else {
            return migrateLegacySnapshot(from: defaults)
        }
        return (try? JSONDecoder().decode(QuietTimeShieldScheduleRegistry.self, from: data))
            ?? migrateLegacySnapshot(from: defaults)
    }

    static func save(_ registry: QuietTimeShieldScheduleRegistry, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(registry) else { return }
        defaults.set(data, forKey: key)
    }

    static func migrateLegacySnapshot(from defaults: UserDefaults) -> QuietTimeShieldScheduleRegistry {
        guard let data = defaults.data(forKey: QuietTimeShieldSharedStorage.scheduleKey),
              let snapshot = try? JSONDecoder().decode(QuietTimeShieldScheduleSnapshot.self, from: data) else {
            return QuietTimeShieldScheduleRegistry()
        }
        let interval = snapshot.protectedSessionInterval
            ?? snapshot.windDownInterval
            ?? snapshot.morningQuietInterval
        var registry = QuietTimeShieldScheduleRegistry()
        _ = registry.upsert(
            occurrenceID: snapshot.runID,
            interval: interval,
            role: snapshot.role,
            at: snapshot.updatedAt
        )
        return registry
    }
}

/// App Group projection of desired shielding windows. It contains no reward
/// result or selection payload. An extension can only act on the newest
/// occurrence/revision pair, so a stale callback cannot override a later gap
/// or deferred Screen-Free Morning window.
struct QuietTimeShieldScheduleRegistry: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let maximumEntryCount = 64
    static let maximumTombstoneCount = 128

    var schemaVersion: Int
    var epoch: Int
    var entries: [QuietTimeShieldScheduleRegistryEntry]
    var tombstones: [QuietTimeShieldScheduleRegistryTombstone]

    init(
        schemaVersion: Int = currentSchemaVersion,
        epoch: Int = 0,
        entries: [QuietTimeShieldScheduleRegistryEntry] = [],
        tombstones: [QuietTimeShieldScheduleRegistryTombstone] = []
    ) {
        self.schemaVersion = max(schemaVersion, Self.currentSchemaVersion)
        self.epoch = max(0, epoch)
        self.entries = entries
        self.tombstones = tombstones
    }

    func entry(for occurrenceID: UUID) -> QuietTimeShieldScheduleRegistryEntry? {
        entries.first { $0.occurrenceID == occurrenceID }
    }

    mutating func upsert(
        occurrenceID: UUID,
        interval: DateInterval,
        role: QuietTimeShieldRole,
        at date: Date
    ) -> QuietTimeShieldScheduleRegistryEntry {
        prune(at: date)
        epoch += 1
        let revision = (entry(for: occurrenceID)?.revision ?? 0) + 1
        let value = QuietTimeShieldScheduleRegistryEntry(
            occurrenceID: occurrenceID,
            revision: revision,
            epoch: epoch,
            role: role,
            interval: interval,
            updatedAt: date
        )
        entries.removeAll { $0.occurrenceID == occurrenceID }
        entries.append(value)
        tombstones.removeAll { $0.occurrenceID == occurrenceID }
        trimEntries(at: date)
        return value
    }

    mutating func remove(occurrenceID: UUID, at date: Date) {
        prune(at: date)
        guard let entry = entry(for: occurrenceID) else { return }
        entries.removeAll { $0.occurrenceID == occurrenceID }
        appendTombstone(for: entry, at: date)
    }

    /// Bounds cross-process schedule state without disturbing an active
    /// handoff or the nearest future deferred window. Expired entries become
    /// tombstones so late callbacks are still rejected.
    mutating func prune(at date: Date) {
        let expired = entries.filter { $0.interval.end <= date }
        guard !expired.isEmpty else { return }
        entries.removeAll { $0.interval.end <= date }
        expired.sorted { $0.interval.end < $1.interval.end }.forEach {
            appendTombstone(for: $0, at: date)
        }
    }

    private mutating func trimEntries(at date: Date) {
        guard entries.count > Self.maximumEntryCount else { return }
        let ordered = entries.sorted { lhs, rhs in
            let lhsActive = lhs.interval.contains(date)
            let rhsActive = rhs.interval.contains(date)
            if lhsActive != rhsActive { return lhsActive }
            if lhs.interval.start != rhs.interval.start { return lhs.interval.start < rhs.interval.start }
            return lhs.occurrenceID.uuidString < rhs.occurrenceID.uuidString
        }
        let retained = Array(ordered.prefix(Self.maximumEntryCount))
        let retainedIDs = Set(retained.map(\.occurrenceID))
        let evicted = entries.filter { !retainedIDs.contains($0.occurrenceID) }
        entries = retained
        evicted.sorted { $0.interval.start < $1.interval.start }.forEach {
            appendTombstone(for: $0, at: date)
        }
    }

    private mutating func appendTombstone(for entry: QuietTimeShieldScheduleRegistryEntry, at date: Date) {
        epoch += 1
        tombstones.removeAll { $0.occurrenceID == entry.occurrenceID }
        tombstones.append(QuietTimeShieldScheduleRegistryTombstone(
            occurrenceID: entry.occurrenceID,
            revision: entry.revision + 1,
            epoch: epoch,
            removedAt: date
        ))
        if tombstones.count > Self.maximumTombstoneCount {
            tombstones.removeFirst(tombstones.count - Self.maximumTombstoneCount)
        }
    }

    func accepts(occurrenceID: UUID, revision: Int, epoch: Int) -> Bool {
        guard let entry = entry(for: occurrenceID) else { return false }
        return entry.revision == revision && entry.epoch == epoch
    }

    func activeEntries(at date: Date) -> [QuietTimeShieldScheduleRegistryEntry] {
        entries.filter { $0.interval.contains(date) }
    }

    func nextEntry(after date: Date) -> QuietTimeShieldScheduleRegistryEntry? {
        entries.filter { $0.interval.start > date }.sorted { $0.interval.start < $1.interval.start }.first
    }
}

struct QuietTimeShieldScheduleRegistryEntry: Codable, Equatable, Identifiable {
    var id: UUID { occurrenceID }
    var occurrenceID: UUID
    var revision: Int
    var epoch: Int
    var role: QuietTimeShieldRole
    var interval: DateInterval
    var updatedAt: Date
}

struct QuietTimeShieldScheduleRegistryTombstone: Codable, Equatable, Identifiable {
    var id: UUID { occurrenceID }
    var occurrenceID: UUID
    var revision: Int
    var epoch: Int
    var removedAt: Date
}

enum QuietTimeShieldRegistryReconciliation: Equatable {
    case apply(QuietTimeShieldScheduleRegistryEntry)
    case clear
    case ignoreStale
}

enum QuietTimeShieldRegistryPolicy {
    /// A registry entry is the cross-process source of truth. A compatibility
    /// snapshot that is missing, tombstoned, or superseded must not clear a
    /// different entry which is active at the callback time.
    static func retainsActiveBarrier(
        registry: QuietTimeShieldScheduleRegistry,
        snapshotOccurrenceID: UUID?,
        at date: Date
    ) -> Bool {
        guard !registry.activeEntries(at: date).isEmpty else { return false }
        guard let snapshotOccurrenceID else { return true }
        return registry.tombstones.contains(where: { $0.occurrenceID == snapshotOccurrenceID })
            || registry.entry(for: snapshotOccurrenceID) == nil
    }

    static func reconciliation(
        registry: QuietTimeShieldScheduleRegistry,
        occurrenceID: UUID,
        revision: Int,
        epoch: Int,
        at date: Date
    ) -> QuietTimeShieldRegistryReconciliation {
        guard let entry = registry.entry(for: occurrenceID) else {
            return registry.tombstones.contains(where: { $0.occurrenceID == occurrenceID })
                ? .ignoreStale
                : .clear
        }
        guard entry.revision == revision, entry.epoch == epoch else { return .ignoreStale }
        return entry.interval.contains(date) ? .apply(entry) : .clear
    }
}

/// Stable, namespaced activity identifiers let DeviceActivity callbacks be
/// mapped back to the exact desired registry entry. Legacy static names remain
/// readable for an install that has not yet published the registry.
struct QuietTimeShieldRegistryActivity: Equatable, Hashable {
    static let prefix = "ollie.quietTime.registry"

    var occurrenceID: UUID
    var revision: Int
    var epoch: Int

    var identifier: String {
        "\(Self.prefix).\(occurrenceID.uuidString.lowercased()).r\(revision).e\(epoch)"
    }

    init(occurrenceID: UUID, revision: Int, epoch: Int) {
        self.occurrenceID = occurrenceID
        self.revision = max(1, revision)
        self.epoch = max(1, epoch)
    }

    init?(identifier: String) {
        let components = identifier.split(separator: ".")
        guard components.count == 6,
              components[0...2].joined(separator: ".") == Self.prefix,
              let occurrenceID = UUID(uuidString: String(components[3])),
              components[4].first == "r",
              components[5].first == "e",
              let revision = Int(components[4].dropFirst()),
              let epoch = Int(components[5].dropFirst()) else { return nil }
        self.init(occurrenceID: occurrenceID, revision: revision, epoch: epoch)
    }
}

struct QuietTimeShieldRegistryActivityDiff: Equatable {
    var register: Set<QuietTimeShieldRegistryActivity>
    var stop: Set<QuietTimeShieldRegistryActivity>

    static func make(
        previous: QuietTimeShieldScheduleRegistry,
        desired: QuietTimeShieldScheduleRegistry
    ) -> Self {
        let before = Set(previous.entries.map {
            QuietTimeShieldRegistryActivity(occurrenceID: $0.occurrenceID, revision: $0.revision, epoch: $0.epoch)
        })
        let after = Set(desired.entries.map {
            QuietTimeShieldRegistryActivity(occurrenceID: $0.occurrenceID, revision: $0.revision, epoch: $0.epoch)
        })
        return Self(register: after.subtracting(before), stop: before.subtracting(after))
    }
}

/// Pure fail-open cleanup decision. Removing a terminal occurrence must clear
/// the managed store only when no other desired registry window is active;
/// overlapping handoffs keep the barrier and reconcile the remaining entry.
enum QuietTimeShieldRegistryCleanupDecision: Equatable {
    case clearStore
    case keepShielded([QuietTimeShieldScheduleRegistryEntry])
}

enum QuietTimeShieldRegistryCleanupPolicy {
    static func decision(
        registry: QuietTimeShieldScheduleRegistry,
        removing occurrenceID: UUID,
        at date: Date
    ) -> QuietTimeShieldRegistryCleanupDecision {
        let remaining = registry.entries.filter {
            $0.occurrenceID != occurrenceID && $0.interval.contains(date)
        }
        return remaining.isEmpty ? .clearStore : .keepShielded(remaining)
    }

    /// Reprojects the currently active registry entry into the legacy snapshot
    /// read by older monitor/configuration paths during a multi-window
    /// handoff. The registry remains authoritative; this is a compatibility
    /// projection, never a reward store.
    static func snapshot(for entry: QuietTimeShieldScheduleRegistryEntry) -> QuietTimeShieldScheduleSnapshot {
        QuietTimeShieldScheduleSnapshot(
            runID: entry.occurrenceID,
            revision: entry.revision,
            registryRevision: entry.revision,
            registryEpoch: entry.epoch,
            role: entry.role,
            windDownInterval: nil,
            morningQuietInterval: entry.interval,
            updatedAt: entry.updatedAt
        )
    }
}

#if os(iOS) && canImport(DeviceActivity)
import DeviceActivity

extension QuietTimeShieldRegistryActivity {
    var deviceActivityName: DeviceActivityName { DeviceActivityName(identifier) }

    init?(deviceActivityName: DeviceActivityName) {
        self.init(identifier: deviceActivityName.rawValue)
    }
}
#endif
