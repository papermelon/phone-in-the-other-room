import Foundation

enum WindDownPhonePlacement: String, Codable, CaseIterable, Identifiable {
    case anotherRoom
    case accessibleNearby

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anotherRoom: return "Outside your bedroom"
        case .accessibleNearby: return "Accessible nearby"
        }
    }

    var detail: String {
        switch self {
        case .anotherRoom:
            return "Choose a place in another room for your phone around bedtime."
        case .accessibleNearby:
            return "Keep your phone nearby if you need it for communication or alerts. Review which apps you select for protection."
        }
    }

    var actionCue: String {
        switch self {
        case .anotherRoom: return "Put your phone outside your bedroom"
        case .accessibleNearby: return "Set your phone in its chosen nearby place"
        }
    }
}

/// Private planning support. These invitations never establish that an activity happened.
struct WindDownHabitPlan: Codable, Equatable {
    static let storageKey = "ollie.windDown.habitPlan"
    static let maximumContextLength = 120
    static let maximumActivityLength = PhoneFreeCue.maximumTextLength

    var cue: String?
    var morningCue: String?
    var preparation: String?
    var smallerActivity: String?
    var phonePlacement: WindDownPhonePlacement
    var useSmallerVersionNextTime: Bool
    var smallerVersionSelectionID: UUID?

    init(
        cue: String? = nil,
        morningCue: String? = nil,
        preparation: String? = nil,
        smallerActivity: String? = nil,
        phonePlacement: WindDownPhonePlacement = .anotherRoom,
        useSmallerVersionNextTime: Bool = false,
        smallerVersionSelectionID: UUID? = nil
    ) {
        self.cue = Self.normalizedText(cue, limit: Self.maximumContextLength)
        self.morningCue = Self.normalizedText(morningCue, limit: Self.maximumContextLength)
        self.preparation = Self.normalizedText(preparation, limit: Self.maximumContextLength)
        self.smallerActivity = PhoneFreeCue.normalized(smallerActivity)
        self.phonePlacement = phonePlacement
        self.useSmallerVersionNextTime = useSmallerVersionNextTime && Self.isValidSmallerActivity(self.smallerActivity)
        self.smallerVersionSelectionID = self.useSmallerVersionNextTime
            ? smallerVersionSelectionID ?? UUID()
            : nil
    }

    func normalized() -> Self {
        Self(
            cue: cue,
            morningCue: morningCue,
            preparation: preparation,
            smallerActivity: smallerActivity,
            phonePlacement: phonePlacement,
            useSmallerVersionNextTime: useSmallerVersionNextTime,
            smallerVersionSelectionID: smallerVersionSelectionID
        )
    }

    var hasSmallerVersion: Bool {
        WindDownHabitRules.smallerActivityInvitation(for: self) != nil
    }

    private enum CodingKeys: String, CodingKey {
        case cue, morningCue, preparation, smallerActivity, phonePlacement, useSmallerVersionNextTime, smallerVersionSelectionID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            cue: try container.decodeIfPresent(String.self, forKey: .cue),
            morningCue: try container.decodeIfPresent(String.self, forKey: .morningCue),
            preparation: try container.decodeIfPresent(String.self, forKey: .preparation),
            smallerActivity: try container.decodeIfPresent(String.self, forKey: .smallerActivity),
            phonePlacement: try container.decodeIfPresent(String.self, forKey: .phonePlacement)
                .flatMap(WindDownPhonePlacement.init(rawValue:)) ?? .anotherRoom,
            useSmallerVersionNextTime: try container.decodeIfPresent(Bool.self, forKey: .useSmallerVersionNextTime) ?? false,
            smallerVersionSelectionID: try container.decodeIfPresent(UUID.self, forKey: .smallerVersionSelectionID)
        )
    }

    private static func normalizedText(_ text: String?, limit: Int) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(limit))
    }

    private static func isValidSmallerActivity(_ text: String?) -> Bool {
        guard let text else { return false }
        return !WindDownRoutineStep.normalized([.custom(text, phase: .evening)], for: .evening).isEmpty
    }
}

enum WindDownStartingEase: String, Codable, CaseIterable, Identifiable {
    case easy, mixed, hard, notTried, notSure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy to begin"
        case .mixed: return "Somewhere in between"
        case .hard: return "Hard to begin"
        case .notTried: return "I didn’t try it"
        case .notSure: return "Not sure"
        }
    }
}

enum WindDownHabitEditFocus: String, CaseIterable, Identifiable {
    case activity, cue, preparation, smallerVersion, access

    var id: String { rawValue }
}

enum WindDownObstacle: String, Codable, CaseIterable, Identifiable {
    case forgot, tooMuch, rushed, notAppealing, neededPhone, timing, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forgot: return "It slipped my mind"
        case .tooMuch: return "It felt like too much"
        case .rushed: return "It felt rushed"
        case .notAppealing: return "I wanted something else"
        case .neededPhone: return "I needed my phone"
        case .timing: return "The timing didn’t fit"
        case .other: return "Something else"
        }
    }

    var editFocus: WindDownHabitEditFocus {
        switch self {
        case .forgot: return .cue
        case .tooMuch, .rushed: return .smallerVersion
        case .notAppealing, .timing: return .activity
        case .neededPhone: return .access
        case .other: return .preparation
        }
    }

    var adjustmentTitle: String {
        switch self {
        case .forgot: return "Choose a familiar cue"
        case .tooMuch, .rushed: return "Make room for a smaller version"
        case .notAppealing: return "Choose something to look forward to"
        case .neededPhone: return "Review what needs to stay available"
        case .timing: return "Review your plan"
        case .other: return "Consider what would help"
        }
    }

    var adjustmentBody: String {
        switch self {
        case .forgot:
            return "You could link your first activity to something you already do."
        case .tooMuch, .rushed:
            return "You could choose one small activity for a difficult evening. Your timing stays the same."
        case .notAppealing:
            return "You can replace an idea with something you would enjoy."
        case .neededPhone:
            return "Review your selected apps and the communication or alerts you need."
        case .timing:
            return "You can review your activities here. To change your schedule, open Plan and edit the timing."
        case .other:
            return "You could prepare something beforehand, or leave your plan as it is."
        }
    }
}

/// Optional self-report, independent of session history, sleep questions, and rewards.
struct WindDownHabitReflection: Codable, Equatable, Identifiable {
    let day: Date
    /// Immutable Gregorian civil day; absent on older, unanchored reflections.
    let localDate: NightFlockLocalDate?
    var mode: WindDownRoutinePhase = .evening
    var experience: RitualExperienceFeedback?
    var ease: WindDownStartingEase?
    var obstacle: WindDownObstacle?

    var id: Date { localDate?.date(in: "UTC", calendar: Self.civilCalendar(.current)) ?? day }
    var isEmpty: Bool { ease == nil && obstacle == nil && experience?.answer == nil && experience?.context == nil }
    var displayDay: Date { displayDay(in: .current) }

    init(
        day: Date,
        ease: WindDownStartingEase? = nil,
        obstacle: WindDownObstacle? = nil,
        calendar: Calendar = .current,
        mode: WindDownRoutinePhase = .evening
    ) {
        self.mode = mode
        self.day = calendar.startOfDay(for: day)
        self.localDate = Self.civilDate(for: day, calendar: calendar)
        self.ease = ease
        self.obstacle = obstacle
    }

    func displayDay(in calendar: Calendar) -> Date {
        localDate?.date(in: calendar.timeZone.identifier, calendar: Self.civilCalendar(calendar)) ?? day
    }

    fileprivate static func civilDate(for day: Date, calendar: Calendar) -> NightFlockLocalDate? {
        NightFlockLocalDate(date: day, timeZoneIdentifier: calendar.timeZone.identifier, calendar: civilCalendar(calendar))
    }

    private static func civilCalendar(_ source: Calendar) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = source.timeZone
        return calendar
    }

    private enum CodingKeys: String, CodingKey {
        case day, localDate, ease, obstacle, mode, experience
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let day = try container.decodeIfPresent(Date.self, forKey: .day) else {
            // An undated partial entry cannot be attributed to today's routine.
            self.day = .distantPast
            localDate = nil
            ease = nil
            obstacle = nil
            return
        }
        self.day = day
        mode = try container.decodeIfPresent(WindDownRoutinePhase.self, forKey: .mode) ?? .evening
        experience = try container.decodeIfPresent(RitualExperienceFeedback.self, forKey: .experience)
        if let text = experience?.context {
            experience?.context = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240))
        }
        // A legacy absolute date cannot reveal its original time zone. Preserve
        // it without inventing an anchor; current-zone lookup remains approximate.
        localDate = try container.decodeIfPresent(NightFlockLocalDate.self, forKey: .localDate)
        if let localDate {
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(secondsFromGMT: 0)!
            guard let date = localDate.date(in: "UTC", calendar: utc),
                  Self.civilDate(for: date, calendar: utc) == localDate else {
                throw DecodingError.dataCorruptedError(forKey: .localDate, in: container, debugDescription: "Invalid reflection civil date")
            }
        }
        ease = try container.decodeIfPresent(String.self, forKey: .ease).flatMap(WindDownStartingEase.init(rawValue:))
        obstacle = try container.decodeIfPresent(String.self, forKey: .obstacle).flatMap(WindDownObstacle.init(rawValue:))
    }
}

struct WindDownHabitReflectionHistory: Codable, Equatable {
    static let storageKey = "ollie.windDown.habitReflections"
    static let maximumEntryCount = 45

    private(set) var entries: [WindDownHabitReflection]

    init(entries: [WindDownHabitReflection] = [], calendar: Calendar = .current) {
        self.entries = Self.compacted(entries, calendar: calendar)
    }

    func entry(for date: Date, calendar: Calendar = .current, mode: WindDownRoutinePhase = .evening) -> WindDownHabitReflection? {
        let localDate = WindDownHabitReflection.civilDate(for: date, calendar: calendar)
        return entries.first {
            guard $0.mode == mode else { return false }
            if let anchor = $0.localDate { return anchor == localDate }
            return calendar.isDate($0.day, inSameDayAs: date)
        }
    }

    mutating func upsert(_ entry: WindDownHabitReflection, calendar: Calendar = .current) {
        entries = Self.compacted(entries + [entry], calendar: calendar)
    }

    private enum CodingKeys: String, CodingKey {
        case entries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Anchors retain their civil identity across travel. Preserve unanchored
        // legacy timestamps without assigning an assumed original time zone.
        entries = Self.compacted(
            try container.decodeIfPresent([WindDownHabitReflection].self, forKey: .entries) ?? [],
            calendar: nil
        )
    }

    private static func compacted(
        _ entries: [WindDownHabitReflection],
        calendar: Calendar?
    ) -> [WindDownHabitReflection] {
        var unique: [ModeDayIdentity: WindDownHabitReflection] = [:]
        for entry in entries {
            let approximateLegacyDate = calendar.flatMap {
                WindDownHabitReflection.civilDate(for: entry.day, calendar: $0)
            }
            let identity = (entry.localDate ?? approximateLegacyDate).map(DayIdentity.civil) ?? .legacy(entry.day)
            // Later entries win, including an explicit clearing of that day.
            unique[ModeDayIdentity(mode: entry.mode, day: identity)] = entry.isEmpty ? nil : entry
        }
        return Array(unique.values.sorted {
            $0.id == $1.id ? $0.mode.rawValue < $1.mode.rawValue : $0.id > $1.id
        }.prefix(maximumEntryCount))
    }

    private struct ModeDayIdentity: Hashable {
        let mode: WindDownRoutinePhase
        let day: DayIdentity
    }

    private enum DayIdentity: Hashable {
        case civil(NightFlockLocalDate)
        case legacy(Date)
    }
}

enum WindDownHabitRules {
    private static let smallerStepID = UUID(uuidString: "57494E44-444F-574E-8000-000000000001")!

    static func smallerActivityInvitation(for support: WindDownHabitPlan) -> String? {
        guard let text = support.normalized().smallerActivity else { return nil }
        // Use the existing custom-invitation limit and duplicate-phone-away rule
        // so this snapshot survives the same Codable normalization as other plans.
        return WindDownRoutineStep.normalized(
            [.custom(text, phase: .evening, id: smallerStepID)],
            for: .evening
        ).first?.customText
    }

    static func planForStart(
        _ plan: NightWatchPlan,
        support: WindDownHabitPlan,
        useSmallerVersion: Bool
    ) -> NightWatchPlan {
        guard plan.role == .primarySleepBookend else { return plan }
        let support = support.normalized()
        var snapshot = plan
        snapshot.phonePlacement = support.phonePlacement
        guard useSmallerVersion, let text = smallerActivityInvitation(for: support) else { return snapshot }
        snapshot.eveningRoutine = [.custom(text, phase: .evening, id: smallerStepID)]
        snapshot.eveningCueText = text
        snapshot.usesSmallerRoutine = true
        snapshot.smallerRoutineSelectionID = support.smallerVersionSelectionID
        return snapshot
    }
}
