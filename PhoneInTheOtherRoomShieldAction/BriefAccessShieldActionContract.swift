import DeviceActivity
import FamilyControls
import Foundation

enum BriefAccessShieldActionStorage {
    static let appGroupIdentifier = "group.com.ngawangchime.countingsheep"
    static let selectionKey = "ollie.screenTime.selection.bedtime"
    static let scheduleKey = "ollie.screenTime.shieldSchedule"
    static let stateKey = "ollie.screenTime.briefAccessState"
    static let restoreActivity = DeviceActivityName("ollie.quietTime.briefAccessRestore")
    static let duration: TimeInterval = 5 * 60
    static let lead: TimeInterval = 1
    static let minimumDuration: TimeInterval = 2
    static let minimumRestoreMonitoringDuration: TimeInterval = 15 * 60
}

/// ShieldAction does not compile the main-app registry source. These minimal
/// wire types intentionally decode only the identity fields needed to reject a
/// stale Brief Access grant. Their key and activity format are kept in parity
/// with `Shared/QuietTimeShieldScheduleRegistry.swift`; no selection or reward
/// data is mirrored into this extension.
enum BriefAccessShieldActionRegistryStorage {
    static let key = "ollie.screenTime.shieldScheduleRegistry"

    static func load(from defaults: UserDefaults) -> BriefAccessShieldActionRegistry {
        guard let data = defaults.data(forKey: key) else { return .empty }
        return (try? JSONDecoder().decode(BriefAccessShieldActionRegistry.self, from: data)) ?? .empty
    }
}

struct BriefAccessShieldActionRegistry: Decodable {
    static let empty = Self(entries: [], tombstones: [])

    var entries: [Entry]
    var tombstones: [Tombstone]

    func entry(for occurrenceID: UUID) -> Entry? {
        entries.first { $0.occurrenceID == occurrenceID }
    }

    func accepts(occurrenceID: UUID, revision: Int, epoch: Int) -> Bool {
        guard let entry = entry(for: occurrenceID) else { return false }
        return entry.revision == revision && entry.epoch == epoch
    }

    struct Entry: Decodable {
        var occurrenceID: UUID
        var revision: Int
        var epoch: Int
        var interval: DateInterval
    }

    struct Tombstone: Decodable {
        var occurrenceID: UUID
    }
}

struct BriefAccessShieldActionRegistryActivity: Equatable {
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

enum BriefAccessGrantStatus: String, Codable {
    case pending
    case scheduled
}

struct BriefAccessUse: Codable {
    let nonce: UUID
    let requestedAt: Date
    let expiresAt: Date
}

struct BriefAccessGrant: Codable {
    let schemaVersion: Int
    let runID: UUID
    let occurrenceID: UUID
    let scheduleRevision: Int
    let scheduleEpoch: Int
    let requestedAt: Date
    let expiresAt: Date
    let nonce: UUID
    let restoreActivityIdentifier: String
    var status: BriefAccessGrantStatus

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, runID, occurrenceID, scheduleRevision, scheduleEpoch, requestedAt, expiresAt
        case nonce, restoreActivityIdentifier, status
    }

    init(
        schemaVersion: Int,
        runID: UUID,
        occurrenceID: UUID? = nil,
        scheduleRevision: Int,
        scheduleEpoch: Int = 1,
        requestedAt: Date,
        expiresAt: Date,
        nonce: UUID,
        restoreActivityIdentifier: String,
        status: BriefAccessGrantStatus
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.occurrenceID = occurrenceID ?? runID
        self.scheduleRevision = max(1, scheduleRevision)
        self.scheduleEpoch = max(1, scheduleEpoch)
        self.requestedAt = requestedAt
        self.expiresAt = expiresAt
        self.nonce = nonce
        self.restoreActivityIdentifier = restoreActivityIdentifier
        self.status = status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let runID = try container.decode(UUID.self, forKey: .runID)
        self.init(
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1,
            runID: runID,
            occurrenceID: try container.decodeIfPresent(UUID.self, forKey: .occurrenceID) ?? runID,
            scheduleRevision: try container.decodeIfPresent(Int.self, forKey: .scheduleRevision) ?? 1,
            scheduleEpoch: try container.decodeIfPresent(Int.self, forKey: .scheduleEpoch) ?? 1,
            requestedAt: try container.decode(Date.self, forKey: .requestedAt),
            expiresAt: try container.decode(Date.self, forKey: .expiresAt),
            nonce: try container.decode(UUID.self, forKey: .nonce),
            restoreActivityIdentifier: try container.decodeIfPresent(String.self, forKey: .restoreActivityIdentifier)
                ?? "ollie.quietTime.briefAccessRestore",
            status: try container.decodeIfPresent(BriefAccessGrantStatus.self, forKey: .status) ?? .pending
        )
    }
}

struct BriefAccessLedgerEntry: Codable {
    let runID: UUID
    let successfulUseCount: Int
    let updatedAt: Date
}

struct BriefAccessShieldActionState: Codable {
    static let maximumHistoryCount = 20

    var schemaVersion: Int
    var runID: UUID
    var occurrenceID: UUID
    var scheduleRevision: Int
    var scheduleEpoch: Int
    var successfulUseCount: Int
    var successfulUses: [BriefAccessUse]
    var activeGrant: BriefAccessGrant?
    var completedRunCounts: [BriefAccessLedgerEntry]
    var rejectedGrantNonce: UUID?
    var rejectedAt: Date?
    var archivedAt: Date?
    var updatedAt: Date

    init(runID: UUID, occurrenceID: UUID? = nil, scheduleRevision: Int, scheduleEpoch: Int = 1, updatedAt: Date) {
        self.schemaVersion = 1
        self.runID = runID
        self.occurrenceID = occurrenceID ?? runID
        self.scheduleRevision = max(1, scheduleRevision)
        self.scheduleEpoch = max(1, scheduleEpoch)
        self.successfulUseCount = 0
        self.successfulUses = []
        self.activeGrant = nil
        self.completedRunCounts = []
        self.rejectedGrantNonce = nil
        self.rejectedAt = nil
        self.archivedAt = nil
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, runID, occurrenceID, scheduleRevision, scheduleEpoch, successfulUseCount
        case successfulUses, activeGrant, completedRunCounts
        case rejectedGrantNonce, rejectedAt, archivedAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        runID = try container.decode(UUID.self, forKey: .runID)
        occurrenceID = try container.decodeIfPresent(UUID.self, forKey: .occurrenceID) ?? runID
        scheduleRevision = max(1, try container.decodeIfPresent(Int.self, forKey: .scheduleRevision) ?? 1)
        scheduleEpoch = max(1, try container.decodeIfPresent(Int.self, forKey: .scheduleEpoch) ?? 1)
        successfulUseCount = max(0, try container.decodeIfPresent(Int.self, forKey: .successfulUseCount) ?? 0)
        successfulUses = try container.decodeIfPresent([BriefAccessUse].self, forKey: .successfulUses) ?? []
        successfulUseCount = max(successfulUseCount, successfulUses.count)
        activeGrant = try container.decodeIfPresent(BriefAccessGrant.self, forKey: .activeGrant)
        completedRunCounts = try container.decodeIfPresent([BriefAccessLedgerEntry].self, forKey: .completedRunCounts) ?? []
        rejectedGrantNonce = try container.decodeIfPresent(UUID.self, forKey: .rejectedGrantNonce)
        rejectedAt = try container.decodeIfPresent(Date.self, forKey: .rejectedAt)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    mutating func propose(_ grant: BriefAccessGrant, at date: Date) -> Bool {
        guard activeGrant == nil,
              grant.runID == runID,
              grant.occurrenceID == occurrenceID,
              grant.scheduleRevision == scheduleRevision,
              grant.scheduleEpoch == scheduleEpoch else { return false }
        activeGrant = grant
        rejectedGrantNonce = nil
        rejectedAt = nil
        archivedAt = nil
        updatedAt = date
        return true
    }

    mutating func markScheduled(nonce: UUID, at date: Date) -> Bool {
        guard var grant = activeGrant,
              grant.nonce == nonce,
              grant.status == .pending else { return false }
        grant.status = .scheduled
        activeGrant = grant
        successfulUseCount += 1
        successfulUses.append(
            BriefAccessUse(nonce: nonce, requestedAt: grant.requestedAt, expiresAt: grant.expiresAt)
        )
        successfulUses = Array(successfulUses.suffix(Self.maximumHistoryCount))
        rejectedGrantNonce = nil
        rejectedAt = nil
        archivedAt = nil
        updatedAt = date
        return true
    }

    mutating func rejectPendingGrant(nonce: UUID, at date: Date) {
        guard activeGrant?.nonce == nonce,
              activeGrant?.status == .pending else { return }
        activeGrant = nil
        rejectedGrantNonce = nonce
        rejectedAt = date
        updatedAt = date
    }

    mutating func rollback(nonce: UUID, at date: Date) {
        guard activeGrant?.nonce == nonce else { return }
        activeGrant = nil
        updatedAt = date
    }

    mutating func archiveCurrentRun(at date: Date) {
        if successfulUseCount > 0 {
            completedRunCounts.removeAll { $0.runID == runID }
            completedRunCounts.insert(
                BriefAccessLedgerEntry(
                    runID: runID,
                    successfulUseCount: successfulUseCount,
                    updatedAt: date
                ),
                at: 0
            )
            completedRunCounts = Array(completedRunCounts.prefix(Self.maximumHistoryCount))
        }
        activeGrant = nil
        archivedAt = date
        updatedAt = date
    }

    mutating func carryingLedgerForward(to runID: UUID, occurrenceID: UUID? = nil, revision: Int, epoch: Int = 1, at date: Date) {
        archiveCurrentRun(at: date)
        self.runID = runID
        self.occurrenceID = occurrenceID ?? runID
        scheduleRevision = max(1, revision)
        scheduleEpoch = max(1, epoch)
        successfulUseCount = 0
        successfulUses = []
        activeGrant = nil
        rejectedGrantNonce = nil
        rejectedAt = nil
        archivedAt = nil
        updatedAt = date
    }
}

struct BriefAccessRestorePlan {
    let intervalStart: Date
    let intervalEnd: Date
    let warningTime: DateComponents

    static func make(requestedAt: Date, expiresAt: Date) -> Self? {
        let intervalStart = requestedAt.addingTimeInterval(BriefAccessShieldActionStorage.lead)
        guard expiresAt > intervalStart else { return nil }
        let intervalEnd = max(
            intervalStart.addingTimeInterval(BriefAccessShieldActionStorage.minimumRestoreMonitoringDuration),
            expiresAt.addingTimeInterval(1)
        )
        let warningSeconds = max(1, Int(ceil(intervalEnd.timeIntervalSince(expiresAt))))
        return Self(
            intervalStart: intervalStart,
            intervalEnd: intervalEnd,
            warningTime: DateComponents(
                hour: warningSeconds / 3600,
                minute: (warningSeconds % 3600) / 60,
                second: warningSeconds % 60
            )
        )
    }
}

struct BriefAccessShieldActionSchedule: Codable {
    let runID: UUID
    let occurrenceID: UUID
    let revision: Int
    let epoch: Int
    let protectedSessionInterval: DateInterval?
    let windDownInterval: DateInterval?
    let morningQuietInterval: DateInterval
    let repeatsDaily: Bool

    private enum CodingKeys: String, CodingKey {
        case runID, occurrenceID, revision, epoch, protectedSessionInterval, windDownInterval, morningQuietInterval, repeatsDaily
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runID = try container.decode(UUID.self, forKey: .runID)
        occurrenceID = try container.decodeIfPresent(UUID.self, forKey: .occurrenceID) ?? runID
        revision = max(1, try container.decodeIfPresent(Int.self, forKey: .revision) ?? 1)
        epoch = max(1, try container.decodeIfPresent(Int.self, forKey: .epoch) ?? 1)
        protectedSessionInterval = try container.decodeIfPresent(DateInterval.self, forKey: .protectedSessionInterval)
        windDownInterval = try container.decodeIfPresent(DateInterval.self, forKey: .windDownInterval)
        morningQuietInterval = try container.decode(DateInterval.self, forKey: .morningQuietInterval)
        repeatsDaily = try container.decodeIfPresent(Bool.self, forKey: .repeatsDaily) ?? false
    }

    func contains(_ date: Date, in interval: DateInterval?) -> Bool {
        guard let interval else { return false }
        if !repeatsDaily { return date >= interval.start && date < interval.end }
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute, .second], from: interval.start)
        let end = calendar.dateComponents([.hour, .minute, .second], from: interval.end)
        let current = calendar.dateComponents([.hour, .minute, .second], from: date)
        let startSeconds = (start.hour ?? 0) * 3600 + (start.minute ?? 0) * 60 + (start.second ?? 0)
        let endSeconds = (end.hour ?? 0) * 3600 + (end.minute ?? 0) * 60 + (end.second ?? 0)
        let currentSeconds = (current.hour ?? 0) * 3600 + (current.minute ?? 0) * 60 + (current.second ?? 0)
        return endSeconds > startSeconds
            ? currentSeconds >= startSeconds && currentSeconds < endSeconds
            : currentSeconds >= startSeconds || currentSeconds < endSeconds
    }

    func isEligible(at date: Date) -> Bool {
        if repeatsDaily { return true }
        return date >= (protectedSessionInterval?.start ?? windDownInterval?.start ?? morningQuietInterval.start)
    }

    func isShielded(at date: Date) -> Bool {
        contains(date, in: protectedSessionInterval)
            || contains(date, in: windDownInterval)
            || contains(date, in: morningQuietInterval)
    }

    func intervalEnd(at date: Date) -> Date? {
        let intervals = [protectedSessionInterval, windDownInterval, morningQuietInterval]
        if !repeatsDaily {
            return intervals.compactMap { interval in
                guard contains(date, in: interval) else { return nil }
                return interval?.end
            }.min()
        }
        let calendar = Calendar.current
        let current = calendar.dateComponents([.hour, .minute, .second], from: date)
        let currentSeconds = (current.hour ?? 0) * 3600 + (current.minute ?? 0) * 60 + (current.second ?? 0)
        let dayStart = calendar.startOfDay(for: date)
        return intervals.compactMap { interval in
            guard let interval, contains(date, in: interval) else { return nil }
            let end = calendar.dateComponents([.hour, .minute, .second], from: interval.end)
            let endSeconds = (end.hour ?? 0) * 3600 + (end.minute ?? 0) * 60 + (end.second ?? 0)
            let endDay = calendar.date(byAdding: .day, value: endSeconds <= currentSeconds ? 1 : 0, to: dayStart) ?? dayStart
            return calendar.date(bySettingHour: end.hour ?? 0, minute: end.minute ?? 0, second: end.second ?? 0, of: endDay)
        }.min()
    }
}
