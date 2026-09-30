import Foundation

enum SocialInboxError: Error, LocalizedError {
    case unavailable, account, rateLimited, connection
    var errorDescription: String? {
        switch self {
        case .unavailable: return "This shared moment is no longer available."
        case .account: return "Sign in again to open your inbox."
        case .rateLimited: return "You’ve sent a few requests. Please try again later."
        case .connection: return "Couldn’t reach your inbox. Please try again."
        }
    }
}

/// A separate wire vocabulary preserves the meaning of historical decorative cheers.
enum SupportMessage: String, CaseIterable, Codable, Identifiable, Sendable {
    case rootingForYou, youveGotThis, cheeringYouOn
    case niceWork, highFive, lovelyProgress
    case restWell, goodNight, peacefulEvening
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rootingForYou: return "Rooting for you"
        case .youveGotThis: return "You’ve got this"
        case .cheeringYouOn: return "Cheering you on"
        case .niceWork: return "Nice work"
        case .highFive: return "High five"
        case .lovelyProgress: return "Lovely progress"
        case .restWell: return "Rest well"
        case .goodNight: return "Good night"
        case .peacefulEvening: return "Wishing you a peaceful evening"
        }
    }
    var symbol: String {
        switch self {
        case .rootingForYou, .youveGotThis, .cheeringYouOn: return "heart"
        case .niceWork, .highFive, .lovelyProgress: return "hands.clap"
        case .restWell, .goodNight, .peacefulEvening: return "moon"
        }
    }
    static func title(for id: String) -> String {
        if let message = Self(rawValue: id) { return message.title }
        switch id {
        case "warmWave": return "Warm wave"
        case "moonGlow": return "Moon glow"
        case "pawPrint": return "Paw print"
        default: return "A little encouragement"
        }
    }
}

struct SocialSource: Codable, Hashable, Sendable {
    var kind: String
    var id: UUID
    var partyID: UUID? = nil
    var memberID: UUID? = nil
}

struct SocialNotificationPreferences: Codable, Equatable, Sendable {
    var invitations = false
    var cheers = false
    var globalCheers = false
}

struct SocialInboxRequest: Codable, Equatable, Sendable {
    var action: String
    var source: SocialSource? = nil
    var messageID: String? = nil
    var commandID: UUID? = nil
    var eventIDs: [String]? = nil
    var cursor: String? = nil
    var preferences: SocialNotificationPreferences? = nil
    var ownerID: UUID? = nil
}

struct SocialInboxEvent: Decodable, Equatable, Identifiable, Sendable {
    var id: String
    var kind: String
    var source: SocialSource?
    var invitationID: UUID?
    var partyID: UUID?
    var partyName: String?
    var senderName: String?
    var messageID: String?
    var context: String
    var occurredAt: Date
    var arrivedAt: Date
    var isRead: Bool
    var count: Int
    var title: String {
        if kind == "invitation" { return "Invitation to \(partyName ?? "a Slumber Party")" }
        if kind == "joined" { return "\(senderName ?? "A Shepherd") joined your party" }
        let phrase = SupportMessage.title(for: messageID ?? "encouragement")
        if senderName == nil { return count == 1 ? "Someone sent: “\(phrase)”" : "\(count) people sent: “\(phrase)”" }
        return "\(senderName!): “\(phrase)”"
    }
}

struct SocialSourceDetail: Decodable, Equatable, Sendable {
    var source: SocialSource
    var name: String
    var context: String
    var occurredAt: Date
    var messages: [String]
    var sentMessageID: String?
    var removed: Bool
}

struct SocialInboxResponse: Decodable, Equatable, Sendable {
    var version: Int
    var userID: UUID
    var events: [SocialInboxEvent]?
    var unreadCount: Int?
    var pendingInvitations: Int?
    var nextCursor: String?
    var preferences: SocialNotificationPreferences?
    var detail: SocialSourceDetail?
}

struct SocialInboxGroup: Identifiable, Equatable {
    var id: String
    var events: [SocialInboxEvent]
    var presentation: SocialInboxEvent {
        var event = events[0]
        event.count = events.reduce(0) { $0 + $1.count }
        event.isRead = events.allSatisfy(\.isRead)
        return event
    }
    static func grouped(_ events: [SocialInboxEvent]) -> [Self] {
        var result: [Self] = []
        for event in events {
            // Private senders keep their exact words. Only anonymous Global
            // messages of the same meaning and original session are combined.
            let key = event.source?.kind == "global"
                ? "global:\(event.source!.id):\(event.messageID ?? "encouragement")" : event.id
            if let index = result.firstIndex(where: { $0.id == key }) { result[index].events.append(event) }
            else { result.append(.init(id: key, events: [event])) }
        }
        return result
    }
}

struct PendingSupportMessage: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var source: SocialSource
    var messageID: String
    var createdAt = Date()
    var action = "send"
    func request(owner: UUID) -> SocialInboxRequest {
        .init(action: action, source: source, messageID: messageID, commandID: id, ownerID: owner)
    }
}

struct SocialNotificationRoute: Codable, Equatable {
    var ownerID: UUID
    var eventID: String
    static let defaultsKey = "ollie.social.pendingRoute"
    static func parse(_ info: [AnyHashable: Any]) -> Self? {
        guard let owner = info["socialOwnerID"] as? String, let id = UUID(uuidString: owner),
              let event = info["socialEventID"] as? String, event.count <= 180,
              ["invite:", "support:", "legacy:", "global:", "campfire:"].contains(where: event.hasPrefix) else { return nil }
        return .init(ownerID: id, eventID: event)
    }
}
