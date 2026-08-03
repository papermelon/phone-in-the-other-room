import Foundation

/// The role of a Wind Down occurrence determines whether it belongs to the
/// sleep-bookend ritual and whether it can advance Ollie's search.
enum WindDownOccurrenceRole: String, Codable, CaseIterable, Hashable {
    case primarySleepBookend
    case additionalQuiet

    var isProgressionEligible: Bool {
        self == .primarySleepBookend
    }
}

struct WindDownClockTime: Codable, Equatable, Hashable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(23, max(0, hour))
        self.minute = min(59, max(0, minute))
    }

    func date(on day: Date, calendar: Calendar) -> Date {
        calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: calendar.startOfDay(for: day)
        ) ?? day
    }
}

/// A recurring local-time template. The interval is the period in which the
/// phone-away occurrence may be active; the persisted plan remains the source
/// of truth for the primary sleep-bookend phases and credits.
struct WindDownRoutine: Codable, Identifiable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    let id: UUID
    var title: String
    var role: WindDownOccurrenceRole
    var start: WindDownClockTime
    var end: WindDownClockTime
    var weekdays: [Int]
    var enabled: Bool
    var automaticStartEnabled: Bool

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID = UUID(),
        title: String,
        role: WindDownOccurrenceRole = .primarySleepBookend,
        start: WindDownClockTime,
        end: WindDownClockTime,
        weekdays: [Int] = Array(1...7),
        enabled: Bool = true,
        automaticStartEnabled: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Wind Down"
            : title
        self.role = role
        self.start = start
        self.end = end
        self.weekdays = Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
        self.enabled = enabled
        self.automaticStartEnabled = automaticStartEnabled
    }

    func interval(on day: Date, calendar: Calendar = .current) -> DateInterval? {
        guard enabled else { return nil }
        let weekday = calendar.component(.weekday, from: day)
        guard weekdays.contains(weekday) else { return nil }

        let startDate = start.date(on: day, calendar: calendar)
        var endDate = end.date(on: day, calendar: calendar)
        if endDate <= startDate {
            endDate = calendar.date(byAdding: .day, value: 1, to: endDate)
                ?? endDate.addingTimeInterval(24 * 60 * 60)
        }
        guard endDate > startDate else { return nil }
        return DateInterval(start: startDate, end: endDate)
    }

    static func primary(from preferences: NightWatchPreferences, id: UUID = UUID()) -> Self {
        let bedtimeMinutes = preferences.bedtimeHour * 60 + preferences.bedtimeMinute
        let startMinutes = (bedtimeMinutes - preferences.windDownMinutes + 24 * 60) % (24 * 60)
        let start = WindDownClockTime(hour: startMinutes / 60, minute: startMinutes % 60)
        let wake = WindDownClockTime(hour: preferences.wakeHour, minute: preferences.wakeMinute)
        // A recurring routine stores the visible start and wake clock times.
        // The primary plan still derives its protected end from morningQuietMinutes.
        return Self(
            id: id,
            title: "Usual Wind Down",
            role: .primarySleepBookend,
            start: start,
            end: wake,
            automaticStartEnabled: preferences.automaticStartEnabled
        )
    }
}

struct WindDownOccurrence: Codable, Identifiable, Equatable {
    enum State: String, Codable, Equatable {
        case pending
        case active
        case completed
        case endedEarly
        case cancelled
    }

    static let currentSchemaVersion = 1

    var schemaVersion: Int
    let id: UUID
    let routineID: UUID
    let role: WindDownOccurrenceRole
    let interval: DateInterval
    var state: State

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID = UUID(),
        routineID: UUID,
        role: WindDownOccurrenceRole,
        interval: DateInterval,
        state: State = .pending
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.routineID = routineID
        self.role = role
        self.interval = interval
        self.state = state
    }
}

struct NextWindDownOverride: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    let id: UUID
    let routineID: UUID
    let role: WindDownOccurrenceRole
    let interval: DateInterval
    let createdAt: Date
    let expiresAt: Date
    var consumedAt: Date?

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID = UUID(),
        routineID: UUID,
        role: WindDownOccurrenceRole,
        interval: DateInterval,
        createdAt: Date = Date(),
        expiresAt: Date,
        consumedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.routineID = routineID
        self.role = role
        self.interval = interval
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.consumedAt = consumedAt
    }

    var isAvailable: Bool {
        isAvailable(at: Date())
    }

    func isAvailable(at date: Date) -> Bool {
        consumedAt == nil && expiresAt > date
    }

    mutating func consume(at date: Date = Date()) -> Bool {
        guard consumedAt == nil, date < expiresAt else { return false }
        consumedAt = date
        return true
    }
}

enum WindDownScheduleError: Error, Equatable {
    case invalidInterval
    case overlappingOccurrences(UUID, UUID)
}

enum WindDownScheduleEngine {
    static func occurrence(
        for routine: WindDownRoutine,
        on day: Date,
        calendar: Calendar = .current
    ) -> WindDownOccurrence? {
        guard let interval = routine.interval(on: day, calendar: calendar) else { return nil }
        return WindDownOccurrence(
            routineID: routine.id,
            role: routine.role,
            interval: interval
        )
    }

    static func nextOccurrence(
        for routine: WindDownRoutine,
        after date: Date,
        calendar: Calendar = .current
    ) -> WindDownOccurrence? {
        let startDay = calendar.startOfDay(for: date)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay),
                  let occurrence = occurrence(for: routine, on: day, calendar: calendar),
                  occurrence.interval.end > date else {
                continue
            }
            return occurrence
        }
        return nil
    }

    static func validateNoOverlaps(_ occurrences: [WindDownOccurrence]) throws {
        let sorted = occurrences.sorted { $0.interval.start < $1.interval.start }
        for pair in zip(sorted, sorted.dropFirst()) {
            guard pair.0.interval.end > pair.1.interval.start else { continue }
            throw WindDownScheduleError.overlappingOccurrences(pair.0.id, pair.1.id)
        }
    }

    static func unionedIntervals(_ intervals: [DateInterval]) -> [DateInterval] {
        SleepIntervalMath.merge(intervals)
    }

    static func unionedMinutes(_ intervals: [DateInterval]) -> Int {
        Int(SleepIntervalMath.duration(of: intervals) / 60)
    }
}

struct WindDownDaySummary: Equatable, Identifiable {
    let day: Date
    let occurrenceCount: Int
    let completedOccurrenceCount: Int
    let earlyEndedOccurrenceCount: Int
    let quietMinutes: Int
    let protectedNightCount: Int

    var id: Date { day }
}

enum WindDownHistoryAggregator {
    static func daySummaries(
        from records: [NightWatchRecord],
        calendar: Calendar = .current
    ) -> [WindDownDaySummary] {
        let grouped = Dictionary(grouping: records.filter { $0.outcome != .active }) { record in
            calendar.startOfDay(for: record.plan.intendedBedtime)
        }

        return grouped.keys.sorted().map { day in
            let dayRecords = grouped[day] ?? []
            let intervals = dayRecords.flatMap(\.creditedIntervals)
            return WindDownDaySummary(
                day: day,
                occurrenceCount: dayRecords.count,
                completedOccurrenceCount: dayRecords.filter { $0.outcome == .completed }.count,
                earlyEndedOccurrenceCount: dayRecords.filter { $0.outcome == .endedEarly }.count,
                quietMinutes: WindDownScheduleEngine.unionedMinutes(intervals),
                protectedNightCount: dayRecords.filter {
                    $0.outcome == .completed && $0.occurrenceRole.isProgressionEligible
                }.count
            )
        }
    }

    static func monthSummaries(
        from records: [NightWatchRecord],
        containing date: Date,
        calendar: Calendar = .current
    ) -> [WindDownDaySummary] {
        daySummaries(from: records, calendar: calendar).filter {
            calendar.isDate($0.day, equalTo: date, toGranularity: .month)
        }
    }
}

extension NightWatchRecord {
    /// The occurrence role was added after the original Night Watch schema. Old
    /// records decode as the primary sleep-bookend ritual.
    var occurrenceRole: WindDownOccurrenceRole { role }

    var creditedIntervals: [DateInterval] {
        guard outcome != .active else { return [] }
        let endDate = endedAt ?? updatedAt
        if occurrenceRole == .additionalQuiet {
            let quietEnd = min(endDate, plan.protectedUntil)
            guard quietEnd > startedAt, creditedWindDownMinutes > 0 else { return [] }
            return [DateInterval(start: startedAt, end: quietEnd)]
        }
        let windDownStart = plan.intendedBedtime.addingTimeInterval(
            TimeInterval(-plan.windDownMinutes * 60)
        )
        let actualWindDownStart = max(startedAt, windDownStart)
        let actualWindDownEnd = min(endDate, plan.intendedBedtime)
        var intervals: [DateInterval] = []
        if actualWindDownEnd > actualWindDownStart, creditedWindDownMinutes > 0 {
            intervals.append(DateInterval(start: actualWindDownStart, end: actualWindDownEnd))
        }

        let morningStart = max(startedAt, plan.wakeTime)
        let morningEnd = min(endDate, plan.protectedUntil)
        if morningEnd > morningStart, creditedMorningQuietMinutes > 0 {
            intervals.append(DateInterval(start: morningStart, end: morningEnd))
        }
        return intervals
    }
}
