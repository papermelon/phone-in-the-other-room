import Foundation

/// Persisted with Farm inventory in one JSON value. Never prune consumed spans or
/// settlement identities: replaying an old receipt must not mint another reward.
struct CumulativeFarmCredit: Codable, Equatable {
    static let windDownSearchSeconds: TimeInterval = 420 * 60
    static let phoneAwaySearchSeconds: TimeInterval = 100 * 60
    var migrationCompleted = false
    var consumedIntervals: [DateInterval] = []
    var windDownSeconds: TimeInterval = 0
    var phoneAwaySeconds: TimeInterval = 0
    var receipts: [UUID: FarmCreditReceipt] = [:]
    var outcomes: [SheepSearchOutcome] = []
}

struct FarmCreditReceipt: Codable, Equatable {
    let creditedSeconds: TimeInterval
    let excludedAccessSeconds: TimeInterval
    let trackingIncomplete: Bool
    let migrated: Bool
    let outcomeIDs: [UUID]

    var detail: String {
        if trackingIncomplete {
            return "Brief-access timing is incomplete, so no extra credit was added. Previously saved progress stays."
        }
        return "\(Int(creditedSeconds / 60)) min added to wool growth and Ollie's search. Brief access is excluded; earned progress stays."
    }
}

enum FarmCreditIntervals {
    static func union(_ intervals: [DateInterval]) -> [DateInterval] {
        var result: [DateInterval] = []
        for interval in intervals.filter({ $0.duration > 0 }).sorted(by: { $0.start < $1.start }) {
            if let last = result.last, interval.start <= last.end {
                result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else { result.append(interval) }
        }
        return result
    }

    static func subtract(_ exclusions: [DateInterval], from intervals: [DateInterval]) -> [DateInterval] {
        var result = union(intervals)
        for exclusion in union(exclusions) {
            result = result.flatMap { interval -> [DateInterval] in
                guard exclusion.start < interval.end, exclusion.end > interval.start else { return [interval] }
                var pieces: [DateInterval] = []
                if exclusion.start > interval.start {
                    pieces.append(DateInterval(start: interval.start, end: exclusion.start))
                }
                if exclusion.end < interval.end {
                    pieces.append(DateInterval(start: exclusion.end, end: interval.end))
                }
                return pieces
            }
        }
        return result
    }
}

extension FarmState {
    /// One-time conservative backfill. Completed legacy rewards are retained and
    /// their spans reserved. Early receipts need explicit non-practice provenance
    /// and zero access uses; older history has no recoverable access timestamps.
    mutating func migrateCumulativeCredit(
        records: [NightWatchRecord], searchState: SheepSearchState,
        protectedNightCount: Int
    ) {
        guard cumulativeCredit?.migrationCompleted != true else { return }
        cumulativeCredit = cumulativeCredit ?? CumulativeFarmCredit()
        cumulativeCredit?.phoneAwaySeconds = Double(searchState.trailMap.pendingMappedMinutes) * 60
        for index in sheep.indices where sheep[index].regrowthSecondsRemaining == nil {
            sheep[index].regrowthSecondsRemaining = Double(FarmEconomyRules.remainingRegrowthNights(
                for: sheep[index], protectedNightCount: protectedNightCount
            )) * CumulativeFarmCredit.windDownSearchSeconds
        }
        // Reserve old successful intervals before backfilling overlapping early runs.
        let terminal = records.filter { $0.outcome != .active }
        for record in terminal where record.outcome == .completed {
            if let interval = Self.creditInterval(start: record.startedAt, end: record.endedAt,
                                                  plannedEnd: record.plan.protectedUntil) {
                cumulativeCredit?.consumedIntervals.append(interval)
            }
            cumulativeCredit?.receipts[record.id] = FarmCreditReceipt(
                creditedSeconds: 0, excludedAccessSeconds: 0, trackingIncomplete: false,
                migrated: true, outcomeIDs: []
            )
        }
        let reserved = FarmCreditIntervals.union(cumulativeCredit?.consumedIntervals ?? [])
        cumulativeCredit?.consumedIntervals = reserved
        var projectedSearch = searchState
        for record in terminal.filter({ $0.outcome == .endedEarly }).sorted(by: { $0.startedAt < $1.startedAt }) {
            guard record.isPractice == false, record.briefAccessUseCount == 0 else { continue }
            var run = FocusRun(id: record.id, plannedDurationSeconds: max(0, record.plan.protectedUntil.timeIntervalSince(record.startedAt)),
                               startedAt: record.startedAt, state: .endedEarly, nightWatchPlan: record.plan)
            run.endedAt = record.endedAt
            settleCumulativeCredit(run: run, searchState: projectedSearch, migrated: true)
            for outcome in cumulativeCredit?.outcomes ?? [] { projectedSearch.append(outcome) }
        }
        cumulativeCredit?.migrationCompleted = true
    }

    mutating func settleCumulativeCredit(
        run: FocusRun, searchState: SheepSearchState, migrated: Bool = false
    ) {
        // Linked Screen-Free Morning has its own reward ledger. Its scheduled
        // window must not also advance the Wind Down meter or wool here.
        let morningBoundary = run.nightWatchPlan.flatMap { plan -> Date? in
            plan.role == .primarySleepBookend && plan.morningQuietMinutes > 0 ? plan.wakeTime : nil
        }
        guard !run.isPractice, run.farmCreditVersion > 0,
              run.state == .completed || run.state == .endedEarly,
              let interval = Self.creditInterval(start: run.startedAt, end: run.endedAt,
                                                plannedEnd: min(run.plannedEndAt, morningBoundary ?? run.nightWatchPlan?.protectedUntil ?? run.plannedEndAt)) else { return }
        var ledger = cumulativeCredit ?? CumulativeFarmCredit()
        guard ledger.receipts[run.id] == nil else { return }
        // A count without its timestamps cannot establish the excluded intervals.
        let incomplete = run.briefAccessUseCount > run.briefAccessIntervals.count
        let eligible = FarmCreditIntervals.subtract(run.briefAccessIntervals, from: [interval])
        let excluded = interval.duration - eligible.reduce(0) { $0 + $1.duration }
        let newIntervals = incomplete ? [] : FarmCreditIntervals.subtract(ledger.consumedIntervals, from: eligible)
        let seconds = newIntervals.reduce(0) { $0 + $1.duration }
        ledger.consumedIntervals = FarmCreditIntervals.union(ledger.consumedIntervals + [interval])
        // Backfill only advances sheep that existed and were sheared before that time.
        for index in sheep.indices where sheep[index].status == .active {
            let lastShear = transactions.filter { $0.sheepID == sheep[index].id && $0.kind == .shearing }.map(\.createdAt).max()
            if migrated && sheep[index].timesSheared > 0 && lastShear == nil { continue }
            let growthStart = max(sheep[index].arrivedAt, lastShear ?? sheep[index].arrivedAt)
            let growth = newIntervals.reduce(0.0) { total, piece in
                total + max(0, piece.end.timeIntervalSince(max(piece.start, growthStart)))
            }
            if let remaining = sheep[index].regrowthSecondsRemaining {
                sheep[index].regrowthSecondsRemaining = max(0, remaining - growth)
            }
        }
        let phoneAway = run.nightWatchPlan?.role == .additionalQuiet
        let threshold = phoneAway ? CumulativeFarmCredit.phoneAwaySearchSeconds : CumulativeFarmCredit.windDownSearchSeconds
        if phoneAway { ledger.phoneAwaySeconds += seconds } else { ledger.windDownSeconds += seconds }
        var search = searchState
        for outcome in ledger.outcomes { search.append(outcome) }
        var newOutcomes: [UUID] = []
        while (phoneAway ? ledger.phoneAwaySeconds : ledger.windDownSeconds) >= threshold {
            let ordinal = ledger.outcomes.count
            let identity = FarmMigration.stableLegacyID(for: "cumulative:\(run.id.uuidString):\(ordinal)")
            let number = search.completedWindDownSearchCount + 1
            let outcome = phoneAway
                ? SheepSearchEngine.calculatePhoneBreak(runID: identity, protectedNightNumber: max(1, number), state: search,
                    trackedSheepID: trackedSheepDefinitionID, now: interval.end).outcome
                : SheepSearchEngine.calculate(runID: identity, protectedNightNumber: number, evidence: .empty, state: search,
                    trackedSheepID: trackedSheepDefinitionID, now: interval.end).outcome
            ledger.outcomes.append(outcome)
            newOutcomes.append(outcome.id)
            search.append(outcome)
            recordArrival(outcome)
            if phoneAway { ledger.phoneAwaySeconds -= threshold } else { ledger.windDownSeconds -= threshold }
        }
        ledger.receipts[run.id] = FarmCreditReceipt(creditedSeconds: seconds, excludedAccessSeconds: excluded,
            trackingIncomplete: incomplete, migrated: migrated, outcomeIDs: newOutcomes)
        cumulativeCredit = ledger
    }

    private static func creditInterval(start: Date, end: Date?, plannedEnd: Date) -> DateInterval? {
        guard let end, min(end, plannedEnd) > start else { return nil }
        return DateInterval(start: start, end: min(end, plannedEnd))
    }
}

extension SheepTrailMapPresentation {
    static func cumulative(minutes: Int) -> Self? {
        guard minutes > 0 else { return nil }
        return Self(title: "Phone Away search progress · \(minutes) / 100 minutes",
            detail: "Every 100 credited minutes opens a search. Shorter sessions carry forward; brief access is excluded.")
    }
}
