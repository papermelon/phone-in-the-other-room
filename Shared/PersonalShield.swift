import Foundation

struct PersonalShieldStep: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    var checked = false
}

/// Private self-reports, separate from the timer, immutable plan and reward ledger.
struct PersonalShieldSession: Codable, Equatable, Identifiable {
    static let storageKey = "ollie.personalShield.sessions"
    let id: UUID
    let owner: String
    let interval: DateInterval
    let role: QuietTimeShieldRole
    let bedtime: Date?
    let morningStart: Date?
    var steps: [PersonalShieldStep]
    var morningSteps: [PersonalShieldStep]
    let goal: String?
    let morningGoal: String?

    func mode(at date: Date) -> QuietTimeShieldRole {
        if role == .primaryWindDown, let morningStart, date >= morningStart { return .screenFreeMorning }
        return role
    }

    func visibleSteps(at date: Date) -> [PersonalShieldStep] {
        mode(at: date) == .screenFreeMorning && role == .primaryWindDown ? morningSteps : steps
    }

    func isSleepTime(at date: Date) -> Bool {
        guard mode(at: date) == .primaryWindDown else { return false }
        return bedtime.map { date >= $0 } == true || (!steps.isEmpty && steps.allSatisfy(\.checked))
    }

    func title(at date: Date) -> String {
        if isSleepTime(at: date) { return "Time for sleep" }
        switch mode(at: date) {
        case .primaryWindDown: return "My Wind Down"
        case .additionalQuiet: return !steps.isEmpty && steps.allSatisfy(\.checked) ? "Tasks checked off" : "My Phone Away"
        case .screenFreeMorning: return "My morning"
        }
    }

    func listTitle(at date: Date) -> String {
        switch mode(at: date) {
        case .primaryWindDown: return "My Wind Down"
        case .additionalQuiet: return "My tasks"
        case .screenFreeMorning: return "My morning"
        }
    }

    func listButton(at date: Date) -> String { mode(at: date) == .additionalQuiet ? "My tasks" : "My routine" }

    func phrase(at date: Date) -> String {
        // No existing goal field explicitly records a sleep intention. Do not infer one
        // from keywords or turn a broad personal goal into a generated affirmation.
        if isSleepTime(at: date) { return "Put my phone away for sleep" }
        if let next = visibleSteps(at: date).first(where: { !$0.checked && !PersonalShieldPhrase.normalized($0.title).isEmpty }) { return next.title }
        let selectedGoal = mode(at: date) == .screenFreeMorning && role == .primaryWindDown ? morningGoal : goal
        return selectedGoal.flatMap { PersonalShieldPhrase.normalized($0).isEmpty ? nil : $0 } ?? "Put my phone away"
    }

    func summary(at date: Date) -> String {
        if isSleepTime(at: date) { return "Put your phone away for the night." }
        let items = visibleSteps(at: date)
        let selectedGoal = mode(at: date) == .screenFreeMorning && role == .primaryWindDown ? morningGoal : goal
        guard !items.isEmpty else { return selectedGoal ?? "\(mode(at: date).timerName) is on." }
        let lines = items.enumerated().map { index, step in "\(step.checked ? "✓" : "\(index + 1).") \(step.title)" }
        if lines.joined(separator: "\n").count <= 150 { return lines.joined(separator: "\n") }
        let next = items.first(where: { !$0.checked }) ?? items[0]
        return "\(next.checked ? "✓" : "Next:") \(next.title)\n\(items.filter(\.checked).count) of \(items.count) checked"
    }

    mutating func toggle(_ stepID: UUID, at date: Date) -> Bool {
        guard interval.start <= date, date < interval.end else { return false }
        if mode(at: date) == .screenFreeMorning && role == .primaryWindDown {
            guard let index = morningSteps.firstIndex(where: { $0.id == stepID }) else { return false }
            morningSteps[index].checked.toggle()
        } else {
            guard let index = steps.firstIndex(where: { $0.id == stepID }) else { return false }
            steps[index].checked.toggle()
        }
        return true
    }

    static func taskTitles(_ input: [String]) -> [String] {
        input.prefix(3).map { String($0.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(120)) }
            .filter { !$0.isEmpty }
    }
}

enum PersonalShieldPhrase {
    static func normalized(_ text: String) -> String {
        text.precomposedStringWithCompatibilityMapping.lowercased()
            .unicodeScalars.filter { !CharacterSet.punctuationCharacters.contains($0) }
            .map(String.init).joined().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func matches(_ entry: String, phrase: String) -> Bool {
        let expected = normalized(phrase)
        return !expected.isEmpty && normalized(entry) == expected
    }
}

enum PersonalShieldAction: String, Codable { case checklist, briefAccess, endSession }

struct PersonalShieldSheet: Identifiable, Equatable {
    let id = UUID()
    let sessionID: UUID
    let owner: String
    let action: PersonalShieldAction
    let phrase: String
    let mode: QuietTimeShieldRole
    var endDetail: String? = nil
}

/// Only the bounded current/upcoming plan is projected to the device's App Group.
struct PersonalShieldProjection: Codable, Equatable {
    let session: PersonalShieldSession
    let scheduleID: UUID
    let revision: Int
    let epoch: Int

    func matches(_ snapshot: QuietTimeShieldPresentationSnapshot, at date: Date) -> Bool {
        scheduleID == snapshot.runID && revision == snapshot.registryRevision && epoch == snapshot.registryEpoch
            && session.interval.start <= date && date < session.interval.end
    }
}

struct PersonalShieldRoute: Codable, Equatable {
    let owner: String
    let sessionID: UUID
    let scheduleID: UUID
    let revision: Int
    let epoch: Int
    let action: PersonalShieldAction
    let requestedAt: Date

    init(projection: PersonalShieldProjection, action: PersonalShieldAction, at date: Date) {
        owner = projection.session.owner; sessionID = projection.session.id
        scheduleID = projection.scheduleID; revision = projection.revision; epoch = projection.epoch
        self.action = action; requestedAt = date
    }

    func matches(_ projection: PersonalShieldProjection, at date: Date) -> Bool {
        owner == projection.session.owner && sessionID == projection.session.id
            && scheduleID == projection.scheduleID && revision == projection.revision && epoch == projection.epoch
            && requestedAt <= date && date.timeIntervalSince(requestedAt) <= 120
            && projection.session.interval.start <= date && date < projection.session.interval.end
            && action != .endSession
    }
}

enum PersonalShieldStorage {
    static let projectionKey = "ollie.screenTime.personalShield"
    static let routeKey = "ollie.screenTime.personalShieldRoute"

    static func projection(from defaults: UserDefaults) -> PersonalShieldProjection? {
        guard let data = defaults.data(forKey: projectionKey) else { return nil }
        return try? JSONDecoder().decode(PersonalShieldProjection.self, from: data)
    }

    static func save(_ projection: PersonalShieldProjection, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(projection) else { return }
        defaults.set(data, forKey: projectionKey)
    }

    static func request(_ action: PersonalShieldAction, in defaults: UserDefaults, at date: Date) -> Bool {
        guard action != .endSession, let projection = projection(from: defaults),
              let snapshot = QuietTimeShieldPresentationSnapshot.load(from: defaults),
              projection.matches(snapshot, at: date),
              let data = try? JSONEncoder().encode(PersonalShieldRoute(projection: projection, action: action, at: date)) else { return false }
        defaults.set(data, forKey: routeKey)
        return true
    }

    static func consumeRoute(from defaults: UserDefaults) -> PersonalShieldRoute? {
        let data = defaults.data(forKey: routeKey)
        defaults.removeObject(forKey: routeKey)
        return data.flatMap { try? JSONDecoder().decode(PersonalShieldRoute.self, from: $0) }
    }

    static func clear(from defaults: UserDefaults) {
        defaults.removeObject(forKey: projectionKey)
        defaults.removeObject(forKey: routeKey)
    }
}
