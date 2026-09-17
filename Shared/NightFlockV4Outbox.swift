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
    /// Set only for a live delivery after the canonical list response has
    /// advertised membership sharing. Backfill deliberately remains nil.
    var sharingScope: NightFlockV4SharingScope?

    init(source: NightFlockV4SourceActivityRecord, origin: NightFlockV4OutboxOrigin, idempotencyKey: String, attemptCount: Int = 0, createdAt: Date = Date(), sharingScope: NightFlockV4SharingScope? = nil) {
        self.source = source
        self.origin = origin
        self.idempotencyKey = idempotencyKey
        self.attemptCount = max(0, attemptCount)
        self.createdAt = createdAt
        self.sharingScope = origin == .live ? sharingScope : nil
    }

    func publishing(toMembershipStream: Bool) -> Self {
        var copy = self
        guard origin == .live, toMembershipStream else {
            copy.sharingScope = nil
            return copy
        }
        // A response may be lost while the backend gains or loses the
        // capability. Scope gets its own deterministic transport key, so a
        // retry never reuses an old payload hash under the same idempotency
        // key. The server still deduplicates the factual source event.
        copy.sharingScope = .membership
        copy.idempotencyKey = NightFlockV4Idempotency.command(
            "membership-activity-\(source.kind.rawValue)",
            seed: source.sourceEventID
        )
        return copy
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
    /// Local-only primary-run privacy provenance. Legacy rows decode as nil.
    var requiresPrimaryRunDecision: Bool?
    var originStartedAt: Date?

    var identity: NightFlockV4StatusOutboxIdentity {
        NightFlockV4StatusOutboxIdentity(
            sourceEventID: sourceEventID,
            revision: revision,
            idempotencyKey: idempotencyKey
        )
    }

    init(
        sourceEventID: UUID,
        status: NightFlockV4LiveStatusKind,
        revision: Int,
        observedAt: Date,
        idempotencyKey: String,
        attemptCount: Int = 0,
        requiresPrimaryRunDecision: Bool? = nil,
        originStartedAt: Date? = nil
    ) {
        self.sourceEventID = sourceEventID
        self.status = status
        self.revision = max(0, revision)
        self.observedAt = observedAt
        self.idempotencyKey = idempotencyKey
        self.attemptCount = max(0, attemptCount)
        self.requiresPrimaryRunDecision = requiresPrimaryRunDecision
        self.originStartedAt = originStartedAt
    }

    private enum CodingKeys: String, CodingKey { case sourceEventID, status, revision, observedAt, idempotencyKey, attemptCount, requiresPrimaryRunDecision, originStartedAt }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sourceEventID = try c.decode(UUID.self, forKey: .sourceEventID); status = try c.decode(NightFlockV4LiveStatusKind.self, forKey: .status)
        revision = max(0, try c.decode(Int.self, forKey: .revision)); observedAt = try c.decode(Date.self, forKey: .observedAt)
        idempotencyKey = try c.decode(String.self, forKey: .idempotencyKey); attemptCount = max(0, try c.decodeIfPresent(Int.self, forKey: .attemptCount) ?? 0)
        requiresPrimaryRunDecision = try c.decodeIfPresent(Bool.self, forKey: .requiresPrimaryRunDecision)
        originStartedAt = try c.decodeIfPresent(Date.self, forKey: .originStartedAt)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sourceEventID, forKey: .sourceEventID); try c.encode(status, forKey: .status); try c.encode(revision, forKey: .revision)
        try c.encode(observedAt, forKey: .observedAt); try c.encode(idempotencyKey, forKey: .idempotencyKey); try c.encode(attemptCount, forKey: .attemptCount)
        try c.encodeIfPresent(requiresPrimaryRunDecision, forKey: .requiresPrimaryRunDecision); try c.encodeIfPresent(originStartedAt, forKey: .originStartedAt)
    }
}

/// A response may arrive after a newer status for the same source has replaced
/// it in the durable queue. Source ID alone is therefore not an acknowledgement
/// identity.
struct NightFlockV4StatusOutboxIdentity: Equatable, Sendable {
    let sourceEventID: UUID
    let revision: Int
    let idempotencyKey: String
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
            if incoming.revision > old.revision
                || (incoming.revision == old.revision && incoming.observedAt > old.observedAt) {
                records[index] = incoming
            }
        } else {
            records.append(incoming)
        }
        return Array(records.sorted { $0.observedAt < $1.observedAt }.suffix(NightFlockV4Rules.maximumOutboxSources))
    }
}

/// The one-shot sharing choice belongs to the run admitted now. The caller
/// captures it before the view model restores the default for a later run.
enum NightFlockPrimaryRunSharingHandoffRules {
    static func capturedShareSelection(_ selected: Bool) -> Bool { selected }

    /// An asynchronous admission must not read the mutable one-shot control a
    /// second time. The durable decision is the source of truth for its exact
    /// continuation, including automatic Wind Down.
    static func selectionForStagedContinuation(
        decision: NightFlockPrimaryRunSharingDecision?,
        fallbackSelection: Bool
    ) -> Bool {
        decision?.allowsSharing ?? fallbackSelection
    }
}

/// Coordinator admission may synchronously report timer/NFC validation before
/// the caller has had a chance to persist the primary run's one-shot sharing
/// choice.  Deferring only that narrow interval keeps the decision durable
/// before any social status is constructed, while ordinary Phone Away and
/// later placement confirmations continue to publish immediately.
enum NightFlockPrimaryRunValidationAdmissionRules {
    static func shouldDeferValidation(
        isPrimaryWindDown: Bool,
        sharingAdmissionIsPending: Bool
    ) -> Bool {
        isPrimaryWindDown && sharingAdmissionIsPending
    }

    static func shouldPublishValidatedStatusAfterAdmission(
        sharesRun: Bool,
        wasValidatedDuringAdmission: Bool
    ) -> Bool {
        sharesRun && wasValidatedDuringAdmission
    }
}

/// A durable primary-run choice fences every social publication associated
/// with that run. `requiredAfter` is installed once per device so records from
/// before this capability retain their explicit compatibility behavior.
struct NightFlockPrimaryRunSharingDecision: Codable, Equatable, Sendable, Identifiable {
    var runID: UUID
    var allowsSharing: Bool
    var capturedAt: Date
    var id: UUID { runID }
}

enum NightFlockPrimaryRunSharingDecisionRules {
    /// A run ID is an admission identity, not a preference slot. Once staged,
    /// its choice is immutable so a relaunch cannot replace "private" with
    /// the current default before automatic reconciliation resumes.
    static func durableDecision(
        incoming: NightFlockPrimaryRunSharingDecision,
        existing: NightFlockPrimaryRunSharingDecision?
    ) -> NightFlockPrimaryRunSharingDecision {
        existing?.runID == incoming.runID ? existing! : incoming
    }
}

enum NightFlockPrimaryRunSharingPolicy {
    static func mayShare(
        runID: UUID,
        startedAt: Date,
        decision: NightFlockPrimaryRunSharingDecision?,
        requiredAfter: Date?
    ) -> Bool {
        if let decision, decision.runID == runID { return decision.allowsSharing }
        // A missing policy marker is never evidence of consent for a new run.
        guard let requiredAfter else { return false }
        return startedAt < requiredAfter
    }
}

enum NightFlockPrimaryRunStatusPublicationRules {
    static func mayShare(
        requiresPrimaryRunDecision: Bool?,
        runID: UUID,
        originStartedAt: Date?,
        observedAt: Date,
        decision: NightFlockPrimaryRunSharingDecision?,
        requiredAfter: Date?
    ) -> Bool {
        switch requiresPrimaryRunDecision {
        case false: return true
        case true:
            return NightFlockPrimaryRunSharingPolicy.mayShare(
                runID: runID, startedAt: originStartedAt ?? observedAt,
                decision: decision, requiredAfter: requiredAfter
            )
        case nil:
            return NightFlockPrimaryRunSharingPolicy.mayShare(
                runID: runID, startedAt: observedAt,
                decision: nil, requiredAfter: requiredAfter
            )
        }
    }
}

enum SharedNightEmergencyExitPresentationRules {
    static func emergencyExitUsed(
        completedSuccessfully: Bool,
        endedEarlyReason: EarlyEndReason?
    ) -> Bool? {
        if endedEarlyReason == .emergencyBypass { return true }
        if completedSuccessfully || endedEarlyReason != nil { return false }
        return nil
    }
}
