import Foundation

enum NightsPrimaryOutcome: Equatable {
    case protected
    case endedEarly
}

struct NightsHistoryDay: Equatable, Identifiable {
    let day: Date
    let primaryOutcome: NightsPrimaryOutcome?
    let primaryAttemptCount: Int
    let protectedNightCount: Int
    let protectedWindDownMinutes: Int
    let protectedMorningQuietMinutes: Int
    let primaryQuietMinutes: Int
    let earlyEndedPrimaryCount: Int
    let additionalCount: Int
    let additionalQuietMinutes: Int
    let recordedQuietMinutes: Int
    let primaryRecordIDs: [UUID]
    let additionalRecordIDs: [UUID]

    var id: Date { day }

    var protectedQuietMinutes: Int {
        protectedWindDownMinutes + protectedMorningQuietMinutes
    }

    var totalOccurrenceCount: Int {
        primaryAttemptCount + additionalCount
    }

    var allRecordIDs: [UUID] {
        primaryRecordIDs + additionalRecordIDs
    }

    var hasRecords: Bool {
        totalOccurrenceCount > 0
    }
}

struct NightsHistoryRange: Equatable {
    let days: [NightsHistoryDay]
    let protectedNightCount: Int
    let recordedQuietMinutes: Int
    let totalOccurrenceCount: Int
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
        endingAt date: Date = Date(),
        calendar: Calendar = .current
    ) -> [NightsHistoryDay] {
        let endDay = calendar.startOfDay(for: date)
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: endDay) else {
                return nil
            }
            return summary(for: day, from: records, calendar: calendar)
        }
    }

    static func weekSummary(
        from records: [NightWatchRecord],
        endingAt date: Date = Date(),
        calendar: Calendar = .current
    ) -> NightsHistoryRange {
        rangeSummary(
            days: week(from: records, endingAt: date, calendar: calendar),
            records: records,
            calendar: calendar
        )
    }

    static func month(
        from records: [NightWatchRecord],
        containing date: Date,
        calendar: Calendar = .current
    ) -> [NightsHistoryDay] {
        daySummaries(from: records, calendar: calendar).filter {
            calendar.isDate($0.day, equalTo: date, toGranularity: .month)
        }
    }

    static func monthSummary(
        from records: [NightWatchRecord],
        containing date: Date,
        calendar: Calendar = .current
    ) -> NightsHistoryRange {
        rangeSummary(
            days: month(from: records, containing: date, calendar: calendar),
            records: records,
            calendar: calendar
        )
    }

    static func daySummaries(
        from records: [NightWatchRecord],
        calendar: Calendar = .current
    ) -> [NightsHistoryDay] {
        let grouped = Dictionary(grouping: completedRecords(records)) {
            displayDay(for: $0, calendar: calendar)
        }
        return grouped.keys.sorted().map { day in
            makeSummary(day: day, records: grouped[day] ?? [])
        }
    }

    static func summary(
        for day: Date,
        from records: [NightWatchRecord],
        calendar: Calendar = .current
    ) -> NightsHistoryDay {
        let normalizedDay = calendar.startOfDay(for: day)
        let matching = completedRecords(records).filter {
            displayDay(for: $0, calendar: calendar) == normalizedDay
        }
        return makeSummary(day: normalizedDay, records: matching)
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

    private static func rangeSummary(
        days: [NightsHistoryDay],
        records: [NightWatchRecord],
        calendar: Calendar
    ) -> NightsHistoryRange {
        let displayDays = Set(days.map(\.day))
        let matchingRecords = completedRecords(records).filter {
            displayDays.contains(displayDay(for: $0, calendar: calendar))
        }
        return NightsHistoryRange(
            days: days,
            protectedNightCount: days.reduce(0) { $0 + $1.protectedNightCount },
            recordedQuietMinutes: unionedMinutes(matchingRecords.flatMap(\.creditedIntervals)),
            totalOccurrenceCount: days.reduce(0) { $0 + $1.totalOccurrenceCount }
        )
    }

    private static func makeSummary(
        day: Date,
        records: [NightWatchRecord]
    ) -> NightsHistoryDay {
        let primary = records.filter { $0.occurrenceRole.isProgressionEligible }
        let protected = primary.filter { $0.outcome == .completed }
        let additional = records.filter { $0.occurrenceRole == .additionalQuiet }
        let earlyEndedPrimaryCount = primary.filter { $0.outcome == .endedEarly }.count

        let primaryOutcome: NightsPrimaryOutcome?
        if !protected.isEmpty {
            primaryOutcome = .protected
        } else if earlyEndedPrimaryCount > 0 {
            primaryOutcome = .endedEarly
        } else {
            primaryOutcome = nil
        }

        return NightsHistoryDay(
            day: day,
            primaryOutcome: primaryOutcome,
            primaryAttemptCount: primary.count,
            protectedNightCount: protected.count,
            protectedWindDownMinutes: unionedMinutes(
                protected.flatMap(creditedWindDownInterval)
            ),
            protectedMorningQuietMinutes: unionedMinutes(
                protected.flatMap(creditedMorningQuietInterval)
            ),
            primaryQuietMinutes: unionedMinutes(primary.flatMap(\.creditedIntervals)),
            earlyEndedPrimaryCount: earlyEndedPrimaryCount,
            additionalCount: additional.count,
            additionalQuietMinutes: unionedMinutes(additional.flatMap(\.creditedIntervals)),
            recordedQuietMinutes: unionedMinutes(records.flatMap(\.creditedIntervals)),
            primaryRecordIDs: primary.map(\.id),
            additionalRecordIDs: additional.map(\.id)
        )
    }

    private static func creditedWindDownInterval(
        _ record: NightWatchRecord
    ) -> [DateInterval] {
        guard record.creditedWindDownMinutes > 0 else { return [] }
        let endDate = record.endedAt ?? record.updatedAt
        let plannedStart = record.plan.intendedBedtime.addingTimeInterval(
            TimeInterval(-record.plan.windDownMinutes * 60)
        )
        let start = max(record.startedAt, plannedStart)
        let end = min(endDate, record.plan.intendedBedtime)
        guard end > start else { return [] }
        return [DateInterval(start: start, end: end)]
    }

    private static func creditedMorningQuietInterval(
        _ record: NightWatchRecord
    ) -> [DateInterval] {
        guard record.creditedMorningQuietMinutes > 0 else { return [] }
        let endDate = record.endedAt ?? record.updatedAt
        let start = max(record.startedAt, record.plan.wakeTime)
        let end = min(endDate, record.plan.protectedUntil)
        guard end > start else { return [] }
        return [DateInterval(start: start, end: end)]
    }

    private static func unionedMinutes(_ intervals: [DateInterval]) -> Int {
        WindDownScheduleEngine.unionedMinutes(intervals)
    }

    private static func completedRecords(_ records: [NightWatchRecord]) -> [NightWatchRecord] {
        records.filter { $0.outcome != .active }
    }

    private static func resultDate(_ record: NightWatchRecord) -> Date {
        record.endedAt ?? record.updatedAt
    }
}
