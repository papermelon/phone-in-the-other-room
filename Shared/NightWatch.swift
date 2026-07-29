import Foundation

enum NightWatchPhase: String, Codable, CaseIterable, Hashable {
    case windDown
    case overnight
    case morningQuiet
    case complete

    var title: String {
        switch self {
        case .windDown: return "Phone-free wind-down"
        case .overnight: return "Sleep time"
        case .morningQuiet: return "Phone-free morning"
        case .complete: return "Night complete"
        }
    }
}

enum PhoneFreeActivity: String, Codable, CaseIterable, Identifiable {
    case read
    case shower
    case prepareTomorrow
    case stretch
    case journal
    case makeTea
    case openCurtains
    case breakfast
    case morningWalk
    case getReady

    var id: String { rawValue }

    static let eveningChoices: [Self] = [.read, .shower, .prepareTomorrow, .stretch, .journal, .makeTea]
    static let morningChoices: [Self] = [.openCurtains, .breakfast, .morningWalk, .getReady, .stretch, .journal]

    var title: String {
        switch self {
        case .read: return "Read a paper book"
        case .shower: return "Take a warm shower"
        case .prepareTomorrow: return "Prepare for tomorrow"
        case .stretch: return "Stretch gently"
        case .journal: return "Write on paper"
        case .makeTea: return "Make a warm drink"
        case .openCurtains: return "Open the curtains"
        case .breakfast: return "Make breakfast"
        case .morningWalk: return "Step outside for a walk"
        case .getReady: return "Shower and get dressed"
        }
    }

    var shortTitle: String {
        switch self {
        case .read: return "Read"
        case .shower: return "Shower"
        case .prepareTomorrow: return "Prepare tomorrow"
        case .stretch: return "Stretch"
        case .journal: return "Write"
        case .makeTea: return "Make a drink"
        case .openCurtains: return "Open curtains"
        case .breakfast: return "Make breakfast"
        case .morningWalk: return "Take a walk"
        case .getReady: return "Get ready"
        }
    }

    var systemImage: String {
        switch self {
        case .read: return "book.closed.fill"
        case .shower: return "shower.fill"
        case .prepareTomorrow: return "backpack.fill"
        case .stretch: return "figure.flexibility"
        case .journal: return "pencil.and.scribble"
        case .makeTea: return "mug.fill"
        case .openCurtains: return "sun.max.fill"
        case .breakfast: return "fork.knife"
        case .morningWalk: return "figure.walk"
        case .getReady: return "tshirt.fill"
        }
    }
}

struct NightWatchPreferences: Codable, Equatable {
    var bedtimeHour: Int
    var bedtimeMinute: Int
    var wakeHour: Int
    var wakeMinute: Int
    var windDownMinutes: Int
    var morningQuietMinutes: Int
    var eveningActivity: PhoneFreeActivity
    var morningActivity: PhoneFreeActivity
    var guardKind: SessionGuardKind
    var isConfigured: Bool

    static let defaults = NightWatchPreferences(
        bedtimeHour: 23,
        bedtimeMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
        windDownMinutes: 30,
        morningQuietMinutes: 30,
        eveningActivity: .read,
        morningActivity: .openCurtains,
        guardKind: .honorTimer,
        isConfigured: false
    )

    init(
        bedtimeHour: Int,
        bedtimeMinute: Int,
        wakeHour: Int,
        wakeMinute: Int,
        windDownMinutes: Int,
        morningQuietMinutes: Int,
        eveningActivity: PhoneFreeActivity,
        morningActivity: PhoneFreeActivity,
        guardKind: SessionGuardKind,
        isConfigured: Bool
    ) {
        self.bedtimeHour = min(23, max(0, bedtimeHour))
        self.bedtimeMinute = min(59, max(0, bedtimeMinute))
        self.wakeHour = min(23, max(0, wakeHour))
        self.wakeMinute = min(59, max(0, wakeMinute))
        self.windDownMinutes = min(180, max(15, windDownMinutes))
        self.morningQuietMinutes = min(180, max(15, morningQuietMinutes))
        self.eveningActivity = eveningActivity
        self.morningActivity = morningActivity
        self.guardKind = guardKind
        self.isConfigured = isConfigured
    }

    func bedtimeDate(on referenceDate: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(
            bySettingHour: bedtimeHour,
            minute: bedtimeMinute,
            second: 0,
            of: referenceDate
        ) ?? referenceDate
    }

    func wakeDate(on referenceDate: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(
            bySettingHour: wakeHour,
            minute: wakeMinute,
            second: 0,
            of: referenceDate
        ) ?? referenceDate
    }

    func nextStart(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        let todayBedtime = bedtimeDate(on: date, calendar: calendar)
        let todayStart = calendar.date(byAdding: .minute, value: -windDownMinutes, to: todayBedtime)
            ?? todayBedtime.addingTimeInterval(TimeInterval(-windDownMinutes * 60))
        if todayStart > date { return todayStart }
        let nextBedtime = calendar.date(byAdding: .day, value: 1, to: todayBedtime)
            ?? todayBedtime.addingTimeInterval(24 * 60 * 60)
        return calendar.date(byAdding: .minute, value: -windDownMinutes, to: nextBedtime)
            ?? nextBedtime.addingTimeInterval(TimeInterval(-windDownMinutes * 60))
    }

    func isStartWindowOpen(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let bedtime = nextIntendedBedtime(after: date, calendar: calendar)
        let start = calendar.date(byAdding: .minute, value: -windDownMinutes, to: bedtime)
            ?? bedtime.addingTimeInterval(TimeInterval(-windDownMinutes * 60))
        return date >= start
    }

    func makePlan(startedAt: Date = Date(), calendar: Calendar = .current) -> NightWatchPlan {
        let bedtime = nextIntendedBedtime(after: startedAt, calendar: calendar)
        let wakeComponents = DateComponents(hour: wakeHour, minute: wakeMinute, second: 0)
        let wake = calendar.nextDate(
            after: bedtime,
            matching: wakeComponents,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? bedtime.addingTimeInterval(8 * 60 * 60)
        let protectedUntil = calendar.date(byAdding: .minute, value: morningQuietMinutes, to: wake)
            ?? wake.addingTimeInterval(TimeInterval(morningQuietMinutes * 60))

        return NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: wake,
            protectedUntil: protectedUntil,
            windDownMinutes: windDownMinutes,
            morningQuietMinutes: morningQuietMinutes,
            eveningActivity: eveningActivity,
            morningActivity: morningActivity
        )
    }

    private func nextIntendedBedtime(after date: Date, calendar: Calendar) -> Date {
        let todayBedtime = bedtimeDate(on: date, calendar: calendar)
        if todayBedtime >= date {
            let previousBedtime = calendar.date(byAdding: .day, value: -1, to: todayBedtime)
                ?? todayBedtime.addingTimeInterval(-24 * 60 * 60)
            if date.timeIntervalSince(previousBedtime) <= 6 * 60 * 60 {
                return previousBedtime
            }
            return todayBedtime
        }

        // A start shortly after the chosen bedtime is a late tuck-in for this night,
        // not a session that should wait almost a full day to enter its overnight phase.
        if date.timeIntervalSince(todayBedtime) <= 6 * 60 * 60 {
            return todayBedtime
        }

        return calendar.date(byAdding: .day, value: 1, to: todayBedtime)
            ?? todayBedtime.addingTimeInterval(24 * 60 * 60)
    }
}

struct NightWatchPlan: Codable, Equatable {
    var intendedBedtime: Date
    var wakeTime: Date
    var protectedUntil: Date
    var windDownMinutes: Int
    var morningQuietMinutes: Int
    var eveningActivity: PhoneFreeActivity
    var morningActivity: PhoneFreeActivity

    func phase(at date: Date) -> NightWatchPhase {
        if date >= protectedUntil { return .complete }
        if date >= wakeTime { return .morningQuiet }
        if date >= intendedBedtime { return .overnight }
        return .windDown
    }

    func nextTransition(after date: Date) -> Date? {
        switch phase(at: date) {
        case .windDown: return intendedBedtime
        case .overnight: return wakeTime
        case .morningQuiet: return protectedUntil
        case .complete: return nil
        }
    }

    func creditedWindDownMinutes(startedAt: Date, through endDate: Date? = nil) -> Int {
        let endDate = min(endDate ?? protectedUntil, protectedUntil)
        let plannedWindDownStart = intendedBedtime.addingTimeInterval(TimeInterval(-windDownMinutes * 60))
        let actualWindDownStart = max(startedAt, plannedWindDownStart)
        let actualWindDownEnd = min(endDate, intendedBedtime)
        let eveningSeconds = max(0, actualWindDownEnd.timeIntervalSince(actualWindDownStart))
        return Int(eveningSeconds / 60)
    }

    func creditedMorningQuietMinutes(startedAt: Date, through endDate: Date? = nil) -> Int {
        let endDate = min(endDate ?? protectedUntil, protectedUntil)
        let morningStart = max(startedAt, wakeTime)
        let morningSeconds = max(0, endDate.timeIntervalSince(morningStart))
        return Int(morningSeconds / 60)
    }

    func creditedQuietMinutes(startedAt: Date, through endDate: Date? = nil) -> Int {
        creditedWindDownMinutes(startedAt: startedAt, through: endDate)
            + creditedMorningQuietMinutes(startedAt: startedAt, through: endDate)
    }
}

extension FocusRun {
    var isNightWatch: Bool { nightWatchPlan != nil }

    func nightWatchPhase(at date: Date = Date()) -> NightWatchPhase? {
        nightWatchPlan?.phase(at: date)
    }

    var creditedQuietMinutes: Int {
        nightWatchPlan?.creditedQuietMinutes(startedAt: startedAt, through: quietCreditEndDate)
            ?? max(1, Int(plannedDurationSeconds / 60))
    }

    var creditedWindDownMinutes: Int {
        nightWatchPlan?.creditedWindDownMinutes(startedAt: startedAt, through: quietCreditEndDate) ?? 0
    }

    var creditedMorningQuietMinutes: Int {
        nightWatchPlan?.creditedMorningQuietMinutes(startedAt: startedAt, through: quietCreditEndDate) ?? 0
    }

    var progressDate: Date {
        nightWatchPlan?.intendedBedtime ?? endedAt ?? startedAt
    }

    private var quietCreditEndDate: Date? {
        completedSuccessfully ? plannedEndAt : endedAt
    }
}
