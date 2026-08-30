import Foundation

enum WindDownGuidanceSourceKind: String, Codable, Equatable {
    case external
    case internalReference
}

extension WindDownGuidanceSourceKind {
    var title: String {
        switch self {
        case .external: return "External references"
        case .internalReference: return "Counting Sheep design notes"
        }
    }
}

struct WindDownGuidanceSource: Codable, Equatable, Identifiable {
    let id: String
    let organization: String
    let title: String
    let urlString: String?
    let kind: WindDownGuidanceSourceKind
    let editorialNote: String

    var url: URL? { urlString.flatMap(URL.init(string:)) }
}

enum WindDownGuidanceSourceRegistry {
    static let sources: [WindDownGuidanceSource] = [
        WindDownGuidanceSource(
            id: "nhlbi-healthy-sleep",
            organization: "National Heart, Lung, and Blood Institute",
            title: "Healthy Sleep Habits",
            urlString: "https://www.nhlbi.nih.gov/health/sleep-deprivation/healthy-sleep-habits",
            kind: .external,
            editorialNote: "General sleep-health education; not a treatment plan."
        ),
        WindDownGuidanceSource(
            id: "nhlbi-sleep-wake-cycle",
            organization: "National Heart, Lung, and Blood Institute",
            title: "How Sleep Works: Your Sleep/Wake Cycle",
            urlString: "https://www.nhlbi.nih.gov/health/sleep/sleep-wake-cycle",
            kind: .external,
            editorialNote: "General sleep-health education; not a treatment plan."
        ),
        WindDownGuidanceSource(
            id: "nhlbi-circadian-treatment",
            organization: "National Heart, Lung, and Blood Institute",
            title: "Circadian Rhythm Disorders: Treatment",
            urlString: "https://www.nhlbi.nih.gov/health/circadian-rhythm-disorders/treatment",
            kind: .external,
            editorialNote: "Reference context only; Counting Sheep does not provide treatment."
        ),
        WindDownGuidanceSource(
            id: "aasm-cbt-i",
            organization: "American Academy of Sleep Medicine",
            title: "Behavioral and Psychological Treatments for Chronic Insomnia",
            urlString: "https://pmc.ncbi.nlm.nih.gov/articles/PMC7853203/",
            kind: .external,
            editorialNote: "Reference context only; Counting Sheep does not reproduce a treatment protocol."
        ),
        WindDownGuidanceSource(
            id: "va-stimulus-control",
            organization: "Veterans Health Library",
            title: "Understanding CBT-I: Using Your Bed Only for Sleep",
            urlString: "https://veteranshealthlibrary.va.gov/Encyclopedia/142%2C41435_VA",
            kind: .external,
            editorialNote: "Reference context only; not a prescribed routine."
        ),
        WindDownGuidanceSource(
            id: "counting-sheep-principles",
            organization: "Counting Sheep",
            title: "Product principles",
            urlString: nil,
            kind: .internalReference,
            editorialNote: "The local product rationale for a warm, optional phone-away ritual."
        ),
        WindDownGuidanceSource(
            id: "counting-sheep-booklet",
            organization: "Counting Sheep",
            title: "Wellness booklet reference",
            urlString: nil,
            kind: .internalReference,
            editorialNote: "Internal design reference; clinical assessment and outcome claims are not shipped."
        )
    ]

    static func source(for id: String) -> WindDownGuidanceSource? {
        sources.first { $0.id == id }
    }

    static func sources(of kind: WindDownGuidanceSourceKind) -> [WindDownGuidanceSource] {
        sources.filter { $0.kind == kind }
    }
}

extension WindDownGuidanceSource {
    /// This record provides library background only and is intentionally not
    /// presented as support for a specific idea.
    var isBackgroundContext: Bool { id == "aasm-cbt-i" }
}

enum WindDownGuidanceGroup: String, CaseIterable, Identifiable {
    case evening
    case morning
    case phoneAway

    var id: String { rawValue }

    var title: String {
        switch self {
        case .evening: return "Evening"
        case .morning: return "Morning"
        case .phoneAway: return "Phone Away"
        }
    }

    var detail: String {
        switch self {
        case .evening: return "Small ways to let the day soften."
        case .morning: return "A little space before the phone returns."
        case .phoneAway: return "Ideas for the room you make around a screen."
        }
    }
}

enum WindDownGuidanceRoutineAddResult: Equatable {
    case added
    case alreadyAdded
    case needsReplacement(phase: WindDownRoutinePhase, stepIDs: [UUID])
    case unavailable
}

enum WindDownGuidanceRoutineMutation {
    @discardableResult
    static func add(
        _ item: WindDownGuidanceItem,
        replacing stepID: UUID? = nil,
        to steps: inout [WindDownRoutineStep]
    ) -> WindDownGuidanceRoutineAddResult {
        guard let phase = item.routinePhase,
              let activity = item.routineActivity else {
            return .unavailable
        }
        guard !steps.contains(where: { $0.guidanceID == item.id }) else {
            return .alreadyAdded
        }
        // A different idea that happens to use the same activity is not this
        // idea and must not be reported as already added. Leave the draft
        // unchanged so the person can choose a different concrete action.
        guard !steps.contains(where: { $0.activity == activity }) else {
            return .unavailable
        }
        let limit = phase == .evening
            ? WindDownRoutineStep.maximumEveningCount
            : WindDownRoutineStep.maximumMorningCount
        if let stepID {
            guard let index = steps.firstIndex(where: { $0.id == stepID }) else {
                return .unavailable
            }
            steps[index] = .suggested(activity, phase: phase, id: stepID, guidanceID: item.id)
            return .added
        }
        guard steps.count < limit else {
            return .needsReplacement(phase: phase, stepIDs: steps.map(\.id))
        }
        steps.append(.suggested(activity, phase: phase, guidanceID: item.id))
        return .added
    }
}

extension WindDownGuidanceItem {
    var group: WindDownGuidanceGroup {
        switch id {
        case "phone-bed": return .phoneAway
        case "steady-wake", "morning-light", "daytime-shape": return .morning
        default: return .evening
        }
    }

    var suggestion: String {
        switch id {
        case "phone-bed": return "Put the phone somewhere it can rest before the evening gets busy."
        case "quiet-hour": return "Try making the last hour before bed a little quieter."
        case "leave-room-after-heavy-meal": return "Notice whether leaving a little room after a large meal suits your evening."
        case "personal-caffeine-cutoff": return "Try noticing whether an earlier personal caffeine cutoff changes the feel of your evening."
        case "steady-wake": return "Give the morning a familiar shape when your days allow it."
        case "morning-light": return "Let daylight be one of the first things your attention meets."
        case "rest-not-performance": return "Let resting comfortably be enough when sleep is slow."
        case "bed-as-cue": return "Leave scrolling and work outside the bed when you can."
        case "calm-room": return "Make one small change that helps the room feel ready."
        case "daytime-shape": return "Give daytime some room for light and gentle movement."
        default: return body
        }
    }

    var rationale: String { body }

    var practicalExample: String {
        switch id {
        case "phone-bed": return "For example, let the charger outside the bedroom be where the phone goes when Wind Down begins."
        case "quiet-hour": return "For example, trade the last part of scrolling for one familiar offline activity."
        case "leave-room-after-heavy-meal": return "For example, notice whether a little more time between a large meal and bed feels better for you."
        case "personal-caffeine-cutoff": return "For example, try a personal afternoon cutoff for a few days and notice how the evening feels."
        case "steady-wake": return "For example, choose a wake-time range that still gives the morning a familiar starting point."
        case "morning-light": return "For example, open the curtains before the phone comes back."
        case "rest-not-performance": return "For example, let lying comfortably be enough for a while instead of trying to make sleep happen."
        case "bed-as-cue": return "For example, leave the phone on its resting place before getting into bed."
        case "calm-room": return "For example, dim the room and remove one distraction before settling in."
        case "daytime-shape": return "For example, give a walk or a few minutes by a window a place in the day."
        default: return suggestion
        }
    }

    var howToFit: String {
        switch group {
        case .evening:
            return routineActivity == nil
                ? "Keep this as background guidance for an evening that suits you."
                : "Choose it as one of your optional evening ideas after putting the phone away."
        case .morning:
            return routineActivity == nil
                ? "Keep this as background guidance for a morning that suits you."
                : "Choose it as one of your optional morning ideas before the phone returns."
        case .phoneAway: return "Phone Away itself is the invitation. This idea is already represented by the start action."
        }
    }

    var routinePhase: WindDownRoutinePhase? {
        switch group {
        case .evening: return .evening
        case .morning: return .morning
        case .phoneAway: return nil
        }
    }

    var routineActivity: PhoneFreeActivity? {
        switch id {
        case "quiet-hour", "bed-as-cue": return .read
        // These are useful background ideas, but neither is the routine action
        // it describes. Do not invent a substitute activity in Add-to-routine.
        case "leave-room-after-heavy-meal", "personal-caffeine-cutoff": return nil
        case "steady-wake": return nil
        case "morning-light": return .openCurtains
        case "rest-not-performance": return .relaxation
        case "calm-room": return .makeBed
        case "daytime-shape": return nil
        default: return nil
        }
    }
}

struct WindDownGuidanceDismissalStore {
    static let key = "ollie.guidance.home.dismissals"
    static let cooldown: TimeInterval = 7 * 24 * 60 * 60

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func dismissalDate(for id: String) -> Date? {
        guard let data = defaults.data(forKey: Self.key),
              let values = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return nil
        }
        return values[id]
    }

    func dismiss(_ id: String, at date: Date) {
        var values: [String: Date] = [:]
        if let data = defaults.data(forKey: Self.key) {
            values = (try? JSONDecoder().decode([String: Date].self, from: data)) ?? [:]
        }
        values[id] = date
        if let data = try? JSONEncoder().encode(values) {
            defaults.set(data, forKey: Self.key)
        }
    }

    func isSuppressed(_ id: String, at date: Date) -> Bool {
        guard let dismissed = dismissalDate(for: id) else { return false }
        return date.timeIntervalSince(dismissed) < Self.cooldown
    }
}

struct WindDownGuidanceDisplayRecord: Codable, Equatable {
    let contextID: String
    let shownAt: Date
}

/// Home guidance is an opportunity, not a permanent explanatory card. A
/// context is shown once; a changed routine/day may create a later opportunity
/// after a quiet spacing interval. The store is injected for deterministic QA.
struct WindDownGuidanceDisplayStore {
    static let key = "ollie.guidance.home.displayRecords"
    static let minimumRepeatInterval: TimeInterval = 3 * 24 * 60 * 60

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func record(for id: String) -> WindDownGuidanceDisplayRecord? {
        guard let data = defaults.data(forKey: Self.key),
              let values = try? JSONDecoder().decode([String: WindDownGuidanceDisplayRecord].self, from: data) else {
            return nil
        }
        return values[id]
    }

    func shouldDisplay(
        itemID: String,
        contextID: String,
        at date: Date
    ) -> Bool {
        guard let record = record(for: itemID) else { return true }
        guard record.contextID != contextID else { return false }
        return date.timeIntervalSince(record.shownAt) >= Self.minimumRepeatInterval
    }

    func markShown(_ itemID: String, contextID: String, at date: Date) {
        var values: [String: WindDownGuidanceDisplayRecord] = [:]
        if let data = defaults.data(forKey: Self.key) {
            values = (try? JSONDecoder().decode([String: WindDownGuidanceDisplayRecord].self, from: data)) ?? [:]
        }
        values[itemID] = WindDownGuidanceDisplayRecord(contextID: contextID, shownAt: date)
        if let data = try? JSONEncoder().encode(values) {
            defaults.set(data, forKey: Self.key)
        }
    }
}

enum WindDownGuidanceDisplayPolicy {
    static func contextID(
        for item: WindDownGuidanceItem,
        eveningRoutine: [WindDownRoutineStep],
        morningRoutine: [WindDownRoutineStep],
        at date: Date,
        calendar: Calendar = .current
    ) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let routineIDs = (eveningRoutine + morningRoutine).map { $0.id.uuidString }.joined(separator: ",")
        return "\(item.id)|\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)|\(routineIDs)"
    }
}
