import Foundation

/// The iPhone records one stable source event. The server, not the client, derives every
/// eligible party/round fan-out and its grants from this identifier.
struct NightFlockV4SourceActivityRecord: Codable, Equatable, Sendable {
    var sourceEventID: UUID
    var kind: NightFlockV4ActivityKind
    var outcome: NightFlockV4ActivityStatus
    var startedAt: Date
    var endedAt: Date
    var windDownMinutes: Int
    var phoneAwayMinutes: Int
    var statusRevision: Int

    init(sourceEventID: UUID, kind: NightFlockV4ActivityKind, outcome: NightFlockV4ActivityStatus, startedAt: Date, endedAt: Date, windDownMinutes: Int, phoneAwayMinutes: Int, statusRevision: Int) {
        self.sourceEventID = sourceEventID
        self.kind = kind
        self.outcome = outcome
        self.startedAt = startedAt
        self.endedAt = max(endedAt, startedAt)
        self.windDownMinutes = max(0, windDownMinutes)
        self.phoneAwayMinutes = max(0, phoneAwayMinutes)
        self.statusRevision = max(0, statusRevision)
    }
}

enum NightFlockV4OutboxOrigin: String, Codable, Sendable { case live, backfill }

struct NightFlockV4OutboxSourceRecord: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { source.sourceEventID }
    var source: NightFlockV4SourceActivityRecord
    var origin: NightFlockV4OutboxOrigin
    var idempotencyKey: String
    var attemptCount: Int
    var createdAt: Date

    init(source: NightFlockV4SourceActivityRecord, origin: NightFlockV4OutboxOrigin, idempotencyKey: String, attemptCount: Int = 0, createdAt: Date = Date()) {
        self.source = source
        self.origin = origin
        self.idempotencyKey = idempotencyKey
        self.attemptCount = max(0, attemptCount)
        self.createdAt = createdAt
    }
}

/// Transient status is still queued briefly so a momentary transport loss does
/// not erase an otherwise useful social signal. The server expiry remains the
/// authority; this is not a second activity ledger.
struct NightFlockV4StatusOutboxRecord: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { sourceEventID }
    var sourceEventID: UUID
    var status: NightFlockV4LiveStatusKind
    var revision: Int
    var observedAt: Date
    var idempotencyKey: String
    var attemptCount: Int

    init(
        sourceEventID: UUID,
        status: NightFlockV4LiveStatusKind,
        revision: Int,
        observedAt: Date,
        idempotencyKey: String,
        attemptCount: Int = 0
    ) {
        self.sourceEventID = sourceEventID
        self.status = status
        self.revision = max(0, revision)
        self.observedAt = observedAt
        self.idempotencyKey = idempotencyKey
        self.attemptCount = max(0, attemptCount)
    }
}

enum NightFlockV4OutboxRules {
    static func merge(_ incoming: NightFlockV4OutboxSourceRecord, into existing: [NightFlockV4OutboxSourceRecord]) -> [NightFlockV4OutboxSourceRecord] {
        var result = existing
        if let index = result.firstIndex(where: {
            $0.source.sourceEventID == incoming.source.sourceEventID && $0.source.kind == incoming.source.kind
        }) {
            var merged = result[index]
            let preferred = preferred(existing: merged, incoming: incoming)
            merged.source = preferred.source
            merged.origin = preferred.origin
            merged.idempotencyKey = preferred.idempotencyKey
            merged.attemptCount = max(merged.attemptCount, incoming.attemptCount)
            result[index] = merged
        } else {
            result.append(incoming)
        }
        return Array(result.sorted { $0.createdAt < $1.createdAt }.suffix(NightFlockV4Rules.maximumOutboxSources))
    }

    private static func preferred(existing: NightFlockV4OutboxSourceRecord, incoming: NightFlockV4OutboxSourceRecord) -> NightFlockV4OutboxSourceRecord {
        if incoming.source.statusRevision > existing.source.statusRevision { return incoming }
        if incoming.source.statusRevision < existing.source.statusRevision { return existing }
        if incoming.origin == .live && existing.origin == .backfill { return incoming }
        if incoming.source.endedAt > existing.source.endedAt { return incoming }
        return existing
    }
}

enum NightFlockV4StatusOutboxRules {
    static func merge(
        _ incoming: NightFlockV4StatusOutboxRecord,
        into existing: [NightFlockV4StatusOutboxRecord]
    ) -> [NightFlockV4StatusOutboxRecord] {
        var records = existing
        if let index = records.firstIndex(where: { $0.sourceEventID == incoming.sourceEventID }) {
            let old = records[index]
            if incoming.revision >= old.revision || incoming.observedAt > old.observedAt {
                records[index] = incoming
            }
        } else {
            records.append(incoming)
        }
        return Array(records.sorted { $0.observedAt < $1.observedAt }.suffix(NightFlockV4Rules.maximumOutboxSources))
    }
}
