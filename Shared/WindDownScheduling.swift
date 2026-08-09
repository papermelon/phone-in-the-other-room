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

/// The repeat choices shown by the finite Upcoming quiet times editor. The
/// weekday numbers follow `Calendar.Component.weekday` (Sunday is 1).
enum WindDownRecurrence: Codable, Equatable, Hashable {
    case daily
    case weekdays
    case custom([Int])

    var weekdays: [Int] {
        switch self {
        case .daily: return Array(1...7)
        case .weekdays: return Array(2...6)
        case let .custom(days): return Array(Set(days.filter { (1...7).contains($0) })).sorted()
        }
    }

    var title: String {
        switch self {
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .custom: return "Custom days"
        }
    }

    var isValid: Bool {
        !weekdays.isEmpty
    }

    static func from(weekdays: [Int]) -> Self {
        let normalized = Array(Set(weekdays.filter { (1...7).contains($0) })).sorted()
        if normalized == Array(1...7) { return .daily }
        if normalized == Array(2...6) { return .weekdays }
        return .custom(normalized)
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
    var recurrence: WindDownRecurrence
    var enabled: Bool
    var automaticStartEnabled: Bool

    var weekdays: [Int] { recurrence.weekdays }

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID = UUID(),
        title: String,
        role: WindDownOccurrenceRole = .primarySleepBookend,
        start: WindDownClockTime,
        end: WindDownClockTime,
        weekdays: [Int] = Array(1...7),
        recurrence: WindDownRecurrence? = nil,
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
        self.recurrence = recurrence ?? WindDownRecurrence.from(weekdays: weekdays)
        self.enabled = enabled
        self.automaticStartEnabled = automaticStartEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, title, role, start, end, weekdays, recurrence, enabled, automaticStartEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title)?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmptyOrNil ?? "Wind Down"
        role = try container.decodeIfPresent(WindDownOccurrenceRole.self, forKey: .role) ?? .primarySleepBookend
        start = try container.decodeIfPresent(WindDownClockTime.self, forKey: .start) ?? WindDownClockTime(hour: 22, minute: 30)
        end = try container.decodeIfPresent(WindDownClockTime.self, forKey: .end) ?? WindDownClockTime(hour: 7, minute: 0)
        if let recurrence = try container.decodeIfPresent(WindDownRecurrence.self, forKey: .recurrence) {
            self.recurrence = recurrence
        } else {
            self.recurrence = WindDownRecurrence.from(
                weekdays: try container.decodeIfPresent([Int].self, forKey: .weekdays) ?? Array(1...7)
            )
        }
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        automaticStartEnabled = try container.decodeIfPresent(Bool.self, forKey: .automaticStartEnabled) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(role, forKey: .role)
        try container.encode(start, forKey: .start)
        try container.encode(end, forKey: .end)
        // Keep the old field alongside the new semantic value so older builds
        // can still read a saved routine if a person rolls back.
        try container.encode(weekdays, forKey: .weekdays)
        try container.encode(recurrence, forKey: .recurrence)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(automaticStartEnabled, forKey: .automaticStartEnabled)
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

struct WindDownOneTimePeriod: Codable, Identifiable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    let id: UUID
    var title: String
    var role: WindDownOccurrenceRole
    var interval: DateInterval
    var enabled: Bool
    var cancelledAt: Date?

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID = UUID(),
        title: String = "One-time quiet period",
        role: WindDownOccurrenceRole = .additionalQuiet,
        interval: DateInterval,
        enabled: Bool = true,
        cancelledAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).nonEmptyOrNil ?? "One-time quiet period"
        self.role = role
        self.interval = interval
        self.enabled = enabled
        self.cancelledAt = cancelledAt
    }

    var isCancelled: Bool { cancelledAt != nil }
    var isAvailable: Bool { enabled && !isCancelled }

    func isEligible(
        at date: Date,
        minimumRemainingDuration: TimeInterval = QuietPeriodScheduling.meaningfulMinimumRemainingDuration
    ) -> Bool {
        isAvailable
            && interval.end > interval.start
            && interval.end.timeIntervalSince(max(interval.start, date)) >= minimumRemainingDuration
    }

    func occurrence() -> WindDownOccurrence? {
        guard isAvailable, interval.end > interval.start else { return nil }
        return WindDownOccurrence(
            id: id,
            routineID: id,
            role: role,
            interval: interval
        )
    }
}

struct WindDownScheduleState: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var oneTimePeriods: [WindDownOneTimePeriod]
    var routines: [WindDownRoutine]

    init(
        schemaVersion: Int = currentSchemaVersion,
        oneTimePeriods: [WindDownOneTimePeriod] = [],
        routines: [WindDownRoutine] = []
    ) {
        self.schemaVersion = schemaVersion
        self.oneTimePeriods = oneTimePeriods
        self.routines = routines
    }

    static func migrated(
        routines: [WindDownRoutine],
        nextOverride: NextWindDownOverride?
    ) -> Self {
        var oneTimePeriods: [WindDownOneTimePeriod] = []
        if let nextOverride,
           nextOverride.consumedAt == nil,
           nextOverride.interval.end > nextOverride.interval.start {
            oneTimePeriods = [WindDownOneTimePeriod(
                id: nextOverride.id,
                title: nextOverride.role == .primarySleepBookend ? "Adjusted Wind Down" : "One-time quiet period",
                role: nextOverride.role,
                interval: nextOverride.interval
            )]
        }
        return Self(oneTimePeriods: oneTimePeriods, routines: routines)
    }

    mutating func prunePassedOneTimePeriods(at date: Date) {
        oneTimePeriods.removeAll { $0.interval.end <= date || $0.isCancelled }
    }

    @discardableResult
    mutating func consumeOneTimePeriod(id: UUID) -> Bool {
        guard let index = oneTimePeriods.firstIndex(where: { $0.id == id }),
              oneTimePeriods[index].isAvailable else { return false }
        oneTimePeriods.remove(at: index)
        return true
    }

    func upcomingPeriods(
        after date: Date,
        calendar: Calendar = .current,
        primaryExtensionMinutes: Int = 0,
        limit: Int = 64
    ) -> [WindDownSchedulePeriod] {
        WindDownScheduleEngine.futureOccurrences(
            in: self,
            after: date,
            calendar: calendar,
            primaryExtensionMinutes: primaryExtensionMinutes,
            limit: limit
        )
    }
}

struct WindDownSchedulePeriod: Equatable, Identifiable {
    let occurrence: WindDownOccurrence
    let title: String
    let recurring: Bool

    var id: UUID { occurrence.id }
    /// Occurrence IDs are intentionally unique for lists. Starting a period
    /// needs an identity that survives recalculation at confirmation time.
    var sourceID: UUID { recurring ? occurrence.routineID : occurrence.id }
}

private extension String {
    var nonEmptyOrNil: String? { isEmpty ? nil : self }
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
    case invalidRecurrence
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
        for offset in 0...370 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay),
                  let occurrence = occurrence(for: routine, on: day, calendar: calendar),
                  occurrence.interval.end > date else {
                continue
            }
            return occurrence
        }
        return nil
    }

    static func futureOccurrences(
        in state: WindDownScheduleState,
        after date: Date,
        calendar: Calendar = .current,
        primaryExtensionMinutes: Int = 0,
        limit: Int = 64
    ) -> [WindDownSchedulePeriod] {
        var periods = state.oneTimePeriods.compactMap { item -> WindDownSchedulePeriod? in
            guard let occurrence = item.occurrence(), occurrence.interval.start > date else { return nil }
            return WindDownSchedulePeriod(occurrence: occurrence, title: item.title, recurring: false)
        }

        let oneTimeIntervals = state.oneTimePeriods.compactMap { item -> (WindDownOccurrenceRole, DateInterval)? in
            guard let occurrence = item.occurrence() else { return nil }
            return (occurrence.role, occurrence.interval)
        }
        for routine in state.routines where routine.enabled {
            var nextDate = date
            for _ in 0..<max(1, limit) {
                guard let occurrence = nextOccurrence(for: routine, after: nextDate, calendar: calendar) else { break }
                let expanded = expandedOccurrence(
                    occurrence,
                    routine: routine,
                    primaryExtensionMinutes: primaryExtensionMinutes,
                    calendar: calendar
                )
                let replacesOneTime = oneTimeIntervals.contains {
                    $0.0 == routine.role && $0.1.intersects(expanded.interval)
                }
                if expanded.interval.start > date && !replacesOneTime {
                    periods.append(
                        WindDownSchedulePeriod(occurrence: expanded, title: routine.title, recurring: true)
                    )
                }
                nextDate = occurrence.interval.end.addingTimeInterval(1)
            }
        }
        return periods
            .sorted { lhs, rhs in
                lhs.occurrence.interval.start == rhs.occurrence.interval.start
                    ? lhs.title < rhs.title
                    : lhs.occurrence.interval.start < rhs.occurrence.interval.start
            }
            .prefix(max(0, limit))
            .map { $0 }
    }

    static func eligibleOccurrence(
        in state: WindDownScheduleState,
        at date: Date,
        calendar: Calendar = .current,
        primaryExtensionMinutes: Int = 0
    ) -> WindDownSchedulePeriod? {
        var candidates = state.oneTimePeriods.compactMap { item -> WindDownSchedulePeriod? in
            guard item.isEligible(at: date),
                  let occurrence = item.occurrence(),
                  occurrence.interval.contains(date) else { return nil }
            return WindDownSchedulePeriod(occurrence: occurrence, title: item.title, recurring: false)
        }
        for routine in state.routines where routine.enabled {
            let startOfToday = calendar.startOfDay(for: date)
            let days = [
                startOfToday,
                calendar.date(byAdding: .day, value: -1, to: startOfToday)
            ].compactMap { $0 }

            for day in days {
                guard let occurrence = occurrence(for: routine, on: day, calendar: calendar) else { continue }
                let expanded = expandedOccurrence(
                    occurrence,
                    routine: routine,
                    primaryExtensionMinutes: primaryExtensionMinutes,
                    calendar: calendar
                )
                guard expanded.interval.contains(date),
                      expanded.interval.end.timeIntervalSince(date)
                        >= QuietPeriodScheduling.meaningfulMinimumRemainingDuration else { continue }
                if state.oneTimePeriods.contains(where: {
                    $0.role == routine.role && $0.interval.intersects(expanded.interval) && $0.isAvailable
                }) { continue }
                candidates.append(WindDownSchedulePeriod(occurrence: expanded, title: routine.title, recurring: true))
            }
        }
        return candidates.min {
            if $0.occurrence.interval.start == $1.occurrence.interval.start {
                return $0.title < $1.title
            }
            return $0.occurrence.interval.start < $1.occurrence.interval.start
        }
    }

    static func expandedOccurrence(
        _ occurrence: WindDownOccurrence,
        routine: WindDownRoutine,
        primaryExtensionMinutes: Int,
        calendar: Calendar
    ) -> WindDownOccurrence {
        guard routine.role == .primarySleepBookend, primaryExtensionMinutes > 0 else { return occurrence }
        let end = calendar.date(
            byAdding: .minute,
            value: primaryExtensionMinutes,
            to: occurrence.interval.end
        ) ?? occurrence.interval.end
        return WindDownOccurrence(
            schemaVersion: occurrence.schemaVersion,
            id: occurrence.id,
            routineID: occurrence.routineID,
            role: occurrence.role,
            interval: DateInterval(start: occurrence.interval.start, end: end),
            state: occurrence.state
        )
    }

    static func plan(
        for period: WindDownSchedulePeriod,
        preferences: NightWatchPreferences,
        startedAt: Date,
        calendar: Calendar = .current
    ) -> NightWatchPlan {
        if period.occurrence.role == .additionalQuiet {
            return NightWatchPlan.additionalQuiet(
                start: max(period.occurrence.interval.start, startedAt),
                end: period.occurrence.interval.end,
                activity: preferences.eveningActivity,
                cueText: preferences.eveningCueText
            )
        }

        if period.recurring {
            // A primary routine's visible interval ends at wake time, not at
            // bedtime. The saved preferences own the phase boundaries.
            return preferences.makePlan(startedAt: startedAt, calendar: calendar)
        }

        let bedtime = period.occurrence.interval.end
        let wakeComponents = DateComponents(
            hour: preferences.wakeHour,
            minute: preferences.wakeMinute
        )
        let wake = calendar.nextDate(
            after: bedtime,
            matching: wakeComponents,
            matchingPolicy: .nextTime
        ) ?? bedtime.addingTimeInterval(8 * 60 * 60)
        let protectedUntil = calendar.date(
            byAdding: .minute,
            value: preferences.morningQuietMinutes,
            to: wake
        ) ?? wake.addingTimeInterval(TimeInterval(preferences.morningQuietMinutes * 60))
        return NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: wake,
            protectedUntil: protectedUntil,
            windDownMinutes: max(
                15,
                Int(bedtime.timeIntervalSince(period.occurrence.interval.start) / 60)
            ),
            morningQuietMinutes: preferences.morningQuietMinutes,
            eveningActivity: preferences.eveningActivity,
            morningActivity: preferences.morningActivity,
            eveningCueText: preferences.eveningCueText,
            morningCueText: preferences.morningCueText
        )
    }

    static func validateNoOverlaps(_ occurrences: [WindDownOccurrence]) throws {
        guard occurrences.allSatisfy({ $0.interval.end > $0.interval.start }) else {
            throw WindDownScheduleError.invalidInterval
        }
        let sorted = occurrences.sorted { $0.interval.start < $1.interval.start }
        for pair in zip(sorted, sorted.dropFirst()) {
            guard pair.0.interval.end > pair.1.interval.start else { continue }
            throw WindDownScheduleError.overlappingOccurrences(pair.0.routineID, pair.1.routineID)
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
