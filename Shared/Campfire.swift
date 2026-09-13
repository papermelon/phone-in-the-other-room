import Foundation

/// Only this bounded invitation can leave the phone. Private routine/task text
/// is deliberately absent from both the command and the public projection.
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
    var permitsSharing: Bool { version == 1 && enabled }
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
    var title: String { kind == .windDown ? "Wind Down" : activity?.title ?? "Phone Away" }
    func isCurrent(at date: Date) -> Bool {
        !ended && revision == 1 && startedAt <= date && observedAt <= date.addingTimeInterval(300) && expiresAt > date
            && expiresAt <= startedAt.addingTimeInterval(CampfireRules.maximumDuration)
    }
}

struct CampfireState: Codable, Equatable, Sendable {
    var version: Int = 1
    var agreement: CampfireAgreement?
    var sessions: [CampfireSession] = []
    var isSupported: Bool { version == 1 }
}

enum CampfireRules {
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
        let seats: [PastureScenePoint] = [
            .init(x: 0.34, y: 0.68), .init(x: 0.66, y: 0.68),
            .init(x: 0.19, y: 0.78), .init(x: 0.81, y: 0.78),
            .init(x: 0.20, y: 0.49), .init(x: 0.80, y: 0.49),
            .init(x: 0.41, y: 0.48), .init(x: 0.60, y: 0.48)
        ]
        return seats[max(0, index) % seats.count]
    }

    static func visitorSeat(index: Int, count: Int) -> PastureScenePoint {
        let owner = seat(index: index, count: count)
        return SharedPastureRules.bounded(.init(x: owner.x + (owner.x < 0.5 ? -0.16 : 0.16), y: owner.y + 0.12))
    }

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
    private enum CodingKeys: String, CodingKey { case version, agreement, sessions }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard version == 1 else {
            // Do not decode a future schema's fields as if they were v1.
            agreement = nil; sessions = []; return
        }
        agreement = try container.decodeIfPresent(CampfireAgreement.self, forKey: .agreement)
        sessions = try container.decodeIfPresent([CampfireSession].self, forKey: .sessions) ?? []
    }
}
