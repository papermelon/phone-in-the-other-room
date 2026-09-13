import Foundation

enum NightsPrimaryOutcome: Equatable {
    case completed
    case endedEarly
}

struct NightsHistoryDay: Equatable, Identifiable {
    let day: Date
    let primaryOutcome: NightsPrimaryOutcome?
    let primaryAttemptCount: Int
    let completedWindDownCount: Int
    let windDownMinutes: Int
    let earlyEndedPrimaryCount: Int
    let screenFreeMorningCount: Int
    let completedScreenFreeMorningCount: Int
    let skippedScreenFreeMorningCount: Int
    let screenFreeMorningMinutes: Int
    /// Older records could store after-waking credit inside Wind Down. Keep
    /// that factual value visible without treating it as Morning evidence.
    let legacyMorningQuietMinutes: Int
    let legacyMorningRecordCount: Int
    let additionalCount: Int
    let phoneAwayMinutes: Int
    let primaryRecordIDs: [UUID]
    let screenFreeMorningOccurrenceIDs: [UUID]
    let additionalRecordIDs: [UUID]

    var id: Date { day }

    var totalOccurrenceCount: Int {
        primaryAttemptCount + screenFreeMorningCount + additionalCount
    }

    var allRecordIDs: [UUID] {
        primaryRecordIDs + additionalRecordIDs
    }

    var hasRecords: Bool {
        totalOccurrenceCount > 0
    }

    // Compatibility names for non-presentation call sites. New Nights UI uses
    // the source-specific properties above and never presents a combined total.
    var protectedNightCount: Int { completedWindDownCount }
    var protectedWindDownMinutes: Int { windDownMinutes }
    var protectedMorningQuietMinutes: Int { legacyMorningQuietMinutes }
    var primaryQuietMinutes: Int { windDownMinutes }
    var additionalQuietMinutes: Int { phoneAwayMinutes }
}

struct NightsHistoryRange: Equatable {
    let days: [NightsHistoryDay]
    let completedWindDownCount: Int
    let windDownMinutes: Int
    let screenFreeMorningCount: Int
    let completedScreenFreeMorningCount: Int
    let screenFreeMorningMinutes: Int
    let phoneAwayMinutes: Int
    let legacyMorningQuietMinutes: Int
    let totalOccurrenceCount: Int

    // Retained for source compatibility only; release copy says "completed."
    var protectedNightCount: Int { completedWindDownCount }
}

enum NightsHistoryAggregator {
    static func displayDay(
        for record: NightWatchRecord,
        calendar: Calendar = .current
    ) -> Date {
        let date = record.occurrenceRole == .additionalQuiet
            ? record.startedAt
            : record.plan.wakeTime
        return calendar.startOfDay(for: date)
    }

    static func displayDay(
        for occurrence: MorningQuietOccurrence,
        calendar: Calendar = .current
    ) -> Date {
        calendar.startOfDay(for: occurrence.scheduledStart)
    }

    static func latestPrimaryRecord(from records: [NightWatchRecord]) -> NightWatchRecord? {
        completedRecords(records)
            .filter { $0.occurrenceRole.isProgressionEligible }
            .max {
                if $0.plan.wakeTime == $1.plan.wakeTime {
                    return resultDate($0) < resultDate($1)
                }
                return $0.plan.wakeTime < $1.plan.wakeTime
            }
    }

    static func latestAdditionalRecord(from records: [NightWatchRecord]) -> NightWatchRecord? {
        completedRecords(records)
            .filter { $0.occurrenceRole == .additionalQuiet }
            .max {
                if $0.startedAt == $1.startedAt {
                    return resultDate($0) < resultDate($1)
                }
                return $0.startedAt < $1.startedAt
            }
    }

    static func week(
        from records: [NightWatchRecord],
        morningOccurrences: [MorningQuietOccurrence] = [],
        endingAt date: Date = Date(),
        calendar: Calendar = .current
    ) -> [NightsHistoryDay] {
        let endDay = calendar.startOfDay(for: date)
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: endDay) else {
                return nil
            }
            return summary(
                for: day,
                from: records,
                morningOccurrences: morningOccurrences,
                calendar: calendar
            )
        }
    }

    static func weekSummary(
        from records: [NightWatchRecord],
        morningOccurrences: [MorningQuietOccurrence] = [],
        endingAt date: Date = Date(),
        calendar: Calendar = .current
    ) -> NightsHistoryRange {
        let days = week(
                from: records,
                morningOccurrences: morningOccurrences,
                endingAt: date,
                calendar: calendar
            )
        return rangeSummary(
            days: days,
            records: records,
            morningOccurrences: morningOccurrences,
            calendar: calendar
        )
    }

    static func month(
        from records: [NightWatchRecord],
        morningOccurrences: [MorningQuietOccurrence] = [],
        containing date: Date,
        calendar: Calendar = .current
    ) -> [NightsHistoryDay] {
        daySummaries(
            from: records,
            morningOccurrences: morningOccurrences,
            calendar: calendar
        ).filter {
            calendar.isDate($0.day, equalTo: date, toGranularity: .month)
        }
    }

    static func monthSummary(
        from records: [NightWatchRecord],
        morningOccurrences: [MorningQuietOccurrence] = [],
        containing date: Date,
        calendar: Calendar = .current
    ) -> NightsHistoryRange {
        let days = month(
                from: records,
                morningOccurrences: morningOccurrences,
                containing: date,
                calendar: calendar
            )
        return rangeSummary(
            days: days,
            records: records,
            morningOccurrences: morningOccurrences,
            calendar: calendar
        )
    }

    static func daySummaries(
        from records: [NightWatchRecord],
        morningOccurrences: [MorningQuietOccurrence] = [],
        calendar: Calendar = .current
    ) -> [NightsHistoryDay] {
        let groupedRecords = Dictionary(grouping: completedRecords(records)) {
            displayDay(for: $0, calendar: calendar)
        }
        let groupedMornings = Dictionary(grouping: settledMorningOccurrences(morningOccurrences)) {
            displayDay(for: $0, calendar: calendar)
        }
        let days = Set(groupedRecords.keys).union(groupedMornings.keys)
        return days.sorted().map { day in
            makeSummary(
                day: day,
                records: groupedRecords[day] ?? [],
                morningOccurrences: groupedMornings[day] ?? []
            )
        }
    }

    static func summary(
        for day: Date,
        from records: [NightWatchRecord],
        morningOccurrences: [MorningQuietOccurrence] = [],
        calendar: Calendar = .current
    ) -> NightsHistoryDay {
        let normalizedDay = calendar.startOfDay(for: day)
        let matchingRecords = completedRecords(records).filter {
            displayDay(for: $0, calendar: calendar) == normalizedDay
        }
        let matchingMornings = settledMorningOccurrences(morningOccurrences).filter {
            displayDay(for: $0, calendar: calendar) == normalizedDay
        }
        return makeSummary(
            day: normalizedDay,
            records: matchingRecords,
            morningOccurrences: matchingMornings
        )
    }

    static func records(
        for day: Date,
        from records: [NightWatchRecord],
        calendar: Calendar = .current
    ) -> [NightWatchRecord] {
        let normalizedDay = calendar.startOfDay(for: day)
        return completedRecords(records)
            .filter { displayDay(for: $0, calendar: calendar) == normalizedDay }
            .sorted {
                if $0.startedAt == $1.startedAt { return $0.id.uuidString < $1.id.uuidString }
                return $0.startedAt < $1.startedAt
            }
    }

    static func morningOccurrences(
        for day: Date,
        from occurrences: [MorningQuietOccurrence],
        calendar: Calendar = .current
    ) -> [MorningQuietOccurrence] {
        let normalizedDay = calendar.startOfDay(for: day)
        return settledMorningOccurrences(occurrences)
            .filter { displayDay(for: $0, calendar: calendar) == normalizedDay }
            .sorted {
                if $0.scheduledStart == $1.scheduledStart { return $0.id.uuidString < $1.id.uuidString }
                return $0.scheduledStart < $1.scheduledStart
            }
    }

    private static func rangeSummary(
        days: [NightsHistoryDay],
        records: [NightWatchRecord],
        morningOccurrences: [MorningQuietOccurrence],
        calendar: Calendar
    ) -> NightsHistoryRange {
        let displayDays = Set(days.map(\.day))
        let matchingRecords = completedRecords(records).filter {
            displayDays.contains(displayDay(for: $0, calendar: calendar))
        }
        let matchingMornings = settledMorningOccurrences(morningOccurrences).filter {
            displayDays.contains(displayDay(for: $0, calendar: calendar))
        }
        let primary = matchingRecords.filter { $0.occurrenceRole.isProgressionEligible }
        let phoneAway = matchingRecords.filter { $0.occurrenceRole == .additionalQuiet }

        return NightsHistoryRange(
            days: days,
            completedWindDownCount: days.reduce(0) { $0 + $1.completedWindDownCount },
            windDownMinutes: unionedMinutes(primary.flatMap(creditedWindDownInterval)),
            screenFreeMorningCount: days.reduce(0) { $0 + $1.screenFreeMorningCount },
            completedScreenFreeMorningCount: days.reduce(0) {
                $0 + $1.completedScreenFreeMorningCount
            },
            screenFreeMorningMinutes: unionedMinutes(
                matchingMornings.compactMap(screenFreeMorningInterval)
            ),
            phoneAwayMinutes: unionedMinutes(phoneAway.flatMap(phoneAwayInterval)),
            legacyMorningQuietMinutes: days.reduce(0) { $0 + $1.legacyMorningQuietMinutes },
            totalOccurrenceCount: days.reduce(0) { $0 + $1.totalOccurrenceCount }
        )
    }

    private static func makeSummary(
        day: Date,
        records: [NightWatchRecord],
        morningOccurrences: [MorningQuietOccurrence]
    ) -> NightsHistoryDay {
        let primary = records.filter { $0.occurrenceRole.isProgressionEligible }
        let completed = primary.filter { $0.outcome == .completed }
        let additional = records.filter { $0.occurrenceRole == .additionalQuiet }
        let earlyEndedPrimaryCount = primary.filter { $0.outcome == .endedEarly }.count
        let finishedMornings = morningOccurrences.filter { $0.outcome == .finished }
        let skippedMornings = morningOccurrences.filter { $0.outcome == .skipped }
        let legacyMorningRecords = primary.filter { $0.creditedMorningQuietMinutes > 0 }

        let primaryOutcome: NightsPrimaryOutcome?
        if !completed.isEmpty {
            primaryOutcome = .completed
        } else if earlyEndedPrimaryCount > 0 {
            primaryOutcome = .endedEarly
        } else {
            primaryOutcome = nil
        }

        return NightsHistoryDay(
            day: day,
            primaryOutcome: primaryOutcome,
            primaryAttemptCount: primary.count,
            completedWindDownCount: completed.count,
            windDownMinutes: unionedMinutes(primary.flatMap(creditedWindDownInterval)),
            earlyEndedPrimaryCount: earlyEndedPrimaryCount,
            screenFreeMorningCount: morningOccurrences.count,
            completedScreenFreeMorningCount: finishedMornings.count,
            skippedScreenFreeMorningCount: skippedMornings.count,
            screenFreeMorningMinutes: unionedMinutes(
                finishedMornings.compactMap(screenFreeMorningInterval)
            ),
            legacyMorningQuietMinutes: legacyMorningRecords.reduce(0) {
                $0 + $1.creditedMorningQuietMinutes
            },
            legacyMorningRecordCount: legacyMorningRecords.count,
            additionalCount: additional.count,
            phoneAwayMinutes: unionedMinutes(additional.flatMap(phoneAwayInterval)),
            primaryRecordIDs: primary.map(\.id),
            screenFreeMorningOccurrenceIDs: morningOccurrences.map(\.id),
            additionalRecordIDs: additional.map(\.id)
        )
    }

    private static func creditedWindDownInterval(_ record: NightWatchRecord) -> [DateInterval] {
        guard record.creditedWindDownMinutes > 0 else { return [] }
        let endDate = record.endedAt ?? record.updatedAt
        let plannedStart = record.plan.intendedBedtime.addingTimeInterval(
            TimeInterval(-record.plan.windDownMinutes * 60)
        )
        let start = max(record.startedAt, plannedStart)
        let availableEnd = min(endDate, record.plan.intendedBedtime)
        let creditedEnd = start.addingTimeInterval(TimeInterval(record.creditedWindDownMinutes * 60))
        let end = min(availableEnd, creditedEnd)
        guard end > start else { return [] }
        return [DateInterval(start: start, end: end)]
    }

    private static func phoneAwayInterval(_ record: NightWatchRecord) -> [DateInterval] {
        guard record.creditedWindDownMinutes > 0 else { return [] }
        let availableEnd = min(record.endedAt ?? record.updatedAt, record.plan.protectedUntil)
        let creditedEnd = record.startedAt.addingTimeInterval(
            TimeInterval(record.creditedWindDownMinutes * 60)
        )
        let end = min(availableEnd, creditedEnd)
        guard end > record.startedAt else { return [] }
        return [DateInterval(start: record.startedAt, end: end)]
    }

    private static func screenFreeMorningInterval(
        _ occurrence: MorningQuietOccurrence
    ) -> DateInterval? {
        guard occurrence.outcome == .finished,
              let actualStart = occurrence.actualStart,
              let endedAt = occurrence.endedAt else { return nil }
        let eligibleMinutes = occurrence.eligibleElapsedMinutes(at: endedAt)
        let end = min(
            endedAt,
            occurrence.scheduledEnd,
            actualStart.addingTimeInterval(TimeInterval(eligibleMinutes * 60))
        )
        guard end > actualStart else { return nil }
        return DateInterval(start: actualStart, end: end)
    }

    private static func unionedMinutes(_ intervals: [DateInterval]) -> Int {
        WindDownScheduleEngine.unionedMinutes(intervals)
    }

    private static func completedRecords(_ records: [NightWatchRecord]) -> [NightWatchRecord] {
        records.filter { $0.outcome != .active }
    }

    private static func settledMorningOccurrences(
        _ occurrences: [MorningQuietOccurrence]
    ) -> [MorningQuietOccurrence] {
        occurrences.filter { $0.outcome == .finished || $0.outcome == .skipped }
    }

    private static func resultDate(_ record: NightWatchRecord) -> Date {
        record.endedAt ?? record.updatedAt
    }
}
