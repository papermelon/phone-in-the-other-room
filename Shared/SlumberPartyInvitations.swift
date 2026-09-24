import Foundation

struct SlumberPartyConnectionsRequest: Encodable, Equatable, Sendable {
    var action: String
    var partyID: UUID?
    var query: String?
    var userID: UUID?
    var invitationID: UUID?
}

struct SlumberPartyPerson: Decodable, Equatable, Identifiable, Sendable {
    var userID: UUID
    var name: String
    var handle: String?
    var isMember: Bool
    var isInvited: Bool
    var id: UUID { userID }
}

struct SlumberPartyInvitation: Decodable, Equatable, Identifiable, Sendable {
    var id: UUID
    var partyID: UUID
    var partyName: String
    var senderName: String
    var recipientName: String
    var recipientID: UUID
    var isIncoming: Bool
    var canRevoke: Bool
    var expiresAt: Date
}

struct SlumberPartyConnections: Decodable, Equatable, Sendable {
    var version: Int
    var userID: UUID
    var handle: String?
    var person: SlumberPartyPerson?
    var acceptedPartyID: UUID?
    var invitations: [SlumberPartyInvitation]
}

enum SlumberPartyInvitationSearch {
    static func normalized(_ text: String) -> String? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("@") { value.removeFirst() }
        if UUID(uuidString: value) != nil { return value }
        return AccountUsername.normalized(value)
    }
}

enum SlumberPartyConnectionError: Error, LocalizedError {
    case unavailable, full, limit, rateLimited, offline
    var errorDescription: String? {
        switch self {
        case .unavailable: return "This invitation is no longer available. Refresh your invitations to check again."
        case .full: return "This party has eight members. A place needs to open before someone else can join."
        case .limit: return "You’re already in five Slumber Parties. Leave one before joining another."
        case .rateLimited: return "There have been a few requests in a row. Please try again later."
        case .offline: return "Your invitations couldn’t be reached. Check your connection and try again."
        }
    }
}
