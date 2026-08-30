import CryptoKit
import Foundation

/// The app captures this before a long Health query. A result may travel only
/// while the same account and privacy-fence authority still own the request.
struct NightFlockSharedHabitSleepReconciliationAuthority: Equatable, Sendable {
    var socialGeneration: UInt64
    var fenceGeneration: UInt64
    var reconcileGeneration: UInt
    var accountIsLinked: Bool
    var supportsSharedHabits: Bool
}

struct NightFlockPrimaryNightSharingEvidence: Equatable, Sendable {
    var nightEndingDate: NightFlockLocalDate
    var timeZoneIdentifier: String
    var mayShare: Bool
}

enum NightFlockPrimaryRunAdmissionRules {
    static func mayAdmit(sharingDecisionStaged: Bool, transactionIsCurrent: Bool) -> Bool {
        sharingDecisionStaged && transactionIsCurrent
    }

    /// Only the continuation that owns the already-staged run may enter while
    /// an admission is in flight. New taps stay out until that continuation
    /// finishes, so staging cannot turn into a second coordinator start.
    static func mayEnterStart(
        isStartInFlight: Bool,
        hasVerifiedStagedRun: Bool
    ) -> Bool {
        hasVerifiedStagedRun ? isStartInFlight : !isStartInFlight
    }

    static func mayMaterializeAutomaticRun(
        stagedDecision: NightFlockPrimaryRunSharingDecision?
    ) -> Bool {
        stagedDecision != nil
    }
}

/// Selects the local primary records whose explicit private choice must be
/// replayed as a plan fence after a relaunch. The transport itself remains
/// idempotent; this rule only makes the crash-recovery source deterministic.
enum NightFlockPrimaryRunPrivacyRecoveryRules {
    static func recordsNeedingPlanFence(
        from records: [NightWatchRecord],
        decisions: [UUID: NightFlockPrimaryRunSharingDecision]
    ) -> [NightWatchRecord] {
        let recordsByID = Dictionary(grouping: records, by: \.id).compactMapValues { versions in
            versions.max { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
                return (lhs.endedAt ?? .distantPast) < (rhs.endedAt ?? .distantPast)
            }
        }
        return decisions.values.compactMap { decision in
            guard decision.allowsSharing == false,
                  let record = recordsByID[decision.runID],
                  record.plan.role == .primarySleepBookend
            else { return nil }
            return record
        }
        .sorted { $0.id.uuidString < $1.id.uuidString }
    }
}

/// Delayed social authority must not lose an already-terminal, explicitly
/// shared primary run. This selects only modern records with an affirmative
/// durable decision, then keeps the factual winner for each local night.
enum NightFlockPrimaryRunTerminalReplayRules {
    static func recordsEligibleForReplay(
        from records: [NightWatchRecord],
        decisions: [UUID: NightFlockPrimaryRunSharingDecision]
    ) -> [NightWatchRecord] {
        let eligible = records.filter { record in
            guard record.role == .primarySleepBookend,
                  record.outcome != .active,
                  record.isPractice == false,
                  decisions[record.id]?.allowsSharing == true
            else { return false }
            return true
        }
        let grouped = Dictionary(grouping: eligible) { record -> String in
            guard let anchor = record.plan.localDateAnchor else { return record.id.uuidString }
            return "\(anchor.timeZoneIdentifier):\(anchor.nightEndingDate.year)-\(anchor.nightEndingDate.month)-\(anchor.nightEndingDate.day)"
        }
        return grouped.values.compactMap { candidates in
            guard let first = candidates.first,
                  let anchor = first.plan.localDateAnchor
            else { return candidates.max(by: SharedNightReceiptRules.isWorse) }
            return SharedNightReceiptRules.winner(
                from: candidates,
                nightEndingDate: anchor.nightEndingDate,
                timeZoneIdentifier: anchor.timeZoneIdentifier
            )
        }
        .sorted { lhs, rhs in
            if lhs.startedAt != rhs.startedAt { return lhs.startedAt < rhs.startedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

enum NightFlockSharedHabitSleepReconciliationPolicy {
    static func permitsResult(
        captured: NightFlockSharedHabitSleepReconciliationAuthority,
        current: NightFlockSharedHabitSleepReconciliationAuthority,
        taskIsCancelled: Bool,
        hasActiveRun: Bool
    ) -> Bool {
        captured == current && !taskIsCancelled && !hasActiveRun
    }

    static func permitsPartySleepPublication(
        projectionTimeZoneIdentifier: String,
        receiptTimeZoneIdentifier: String
    ) -> Bool {
        projectionTimeZoneIdentifier == receiptTimeZoneIdentifier
    }

    /// Health-derived sleep summaries never bypass a primary run's explicit
    /// privacy choice. No matching primary run remains shareable, including
    /// ordinary legacy windows with no local run record.
    static func permitsSleepWindow(
        nightEndingDate: NightFlockLocalDate,
        timeZoneIdentifier: String,
        primaryRuns: [NightFlockPrimaryNightSharingEvidence]
    ) -> Bool {
        !primaryRuns.contains {
            $0.nightEndingDate == nightEndingDate
                && $0.timeZoneIdentifier == timeZoneIdentifier
                && !$0.mayShare
        }
    }
}

/// The locally derived values that may later be mapped to the separately
/// versioned shared-habits wire record. They intentionally omit schedules,
/// raw Health samples, app selections, and private routine content.
enum NightFlockSharedHabitKind: String, Codable, CaseIterable, Sendable {
    case sleep
    case windDown
    case phoneAway
}

enum NightFlockSharedHabitOutcome: String, Codable, Sendable {
    case completed
    case partlyCompleted
}

enum NightFlockSharedHabitEvidence: String, Codable, Sendable {
    case none
    case appRecorded
}

struct NightFlockSharedHabitProjection: Equatable, Sendable, Identifiable {
    let sourceID: UUID
    let revision: Int64
    let kind: NightFlockSharedHabitKind
    /// Nil is permitted only for retained legacy activity, never nightly stats.
    let localDate: NightFlockLocalDate?
    let timeZoneIdentifier: String
    let minutes: Int
    let outcome: NightFlockSharedHabitOutcome?
    let protectionMinutes: Int?
    let evidence: NightFlockSharedHabitEvidence

    var id: UUID { sourceID }

    init(
        sourceID: UUID,
        revision: Int64,
        kind: NightFlockSharedHabitKind,
        localDate: NightFlockLocalDate?,
        timeZoneIdentifier: String,
        minutes: Int,
        outcome: NightFlockSharedHabitOutcome? = nil,
        protectionMinutes: Int? = nil,
        evidence: NightFlockSharedHabitEvidence = .none
    ) {
        self.sourceID = sourceID
        self.revision = max(0, revision)
        self.kind = kind
        self.localDate = localDate
        self.timeZoneIdentifier = timeZoneIdentifier
        let boundedMinutes = max(0, minutes)
        self.minutes = boundedMinutes
        self.outcome = outcome
        self.evidence = evidence
        self.protectionMinutes = evidence == .appRecorded
            ? protectionMinutes.map { max(0, min($0, boundedMinutes)) }
            : nil
    }
}

enum NightFlockSharedHabitPeriod: Int, CaseIterable, Sendable {
    case lastNight = 1
    case last7Nights = 7
    case last30Nights = 30
}

struct NightFlockSharedHabitPeriodProjection: Equatable, Sendable {
    let kind: NightFlockSharedHabitKind
    let period: NightFlockSharedHabitPeriod
    let availableNights: Int
    let coveredNights: Int
    let averageMinutes: Double?
}

enum NightFlockSharedHabitProjectionRules {
    static let maximumJSONRevision: Int64 = 9_007_199_254_740_991

    /// Produces one Wind Down value per stable night anchor. Restarts are not
    /// additive: the largest factual quiet result is the night's record.
    static func windDownProjections(
        from records: [NightWatchRecord]
    ) -> [NightFlockSharedHabitProjection] {
        let candidates = records.compactMap { record -> NightFlockSharedHabitProjection? in
            guard record.occurrenceRole == .primarySleepBookend,
                  record.outcome != .active,
                  record.isPractice == false,
                  let anchor = record.plan.localDateAnchor
            else { return nil }
            return NightFlockSharedHabitProjection(
                sourceID: record.id,
                revision: sourceRevision(for: record),
                kind: .windDown,
                localDate: anchor.nightEndingDate,
                timeZoneIdentifier: anchor.timeZoneIdentifier,
                minutes: record.creditedWindDownMinutes,
                outcome: record.outcome == .completed ? .completed : .partlyCompleted,
                protectionMinutes: observedPreBedProtection(for: record),
                evidence: protectionEvidence(for: record)
            )
        }
        return oneMaximumWindDownPerNight(candidates)
    }

    /// Phone Away remains a session-level, separate activity-day metric. Its
    /// date uses its actual terminal time in the plan's captured time zone.
    static func phoneAwayProjections(
        from records: [NightWatchRecord]
    ) -> [NightFlockSharedHabitProjection] {
        records.compactMap { record in
            guard record.occurrenceRole == .additionalQuiet,
                  record.outcome != .active,
                  record.isPractice == false,
                  let anchor = record.plan.localDateAnchor,
                  let activityDate = localDate(
                    for: record.endedAt ?? record.updatedAt,
                    timeZoneIdentifier: anchor.timeZoneIdentifier
                  )
            else { return nil }
            return NightFlockSharedHabitProjection(
                sourceID: record.id,
                revision: sourceRevision(for: record),
                kind: .phoneAway,
                localDate: activityDate,
                timeZoneIdentifier: anchor.timeZoneIdentifier,
                minutes: record.creditedWindDownMinutes,
                outcome: record.outcome == .completed ? .completed : .partlyCompleted
            )
        }
    }

    /// Arithmetic means contain only dates with an eligible derived value;
    /// missing local data is never converted to a zero-minute night.
    static func periodSummary(
        for kind: NightFlockSharedHabitKind,
        period: NightFlockSharedHabitPeriod,
        endingOn nightEndingDate: NightFlockLocalDate,
        timeZoneIdentifier: String,
        projections: [NightFlockSharedHabitProjection]
    ) -> NightFlockSharedHabitPeriodProjection {
        let dates = periodDates(
            endingOn: nightEndingDate,
            count: period.rawValue,
            timeZoneIdentifier: timeZoneIdentifier
        )
        let eligible = projections.compactMap { projection -> (NightFlockLocalDate, NightFlockSharedHabitProjection)? in
            guard projection.kind == kind,
                  projection.timeZoneIdentifier == timeZoneIdentifier,
                  let localDate = projection.localDate,
                  dates.contains(localDate)
            else { return nil }
            return (localDate, projection)
        }
        let dailyValues = Dictionary(grouping: eligible, by: \.0)
            .values
            .map { values in dailyMinutes(for: kind, values: values.map(\.1)) }
        let covered = dailyValues.count
        return NightFlockSharedHabitPeriodProjection(
            kind: kind,
            period: period,
            availableNights: period.rawValue,
            coveredNights: covered,
            averageMinutes: covered == 0
                ? nil
                : Double(dailyValues.reduce(0, +)) / Double(covered)
        )
    }

    static func sourceRevision(for record: NightWatchRecord) -> Int64 {
        let milliseconds = record.updatedAt.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite, milliseconds >= 1 else { return 1 }
        guard milliseconds < Double(maximumJSONRevision) else { return maximumJSONRevision }
        return Int64(milliseconds.rounded(.down))
    }

    /// The publisher persists the prior source revision. This keeps a corrected
    /// payload strictly newer even when two local saves share a millisecond.
    static func nextRevision(
        for record: NightWatchRecord,
        after previousRevision: Int64?
    ) -> Int64? {
        let candidate = sourceRevision(for: record)
        guard let previousRevision, previousRevision >= candidate else {
            return candidate
        }
        guard previousRevision < maximumJSONRevision else { return nil }
        return previousRevision + 1
    }

    private static func oneMaximumWindDownPerNight(
        _ projections: [NightFlockSharedHabitProjection]
    ) -> [NightFlockSharedHabitProjection] {
        let keyed = projections.compactMap { projection -> (NightKey, NightFlockSharedHabitProjection)? in
            guard let localDate = projection.localDate else { return nil }
            return (NightKey(localDate: localDate, timeZoneIdentifier: projection.timeZoneIdentifier), projection)
        }
        return Dictionary(grouping: keyed, by: \.0)
            .values
            .compactMap { values in
                values.map(\.1).max(by: isEarlierWindDown)
            }
            .sorted(by: isLaterProjection)
    }

    private static func observedPreBedProtection(for record: NightWatchRecord) -> Int? {
        guard protectionEvidence(for: record) == .appRecorded else { return nil }
        return max(0, min(record.shieldedWindDownMinutes, record.creditedWindDownMinutes))
    }

    private static func protectionEvidence(for record: NightWatchRecord) -> NightFlockSharedHabitEvidence {
        switch record.shieldProtectionEvidence {
        case .partial, .observed: return .appRecorded
        case .notRequested, .unavailable: return .none
        }
    }

    private static func isEarlierWindDown(
        _ lhs: NightFlockSharedHabitProjection,
        _ rhs: NightFlockSharedHabitProjection
    ) -> Bool {
        if lhs.minutes != rhs.minutes { return lhs.minutes < rhs.minutes }
        if lhs.revision != rhs.revision { return lhs.revision < rhs.revision }
        return lhs.sourceID.uuidString < rhs.sourceID.uuidString
    }

    private static func isLaterProjection(
        _ lhs: NightFlockSharedHabitProjection,
        _ rhs: NightFlockSharedHabitProjection
    ) -> Bool {
        switch (lhs.localDate, rhs.localDate) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate > rhsDate
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            break
        }
        return lhs.sourceID.uuidString > rhs.sourceID.uuidString
    }

    private static func dailyMinutes(
        for kind: NightFlockSharedHabitKind,
        values: [NightFlockSharedHabitProjection]
    ) -> Int {
        let latestBySource = Dictionary(grouping: values, by: \.sourceID)
            .values
            .compactMap { sourceValues in
                sourceValues.max { lhs, rhs in
                    if lhs.revision != rhs.revision { return lhs.revision < rhs.revision }
                    return lhs.minutes < rhs.minutes
                }
            }
        switch kind {
        case .sleep, .windDown:
            return latestBySource.map(\.minutes).max() ?? 0
        case .phoneAway:
            return latestBySource.reduce(0) { partial, value in
                let (sum, overflow) = partial.addingReportingOverflow(value.minutes)
                return overflow ? Int.max : sum
            }
        }
    }

    private static func periodDates(
        endingOn date: NightFlockLocalDate,
        count: Int,
        timeZoneIdentifier: String
    ) -> Set<NightFlockLocalDate> {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier),
              let endingDate = date.date(in: timeZoneIdentifier, calendar: gregorianCalendar(timeZone))
        else { return [] }
        let calendar = gregorianCalendar(timeZone)
        return Set((0..<max(0, count)).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: endingDate) else {
                return nil
            }
            return NightFlockLocalDate(date: day, timeZoneIdentifier: timeZoneIdentifier, calendar: calendar)
        })
    }

    private static func gregorianCalendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func localDate(
        for date: Date,
        timeZoneIdentifier: String
    ) -> NightFlockLocalDate? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return nil }
        return NightFlockLocalDate(
            date: date,
            timeZoneIdentifier: timeZoneIdentifier,
            calendar: gregorianCalendar(timeZone)
        )
    }

    private struct NightKey: Hashable {
        let localDate: NightFlockLocalDate
        let timeZoneIdentifier: String
    }
}

/// An immutable contributor-local plan instance for one of the next seven
/// nights. It deliberately excludes recurrence, custom text, app selections,
/// notifications, Health data, and device credentials.
struct SharedNightPlan: Codable, Equatable, Identifiable, Sendable {
    var id: UUID { planID }
    var planID: UUID; var partyID: UUID; var memberID: UUID; var memberEpochID: UUID; var agreementID: UUID
    var revision: Int64; var idempotencyKey: String?; var nightEndingDate: NightFlockLocalDate; var timeZoneIdentifier: String
    var plannedWindDownStart: Date; var intendedBedtime: Date; var intendedWakeTime: Date; var morningQuietEnd: Date
    var beforeBedMinutes: Int; var afterWakingMinutes: Int; var eveningSuggestionIDs: [String]; var morningSuggestionIDs: [String]
    var supersededAt: Date?; var isFormerMember: Bool

    init(planID: UUID, partyID: UUID, memberID: UUID, memberEpochID: UUID, agreementID: UUID, revision: Int64, idempotencyKey: String? = nil, nightEndingDate: NightFlockLocalDate, timeZoneIdentifier: String, plannedWindDownStart: Date, intendedBedtime: Date, intendedWakeTime: Date, morningQuietEnd: Date, beforeBedMinutes: Int, afterWakingMinutes: Int, eveningSuggestionIDs: [String], morningSuggestionIDs: [String], supersededAt: Date? = nil, isFormerMember: Bool = false) {
        self.planID = planID; self.partyID = partyID; self.memberID = memberID; self.memberEpochID = memberEpochID; self.agreementID = agreementID; self.revision = max(0, revision); self.idempotencyKey = idempotencyKey
        self.nightEndingDate = nightEndingDate; self.timeZoneIdentifier = timeZoneIdentifier; self.plannedWindDownStart = SharedNightPlanRules.rounded(plannedWindDownStart); self.intendedBedtime = SharedNightPlanRules.rounded(intendedBedtime); self.intendedWakeTime = SharedNightPlanRules.rounded(intendedWakeTime); self.morningQuietEnd = SharedNightPlanRules.rounded(morningQuietEnd)
        self.beforeBedMinutes = max(0, min(180, beforeBedMinutes)); self.afterWakingMinutes = max(0, min(180, afterWakingMinutes))
        self.eveningSuggestionIDs = SharedNightPlanRules.validSuggestionIDs(eveningSuggestionIDs, limit: WindDownRoutineStep.maximumEveningCount); self.morningSuggestionIDs = SharedNightPlanRules.validSuggestionIDs(morningSuggestionIDs, limit: WindDownRoutineStep.maximumMorningCount); self.supersededAt = supersededAt; self.isFormerMember = isFormerMember
    }
}

enum SharedNightReceiptOutcome: String, Codable, Sendable { case completed, partlyCompleted, unknown }
enum SharedNightProtectionEvidence: String, Codable, Sendable { case observed, partial, unavailable, failedOpen, unknown }

enum SharedNightReceiptRules {
    static func winner(
        from records: [NightWatchRecord],
        nightEndingDate: NightFlockLocalDate,
        timeZoneIdentifier: String
    ) -> NightWatchRecord? {
        records.filter {
            $0.role == .primarySleepBookend
                && $0.plan.localDateAnchor?.timeZoneIdentifier == timeZoneIdentifier
                && $0.plan.localDateAnchor?.nightEndingDate == nightEndingDate
        }.max(by: isWorse)
    }

    /// A member-night receipt reports the strongest factual Wind Down record,
    /// never merely the last terminal callback.
    static func isWorse(_ lhs: NightWatchRecord, _ rhs: NightWatchRecord) -> Bool {
        if lhs.creditedWindDownMinutes != rhs.creditedWindDownMinutes { return lhs.creditedWindDownMinutes < rhs.creditedWindDownMinutes }
        if lhs.shieldedWindDownMinutes != rhs.shieldedWindDownMinutes { return lhs.shieldedWindDownMinutes < rhs.shieldedWindDownMinutes }
        let lhsOutcome = lhs.outcome == .completed ? 2 : lhs.outcome == .endedEarly ? 1 : 0
        let rhsOutcome = rhs.outcome == .completed ? 2 : rhs.outcome == .endedEarly ? 1 : 0
        if lhsOutcome != rhsOutcome { return lhsOutcome < rhsOutcome }
        if lhs.endedAt != rhs.endedAt { return (lhs.endedAt ?? .distantPast) < (rhs.endedAt ?? .distantPast) }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

struct SharedNightReceiptCorrectionFacts: Equatable {
    var actualStart: Date?
    var terminalAt: Date?
    var outcome: SharedNightReceiptOutcome
    var windDownMinutes: Int?
    var protectionMinutes: Int?
    var protectionEvidence: SharedNightProtectionEvidence
    var emergencyExitUsed: Bool?
}

/// Shared client/outbox ordering for a one-member-night receipt correction.
/// It mirrors the Edge/SQL contract: factual core first, then information
/// quality, with unknown emergency evidence unable to erase a known fact.
enum SharedNightReceiptCorrectionRules {
    static func evidenceRank(_ evidence: SharedNightProtectionEvidence) -> Int {
        switch evidence {
        case .observed: return 4
        case .partial: return 3
        case .failedOpen: return 2
        case .unavailable: return 1
        case .unknown: return 0
        }
    }

    /// Positive means candidate wins. Core factual quality always dominates;
    /// only equal facts use revision, then a stable serialized fact key, so
    /// pairwise merges converge regardless of arrival order.
    static func comparison(
        candidate: SharedNightReceiptCorrectionFacts,
        candidateRevision: Int64,
        existing: SharedNightReceiptCorrectionFacts,
        existingRevision: Int64
    ) -> Int {
        let candidateWindDown = candidate.windDownMinutes ?? 0
        let existingWindDown = existing.windDownMinutes ?? 0
        if candidateWindDown != existingWindDown { return candidateWindDown > existingWindDown ? 1 : -1 }
        let candidateProtection = candidate.protectionMinutes ?? 0
        let existingProtection = existing.protectionMinutes ?? 0
        if candidateProtection != existingProtection { return candidateProtection > existingProtection ? 1 : -1 }
        func outcomeRank(_ value: SharedNightReceiptOutcome) -> Int {
            switch value { case .completed: return 2; case .partlyCompleted: return 1; case .unknown: return 0 }
        }
        if outcomeRank(candidate.outcome) != outcomeRank(existing.outcome) {
            return outcomeRank(candidate.outcome) > outcomeRank(existing.outcome) ? 1 : -1
        }
        let candidateEvidence = evidenceRank(candidate.protectionEvidence)
        let storedEvidence = evidenceRank(existing.protectionEvidence)
        if candidateEvidence != storedEvidence { return candidateEvidence > storedEvidence ? 1 : -1 }
        if candidate.actualStart == existing.actualStart,
           candidate.terminalAt == existing.terminalAt,
           candidate.emergencyExitUsed == existing.emergencyExitUsed {
            if candidateRevision != existingRevision { return candidateRevision > existingRevision ? 1 : -1 }
            return 0
        }
        if candidateRevision != existingRevision { return candidateRevision > existingRevision ? 1 : -1 }
        let startComparison = compareOptionalTimestamp(candidate.actualStart, existing.actualStart)
        if startComparison != 0 { return startComparison }
        let terminalComparison = compareOptionalTimestamp(candidate.terminalAt, existing.terminalAt)
        if terminalComparison != 0 { return terminalComparison }
        return emergencyRank(candidate.emergencyExitUsed) - emergencyRank(existing.emergencyExitUsed)
    }

    static func permits(
        candidate: SharedNightReceiptCorrectionFacts,
        candidateRevision: Int64 = 0,
        over existing: SharedNightReceiptCorrectionFacts,
        existingRevision: Int64 = 0
    ) -> Bool {
        comparison(
            candidate: candidate,
            candidateRevision: candidateRevision,
            existing: existing,
            existingRevision: existingRevision
        ) > 0
    }

    static func facts(for receipt: SharedNightReceipt) -> SharedNightReceiptCorrectionFacts {
        .init(
            actualStart: receipt.actualStart,
            terminalAt: receipt.terminalAt,
            outcome: receipt.outcome,
            windDownMinutes: receipt.windDownMinutes,
            protectionMinutes: receipt.protectionMinutes,
            protectionEvidence: receipt.protectionEvidence,
            emergencyExitUsed: receipt.emergencyExitUsed
        )
    }

    private static func compareOptionalTimestamp(_ lhs: Date?, _ rhs: Date?) -> Int {
        switch (lhs, rhs) {
        case (nil, nil): return 0
        case (nil, _): return -1
        case (_, nil): return 1
        case let (lhs?, rhs?): return lhs == rhs ? 0 : (lhs > rhs ? 1 : -1)
        }
    }

    private static func emergencyRank(_ value: Bool?) -> Int {
        switch value { case true: return 2; case false: return 1; case nil: return 0 }
    }
}

/// A delayed restoration may offer the same member-night more than once. A
/// receipt with the same factual source content is already authoritative; an
/// unknown replay must also never erase a previously observed emergency fact.
enum SharedNightReceiptReplayRules {

    static func needsPublication(
        record: NightWatchRecord,
        evidence: SharedNightProtectionEvidence,
        emergencyExitUsed: Bool?,
        existing: SharedNightReceipt?
    ) -> Bool {
        guard let existing else { return true }
        let outcome: SharedNightReceiptOutcome = record.outcome == .completed
            ? .completed
            : .partlyCompleted
        let expectedProtectionMinutes: Int?
        switch evidence {
        case .observed, .partial:
            expectedProtectionMinutes = max(
                0,
                min(record.shieldedWindDownMinutes, max(0, record.creditedWindDownMinutes))
            )
        case .unavailable, .failedOpen, .unknown:
            expectedProtectionMinutes = nil
        }
        var candidate = SharedNightReceiptCorrectionFacts(
            actualStart: SharedNightPlanRules.rounded(record.startedAt),
            terminalAt: record.endedAt.map(SharedNightPlanRules.rounded),
            outcome: outcome,
            windDownMinutes: max(0, record.creditedWindDownMinutes),
            protectionMinutes: expectedProtectionMinutes,
            protectionEvidence: evidence,
            emergencyExitUsed: emergencyExitUsed
        )
        let stored = SharedNightReceiptCorrectionRules.facts(for: existing)
        if candidate.emergencyExitUsed == nil {
            candidate.emergencyExitUsed = stored.emergencyExitUsed
        }
        guard candidate != stored else { return false }
        return SharedNightReceiptCorrectionRules.permits(
            candidate: candidate,
            candidateRevision: NightFlockSharedHabitProjectionRules.sourceRevision(for: record),
            over: stored,
            existingRevision: existing.revision
        )
    }
}

struct SharedNightReceipt: Codable, Equatable, Identifiable, Sendable {
    var id: UUID { receiptID }
    var receiptID: UUID; var partyID: UUID; var memberID: UUID; var memberEpochID: UUID; var agreementID: UUID; var planID: UUID?; var planRevision: Int64?; var sourceID: UUID?; var revision: Int64
    var nightEndingDate: NightFlockLocalDate; var timeZoneIdentifier: String; var actualStart: Date?; var terminalAt: Date?; var outcome: SharedNightReceiptOutcome; var windDownMinutes: Int?; var protectionMinutes: Int?; var protectionEvidence: SharedNightProtectionEvidence; var emergencyExitUsed: Bool?; var profileSnapshot: NightFlockSharedHabitProfileSnapshot; var isFormerMember: Bool

    init(receiptID: UUID, partyID: UUID, memberID: UUID, memberEpochID: UUID, agreementID: UUID, planID: UUID?, planRevision: Int64?, sourceID: UUID?, revision: Int64, nightEndingDate: NightFlockLocalDate, timeZoneIdentifier: String, actualStart: Date?, terminalAt: Date?, outcome: SharedNightReceiptOutcome, windDownMinutes: Int?, protectionMinutes: Int?, protectionEvidence: SharedNightProtectionEvidence, emergencyExitUsed: Bool?, profileSnapshot: NightFlockSharedHabitProfileSnapshot, isFormerMember: Bool = false) {
        self.receiptID = receiptID; self.partyID = partyID; self.memberID = memberID; self.memberEpochID = memberEpochID; self.agreementID = agreementID; self.planID = planID; self.planRevision = planRevision; self.sourceID = sourceID; self.revision = max(0, revision); self.nightEndingDate = nightEndingDate; self.timeZoneIdentifier = timeZoneIdentifier; self.actualStart = actualStart.map(SharedNightPlanRules.rounded); self.terminalAt = terminalAt.map(SharedNightPlanRules.rounded); self.outcome = outcome; self.windDownMinutes = windDownMinutes.map { max(0, min(180, $0)) }; self.protectionEvidence = protectionEvidence
        let protectionLimit = self.windDownMinutes ?? 180
        switch protectionEvidence { case .observed, .partial: self.protectionMinutes = protectionMinutes.map { max(0, min($0, protectionLimit)) }; case .unavailable, .failedOpen, .unknown: self.protectionMinutes = nil }
        self.emergencyExitUsed = emergencyExitUsed; self.profileSnapshot = profileSnapshot; self.isFormerMember = isFormerMember
    }
}

/// A one-night privacy choice is durable cancellation authority, not a UI
/// filter. It suppresses the bounded plan and any social receipt for the same
/// party membership epoch without deleting immutable historical SQL rows.
struct SharedNightPlanCancellation: Codable, Equatable, Sendable {
    enum Authority: String, Codable, Sendable { case schedule, privacy }
    var partyID: UUID
    var memberEpochID: UUID
    var agreementID: UUID
    var nightEndingDate: NightFlockLocalDate
    var timeZoneIdentifier: String
    var revision: Int64
    var authority: Authority

    private enum CodingKeys: String, CodingKey { case partyID, memberEpochID, agreementID, nightEndingDate, timeZoneIdentifier, revision, authority }

    init(
        partyID: UUID,
        memberEpochID: UUID,
        agreementID: UUID,
        nightEndingDate: NightFlockLocalDate,
        timeZoneIdentifier: String,
        revision: Int64,
        authority: Authority = .privacy
    ) {
        self.partyID = partyID
        self.memberEpochID = memberEpochID
        self.agreementID = agreementID
        self.nightEndingDate = nightEndingDate
        self.timeZoneIdentifier = timeZoneIdentifier
        self.revision = max(0, revision)
        self.authority = authority
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        partyID = try values.decode(UUID.self, forKey: .partyID)
        memberEpochID = try values.decode(UUID.self, forKey: .memberEpochID)
        agreementID = try values.decode(UUID.self, forKey: .agreementID)
        nightEndingDate = try values.decode(NightFlockLocalDate.self, forKey: .nightEndingDate)
        timeZoneIdentifier = try values.decode(String.self, forKey: .timeZoneIdentifier)
        revision = max(0, try values.decode(Int64.self, forKey: .revision))
        authority = try values.decodeIfPresent(Authority.self, forKey: .authority) ?? .privacy
    }
}

extension SharedNightPlanCancellation {
    var identity: String {
        "\(partyID.uuidString.lowercased()):\(memberEpochID.uuidString.lowercased()):\(nightEndingDate.year)-\(nightEndingDate.month)-\(nightEndingDate.day)"
    }
}

enum SharedNightPlanCancellationRules {
    /// Keeps the highest revision for a member-night. Equal revisions retain
    /// the persisted value so an in-flight retry's identity never changes.
    static func merging(
        _ incoming: SharedNightPlanCancellation,
        into existing: [SharedNightPlanCancellation],
        limit: Int = 256
    ) -> [SharedNightPlanCancellation] {
        if let prior = existing.first(where: { $0.identity == incoming.identity }),
           prior.revision >= incoming.revision {
            return existing
        }
        var result = existing.filter { $0.identity != incoming.identity }
        result.append(incoming)
        return Array(result.sorted { $0.revision < $1.revision }.suffix(max(1, limit)))
    }
}

enum SharedNightPlanRules {
    static let fiveMinutes: TimeInterval = 5 * 60
    static func rounded(_ date: Date) -> Date { Date(timeIntervalSince1970: (date.timeIntervalSince1970 / fiveMinutes).rounded() * fiveMinutes) }
    static func stablePlanID(partyID: UUID, memberEpochID: UUID, nightEndingDate: NightFlockLocalDate) -> UUID {
        versionedPlanID(partyID: partyID, memberEpochID: memberEpochID, nightEndingDate: nightEndingDate, revision: 0)
    }

    /// Receipt provenance names one factual contributor night, not a plan
    /// version. Keeping this namespace separate prevents future ID confusion.
    static func stableReceiptSourceID(partyID: UUID, memberEpochID: UUID, nightEndingDate: NightFlockLocalDate) -> UUID {
        let input = "receipt:\(partyID.uuidString.lowercased()):\(memberEpochID.uuidString.lowercased()):\(nightEndingDate.year)-\(nightEndingDate.month)-\(nightEndingDate.day)"
        let bytes = Array(SHA256.hash(data: Data(input.utf8)))
        var uuid = uuid_t(bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
        uuid.6 = (uuid.6 & 0x0F) | 0x50; uuid.8 = (uuid.8 & 0x3F) | 0x80
        return UUID(uuid: uuid)
    }
    static func versionedPlanID(partyID: UUID, memberEpochID: UUID, nightEndingDate: NightFlockLocalDate, revision: Int64) -> UUID {
        let input = "\(partyID.uuidString.lowercased()):\(memberEpochID.uuidString.lowercased()):\(nightEndingDate.year)-\(nightEndingDate.month)-\(nightEndingDate.day):\(max(0, revision))"
        let bytes = Array(SHA256.hash(data: Data(input.utf8)))
        var uuid = uuid_t(bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
        uuid.6 = (uuid.6 & 0x0F) | 0x50; uuid.8 = (uuid.8 & 0x3F) | 0x80
        return UUID(uuid: uuid)
    }
    static func hasSamePublishedContent(_ lhs: SharedNightPlan, _ rhs: SharedNightPlan) -> Bool {
        lhs.partyID == rhs.partyID
            && lhs.memberEpochID == rhs.memberEpochID
            && lhs.agreementID == rhs.agreementID
            && lhs.nightEndingDate == rhs.nightEndingDate
            && lhs.timeZoneIdentifier == rhs.timeZoneIdentifier
            && lhs.plannedWindDownStart == rhs.plannedWindDownStart
            && lhs.intendedBedtime == rhs.intendedBedtime
            && lhs.intendedWakeTime == rhs.intendedWakeTime
            && lhs.morningQuietEnd == rhs.morningQuietEnd
            && lhs.beforeBedMinutes == rhs.beforeBedMinutes
            && lhs.afterWakingMinutes == rhs.afterWakingMinutes
            && lhs.eveningSuggestionIDs == rhs.eveningSuggestionIDs
            && lhs.morningSuggestionIDs == rhs.morningSuggestionIDs
    }
    static func isFuturePublicationCandidate(_ plan: SharedNightPlan, now: Date) -> Bool {
        plan.plannedWindDownStart > now
    }
    /// A schedule edit may remove or move a future occurrence. Only the
    /// newest version for each contributor-local night is relevant to the
    /// cancellation decision; frozen/historical versions remain available
    /// for receipt correlation.
    static func staleFuturePlans(
        _ plans: [SharedNightPlan],
        desiredNightEndingDates: Set<NightFlockLocalDate>,
        now: Date
    ) -> [SharedNightPlan] {
        Dictionary(grouping: plans, by: \.nightEndingDate).values.compactMap { versions in
            guard let latest = versions.max(by: { $0.revision < $1.revision }),
                  !desiredNightEndingDates.contains(latest.nightEndingDate),
                  isFuturePublicationCandidate(latest, now: now)
            else { return nil }
            return latest
        }
    }
    static func validSuggestionIDs(_ values: [String], limit: Int) -> [String] { Array(values.reduce(into: [String]()) { result, value in let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines); guard PhoneFreeActivity(rawValue: trimmed) != nil, !result.contains(trimmed) else { return }; result.append(trimmed) }.prefix(limit)) }
    static func startRelationship(plan: SharedNightPlan?, receipt: SharedNightReceipt) -> SharedNightStartRelationship { guard let plan, let actual = receipt.actualStart else { return .unknown }; let difference = Int(actual.timeIntervalSince(plan.plannedWindDownStart) / 60); return difference < 0 ? .early(minutes: abs(difference)) : .afterPlan(minutes: difference) }
}

enum SharedNightStartRelationship: Equatable, Sendable { case early(minutes: Int), afterPlan(minutes: Int), unknown }

/// The cooperative mosaic is a current-round view, but receipts must keep
/// their frozen plan version. Active plan slots and receipt-correlated
/// superseded versions are selected separately so an edit cannot erase the
/// factual comparison that already happened.
enum SharedNightMosaicPresentation {
    static func receipts(
        in dates: Set<NightFlockLocalDate>,
        from receipts: [SharedNightReceipt]
    ) -> [SharedNightReceipt] {
        let current = receipts.filter { dates.contains($0.nightEndingDate) && !$0.isFormerMember }
        return Dictionary(grouping: current, by: {
            "\($0.partyID.uuidString):\($0.memberID.uuidString):\($0.memberEpochID.uuidString):\($0.nightEndingDate.year)-\($0.nightEndingDate.month)-\($0.nightEndingDate.day)"
        }).values.compactMap { $0.max { $0.revision < $1.revision } }
    }

    static func plans(
        in dates: Set<NightFlockLocalDate>,
        plans: [SharedNightPlan],
        receipts: [SharedNightReceipt]
    ) -> [SharedNightPlan] {
        let active = plans.filter { dates.contains($0.nightEndingDate) && !$0.isFormerMember && $0.supersededAt == nil }
        let referenced = Set(receipts.compactMap { receipt -> String? in
            guard let id = receipt.planID, let revision = receipt.planRevision else { return nil }
            return "\(id.uuidString):\(revision)"
        })
        let frozen = plans.filter { referenced.contains("\($0.planID.uuidString):\($0.revision)") }
        return Dictionary(grouping: active + frozen, by: { "\($0.planID.uuidString):\($0.revision)" })
            .values.compactMap(\.first)
    }

    /// Multiple immutable versions still occupy one contributor-night slot.
    static func coverageSlotCount(for plans: [SharedNightPlan]) -> Int {
        Set(plans.map {
            "\($0.partyID.uuidString):\($0.memberID.uuidString):\($0.memberEpochID.uuidString):\($0.nightEndingDate.year)-\($0.nightEndingDate.month)-\($0.nightEndingDate.day)"
        }).count
    }

    static func planBackedReceipts(
        _ receipts: [SharedNightReceipt],
        plans: [SharedNightPlan]
    ) -> [SharedNightReceipt] {
        let versions = Set(plans.map { "\($0.planID.uuidString):\($0.revision)" })
        return receipts.filter {
            guard let planID = $0.planID, let planRevision = $0.planRevision else { return false }
            return versions.contains("\(planID.uuidString):\(planRevision)")
        }
    }
}

enum SharedNightReceiptPublicationRules {
    /// V2 factual receipts never backfill a night that began before consent.
    static func permits(
        actualStart: Date?,
        acceptedAt: Date
    ) -> Bool {
        // Receipt times use the established nearest-five-minute serialization.
        // Require both facts: a pre-consent start cannot gain eligibility by
        // rounding up, and a just-post-consent start cannot round back before
        // consent on the wire. Sleep-specific eligibility is not a Wind Down
        // receipt cutoff.
        guard let actualStart,
              actualStart >= acceptedAt,
              SharedNightPlanRules.rounded(actualStart) >= acceptedAt
        else { return false }
        return true
    }
}

enum SharedNightPlanBindingPolicy {
    enum Acknowledgement: Equatable, Sendable {
        case bind
        case clearMatchingBinding
    }

    /// Stale acknowledgement may describe an older local version; refresh is
    /// authoritative, so it must not become a frozen receipt binding.
    static func shouldPersistAfterAcknowledgement(accepted: Bool, staleRevision: Bool?) -> Bool {
        accepted && staleRevision != true
    }

    static func acknowledgement(accepted: Bool, staleRevision: Bool?) -> Acknowledgement {
        shouldPersistAfterAcknowledgement(accepted: accepted, staleRevision: staleRevision)
            ? .bind
            : .clearMatchingBinding
    }

    /// A stale response may only clear the exact older binding it describes.
    /// A newer local plan for the same night remains available for its own
    /// acknowledgement; a queued cancellation intentionally clears any plan.
    static func shouldClearBinding(
        binding: SharedNightPlan?,
        acknowledgedPlan: SharedNightPlan,
        acknowledgement: Acknowledgement,
        queuedCancellation: Bool,
        hasNewerQueuedPlan: Bool
    ) -> Bool {
        guard let binding else { return false }
        if queuedCancellation { return true }
        guard binding.partyID == acknowledgedPlan.partyID,
              binding.memberEpochID == acknowledgedPlan.memberEpochID,
              binding.nightEndingDate == acknowledgedPlan.nightEndingDate
        else { return false }
        guard binding.planID == acknowledgedPlan.planID,
              binding.revision == acknowledgedPlan.revision
        else { return false }
        return acknowledgement == .clearMatchingBinding || hasNewerQueuedPlan
    }
}

enum SharedNightPresentation {
    static func startRelationshipText(_ value: SharedNightStartRelationship) -> String { switch value { case let .early(minutes): return minutes == 0 ? "Started at the planned time" : "Started \(minutes) min before the plan"; case let .afterPlan(minutes): return minutes == 0 ? "Started at the planned time" : "Started \(minutes) min after the plan"; case .unknown: return "Start time unavailable" } }
    static func receiptText(plan: SharedNightPlan?, receipt: SharedNightReceipt) -> String { var parts: [String] = []; if let plan { parts.append("Planned " + plan.plannedWindDownStart.formatted(date: .omitted, time: .shortened)) }; if receipt.actualStart != nil { parts.append(startRelationshipText(SharedNightPlanRules.startRelationship(plan: plan, receipt: receipt))) }; switch receipt.outcome { case .completed: parts.append("Completed"); case .partlyCompleted: parts.append("Ended early"); case .unknown: parts.append("Result unavailable") }; if let minutes = receipt.protectionMinutes, receipt.protectionEvidence == .observed { parts.append("Protection recorded for \(minutes) min before bed") }; return parts.joined(separator: " · ") }
}
