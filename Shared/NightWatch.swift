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

enum PhoneFreeCue {
    static let maximumTextLength = 80

    static func normalized(_ text: String?) -> String? {
        guard let text else { return nil }
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maximumTextLength))
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
    var eveningCueText: String?
    var morningCueText: String?
    var guardKind: SessionGuardKind
    var isConfigured: Bool
    var automaticStartEnabled: Bool

    static let defaults = NightWatchPreferences(
        bedtimeHour: 23,
        bedtimeMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
        windDownMinutes: 30,
        morningQuietMinutes: 30,
        eveningActivity: .read,
        morningActivity: .openCurtains,
        eveningCueText: nil,
        morningCueText: nil,
        guardKind: .nfcTag,
        isConfigured: false,
        automaticStartEnabled: true
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
        eveningCueText: String? = nil,
        morningCueText: String? = nil,
        guardKind: SessionGuardKind,
        isConfigured: Bool,
        automaticStartEnabled: Bool = true
    ) {
        self.bedtimeHour = min(23, max(0, bedtimeHour))
        self.bedtimeMinute = min(59, max(0, bedtimeMinute))
        self.wakeHour = min(23, max(0, wakeHour))
        self.wakeMinute = min(59, max(0, wakeMinute))
        self.windDownMinutes = min(180, max(15, windDownMinutes))
        self.morningQuietMinutes = min(180, max(15, morningQuietMinutes))
        self.eveningActivity = eveningActivity
        self.morningActivity = morningActivity
        self.eveningCueText = PhoneFreeCue.normalized(eveningCueText)
        self.morningCueText = PhoneFreeCue.normalized(morningCueText)
        self.guardKind = guardKind
        self.isConfigured = isConfigured
        self.automaticStartEnabled = automaticStartEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case bedtimeHour, bedtimeMinute, wakeHour, wakeMinute
        case windDownMinutes, morningQuietMinutes, eveningActivity, morningActivity
        case eveningCueText, morningCueText
        case guardKind, isConfigured, automaticStartEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bedtimeHour = min(23, max(0, try container.decodeIfPresent(Int.self, forKey: .bedtimeHour) ?? Self.defaults.bedtimeHour))
        bedtimeMinute = min(59, max(0, try container.decodeIfPresent(Int.self, forKey: .bedtimeMinute) ?? Self.defaults.bedtimeMinute))
        wakeHour = min(23, max(0, try container.decodeIfPresent(Int.self, forKey: .wakeHour) ?? Self.defaults.wakeHour))
        wakeMinute = min(59, max(0, try container.decodeIfPresent(Int.self, forKey: .wakeMinute) ?? Self.defaults.wakeMinute))
        windDownMinutes = min(180, max(15, try container.decodeIfPresent(Int.self, forKey: .windDownMinutes) ?? Self.defaults.windDownMinutes))
        morningQuietMinutes = min(180, max(15, try container.decodeIfPresent(Int.self, forKey: .morningQuietMinutes) ?? Self.defaults.morningQuietMinutes))
        eveningActivity = try container.decodeIfPresent(PhoneFreeActivity.self, forKey: .eveningActivity) ?? Self.defaults.eveningActivity
        morningActivity = try container.decodeIfPresent(PhoneFreeActivity.self, forKey: .morningActivity) ?? Self.defaults.morningActivity
        eveningCueText = PhoneFreeCue.normalized(try container.decodeIfPresent(String.self, forKey: .eveningCueText))
        morningCueText = PhoneFreeCue.normalized(try container.decodeIfPresent(String.self, forKey: .morningCueText))
        guardKind = try container.decodeIfPresent(SessionGuardKind.self, forKey: .guardKind) ?? Self.defaults.guardKind
        isConfigured = try container.decodeIfPresent(Bool.self, forKey: .isConfigured) ?? false
        // Existing saved plans should not silently begin shielding or sessions after an update.
        automaticStartEnabled = try container.decodeIfPresent(Bool.self, forKey: .automaticStartEnabled) ?? false
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
            morningActivity: morningActivity,
            eveningCueText: eveningCueText,
            morningCueText: morningCueText
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

struct AutomaticWindDownSchedule: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    let id: UUID
    let startedAt: Date
    let plan: NightWatchPlan
    let sourceOccurrenceID: UUID?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, startedAt, plan, sourceOccurrenceID
    }

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID = UUID(),
        startedAt: Date,
        plan: NightWatchPlan,
        sourceOccurrenceID: UUID? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.startedAt = startedAt
        self.plan = plan
        self.sourceOccurrenceID = sourceOccurrenceID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        plan = try container.decode(NightWatchPlan.self, forKey: .plan)
        sourceOccurrenceID = try container.decodeIfPresent(UUID.self, forKey: .sourceOccurrenceID)
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
    var eveningCueText: String?
    var morningCueText: String?
    /// Primary plans span the sleep bookends. Additional plans are standalone
    /// quiet intervals and must not advance protected-night progression.
    var role: WindDownOccurrenceRole

    private enum CodingKeys: String, CodingKey {
        case intendedBedtime, wakeTime, protectedUntil, windDownMinutes, morningQuietMinutes
        case eveningActivity, morningActivity, eveningCueText, morningCueText, role
    }

    init(
        intendedBedtime: Date,
        wakeTime: Date,
        protectedUntil: Date,
        windDownMinutes: Int,
        morningQuietMinutes: Int,
        eveningActivity: PhoneFreeActivity,
        morningActivity: PhoneFreeActivity,
        eveningCueText: String? = nil,
        morningCueText: String? = nil,
        role: WindDownOccurrenceRole = .primarySleepBookend
    ) {
        self.intendedBedtime = intendedBedtime
        self.wakeTime = wakeTime
        self.protectedUntil = protectedUntil
        self.windDownMinutes = max(0, windDownMinutes)
        self.morningQuietMinutes = max(0, morningQuietMinutes)
        self.eveningActivity = eveningActivity
        self.morningActivity = morningActivity
        self.eveningCueText = PhoneFreeCue.normalized(eveningCueText)
        self.morningCueText = PhoneFreeCue.normalized(morningCueText)
        self.role = role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        intendedBedtime = try container.decode(Date.self, forKey: .intendedBedtime)
        wakeTime = try container.decode(Date.self, forKey: .wakeTime)
        protectedUntil = try container.decode(Date.self, forKey: .protectedUntil)
        windDownMinutes = max(0, try container.decodeIfPresent(Int.self, forKey: .windDownMinutes) ?? 0)
        morningQuietMinutes = max(0, try container.decodeIfPresent(Int.self, forKey: .morningQuietMinutes) ?? 0)
        eveningActivity = try container.decodeIfPresent(PhoneFreeActivity.self, forKey: .eveningActivity) ?? .read
        morningActivity = try container.decodeIfPresent(PhoneFreeActivity.self, forKey: .morningActivity) ?? .openCurtains
        eveningCueText = PhoneFreeCue.normalized(try container.decodeIfPresent(String.self, forKey: .eveningCueText))
        morningCueText = PhoneFreeCue.normalized(try container.decodeIfPresent(String.self, forKey: .morningCueText))
        role = try container.decodeIfPresent(WindDownOccurrenceRole.self, forKey: .role) ?? .primarySleepBookend
    }

    static func additionalQuiet(
        start: Date,
        end: Date,
        activity: PhoneFreeActivity = .read,
        cueText: String? = nil
    ) -> Self {
        let minutes = max(0, Int(end.timeIntervalSince(start) / 60))
        return Self(
            intendedBedtime: start,
            wakeTime: end,
            protectedUntil: end,
            windDownMinutes: minutes,
            morningQuietMinutes: 0,
            eveningActivity: activity,
            morningActivity: .openCurtains,
            eveningCueText: cueText,
            role: .additionalQuiet
        )
    }

    func phase(at date: Date) -> NightWatchPhase {
        if role == .additionalQuiet {
            return date >= protectedUntil ? .complete : .windDown
        }
        if date >= protectedUntil { return .complete }
        if date >= wakeTime { return .morningQuiet }
        if date >= intendedBedtime { return .overnight }
        return .windDown
    }

    var eveningActivityTitle: String {
        eveningCueText ?? eveningActivity.shortTitle
    }

    var morningActivityTitle: String {
        morningCueText ?? morningActivity.shortTitle
    }

    func eveningNotificationActivityTitle(allowsPersonalText: Bool) -> String? {
        if eveningCueText != nil && !allowsPersonalText { return nil }
        return eveningActivityTitle
    }

    func morningNotificationActivityTitle(allowsPersonalText: Bool) -> String? {
        if morningCueText != nil && !allowsPersonalText { return nil }
        return morningActivityTitle
    }

    func nextTransition(after date: Date) -> Date? {
        if role == .additionalQuiet {
            return date < protectedUntil ? protectedUntil : nil
        }
        switch phase(at: date) {
        case .windDown: return intendedBedtime
        case .overnight: return wakeTime
        case .morningQuiet: return protectedUntil
        case .complete: return nil
        }
    }

    func creditedWindDownMinutes(startedAt: Date, through endDate: Date? = nil) -> Int {
        if role == .additionalQuiet {
            let endDate = min(endDate ?? protectedUntil, protectedUntil)
            let actualStart = max(startedAt, intendedBedtime)
            return max(0, Int(max(0, endDate.timeIntervalSince(actualStart)) / 60))
        }
        let endDate = min(endDate ?? protectedUntil, protectedUntil)
        let plannedWindDownStart = intendedBedtime.addingTimeInterval(TimeInterval(-windDownMinutes * 60))
        let actualWindDownStart = max(startedAt, plannedWindDownStart)
        let actualWindDownEnd = min(endDate, intendedBedtime)
        let eveningSeconds = max(0, actualWindDownEnd.timeIntervalSince(actualWindDownStart))
        return Int(eveningSeconds / 60)
    }

    func creditedMorningQuietMinutes(startedAt: Date, through endDate: Date? = nil) -> Int {
        guard role == .primarySleepBookend else { return 0 }
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

    var isProgressionEligibleNightWatch: Bool {
        nightWatchPlan?.role.isProgressionEligible ?? false
    }

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
