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
    case brushTeeth
    case quietConversation
    case makeBed
    case brainDump
    case sleepwear
    case relaxation
    case quietMusic
    case calmHobby

    var id: String { rawValue }

    static let eveningChoices: [Self] = [
        .journal, .prepareTomorrow, .brainDump,
        .brushTeeth, .shower, .sleepwear,
        .read, .stretch, .relaxation, .quietMusic,
        .makeTea, .quietConversation, .calmHobby
    ]
    static let morningChoices: [Self] = [
        .openCurtains, .morningWalk, .getReady, .breakfast,
        .makeBed, .stretch, .journal
    ]

    var title: String {
        switch self {
        case .read: return "Read a paper book"
        case .shower: return "Warm shower or bath"
        case .prepareTomorrow: return "Prepare tomorrow’s clothes or bag"
        case .stretch: return "Stretch or move gently"
        case .journal: return "Write tomorrow’s top 3"
        case .makeTea: return "Make a caffeine-free warm drink"
        case .openCurtains: return "Open the curtains"
        case .breakfast: return "Make breakfast"
        case .morningWalk: return "Step outside for a short walk"
        case .getReady: return "Shower and get dressed"
        case .brushTeeth: return "Brush teeth or do skincare"
        case .quietConversation: return "Chat with someone"
        case .makeBed: return "Make the bed"
        case .brainDump: return "Jot down what’s still on your mind"
        case .sleepwear: return "Change into sleepwear"
        case .relaxation: return "Breathing or relaxation"
        case .quietMusic: return "Listen to quiet music"
        case .calmHobby: return "Spend time on a calm hobby"
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
        case .brushTeeth: return "Brush teeth"
        case .quietConversation: return "Quiet conversation"
        case .makeBed: return "Make the bed"
        case .brainDump: return "Jot it down"
        case .sleepwear: return "Change clothes"
        case .relaxation: return "Breathe"
        case .quietMusic: return "Quiet music"
        case .calmHobby: return "Calm hobby"
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
        case .brushTeeth: return "sparkles"
        case .quietConversation: return "bubble.left.and.bubble.right.fill"
        case .makeBed: return "bed.double.fill"
        case .brainDump: return "note.text"
        case .sleepwear: return "moon.fill"
        case .relaxation: return "wind"
        case .quietMusic: return "music.note"
        case .calmHobby: return "paintbrush.fill"
        }
    }

    var onboardingRationale: String {
        switch self {
        case .journal:
            return "Putting tomorrow’s priorities on paper can help the evening feel more closed."
        case .prepareTomorrow:
            return "A little preparation now can make the next morning feel less hurried."
        case .brainDump:
            return "Giving unfinished thoughts a place on paper can help you leave them there for tonight."
        case .brushTeeth:
            return "A familiar getting-ready routine can become a simple cue that the day is closing."
        case .shower:
            return "A warm routine can help mark the transition into a quieter part of the evening."
        case .sleepwear:
            return "Changing clothes is a small, familiar signal that the active part of the day is done."
        case .read:
            return "A paper book offers a quieter way to let the last part of the evening slow down."
        case .stretch:
            return "Gentle movement can create a clear pause between a busy day and rest."
        case .relaxation:
            return "A few unhurried breaths can give the evening a softer pace."
        case .quietMusic:
            return "Quiet music can give your attention somewhere calm to settle."
        case .makeTea:
            return "A warm caffeine-free drink can make the phone-away moment feel more inviting."
        case .quietConversation:
            return "A quiet conversation keeps connection in the evening without returning to the feed."
        case .calmHobby:
            return "A familiar hands-on activity can make offline time feel like something to look forward to."
        case .openCurtains:
            return "Morning light gives your attention somewhere gentle to go before the phone."
        case .morningWalk:
            return "A short step outside can help the morning begin in the world around you."
        case .getReady:
            return "Getting ready first creates a natural boundary before the phone returns."
        case .breakfast:
            return "Breakfast gives the first part of morning a simple purpose of its own."
        case .makeBed:
            return "One small finished action can help the morning feel underway."
        }
    }
}

enum PhoneFreeCue {
    static let maximumTextLength = 80

    static func normalized(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // TextEditor drafts may contain a line break. Keep the persisted cue a
        // single-line label, while preserving ordinary spaces exactly as the
        // person entered them (including a space between words).
        let singleLine = trimmed.contains(where: { $0.isNewline })
            ? trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            : trimmed
        guard !singleLine.isEmpty else { return nil }
        return String(singleLine.prefix(maximumTextLength))
    }
}

enum WindDownRoutinePhase: String, Codable, CaseIterable, Hashable {
    case evening
    case morning
}

enum WindDownRoutineStepKind: String, Codable, CaseIterable, Hashable {
    case suggestion
    case custom
}

/// A private invitation in the Wind Down sequence. The model intentionally has
/// no completion field: choosing an idea is not a promise that it happened.
struct WindDownRoutineStep: Codable, Equatable, Identifiable, Hashable {
    static let maximumEveningCount = 3
    static let maximumMorningCount = 2
    static let phoneAwayTitle = "Put phone away"

    let id: UUID
    let phase: WindDownRoutinePhase
    let kind: WindDownRoutineStepKind
    let activity: PhoneFreeActivity?
    let customText: String?
    let guidanceID: String?

    init(
        id: UUID = UUID(),
        phase: WindDownRoutinePhase,
        kind: WindDownRoutineStepKind,
        activity: PhoneFreeActivity? = nil,
        customText: String? = nil,
        guidanceID: String? = nil
    ) {
        self.id = id
        self.phase = phase
        self.kind = kind
        self.activity = kind == .suggestion ? activity : nil
        self.customText = kind == .custom ? PhoneFreeCue.normalized(customText) : nil
        self.guidanceID = kind == .suggestion ? guidanceID : nil
    }

    static func suggested(
        _ activity: PhoneFreeActivity,
        phase: WindDownRoutinePhase,
        id: UUID = UUID(),
        guidanceID: String? = nil
    ) -> Self {
        Self(
            id: id,
            phase: phase,
            kind: .suggestion,
            activity: activity,
            guidanceID: guidanceID ?? activity.defaultGuidanceID(for: phase)
        )
    }

    static func custom(
        _ text: String,
        phase: WindDownRoutinePhase,
        id: UUID = UUID()
    ) -> Self {
        Self(id: id, phase: phase, kind: .custom, customText: text)
    }

    var title: String {
        switch kind {
        case .suggestion:
            return activity?.title ?? "Quiet idea"
        case .custom:
            return customText ?? "Quiet idea"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, phase, kind, activity, customText, guidanceID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        phase = try container.decodeIfPresent(WindDownRoutinePhase.self, forKey: .phase) ?? .evening
        kind = try container.decodeIfPresent(WindDownRoutineStepKind.self, forKey: .kind) ?? .custom
        activity = kind == .suggestion
            ? try container.decodeIfPresent(PhoneFreeActivity.self, forKey: .activity)
            : nil
        customText = kind == .custom
            ? PhoneFreeCue.normalized(try container.decodeIfPresent(String.self, forKey: .customText))
            : nil
        guidanceID = kind == .suggestion
            ? try container.decodeIfPresent(String.self, forKey: .guidanceID)
            : nil
    }

    static func normalized(
        _ steps: [Self],
        for phase: WindDownRoutinePhase
    ) -> [Self] {
        let limit = phase == .evening ? maximumEveningCount : maximumMorningCount
        var normalized: [Self] = []
        var seenActivities = Set<PhoneFreeActivity>()

        for step in steps where normalized.count < limit && step.phase == phase {
            switch step.kind {
            case .suggestion:
                guard let activity = step.activity, !seenActivities.contains(activity) else { continue }
                seenActivities.insert(activity)
                normalized.append(
                    Self.suggested(
                        activity,
                        phase: phase,
                        id: step.id,
                        guidanceID: step.guidanceID
                    )
                )
            case .custom:
                guard let text = PhoneFreeCue.normalized(step.customText), !isPhoneAwayText(text) else {
                    continue
                }
                normalized.append(Self.custom(text, phase: phase, id: step.id))
            }
        }
        return normalized
    }

    static func migrated(
        phase: WindDownRoutinePhase,
        activity: PhoneFreeActivity,
        cueText: String?
    ) -> [Self] {
        if let cueText = PhoneFreeCue.normalized(cueText) {
            return [custom(cueText, phase: phase)]
        }
        return [suggested(activity, phase: phase)]
    }

    private static func isPhoneAwayText(_ text: String) -> Bool {
        let compact = text
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        return ["putphoneaway", "putthephoneaway", "phoneaway"].contains(compact)
    }
}

private extension PhoneFreeActivity {
    func defaultGuidanceID(for phase: WindDownRoutinePhase) -> String? {
        switch (phase, self) {
        case (.evening, .read), (.evening, .makeTea): return "quiet-hour"
        case (.evening, .journal): return "rest-not-performance"
        case (.evening, .shower): return "calm-room"
        case (.morning, .openCurtains), (.morning, .morningWalk): return "morning-light"
        default: return nil
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
    var eveningCueText: String?
    var morningCueText: String?
    var eveningRoutine: [WindDownRoutineStep]
    var morningRoutine: [WindDownRoutineStep]
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
        // Fresh plans show examples in the authoring UI, but do not enroll
        // them without the person choosing them.
        eveningRoutine: [],
        morningRoutine: [],
        guardKind: .nfcTag,
        isConfigured: false,
        automaticStartEnabled: false
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
        eveningRoutine: [WindDownRoutineStep]? = nil,
        morningRoutine: [WindDownRoutineStep]? = nil,
        guardKind: SessionGuardKind,
        isConfigured: Bool,
        automaticStartEnabled: Bool = false
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
        self.eveningRoutine = Self.normalizedRoutine(
            eveningRoutine,
            phase: .evening,
            activity: eveningActivity,
            cueText: self.eveningCueText
        )
        self.morningRoutine = Self.normalizedRoutine(
            morningRoutine,
            phase: .morning,
            activity: morningActivity,
            cueText: self.morningCueText
        )
        self.guardKind = guardKind
        self.isConfigured = isConfigured
        self.automaticStartEnabled = automaticStartEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case bedtimeHour, bedtimeMinute, wakeHour, wakeMinute
        case windDownMinutes, morningQuietMinutes, eveningActivity, morningActivity
        case eveningCueText, morningCueText
        case eveningRoutine, morningRoutine
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
        eveningRoutine = Self.normalizedRoutine(
            try container.decodeIfPresent([WindDownRoutineStep].self, forKey: .eveningRoutine),
            phase: .evening,
            activity: eveningActivity,
            cueText: eveningCueText
        )
        morningRoutine = Self.normalizedRoutine(
            try container.decodeIfPresent([WindDownRoutineStep].self, forKey: .morningRoutine),
            phase: .morning,
            activity: morningActivity,
            cueText: morningCueText
        )
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
            morningCueText: morningCueText,
            eveningRoutine: eveningRoutine,
            morningRoutine: morningRoutine
        )
    }

    var presentedEveningRoutineTitles: [String] {
        [WindDownRoutineStep.phoneAwayTitle] + eveningRoutine.map(\.title)
    }

    var presentedMorningRoutineTitles: [String] {
        morningRoutine.map(\.title)
    }

    /// Keeps old readers useful when a person edits the new sequence. The new
    /// arrays remain authoritative; these fields stay as a rollback bridge.
    mutating func syncLegacyFieldsFromRoutine() {
        eveningCueText = eveningRoutine.first?.kind == .custom
            ? eveningRoutine.first?.customText
            : nil
        if let activity = eveningRoutine.first?.activity { eveningActivity = activity }
        morningCueText = morningRoutine.first?.kind == .custom
            ? morningRoutine.first?.customText
            : nil
        if let activity = morningRoutine.first?.activity { morningActivity = activity }
    }

    private static func normalizedRoutine(
        _ steps: [WindDownRoutineStep]?,
        phase: WindDownRoutinePhase,
        activity: PhoneFreeActivity,
        cueText: String?
    ) -> [WindDownRoutineStep] {
        guard let steps else {
            return WindDownRoutineStep.normalized(
                WindDownRoutineStep.migrated(phase: phase, activity: activity, cueText: cueText),
                for: phase
            )
        }
        return WindDownRoutineStep.normalized(steps, for: phase)
    }

    private func nextIntendedBedtime(after date: Date, calendar: Calendar) -> Date {
        let todayBedtime = bedtimeDate(on: date, calendar: calendar)
        let candidateBedtimes = [
            calendar.date(byAdding: .day, value: -1, to: todayBedtime) ?? todayBedtime,
            todayBedtime,
            calendar.date(byAdding: .day, value: 1, to: todayBedtime) ?? todayBedtime
        ]

        // A run restarted after an early end belongs to the same local bedtime
        // until its protected morning window has ended. Comparing complete,
        // calendar-built windows avoids guessing based on elapsed hours, which
        // can cross a DST boundary or leave a late-morning restart ambiguous.
        for bedtime in candidateBedtimes {
            guard let window = ritualWindow(around: bedtime, calendar: calendar) else { continue }
            if date >= window.start && date < window.protectedUntil {
                return bedtime
            }
        }

        // No preceding window is active. The next bedtime after the current date
        // is the only valid anchor for a new evening ritual.
        return candidateBedtimes.first(where: { $0 >= date })
            ?? calendar.date(byAdding: .day, value: 2, to: todayBedtime)
            ?? todayBedtime.addingTimeInterval(2 * 24 * 60 * 60)
    }

    private func ritualWindow(
        around bedtime: Date,
        calendar: Calendar
    ) -> (start: Date, wake: Date, protectedUntil: Date)? {
        let start = calendar.date(byAdding: .minute, value: -windDownMinutes, to: bedtime)
            ?? bedtime.addingTimeInterval(TimeInterval(-windDownMinutes * 60))
        let wakeComponents = DateComponents(hour: wakeHour, minute: wakeMinute, second: 0)
        guard let wake = calendar.nextDate(
            after: bedtime,
            matching: wakeComponents,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else { return nil }
        let protectedUntil = calendar.date(
            byAdding: .minute,
            value: morningQuietMinutes,
            to: wake
        ) ?? wake.addingTimeInterval(TimeInterval(morningQuietMinutes * 60))
        return (start, wake, protectedUntil)
    }
}

struct AutomaticWindDownSchedule: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    let id: UUID
    let startedAt: Date
    let plan: NightWatchPlan
    let sourceOccurrenceID: UUID?
    /// Captures future intent separately from Screen Time readiness. Older
    /// schedules default on for backwards-compatible migration.
    let appShieldingRequested: Bool

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, startedAt, plan, sourceOccurrenceID, appShieldingRequested
    }

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID = UUID(),
        startedAt: Date,
        plan: NightWatchPlan,
        sourceOccurrenceID: UUID? = nil,
        appShieldingRequested: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.startedAt = startedAt
        self.plan = plan
        self.sourceOccurrenceID = sourceOccurrenceID
        self.appShieldingRequested = appShieldingRequested
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        plan = try container.decode(NightWatchPlan.self, forKey: .plan)
        sourceOccurrenceID = try container.decodeIfPresent(UUID.self, forKey: .sourceOccurrenceID)
        appShieldingRequested = try container.decodeIfPresent(Bool.self, forKey: .appShieldingRequested) ?? true
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
    var eveningRoutine: [WindDownRoutineStep]
    var morningRoutine: [WindDownRoutineStep]
    /// Primary plans span the sleep bookends. Additional plans are standalone
    /// quiet intervals and must not advance protected-night progression.
    var role: WindDownOccurrenceRole

    private enum CodingKeys: String, CodingKey {
        case intendedBedtime, wakeTime, protectedUntil, windDownMinutes, morningQuietMinutes
        case eveningActivity, morningActivity, eveningCueText, morningCueText
        case eveningRoutine, morningRoutine, role
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
        eveningRoutine: [WindDownRoutineStep]? = nil,
        morningRoutine: [WindDownRoutineStep]? = nil,
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
        self.eveningRoutine = WindDownRoutineStep.normalized(
            eveningRoutine ?? WindDownRoutineStep.migrated(
                phase: .evening,
                activity: eveningActivity,
                cueText: self.eveningCueText
            ),
            for: .evening
        )
        self.morningRoutine = WindDownRoutineStep.normalized(
            morningRoutine ?? WindDownRoutineStep.migrated(
                phase: .morning,
                activity: morningActivity,
                cueText: self.morningCueText
            ),
            for: .morning
        )
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
        eveningRoutine = WindDownRoutineStep.normalized(
            try container.decodeIfPresent([WindDownRoutineStep].self, forKey: .eveningRoutine)
                ?? WindDownRoutineStep.migrated(
                    phase: .evening,
                    activity: eveningActivity,
                    cueText: eveningCueText
                ),
            for: .evening
        )
        morningRoutine = WindDownRoutineStep.normalized(
            try container.decodeIfPresent([WindDownRoutineStep].self, forKey: .morningRoutine)
                ?? WindDownRoutineStep.migrated(
                    phase: .morning,
                    activity: morningActivity,
                    cueText: morningCueText
                ),
            for: .morning
        )
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

    func eveningRoutineSummary(allowsPersonalText: Bool) -> String {
        guard allowsPersonalText else { return WindDownRoutineStep.phoneAwayTitle }
        let titles = [WindDownRoutineStep.phoneAwayTitle] + eveningRoutine.map(\.title)
        return titles.joined(separator: " · ")
    }

    func morningRoutineSummary(allowsPersonalText: Bool) -> String? {
        guard allowsPersonalText else { return nil }
        let titles = morningRoutine.map(\.title)
        guard !titles.isEmpty else { return nil }
        return titles.joined(separator: " · ")
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
        // Qualification is independent from the factual bookends. An
        // authorized terminal Wind Down may be entitled after 420 protected
        // minutes without claiming a planned Screen-Free Morning that never
        // happened.
        endedAt ?? (completedSuccessfully ? plannedEndAt : nil)
    }
}
