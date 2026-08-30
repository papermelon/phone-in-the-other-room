import CryptoKit
import Foundation

/// A party-scoped pending archive publication. It intentionally keeps the
/// agreement and membership epoch beside the record so a later rejoin cannot
/// reuse a former membership's authority.
struct NightFlockSharedHabitsOutboxRecord: Codable, Equatable, Identifiable, Sendable {
    var id: UUID { record.recordID }
    var record: NightFlockSharedHabitRecord
    var agreementID: UUID
    var memberEpochID: UUID
    var idempotencyKey: String
    var attemptCount: Int
    var createdAt: Date

    init(
        record: NightFlockSharedHabitRecord,
        agreementID: UUID,
        memberEpochID: UUID,
        idempotencyKey: String,
        attemptCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.record = record
        self.agreementID = agreementID
        self.memberEpochID = memberEpochID
        self.idempotencyKey = idempotencyKey
        self.attemptCount = max(0, attemptCount)
        self.createdAt = createdAt
    }

    var identity: String {
        "\(record.partyID.uuidString.lowercased()):\(agreementID.uuidString.lowercased()):\(memberEpochID.uuidString.lowercased()):\(record.sourceID?.uuidString.lowercased() ?? record.recordID.uuidString.lowercased()):\(record.kind.rawValue):\(record.revision)"
    }

    /// Revisions are transport ordering, not the source identity. Keeping the
    /// stable key separate lets a local factual correction replace an older
    /// queued revision instead of creating a permanently stale sibling.
    var logicalIdentity: String {
        "\(record.partyID.uuidString.lowercased()):\(agreementID.uuidString.lowercased()):\(memberEpochID.uuidString.lowercased()):\(record.sourceID?.uuidString.lowercased() ?? record.recordID.uuidString.lowercased()):\(record.kind.rawValue)"
    }

    /// The v1 lane does not synthesize receipt payloads, but a same-identity
    /// replacement can still arrive while an older command is in flight.
    func isExactPublication(_ other: NightFlockSharedHabitsOutboxRecord) -> Bool {
        record == other.record
            && agreementID == other.agreementID
            && memberEpochID == other.memberEpochID
            && idempotencyKey == other.idempotencyKey
    }
}

/// V2 publications retain the party agreement and membership epoch beside the
/// payload, so an offline replay can never cross a leave/rejoin boundary.
enum NightFlockSharedNightOutboxPayload: Codable, Equatable, Sendable {
    case plan(SharedNightPlan)
    case cancellation(SharedNightPlanCancellation)
    case receipt(SharedNightReceipt)
}

struct NightFlockSharedNightOutboxRecord: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    /// Local-only provenance for the primary-run privacy fence. It is never
    /// encoded into the Edge command payload.
    var originRunID: UUID?
    var payload: NightFlockSharedNightOutboxPayload
    var partyID: UUID
    var agreementID: UUID
    var memberEpochID: UUID
    var idempotencyKey: String
    var attemptCount: Int
    var createdAt: Date

    init(
        id: UUID,
        payload: NightFlockSharedNightOutboxPayload,
        partyID: UUID,
        agreementID: UUID,
        memberEpochID: UUID,
        idempotencyKey: String,
        attemptCount: Int,
        createdAt: Date,
        originRunID: UUID? = nil
    ) {
        self.id = id; self.payload = payload; self.partyID = partyID
        self.agreementID = agreementID; self.memberEpochID = memberEpochID
        self.idempotencyKey = idempotencyKey; self.attemptCount = attemptCount
        self.createdAt = createdAt; self.originRunID = originRunID
    }

    private enum CodingKeys: String, CodingKey { case id, originRunID, payload, partyID, agreementID, memberEpochID, idempotencyKey, attemptCount, createdAt }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id); originRunID = try c.decodeIfPresent(UUID.self, forKey: .originRunID)
        payload = try c.decode(NightFlockSharedNightOutboxPayload.self, forKey: .payload); partyID = try c.decode(UUID.self, forKey: .partyID)
        agreementID = try c.decode(UUID.self, forKey: .agreementID); memberEpochID = try c.decode(UUID.self, forKey: .memberEpochID)
        idempotencyKey = try c.decode(String.self, forKey: .idempotencyKey); attemptCount = try c.decode(Int.self, forKey: .attemptCount); createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encodeIfPresent(originRunID, forKey: .originRunID); try c.encode(payload, forKey: .payload)
        try c.encode(partyID, forKey: .partyID); try c.encode(agreementID, forKey: .agreementID); try c.encode(memberEpochID, forKey: .memberEpochID)
        try c.encode(idempotencyKey, forKey: .idempotencyKey); try c.encode(attemptCount, forKey: .attemptCount); try c.encode(createdAt, forKey: .createdAt)
    }

    var identity: String {
        switch payload {
        case let .plan(plan): return "plan:\(partyID.uuidString):\(memberEpochID.uuidString):\(plan.nightEndingDate.year)-\(plan.nightEndingDate.month)-\(plan.nightEndingDate.day)"
        case let .cancellation(cancellation): return "cancellation:\(partyID.uuidString):\(memberEpochID.uuidString):\(cancellation.nightEndingDate.year)-\(cancellation.nightEndingDate.month)-\(cancellation.nightEndingDate.day)"
        case let .receipt(receipt): return "receipt:\(partyID.uuidString):\(memberEpochID.uuidString):\(receipt.sourceID?.uuidString ?? receipt.receiptID.uuidString)"
        }
    }

    /// An acknowledgement is for one serialized command, not merely its
    /// logical member-night. A merge can replace that command while its older
    /// transport is still in flight.
    func isExactPublication(_ other: NightFlockSharedNightOutboxRecord) -> Bool {
        id == other.id
            && partyID == other.partyID
            && agreementID == other.agreementID
            && memberEpochID == other.memberEpochID
            && idempotencyKey == other.idempotencyKey
            && payload == other.payload
    }
}

enum NightFlockSharedNightOutboxRules {
    static func merge(_ incoming: NightFlockSharedNightOutboxRecord, into existing: [NightFlockSharedNightOutboxRecord]) -> [NightFlockSharedNightOutboxRecord]? {
        if case let .cancellation(cancellation) = incoming.payload {
            let sameNight = existing.filter {
                isSameNight($0, partyID: cancellation.partyID, memberEpochID: cancellation.memberEpochID, night: cancellation.nightEndingDate)
            }
            let retainedCancellation = sameNight.compactMap { record -> NightFlockSharedNightOutboxRecord? in
                guard case .cancellation = record.payload else { return nil }
                return record
            }.reduce(nil as NightFlockSharedNightOutboxRecord?) { current, record in
                guard let current else { return record }
                return preferredRecord(existing: current, incoming: record)
            }
            // A later privacy action removes same-night plan/receipt work, but
            // an out-of-order retry must never replace a newer cancellation's
            // idempotency identity or retry history.
            let retained = retainedCancellation.map {
                preferredRecord(existing: $0, incoming: incoming)
            } ?? incoming
            var result = existing.filter {
                !isSameNight($0, partyID: cancellation.partyID, memberEpochID: cancellation.memberEpochID, night: cancellation.nightEndingDate)
            }
            // Tombstones are privacy authority, not expendable queue work.
            // At capacity a new cancellation may displace only ordinary plan
            // or receipt work. If every slot is already a cancellation, keep
            // all existing authorities and report admission failure instead.
            while result.count >= 128 {
                guard let oldestOrdinaryIndex = result.indices
                    .filter({
                        if case .cancellation = result[$0].payload { return false }
                        return true
                    })
                    .min(by: { result[$0].createdAt < result[$1].createdAt })
                else { return nil }
                result.remove(at: oldestOrdinaryIndex)
            }
            result.append(retained)
            return result.sorted { $0.createdAt < $1.createdAt }
        }
        if let cancellation = existing.compactMap({ record -> SharedNightPlanCancellation? in
            if case let .cancellation(value) = record.payload { return value }
            return nil
        }).first(where: { cancellation in
            isSameNight(incoming, partyID: cancellation.partyID, memberEpochID: cancellation.memberEpochID, night: cancellation.nightEndingDate)
        }) {
            _ = cancellation
            return existing
        }
        let matching = existing.filter { matchesLogicalPublication($0, incoming) }
        let preferred: NightFlockSharedNightOutboxRecord
        if let first = matching.first {
            preferred = matching.dropFirst().reduce(first) { current, queued in
                preferredRecord(existing: current, incoming: queued)
            }
        } else {
            preferred = incoming
        }
        let retained = matching.isEmpty
            ? preferred
            : preferredRecord(existing: preferred, incoming: incoming)
        var result = existing.filter { !matchesLogicalPublication($0, incoming) }
        guard result.count < 128 || !matching.isEmpty else { return nil }
        result.append(retained)
        return result.sorted { $0.createdAt < $1.createdAt }
    }

    /// Offline writes can arrive out of order after a save/relaunch. Never
    /// replace a newer factual correction or plan revision with an older row.
    /// Equal revisions retain the existing row so its in-flight identity and
    /// retry history remain stable.
    private static func preferredRecord(
        existing: NightFlockSharedNightOutboxRecord,
        incoming: NightFlockSharedNightOutboxRecord
    ) -> NightFlockSharedNightOutboxRecord {
        if case let .cancellation(existingCancellation) = existing.payload,
           case let .cancellation(incomingCancellation) = incoming.payload {
            // Privacy is an explicit, terminal instruction. Unlike an
            // ordinary schedule reconciliation, it must upgrade a queued
            // schedule cancellation even when that schedule row carries a
            // higher transport revision; the server applies the same
            // authority precedence. A later schedule edit can never weaken
            // that local privacy fence.
            let selected: NightFlockSharedNightOutboxRecord
            switch (existingCancellation.authority, incomingCancellation.authority) {
            case (.privacy, .schedule):
                selected = existing
            case (.schedule, .privacy):
                selected = incoming
            default:
                let existingRevision = existingCancellation.revision
                let incomingRevision = incomingCancellation.revision
                selected = incomingRevision > existingRevision ? incoming : existing
            }

            guard selected.id == existing.id,
                  selected.payload != existing.payload || selected.idempotencyKey != existing.idempotencyKey
            else { return selected }

            // A replacement must not reuse a physical queue identity: an
            // acknowledgement from the displaced in-flight cancellation must
            // leave the selected authority intact.
            var replacement = selected
            replacement.id = UUID()
            return replacement
        }
        if case let .receipt(existingReceipt) = existing.payload,
           case let .receipt(incomingReceipt) = incoming.payload {
            let comparison = SharedNightReceiptCorrectionRules.comparison(
                candidate: SharedNightReceiptCorrectionRules.facts(for: incomingReceipt),
                candidateRevision: incomingReceipt.revision,
                existing: SharedNightReceiptCorrectionRules.facts(for: existingReceipt),
                existingRevision: existingReceipt.revision
            )
            guard comparison != 0 else { return existing }
            var retained = comparison > 0 ? incoming : existing
            let selected = retained
            var mergedReceipt = comparison > 0 ? incomingReceipt : existingReceipt
            let maximumCompetingRevision = max(existingReceipt.revision, incomingReceipt.revision)
            let mergedUnknownEmergency = mergedReceipt.emergencyExitUsed == nil
                && (comparison > 0 ? existingReceipt.emergencyExitUsed : incomingReceipt.emergencyExitUsed) != nil
            if mergedReceipt.revision < maximumCompetingRevision || mergedUnknownEmergency {
                mergedReceipt.revision = maximumCompetingRevision + 1
                let seed = mergedReceipt.sourceID ?? mergedReceipt.receiptID
                retained.idempotencyKey = NightFlockV4Idempotency.command(
                    "shared-night-receipt-\(mergedReceipt.revision)",
                    seed: seed
                )
            }
            if mergedReceipt.emergencyExitUsed == nil {
                mergedReceipt.emergencyExitUsed = comparison > 0
                    ? existingReceipt.emergencyExitUsed
                    : incomingReceipt.emergencyExitUsed
            }
            retained.payload = .receipt(mergedReceipt)
            retained.attemptCount = max(existing.attemptCount, incoming.attemptCount)
            // A promoted/hybrid receipt is a different serialized command.
            // Give it a new physical queue identity so an acknowledgement or
            // retry from the row it was derived from cannot remove or mutate
            // this replacement after a relaunch.
            if retained.payload != selected.payload || retained.idempotencyKey != selected.idempotencyKey {
                retained.id = UUID()
            }
            return retained
        }
        let existingRevision = revision(of: existing.payload)
        let incomingRevision = revision(of: incoming.payload)
        if incomingRevision > existingRevision { return incoming }
        if incomingRevision < existingRevision { return existing }
        return existing
    }

    private static func matchesLogicalPublication(
        _ lhs: NightFlockSharedNightOutboxRecord,
        _ rhs: NightFlockSharedNightOutboxRecord
    ) -> Bool {
        guard lhs.partyID == rhs.partyID, lhs.memberEpochID == rhs.memberEpochID else { return false }
        if case let .receipt(left) = lhs.payload,
           case let .receipt(right) = rhs.payload {
            return left.nightEndingDate == right.nightEndingDate
        }
        return lhs.identity == rhs.identity
    }

    private static func revision(of payload: NightFlockSharedNightOutboxPayload) -> Int64 {
        switch payload {
        case let .plan(plan): return plan.revision
        case let .cancellation(cancellation): return cancellation.revision
        case let .receipt(receipt): return receipt.revision
        }
    }

    private static func isSameNight(
        _ record: NightFlockSharedNightOutboxRecord,
        partyID: UUID,
        memberEpochID: UUID,
        night: NightFlockLocalDate
    ) -> Bool {
        guard record.partyID == partyID, record.memberEpochID == memberEpochID else { return false }
        switch record.payload {
        case let .plan(plan): return plan.nightEndingDate == night
        case let .cancellation(cancellation): return cancellation.nightEndingDate == night
        case let .receipt(receipt): return receipt.nightEndingDate == night
        }
    }

    /// A transport attempt belongs to one physical queue row. A same-night
    /// replacement must never inherit retries from an older in-flight row.
    static func markingAttempt(
        _ inFlight: NightFlockSharedNightOutboxRecord,
        in existing: [NightFlockSharedNightOutboxRecord]
    ) -> [NightFlockSharedNightOutboxRecord] {
        var result = existing
        guard let index = result.firstIndex(where: { $0.isExactPublication(inFlight) }) else { return result }
        result[index].attemptCount += 1
        return result
    }

    static func acknowledging(
        _ inFlight: NightFlockSharedNightOutboxRecord,
        in existing: [NightFlockSharedNightOutboxRecord]
    ) -> [NightFlockSharedNightOutboxRecord] {
        existing.filter { !$0.isExactPublication(inFlight) }
    }

    static func hasQueuedCancellation(
        for plan: SharedNightPlan,
        in records: [NightFlockSharedNightOutboxRecord]
    ) -> Bool {
        records.contains { record in
            guard record.partyID == plan.partyID, record.memberEpochID == plan.memberEpochID,
                  case let .cancellation(cancellation) = record.payload
            else { return false }
            return cancellation.nightEndingDate == plan.nightEndingDate
        }
    }

    static func hasNewerQueuedPlan(
        than plan: SharedNightPlan,
        in records: [NightFlockSharedNightOutboxRecord]
    ) -> Bool {
        records.contains { record in
            guard record.partyID == plan.partyID, record.memberEpochID == plan.memberEpochID,
                  case let .plan(candidate) = record.payload
            else { return false }
            return candidate.nightEndingDate == plan.nightEndingDate
                && candidate.revision > plan.revision
        }
    }

    static func shouldRecordPlanBinding(
        for inFlight: NightFlockSharedNightOutboxRecord,
        plan: SharedNightPlan,
        serverAcceptedBinding: Bool,
        in records: [NightFlockSharedNightOutboxRecord]
    ) -> Bool {
        serverAcceptedBinding
            && records.contains { $0.isExactPublication(inFlight) }
            && !hasQueuedCancellation(for: plan, in: records)
    }
}

/// A bounded local cursor for one immutable plan stream. It survives a relaunch
/// between transport acknowledgement and the next state refresh, so a newer
/// explicit save cannot accidentally reuse a published revision.
struct NightFlockSharedNightPlanRevisionLedgerEntry: Codable, Equatable, Sendable {
    var partyID: UUID
    var memberEpochID: UUID
    var nightEndingDate: NightFlockLocalDate
    var revision: Int64
    var updatedAt: Date

    var identity: String {
        "\(partyID.uuidString.lowercased()):\(memberEpochID.uuidString.lowercased()):\(nightEndingDate.year)-\(nightEndingDate.month)-\(nightEndingDate.day)"
    }
}

struct NightFlockSharedNightPlanBindingLedgerEntry: Codable, Equatable, Sendable {
    var plan: SharedNightPlan
    var updatedAt: Date
    var identity: String {
        "\(plan.partyID.uuidString.lowercased()):\(plan.memberEpochID.uuidString.lowercased()):\(plan.nightEndingDate.year)-\(plan.nightEndingDate.month)-\(plan.nightEndingDate.day)"
    }
}

enum NightFlockSharedNightPlanRevisionRules {
    static func nextRevision(
        existing: [NightFlockSharedNightPlanRevisionLedgerEntry],
        partyID: UUID,
        memberEpochID: UUID,
        nightEndingDate: NightFlockLocalDate,
        observedRevision: Int64
    ) -> Int64 {
        let identity = NightFlockSharedNightPlanRevisionLedgerEntry(partyID: partyID, memberEpochID: memberEpochID, nightEndingDate: nightEndingDate, revision: 0, updatedAt: .distantPast).identity
        return max(0, observedRevision, existing.first(where: { $0.identity == identity })?.revision ?? 0) + 1
    }

    static func merging(
        _ incoming: NightFlockSharedNightPlanRevisionLedgerEntry,
        into existing: [NightFlockSharedNightPlanRevisionLedgerEntry]
    ) -> [NightFlockSharedNightPlanRevisionLedgerEntry] {
        var values = existing.filter { $0.identity != incoming.identity }
        values.append(incoming)
        return Array(values.sorted { $0.updatedAt > $1.updatedAt }.prefix(256))
    }
}

enum NightFlockSharedHabitsOutboxRules {
    static func merge(
        _ record: NightFlockSharedHabitsOutboxRecord,
        into existing: [NightFlockSharedHabitsOutboxRecord]
    ) -> [NightFlockSharedHabitsOutboxRecord]? {
        let matching = existing.filter { $0.logicalIdentity == record.logicalIdentity }
        guard existing.count - matching.count < 128 || !matching.isEmpty else {
            return nil
        }
        let retained = matching.reduce(record) { current, queued in
            preferredRecord(existing: queued, incoming: current)
        }
        var merged = existing.filter { $0.logicalIdentity != record.logicalIdentity }
        merged.append(retained)
        return merged.sorted { $0.createdAt < $1.createdAt }
    }

    private static func preferredRecord(
        existing: NightFlockSharedHabitsOutboxRecord,
        incoming: NightFlockSharedHabitsOutboxRecord
    ) -> NightFlockSharedHabitsOutboxRecord {
        let factualComparison = compareFacts(incoming.record, existing.record)
        let selected: NightFlockSharedHabitsOutboxRecord
        if factualComparison > 0 {
            selected = incoming
        } else if factualComparison < 0 {
            selected = existing
        } else if incoming.record.revision > existing.record.revision {
            selected = incoming
        } else if incoming.record.revision < existing.record.revision {
            selected = existing
        } else {
            // Equal factual payloads retain the physical in-flight command.
            return existing
        }

        let maximumRevision = max(existing.record.revision, incoming.record.revision)
        let requiresPromotion = selected.record.revision < maximumRevision
            || (existing.record.revision == incoming.record.revision && factualComparison != 0)
        guard factualComparison != 0, requiresPromotion else {
            return selected
        }
        var promoted = selected
        promoted.record.revision = maximumRevision + 1
        promoted.record.recordID = UUID()
        let seed = promoted.record.sourceID ?? promoted.record.recordID
        promoted.idempotencyKey = NightFlockV4Idempotency.command(
            "shared-habit-\(promoted.record.partyID.uuidString)-\(promoted.agreementID.uuidString)-\(promoted.memberEpochID.uuidString)-\(promoted.record.kind.rawValue)-\(promoted.record.revision)",
            seed: seed
        )
        promoted.attemptCount = max(existing.attemptCount, incoming.attemptCount)
        return promoted
    }

    /// The legacy archive only accepts an increasing revision for a changed
    /// source. This total factual ordering makes offline merge order benign.
    private static func compareFacts(_ lhs: NightFlockSharedHabitRecord, _ rhs: NightFlockSharedHabitRecord) -> Int {
        let lhsValues = [
            lhs.minutes,
            lhs.protectionMinutes ?? 0,
            outcomeRank(lhs.outcome),
            evidenceRank(lhs.evidence)
        ]
        let rhsValues = [
            rhs.minutes,
            rhs.protectionMinutes ?? 0,
            outcomeRank(rhs.outcome),
            evidenceRank(rhs.evidence)
        ]
        for (left, right) in zip(lhsValues, rhsValues) where left != right {
            return left > right ? 1 : -1
        }
        let dateComparison = compareLocalDate(lhs.localDate, rhs.localDate)
        if dateComparison != 0 { return dateComparison }
        if lhs.timeZoneIdentifier != rhs.timeZoneIdentifier {
            return lhs.timeZoneIdentifier > rhs.timeZoneIdentifier ? 1 : -1
        }
        return 0
    }

    private static func outcomeRank(_ outcome: NightFlockSharedHabitOutcome?) -> Int {
        switch outcome { case .completed: return 2; case .partlyCompleted: return 1; case nil: return 0 }
    }

    private static func evidenceRank(_ evidence: NightFlockSharedHabitEvidence) -> Int {
        evidence == .appRecorded ? 1 : 0
    }

    private static func compareLocalDate(_ lhs: NightFlockLocalDate?, _ rhs: NightFlockLocalDate?) -> Int {
        switch (lhs, rhs) {
        case (nil, nil): return 0
        case (nil, _): return -1
        case (_, nil): return 1
        case let (left?, right?):
            let leftValues = [left.year, left.month, left.day]
            let rightValues = [right.year, right.month, right.day]
            for (value, other) in zip(leftValues, rightValues) where value != other {
                return value > other ? 1 : -1
            }
            return 0
        }
    }

    static func acknowledging(
        _ inFlight: NightFlockSharedHabitsOutboxRecord,
        in existing: [NightFlockSharedHabitsOutboxRecord]
    ) -> [NightFlockSharedHabitsOutboxRecord] {
        existing.filter { !$0.isExactPublication(inFlight) }
    }

    static func markingAttempt(
        _ inFlight: NightFlockSharedHabitsOutboxRecord,
        in existing: [NightFlockSharedHabitsOutboxRecord]
    ) -> [NightFlockSharedHabitsOutboxRecord] {
        var records = existing
        guard let index = records.firstIndex(where: { $0.isExactPublication(inFlight) }) else { return records }
        records[index].attemptCount += 1
        return records
    }
}

enum NightFlockSharedHabitsOutboxFailureDisposition: Equatable, Sendable {
    case dropSourceAndReconcile
    case dropRecordAndReconcile
    case retry
}

enum NightFlockSharedHabitsOutboxFailurePolicy {
    static func disposition(
        for code: NightFlockRemoteErrorCode?,
        detail: String? = nil
    ) -> NightFlockSharedHabitsOutboxFailureDisposition {
        if detail?.lowercased().contains("stale_revision") == true {
            return .dropRecordAndReconcile
        }
        switch code {
        case .some(.sharedHistoryDeleted):
            return .dropSourceAndReconcile
        case .some(.publicationBeforeAgreement), .some(.agreementTimezoneMismatch), .some(.staleRevision):
            // The exact stale command has already lost to the server or a
            // newer local replacement. Exact removal below cannot discard a
            // separate promoted publication that still needs to travel.
            return .dropRecordAndReconcile
        default:
            return .retry
        }
    }
}

/// A local, post-membership candidate awaiting the party's canonical agreement
/// receipt. It is never a backfill: the source began after this device already
/// observed the current party in the V4 list, and it is purged by a leave fence.
struct NightFlockSharedHabitsPendingProjection: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var partyID: UUID
    var projection: NightFlockSharedHabitProjection
    var startedAt: Date
    var sleepEligibleAfter: Date?
}

extension NightFlockSharedHabitProjection: Codable {
    private enum CodingKeys: String, CodingKey {
        case sourceID, revision, kind, localDate, timeZoneIdentifier, minutes, outcome, protectionMinutes, evidence
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sourceID: try values.decode(UUID.self, forKey: .sourceID),
            revision: try values.decode(Int64.self, forKey: .revision),
            kind: try values.decode(NightFlockSharedHabitKind.self, forKey: .kind),
            localDate: try values.decodeIfPresent(NightFlockLocalDate.self, forKey: .localDate),
            timeZoneIdentifier: try values.decode(String.self, forKey: .timeZoneIdentifier),
            minutes: try values.decode(Int.self, forKey: .minutes),
            outcome: try values.decodeIfPresent(NightFlockSharedHabitOutcome.self, forKey: .outcome),
            protectionMinutes: try values.decodeIfPresent(Int.self, forKey: .protectionMinutes),
            evidence: try values.decode(NightFlockSharedHabitEvidence.self, forKey: .evidence)
        )
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(sourceID, forKey: .sourceID)
        try values.encode(revision, forKey: .revision)
        try values.encode(kind, forKey: .kind)
        try values.encodeIfPresent(localDate, forKey: .localDate)
        try values.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
        try values.encode(minutes, forKey: .minutes)
        try values.encodeIfPresent(outcome, forKey: .outcome)
        try values.encodeIfPresent(protectionMinutes, forKey: .protectionMinutes)
        try values.encode(evidence, forKey: .evidence)
    }
}

struct NightFlockSharedHabitsAgreementAttempt: Codable, Equatable, Sendable {
    var partyID: UUID
    var memberID: UUID
    var timeZoneIdentifier: String
    var seed: UUID
}

/// A local idempotency ledger for a contributor-local sleep window. It stores
/// only derived minutes and a revision, never Health samples or intervals.
struct NightFlockSharedHabitsSleepPublicationLedger: Codable, Equatable, Sendable {
    var sourceID: UUID
    var nightEndingDate: NightFlockLocalDate
    var timeZoneIdentifier: String
    var minutes: Int
    var revision: Int64
    /// Legacy global state is retained only for decoding older local storage.
    /// v1 delivery acknowledgement is scoped to a party agreement and epoch.
    var delivered: Bool
    var deliveries: [NightFlockSharedHabitsSleepDelivery]?
}

struct NightFlockSharedHabitsSleepDelivery: Codable, Equatable, Hashable, Sendable {
    var partyID: UUID
    var agreementID: UUID
    var memberEpochID: UUID
}

enum NightFlockSharedHabitsSleepDeliveryPolicy {
    static func contains(
        _ deliveries: [NightFlockSharedHabitsSleepDelivery]?,
        partyID: UUID,
        agreementID: UUID,
        memberEpochID: UUID
    ) -> Bool {
        deliveries?.contains {
            $0.partyID == partyID
                && $0.agreementID == agreementID
                && $0.memberEpochID == memberEpochID
        } == true
    }

    static func adding(
        _ delivery: NightFlockSharedHabitsSleepDelivery,
        to deliveries: [NightFlockSharedHabitsSleepDelivery]?
    ) -> [NightFlockSharedHabitsSleepDelivery] {
        var values = deliveries ?? []
        guard !values.contains(delivery) else { return values }
        values.append(delivery)
        return values
    }

    static func resettingForNewRevision() -> [NightFlockSharedHabitsSleepDelivery] {
        []
    }
}

/// Canonical identifiers for the pre-v2 sleep-summary archive. The original
/// local implementation used raw SHA-256 bytes as a UUID. That occasionally
/// produced a UUID whose version or variant is not accepted at the wire
/// boundary. Preserve a legacy identifier that already satisfies the wire
/// UUID contract: it may already be published or tombstoned remotely. Only an
/// invalid raw value is normalized as a deterministic, UUIDv5-like value.
enum NightFlockSharedHabitsSleepIdentifierRules {
    static func sourceID(
        nightEndingDate: NightFlockLocalDate,
        timeZoneIdentifier: String
    ) -> UUID {
        let raw = legacySourceID(nightEndingDate: nightEndingDate, timeZoneIdentifier: timeZoneIdentifier)
        return isTransportSafe(raw)
            ? raw
            : normalizedCandidateSourceID(nightEndingDate: nightEndingDate, timeZoneIdentifier: timeZoneIdentifier)
    }

    static func legacySourceID(
        nightEndingDate: NightFlockLocalDate,
        timeZoneIdentifier: String
    ) -> UUID {
        uuid(from: input(nightEndingDate: nightEndingDate, timeZoneIdentifier: timeZoneIdentifier), normalize: false)
    }

    /// This was the short-lived candidate implementation's output. It is
    /// retained to repair a queue created before the compatibility correction.
    static func normalizedCandidateSourceID(
        nightEndingDate: NightFlockLocalDate,
        timeZoneIdentifier: String
    ) -> UUID {
        uuid(from: input(nightEndingDate: nightEndingDate, timeZoneIdentifier: timeZoneIdentifier), normalize: true)
    }

    static func migratedSourceID(
        _ sourceID: UUID,
        nightEndingDate: NightFlockLocalDate,
        timeZoneIdentifier: String
    ) -> UUID? {
        let raw = legacySourceID(nightEndingDate: nightEndingDate, timeZoneIdentifier: timeZoneIdentifier)
        let candidate = normalizedCandidateSourceID(nightEndingDate: nightEndingDate, timeZoneIdentifier: timeZoneIdentifier)
        guard sourceID == raw || sourceID == candidate else { return nil }
        return self.sourceID(nightEndingDate: nightEndingDate, timeZoneIdentifier: timeZoneIdentifier)
    }

    /// A v1 queue item is rekeyed only when its source exactly matches the
    /// old deterministic sleep identity. Arbitrary activity IDs therefore
    /// retain their established provenance.
    static func migratingOutboxRecords(
        _ records: [NightFlockSharedHabitsOutboxRecord]
    ) -> [NightFlockSharedHabitsOutboxRecord] {
        var selected: [String: NightFlockSharedHabitsOutboxRecord] = [:]
        for original in records {
            var record = original
            if record.record.kind == .sleep,
               let date = record.record.localDate,
               let oldSourceID = record.record.sourceID,
               let desiredSourceID = migratedSourceID(oldSourceID, nightEndingDate: date, timeZoneIdentifier: record.record.timeZoneIdentifier),
               desiredSourceID != oldSourceID {
                record.record.sourceID = desiredSourceID
                record.idempotencyKey = idempotencyKey(for: record)
            }
            if let existing = selected[record.identity] {
                selected[record.identity] = preferred(record, over: existing)
            } else {
                selected[record.identity] = record
            }
        }
        return selected.values.sorted { $0.createdAt < $1.createdAt }
    }

    static func migratingSleepLedger(
        _ entries: [NightFlockSharedHabitsSleepPublicationLedger]
    ) -> [NightFlockSharedHabitsSleepPublicationLedger] {
        var selected: [String: NightFlockSharedHabitsSleepPublicationLedger] = [:]
        for original in entries {
            var entry = original
            if let desiredSourceID = migratedSourceID(entry.sourceID, nightEndingDate: entry.nightEndingDate, timeZoneIdentifier: entry.timeZoneIdentifier),
               desiredSourceID != entry.sourceID {
                entry.sourceID = desiredSourceID
            }
            let identity = "\(entry.nightEndingDate.year)-\(entry.nightEndingDate.month)-\(entry.nightEndingDate.day):\(entry.timeZoneIdentifier)"
            if let existing = selected[identity] {
                var merged = preferred(entry, over: existing)
                merged.delivered = entry.delivered || existing.delivered
                merged.deliveries = Array(Set((entry.deliveries ?? []) + (existing.deliveries ?? [])))
                selected[identity] = merged
            } else {
                selected[identity] = entry
            }
        }
        return selected.values.sorted {
            if $0.nightEndingDate != $1.nightEndingDate { return $0.nightEndingDate < $1.nightEndingDate }
            return $0.timeZoneIdentifier < $1.timeZoneIdentifier
        }
    }

    static func migratingPendingProjections(
        _ projections: [NightFlockSharedHabitsPendingProjection]
    ) -> [NightFlockSharedHabitsPendingProjection] {
        var values: [NightFlockSharedHabitsPendingProjection] = []
        var indexByIdentity: [String: Int] = [:]
        for original in projections {
            var pending = original
            let projection = pending.projection
            if projection.kind == .sleep,
               let date = projection.localDate,
               let desiredSourceID = migratedSourceID(projection.sourceID, nightEndingDate: date, timeZoneIdentifier: projection.timeZoneIdentifier),
               desiredSourceID != projection.sourceID {
                pending.projection = NightFlockSharedHabitProjection(
                    sourceID: desiredSourceID,
                    revision: projection.revision, kind: projection.kind, localDate: projection.localDate,
                    timeZoneIdentifier: projection.timeZoneIdentifier, minutes: projection.minutes,
                    outcome: projection.outcome, protectionMinutes: projection.protectionMinutes,
                    evidence: projection.evidence
                )
            }
            let identity = "\(pending.partyID.uuidString.lowercased()):\(pending.projection.sourceID.uuidString.lowercased()):\(pending.projection.kind.rawValue):\(pending.projection.revision)"
            if let index = indexByIdentity[identity] {
                if pending.startedAt >= values[index].startedAt { values[index] = pending }
            } else {
                indexByIdentity[identity] = values.count
                values.append(pending)
            }
        }
        return values
    }

    static func idempotencyKey(for record: NightFlockSharedHabitsOutboxRecord) -> String {
        NightFlockV4Idempotency.command(
            "shared-habit-\(record.record.partyID.uuidString)-\(record.agreementID.uuidString)-\(record.memberEpochID.uuidString)-\(record.record.kind.rawValue)-\(record.record.revision)",
            seed: record.record.sourceID ?? record.record.recordID
        )
    }

    private static func preferred(
        _ lhs: NightFlockSharedHabitsOutboxRecord,
        over rhs: NightFlockSharedHabitsOutboxRecord
    ) -> NightFlockSharedHabitsOutboxRecord {
        if lhs.record.revision != rhs.record.revision { return lhs.record.revision > rhs.record.revision ? lhs : rhs }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt ? lhs : rhs }
        return lhs.attemptCount >= rhs.attemptCount ? lhs : rhs
    }

    private static func preferred(
        _ lhs: NightFlockSharedHabitsSleepPublicationLedger,
        over rhs: NightFlockSharedHabitsSleepPublicationLedger
    ) -> NightFlockSharedHabitsSleepPublicationLedger {
        if lhs.revision != rhs.revision { return lhs.revision > rhs.revision ? lhs : rhs }
        return (lhs.deliveries?.count ?? 0) >= (rhs.deliveries?.count ?? 0) ? lhs : rhs
    }

    private static func input(nightEndingDate: NightFlockLocalDate, timeZoneIdentifier: String) -> String {
        "shared-habits-sleep-v1:\(nightEndingDate.year)-\(nightEndingDate.month)-\(nightEndingDate.day):\(timeZoneIdentifier)"
    }

    private static func isTransportSafe(_ sourceID: UUID) -> Bool {
        let bytes = sourceID.uuid
        return (1...5).contains(Int(bytes.6 >> 4)) && (bytes.8 & 0xC0) == 0x80
    }

    private static func uuid(from input: String, normalize: Bool) -> UUID {
        let bytes = Array(SHA256.hash(data: Data(input.utf8)))
        var tuple = uuid_t(bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
        if normalize {
            tuple.6 = (tuple.6 & 0x0F) | 0x50
            tuple.8 = (tuple.8 & 0x3F) | 0x80
        }
        return UUID(uuid: tuple)
    }
}

/// The person has read the single joining agreement before an invitation or
/// party creation travels. The server receipt is saved only after membership.
struct NightFlockSharedHabitsJoinAgreementIntent: Codable, Equatable, Sendable {
    var commandID: UUID
    var partyID: UUID?
    var timeZoneIdentifier: String
    var createdAt: Date
}

enum NightFlockSharedHabitsJoinAgreementIntentPolicy {
    /// A pre-join disclosure can only become a receipt attempt for the exact
    /// create/redeem command that produced this canonical party.
    static func resolving(
        _ intent: NightFlockSharedHabitsJoinAgreementIntent?,
        commandID: UUID,
        partyID: UUID
    ) -> NightFlockSharedHabitsJoinAgreementIntent? {
        guard var intent, intent.commandID == commandID else { return nil }
        intent.partyID = partyID
        return intent
    }

    static func permitsResume(
        _ intent: NightFlockSharedHabitsJoinAgreementIntent?,
        partyID: UUID,
        isCurrentMember: Bool,
        hasCurrentMemberDetail: Bool,
        agreementIsMissing: Bool
    ) -> Bool {
        intent?.partyID == partyID
            && isCurrentMember
            && hasCurrentMemberDetail
            && agreementIsMissing
    }
}

/// Minimal local pointer so a former member can request deletion without
/// rejoining or reopening retained archive data on this device.
struct NightFlockSharedHabitsFormerParty: Codable, Equatable, Identifiable, Sendable {
    var id: UUID { partyID }
    var partyID: UUID
    var leftAt: Date
}
