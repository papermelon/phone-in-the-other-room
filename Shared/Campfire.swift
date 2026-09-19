import Foundation

/// Category-only sharing remains available under the original agreement.
enum CampfireActivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case phoneAway, reading, studying, making, chores, resting
    var id: String { rawValue }
    var title: String {
        switch self {
        case .phoneAway: return "Phone Away"
        case .reading: return "Reading"
        case .studying: return "Studying"
        case .making: return "Making something"
        case .chores: return "Chores"
        case .resting: return "Resting"
        }
    }
}

struct CampfireAgreement: Codable, Equatable, Sendable {
    var id: UUID
    var version: Int
    var revision: Int
    var enabled: Bool
    var acceptedAt: Date
    var permitsSharing: Bool { (version == 1 || version == 2) && enabled }
}

struct CampfireSession: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var memberID: UUID
    var kind: NightFlockV4ActivityKind
    var activity: CampfireActivity?
    var startedAt: Date
    var observedAt: Date
    var expiresAt: Date
    var ended: Bool
    var revision: Int
    var title: String { CampfireRules.sessionTitle(kind: kind, activity: activity) }
    func isCurrent(at date: Date) -> Bool {
        !ended && revision == 1 && startedAt <= date && observedAt <= date.addingTimeInterval(300) && expiresAt > date
            && expiresAt <= startedAt.addingTimeInterval(CampfireRules.maximumDuration)
    }
}

struct CampfireState: Codable, Equatable, Sendable {
    var version: Int = 1
    var agreement: CampfireAgreement?
    var sessions: [CampfireSession] = []
    var buddies: CampfireBuddiesState? = nil
    var isSupported: Bool { version == 1 }
}

enum CampfireRules {
    static func sessionTitle(kind: NightFlockV4ActivityKind, activity: CampfireActivity?) -> String {
        guard kind == .phoneAway else { return "Wind Down" }
        guard let activity, activity != .phoneAway else { return "Phone Away" }
        return "Phone Away · \(activity.title)"
    }
    static let maximumDuration: TimeInterval = 24 * 60 * 60
    static let fire = PastureScenePoint(x: 0.5, y: 0.89)

    static func currentSessions(_ state: CampfireState?, members: Set<UUID>, isFresh: Bool, at date: Date) -> [CampfireSession] {
        guard isFresh, let state, state.isSupported else { return [] }
        // Choose the factual latest source before filtering ended/expired rows;
        // an older live start must not win over a newer terminal source.
        return Dictionary(grouping: state.sessions.filter { members.contains($0.memberID) }, by: \.memberID)
            .values.compactMap { rows in
                rows.max {
                    if $0.startedAt != $1.startedAt { return $0.startedAt < $1.startedAt }
                    if $0.revision != $1.revision { return $0.revision < $1.revision }
                    return $0.observedAt < $1.observedAt
                }
            }.filter { $0.isCurrent(at: date) }.sorted { $0.memberID.uuidString < $1.memberID.uuidString }
    }

    /// Temporary rendering anchors. These never enter the arrangement/outbox.
    static func seat(index: Int, count: Int) -> PastureScenePoint {
        if count == 1 { return .init(x: 0.5, y: 0.63) }
        if count == 2 { return .init(x: index == 0 ? 0.28 : 0.72, y: 0.67) }
        // Four columns on the wide canvas; two rows leave room for names.
        let columns = min(max(count, 1), 4)
        let column = max(0, index) % columns
        let row = max(0, index) / columns
        return .init(x: 0.14 + Double(column) * 0.72 / Double(max(1, columns - 1)),
                     y: count <= 4 ? 0.61 : (row == 0 ? 0.76 : 0.43))
    }

    static func participants(in members: [NightFlockV4Membership], sessions: [CampfireSession]) -> [NightFlockV4Membership] {
        // Membership is not presence. Only the same current rows used by the
        // activity labels may place a person at the fire.
        sessions.compactMap { session in members.first { $0.memberID == session.memberID } }
    }

    static let foregroundRefreshInterval: TimeInterval = 20

    static func permitsOwner(captured: UUID?, current: UUID?) -> Bool {
        guard let captured, let current else { return false }
        return captured == current
    }

    static func end(for run: FocusRun) -> Date? {
        guard !run.isPractice, let plan = run.nightWatchPlan else { return nil }
        switch plan.role {
        case .primarySleepBookend: return min(plan.wakeTime, run.startedAt.addingTimeInterval(maximumDuration))
        case .additionalQuiet: return min(run.plannedEndAt, run.startedAt.addingTimeInterval(maximumDuration))
        default: return nil
        }
    }
}

extension CampfireState {
    private enum CodingKeys: String, CodingKey { case version, agreement, sessions, buddies }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard version == 1 else {
            // Do not decode a future schema's fields as if they were v1.
            agreement = nil; sessions = []; buddies = nil; return
        }
        buddies = try container.decodeIfPresent(CampfireBuddiesState.self, forKey: .buddies)
        agreement = try container.decodeIfPresent(CampfireAgreement.self, forKey: .agreement)
        sessions = try container.decodeIfPresent([CampfireSession].self, forKey: .sessions) ?? []
    }
}
