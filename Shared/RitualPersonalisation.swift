import Foundation

/// An explicitly chosen experience, separate from an activity or timer evidence.
enum RitualGoalKind: String, Codable, CaseIterable, Identifiable {
    case lessScrolling, lessRushed, timeForMe, presence, unwind, beginOnTime, personal
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lessScrolling: return "Less automatic morning scrolling"
        case .lessRushed: return "A less rushed start"
        case .timeForMe: return "Time for myself"
        case .presence: return "Being present with others"
        case .unwind: return "Making room to unwind"
        case .beginOnTime: return "Putting my phone down when I intended"
        case .personal: return "My own reason"
        }
    }
    func supports(_ mode: WindDownRoutinePhase) -> Bool {
        switch self {
        case .lessScrolling, .lessRushed: return mode == .morning
        case .unwind, .beginOnTime: return mode == .evening
        default: return true
        }
    }
    var proposedActivity: String? {
        switch self {
        case .lessScrolling: return "Drink a glass of water before checking my phone"
        case .lessRushed: return "Choose just one thing to get ready"
        case .timeForMe: return "Enjoy a quiet drink"
        case .presence: return "Share a few words with someone I care about"
        case .unwind: return "Read one page"
        case .beginOnTime: return "Leave my book where my phone usually rests"
        case .personal: return nil
        }
    }
    var rationale: String {
        switch self {
        case .lessScrolling: return "Try a small action before reaching for your phone."
        case .lessRushed: return "One activity leaves less to fit in."
        case .timeForMe: return "Make a little time that belongs to you."
        case .presence: return "Choose a moment of connection that fits your day."
        case .unwind: return "Start with something small you look forward to."
        case .beginOnTime: return "Get an appealing activity ready before putting your phone down."
        case .personal: return "Choose a small action that fits your reason."
        }
    }
}

struct RitualGoal: Codable, Equatable, Identifiable {
    let id: UUID
    let mode: WindDownRoutinePhase
    let kind: RitualGoalKind
    let wording: String
    let selectedAt: Date
    var archivedAt: Date?

    init(mode: WindDownRoutinePhase, kind: RitualGoalKind, wording: String, now: Date) {
        id = UUID()
        self.mode = mode
        self.kind = kind
        self.wording = String(wording.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        selectedAt = now
    }
}

struct RitualPlanRevision: Codable, Equatable, Identifiable {
    let id: UUID
    let goal: RitualGoal
    let preferences: NightWatchPreferences
    let support: WindDownHabitPlan
    let savedAt: Date
    var activities: [WindDownRoutineStep] {
        goal.mode == .morning ? preferences.morningRoutine : preferences.eveningRoutine
    }
    var cue: String? { goal.mode == .morning ? support.morningCue : support.cue }
    init(goal: RitualGoal, preferences: NightWatchPreferences, support: WindDownHabitPlan, now: Date) {
        id = UUID(); self.goal = goal; self.preferences = preferences; self.support = support; savedAt = now
    }
}

enum RitualExperienceAnswer: String, Codable, CaseIterable, Identifiable {
    case yes, partly, notToday, notSure
    var id: String { rawValue }
    var title: String {
        switch self {
        case .yes: return "Yes"
        case .partly: return "Partly"
        case .notToday: return "Not today"
        case .notSure: return "Not sure"
        }
    }
}

/// Attached to the existing optional habit reflection. No implicit run association.
struct RitualExperienceFeedback: Codable, Equatable {
    var id = UUID()
    var planID: UUID?
    var answer: RitualExperienceAnswer?
    var context: String?
    var recordedAt: Date
    var timeZoneIdentifier: String
}

enum RitualAdjustmentAction: String, Codable, CaseIterable {
    case simplify, swapActivity, cue, preparation
    var title: String {
        switch self {
        case .simplify: return "Try just one activity"
        case .swapActivity: return "Choose a more appealing activity"
        case .cue: return "Link your routine to a familiar moment"
        case .preparation: return "Get one small thing ready"
        }
    }
}

struct RitualSuggestion: Codable, Equatable, Identifiable {
    enum Status: String, Codable { case proposed, accepted, dismissed, deferred, superseded }
    let id: UUID
    let ruleVersion: Int
    let action: RitualAdjustmentAction
    let evidenceIDs: [UUID]
    let targetPlanID: UUID
    let reason: String
    let createdAt: Date
    let expiresAt: Date
    var status: Status
    var deferredUntil: Date?
}

struct RitualReviewedAdjustment: Codable, Equatable, Identifiable {
    var id = UUID()
    let suggestionID: UUID?
    let oldPlan: RitualPlanRevision
    let newPlan: RitualPlanRevision
    let reviewedAt: Date
    var applicationPending = true
    var wasApplied: Bool?
}

struct RitualPersonalisation: Codable, Equatable {
    static let storageKey = "ollie.windDown.personalisation"
    var schemaVersion = 1
    var revision = UUID()
    var goals: [RitualGoal] = []
    var plans: [RitualPlanRevision] = []
    var suggestions: [RitualSuggestion] = []
    var adjustments: [RitualReviewedAdjustment] = []
    // Minimal rejection memory survives detailed evidence expiry for the active goal.
    var rejectedActions: [RitualAdjustmentAction] = []
    var invitationsEnabled = true
    var nextInvitationAt: Date?

    var goal: RitualGoal? { goals.last { $0.archivedAt == nil } }
    var currentPlan: RitualPlanRevision? { plans.last { $0.goal.id == goal?.id } }

    mutating func setGoal(_ goal: RitualGoal?, preferences: NightWatchPreferences, support: WindDownHabitPlan, now: Date) {
        for i in goals.indices where goals[i].archivedAt == nil { goals[i].archivedAt = now }
        supersedeSuggestions()
        rejectedActions = []
        if let goal {
            goals.append(goal)
            plans.append(RitualPlanRevision(goal: goal, preferences: preferences, support: support, now: now))
        }
        nextInvitationAt = now.addingTimeInterval(7 * 86_400)
    }

    mutating func reconcile(preferences: NightWatchPreferences, support: WindDownHabitPlan, now: Date) {
        guard let goal else { return }
        if currentPlan?.preferences != preferences || currentPlan?.support != support {
            supersedeSuggestions()
            plans.append(RitualPlanRevision(goal: goal, preferences: preferences, support: support, now: now))
        }
    }

    mutating func supersedeSuggestions() {
        for i in suggestions.indices where [.proposed, .deferred].contains(suggestions[i].status) {
            suggestions[i].status = .superseded
        }
    }

    func invitationAvailable(now: Date, isActive: Bool) -> Bool {
        invitationsEnabled && goal != nil && !isActive && now >= (nextInvitationAt ?? .distantFuture)
    }

    mutating func postponeInvitation(now: Date, worked: Bool = false) {
        nextInvitationAt = now.addingTimeInterval(Double(worked ? 28 : 7) * 86_400)
    }

    mutating func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-90 * 86_400)
        suggestions.removeAll { $0.createdAt < cutoff }
        adjustments.removeAll { $0.reviewedAt < cutoff }
        let currentID = currentPlan?.id
        plans = Array(plans.filter { $0.id == currentID || $0.savedAt >= cutoff }.suffix(90))
        goals.removeAll { $0.archivedAt.map { $0 < cutoff } ?? false }
    }
}
