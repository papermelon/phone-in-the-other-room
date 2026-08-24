import Foundation

enum RitualEvidenceSource: String, Codable, Equatable {
    case observed
    case inferred
    case selfReported
    case system
}

enum RitualEventKind: String, Codable, Equatable {
    case sessionStarted
    case placementConfirmed
    case placementValidationFailed
    case fallbackSelected
    case shieldScheduleRequested
    case shieldApplied
    case shieldActivationFailed
    case shieldCleared
    case sessionCompleted
    case sessionEndedEarly
    case morningReflectionSaved
    case healthOutcomeLinked
}

struct RitualEvent: Codable, Identifiable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    let id: UUID
    let runID: UUID
    let occurredAt: Date
    let recordedAt: Date
    let kind: RitualEventKind
    let source: RitualEvidenceSource
    let idempotencyKey: String?
    let payload: [String: String]

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID = UUID(),
        runID: UUID,
        occurredAt: Date = Date(),
        recordedAt: Date = Date(),
        kind: RitualEventKind,
        source: RitualEvidenceSource,
        idempotencyKey: String? = nil,
        payload: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.runID = runID
        self.occurredAt = occurredAt
        self.recordedAt = recordedAt
        self.kind = kind
        self.source = source
        self.idempotencyKey = idempotencyKey
        self.payload = payload
    }
}

enum NightWatchOutcome: String, Codable, Equatable {
    case active
    case completed
    case endedEarly
}

enum ShieldProtectionEvidence: String, Codable, Equatable {
    case notRequested
    case unavailable
    case partial
    case observed
}

struct NightWatchRecord: Codable, Identifiable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    let id: UUID
    let plan: NightWatchPlan
    let startedAt: Date
    var endedAt: Date?
    let startMethod: SessionGuardKind
    var outcome: NightWatchOutcome
    var creditedWindDownMinutes: Int
    var creditedMorningQuietMinutes: Int
    var shieldedWindDownMinutes: Int
    var shieldedMorningQuietMinutes: Int
    var shieldProtectionEvidence: ShieldProtectionEvidence
    var briefAccessUseCount: Int
    var role: WindDownOccurrenceRole
    var updatedAt: Date

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID,
        plan: NightWatchPlan,
        startedAt: Date,
        endedAt: Date? = nil,
        startMethod: SessionGuardKind,
        outcome: NightWatchOutcome = .active,
        creditedWindDownMinutes: Int = 0,
        creditedMorningQuietMinutes: Int = 0,
        shieldedWindDownMinutes: Int = 0,
        shieldedMorningQuietMinutes: Int = 0,
        shieldProtectionEvidence: ShieldProtectionEvidence = .notRequested,
        briefAccessUseCount: Int = 0,
        role: WindDownOccurrenceRole = .primarySleepBookend,
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.plan = plan
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.startMethod = startMethod
        self.outcome = outcome
        self.creditedWindDownMinutes = max(0, creditedWindDownMinutes)
        self.creditedMorningQuietMinutes = max(0, creditedMorningQuietMinutes)
        self.shieldedWindDownMinutes = max(0, shieldedWindDownMinutes)
        self.shieldedMorningQuietMinutes = max(0, shieldedMorningQuietMinutes)
        self.shieldProtectionEvidence = shieldProtectionEvidence
        self.briefAccessUseCount = max(0, briefAccessUseCount)
        self.role = role
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case plan
        case startedAt
        case endedAt
        case startMethod
        case outcome
        case creditedWindDownMinutes
        case creditedMorningQuietMinutes
        case shieldedWindDownMinutes
        case shieldedMorningQuietMinutes
        case shieldProtectionEvidence
        case briefAccessUseCount
        case role
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.currentSchemaVersion
        id = try container.decode(UUID.self, forKey: .id)
        plan = try container.decode(NightWatchPlan.self, forKey: .plan)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        startMethod = try container.decode(SessionGuardKind.self, forKey: .startMethod)
        outcome = try container.decodeIfPresent(NightWatchOutcome.self, forKey: .outcome) ?? .active
        creditedWindDownMinutes = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .creditedWindDownMinutes) ?? 0
        )
        creditedMorningQuietMinutes = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .creditedMorningQuietMinutes) ?? 0
        )
        shieldedWindDownMinutes = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .shieldedWindDownMinutes) ?? 0
        )
        shieldedMorningQuietMinutes = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .shieldedMorningQuietMinutes) ?? 0
        )
        shieldProtectionEvidence = try container.decodeIfPresent(
            ShieldProtectionEvidence.self,
            forKey: .shieldProtectionEvidence
        ) ?? .notRequested
        briefAccessUseCount = max(0, try container.decodeIfPresent(Int.self, forKey: .briefAccessUseCount) ?? 0)
        role = try container.decodeIfPresent(WindDownOccurrenceRole.self, forKey: .role)
            ?? .primarySleepBookend
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
            ?? endedAt
            ?? startedAt
    }
}

struct NightWatchHistory: Codable, Equatable {
    static let retentionDays = 90

    private(set) var records: [NightWatchRecord]
    private(set) var events: [RitualEvent]

    init(
        records: [NightWatchRecord] = [],
        events: [RitualEvent] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.records = records
        self.events = events
        normalize(now: now, calendar: calendar)
    }

    mutating func upsert(
        _ record: NightWatchRecord,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        records.removeAll { $0.id == record.id }
        records.append(record)
        normalize(now: now, calendar: calendar)
    }

    mutating func append(
        _ event: RitualEvent,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        if events.contains(where: { existing in
            existing.id == event.id
                || (event.idempotencyKey != nil && existing.idempotencyKey == event.idempotencyKey)
        }) {
            return
        }
        events.append(event)
        normalize(now: now, calendar: calendar)
    }

    func record(for runID: UUID) -> NightWatchRecord? {
        records.first { $0.id == runID }
    }

    func events(for runID: UUID) -> [RitualEvent] {
        events
            .filter { $0.runID == runID }
            .sorted { $0.occurredAt < $1.occurredAt }
    }

    mutating func removeAll() {
        records = []
        events = []
    }

    private mutating func normalize(now: Date, calendar: Calendar) {
        let cutoff = calendar.date(
            byAdding: .day,
            value: -Self.retentionDays,
            to: now
        ) ?? now.addingTimeInterval(TimeInterval(-Self.retentionDays * 24 * 60 * 60))

        var uniqueRecords: [UUID: NightWatchRecord] = [:]
        for record in records where record.updatedAt >= cutoff {
            if let existing = uniqueRecords[record.id], existing.updatedAt > record.updatedAt {
                continue
            }
            uniqueRecords[record.id] = record
        }
        records = uniqueRecords.values.sorted { $0.startedAt > $1.startedAt }

        var seenEventIDs = Set<UUID>()
        var seenIdempotencyKeys = Set<String>()
        events = events
            .filter { $0.recordedAt >= cutoff }
            .sorted { $0.occurredAt < $1.occurredAt }
            .filter { event in
                guard seenEventIDs.insert(event.id).inserted else { return false }
                guard let key = event.idempotencyKey else { return true }
                return seenIdempotencyKeys.insert(key).inserted
            }
    }
}

extension FocusRun {
    func nightWatchRecord(
        updatedAt: Date = Date(),
        shieldedWindDownMinutes: Int = 0,
        shieldedMorningQuietMinutes: Int = 0,
        shieldProtectionEvidence: ShieldProtectionEvidence = .notRequested,
        briefAccessUseCount: Int? = nil
    ) -> NightWatchRecord? {
        guard let nightWatchPlan else { return nil }
        let outcome: NightWatchOutcome
        switch state {
        case .completed:
            outcome = .completed
        case .endedEarly:
            outcome = .endedEarly
        default:
            outcome = .active
        }
        return NightWatchRecord(
            id: id,
            plan: nightWatchPlan,
            startedAt: startedAt,
            endedAt: endedAt,
            startMethod: guardKind,
            outcome: outcome,
            creditedWindDownMinutes: outcome == .active ? 0 : creditedWindDownMinutes,
            // New Screen-Free Morning occurrences are journaled and presented
            // independently. Keep this compatibility Wind Down record from
            // claiming those minutes a second time; legacy decoded records are
            // preserved as stored.
            creditedMorningQuietMinutes: outcome == .active || nightWatchPlan.role == .primarySleepBookend
                ? 0 : creditedMorningQuietMinutes,
            shieldedWindDownMinutes: shieldedWindDownMinutes,
            shieldedMorningQuietMinutes: shieldedMorningQuietMinutes,
            shieldProtectionEvidence: shieldProtectionEvidence,
            briefAccessUseCount: max(self.briefAccessUseCount, briefAccessUseCount ?? 0),
            role: nightWatchPlan.role,
            updatedAt: updatedAt
        )
    }
}
