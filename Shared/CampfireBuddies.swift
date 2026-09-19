import Foundation

/// Explicit public text is separately authored and captured at admission.
/// No private routine field is used to populate this value.
struct CampfireSharedIntention: Codable, Equatable, Sendable {
    var partyID: UUID
    var agreementID: UUID
    var text: String
    var announceStart: Bool
    var asksForBuddy: Bool
}

enum CampfireOutcome: String, Codable, CaseIterable, Identifiable, Sendable {
    case didIt, madeProgress, changedPlans
    var id: String { rawValue }
    var title: String {
        switch self {
        case .didIt: return "Did it"
        case .madeProgress: return "Made progress"
        case .changedPlans: return "Changed plans"
        }
    }
}

struct CampfireBuddySession: Codable, Equatable, Identifiable, Sendable {
    var id: String { "\(memberID):\(sourceID)" }
    var sourceID: UUID
    var memberID: UUID
    var publicIntention: String
    var asksForBuddy: Bool
    var buddyMemberID: UUID?
    var encouragementMemberIDs: [UUID]
    var checkInRequested: Bool
    var outcome: CampfireOutcome?
    var reflection: String?
    var startedAt: Date
    var expiresAt: Date
    var checkInAfter: Date
    var ended: Bool
    var kind: NightFlockV4ActivityKind
    func mayReflect(at now: Date) -> Bool {
        // A Wind Down return invitation waits until its quiet window has ended.
        (kind == .windDown ? now >= checkInAfter : ended || now >= expiresAt)
            && now < startedAt.addingTimeInterval(CampfireBuddiesRules.retention)
    }
}

struct CampfireBuddiesState: Codable, Equatable, Sendable {
    var version: Int
    var startAlerts: Bool
    var sessions: [CampfireBuddySession]
    var isSupported: Bool { version == 1 }
    private enum CodingKeys: String, CodingKey { case version, startAlerts, sessions }
    init(version: Int, startAlerts: Bool, sessions: [CampfireBuddySession]) {
        self.version = version; self.startAlerts = startAlerts; self.sessions = sessions
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard version == 1 else { startAlerts = false; sessions = []; return }
        startAlerts = try container.decode(Bool.self, forKey: .startAlerts)
        sessions = try container.decode([CampfireBuddySession].self, forKey: .sessions)
    }
}

enum CampfireBuddiesRules {
    static let retention: TimeInterval = 7 * 86400
    static func publicText(_ text: String, limit: Int = 80) -> String {
        String(text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            .joined(separator: " ").unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }.prefix(limit))
    }
    static func visible(_ state: CampfireBuddiesState?, members: Set<UUID>, now: Date) -> [CampfireBuddySession] {
        guard let state, state.isSupported else { return [] }
        return state.sessions.filter {
            members.contains($0.memberID) && $0.startedAt <= now && $0.startedAt > now.addingTimeInterval(-retention)
        }.sorted { $0.startedAt > $1.startedAt }
    }
    static func canAccept(_ session: CampfireBuddySession, me: UUID?, active: Bool) -> Bool {
        guard let me else { return false }
        return active && session.asksForBuddy && session.buddyMemberID == nil && session.memberID != me
    }
}
