import Foundation

enum CampfireVisibility: String, Codable, CaseIterable, Identifiable, Sendable {
    case off, party, global
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return "Off"
        case .party: return "My Slumber Party"
        case .global: return "Global"
        }
    }
}

/// Browsing never supplies publication authority. Only a confirmed selection
/// may create this value, including when an already-running session is shared.
struct CampfireAudienceSelection: Codable, Equatable, Sendable {
    var visibility: CampfireVisibility
    var partyIDs: [UUID]
    var effectiveAt: Date
    var publicAgreementID: UUID? = nil
    var publicAgreementCommandID: String? = nil
    var publicStartedAt: Date? = nil
    var partyAgreementIDs: [UUID: UUID]? = nil
    var partyStartedAt: [UUID: Date]? = nil
    var pendingPartyAgreements: [UUID: CampfirePendingPartyAgreement]? = nil
}

struct CampfirePendingPartyAgreement: Codable, Equatable, Sendable {
    var commandID: String
    var memberEpochID: UUID
    var revision: Int
    var acknowledged: Bool = false
}

enum CampfireVisibilityRules {
    static func sharingStart(requested: Date, acceptedAt: Date) -> Date {
        // Wire encoders differ in subsecond precision. Rounding forward keeps
        // a just-accepted session on the consented side of that boundary.
        Date(timeIntervalSince1970: ceil(max(requested, acceptedAt).timeIntervalSince1970))
    }
    static func initialVisibility(saved: CampfireVisibility?, hasPrivateAgreement: Bool) -> CampfireVisibility {
        saved ?? (hasPrivateAgreement ? .party : .off)
    }

    static func permitsPrivatePublication(visibility: CampfireVisibility, selected: [UUID], partyID: UUID) -> Bool {
        visibility != .off && selected.contains(partyID)
    }

    static func permitsPublicPublication(visibility: CampfireVisibility, capturedAgreement: UUID?, current: CampfireAgreement?) -> Bool {
        visibility == .global && current?.version == 2 && current?.enabled == true
            && capturedAgreement != nil && capturedAgreement == current?.id
    }

    static func isFresh(observedAt: Date, now: Date) -> Bool {
        observedAt <= now.addingTimeInterval(5) && now.timeIntervalSince(observedAt) <= 45
    }
}

/// Character appearance shared at the Campfire; older payloads omit head shape.
struct PublicCampfireAppearance: Codable, Equatable, Sendable {
    var headShapeID: String? = nil
    var shepherdShirtID: String? = nil
    var shepherdOuterwearID: String? = nil
    var ollieCoatID: String? = nil
    var skinToneID: String
    var hairStyleID: String
    var shepherdOutfitID: String
    var shepherdAccessoryID: String

    init(_ presentation: CountingSheepPublicPresentation = .defaultValue) {
        let safe = presentation.renderableAppearance
        headShapeID = safe.headShapeID
        shepherdShirtID = safe.shepherdShirtID
        shepherdOuterwearID = safe.shepherdOuterwearID
        ollieCoatID = safe.ollieCoatID
        skinToneID = safe.skinToneID; hairStyleID = safe.hairStyleID
        shepherdOutfitID = safe.shepherdOutfitID; shepherdAccessoryID = safe.shepherdAccessoryID
    }

    var presentation: CountingSheepPublicPresentation {
        .init(skinToneID: skinToneID, hairStyleID: hairStyleID, shepherdOutfitID: shepherdOutfitID,
              shepherdAccessoryID: shepherdAccessoryID, ollieOrnamentID: "none",
              featuredSheepDefinitionID: "none", pastureThemeID: "pasture_meadow", headShapeID: headShapeID,
              shepherdShirtID: shepherdShirtID, shepherdOuterwearID: shepherdOuterwearID, ollieCoatID: ollieCoatID)
    }

    func forServer(supportsWardrobe: Bool) -> Self {
        guard !supportsWardrobe else { return self }
        var legacy = self
        legacy.shepherdShirtID = nil
        legacy.shepherdOuterwearID = nil
        legacy.ollieCoatID = nil
        return legacy
    }
}

enum PublicCampfireTimeBand: String, Codable, Sendable {
    case short, hour, fewHours, severalHours
    var title: String {
        switch self {
        case .short: return "Under half an hour left"
        case .hour: return "About an hour left"
        case .fewHours: return "A few hours left"
        case .severalHours: return "Several hours left"
        }
    }
}

struct GlobalCampfireParticipant: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var profileID: UUID
    var name: String
    var appearance: PublicCampfireAppearance
    var kind: NightFlockV4ActivityKind
    var activity: CampfireActivity?
    var remaining: PublicCampfireTimeBand
    var encouragedByMe: Bool
    var isMe: Bool
    var startedAt: Date? = nil
    var expiresAt: Date? = nil
    var thought: String? = nil
    var hasProfile: Bool? = nil
    var title: String { CampfireRules.sessionTitle(kind: kind, activity: activity) }
}

struct CampfireChannel: Codable, Equatable, Identifiable, Sendable {
    static let capacity = 8
    var id: Int
    var count: Int
    var isFull: Bool { count >= Self.capacity }
    var title: String { "Channel \(id) · \(count)/\(Self.capacity)" }
}

struct GlobalCampfireStateRequest: Encodable, Sendable {
    let command = "state"
    var gathering: String
    var cursor: UUID?
    var channelID: Int?

    init(gathering: String = "all", cursor: UUID? = nil, channelID: Int = 0) {
        self.gathering = gathering
        self.cursor = cursor
        // Zero means the default gathering. Omit it so older servers can
        // answer the initial read that discovers channel support.
        self.channelID = channelID == 0 ? nil : channelID
    }
}

struct GlobalCampfireState: Codable, Equatable, Sendable {
    var version: Int
    var available: Bool
    var observedAt: Date
    var agreement: CampfireAgreement?
    var publicName: String?
    var appearance: PublicCampfireAppearance?
    var participants: [GlobalCampfireParticipant]
    var approximateCount: Int
    var nextCursor: UUID?
    var ownSourceID: UUID?
    var ownEncouragementCount: Int? = nil
    var profileVersion: Int? = nil
    var appearanceVersion: Int? = nil
    var channels: [CampfireChannel]? = nil
    var channelID: Int? = nil
    var ownChannelID: Int? = nil
    var supportsProfiles: Bool { isSupported && profileVersion == 2 }
    var isSupported: Bool { version == 1 && available }
}

struct GlobalCampfireCommand: Codable, Equatable, Identifiable, Sendable {
    var id: String = UUID().uuidString.lowercased()
    var command: String
    var expectedRevision: Int? = nil
    var consentVersion: Int? = nil
    var enabled: Bool? = nil
    var publicName: String? = nil
    var appearance: PublicCampfireAppearance? = nil
    var agreementID: UUID? = nil
    var sourceID: UUID? = nil
    var kind: NightFlockV4ActivityKind? = nil
    var activity: CampfireActivity? = nil
    var startedAt: Date? = nil
    var expiresAt: Date? = nil
    var ended: Bool? = nil
    var targetID: UUID? = nil
    var reason: String? = nil
    var profile: CampfireProfileSnapshot? = nil
    var capturedAt: Date? = nil
    var channelID: Int? = nil
}

struct GlobalCampfireResponse: Decodable, Sendable {
    var accepted: Bool
    var retryable: Bool?
    var conflict: Bool?
    var state: GlobalCampfireState?
    var agreement: CampfireAgreement?
    var channelID: Int?
    var channelFull: Bool?
}

struct CampfireVisibilityDocument: Codable, Equatable {
    var version = 1
    var selection: CampfireAudienceSelection?
    var runSelections: [UUID: CampfireAudienceSelection] = [:]
    var publicAgreement: CampfireAgreement?
    var publicName = ""
    var appearance = PublicCampfireAppearance()
    var commands: [GlobalCampfireCommand] = []

    mutating func repairWithdrawals(for state: GlobalCampfireState) -> Set<String> {
        guard state.isSupported, state.profileVersion == nil else { return [] }
        var repaired = Set<String>()
        for index in commands.indices where commands[index].command == "agreement"
            && commands[index].enabled == false && commands[index].consentVersion == 2 {
            // This server rejects version 2 before execution, so the original
            // idempotency key is safe to retain. Never downgrade an acceptance.
            commands[index].consentVersion = 1
            repaired.insert(commands[index].id)
        }
        return repaired
    }

    mutating func acknowledgePrivateAgreement(commandID: String, partyID: UUID, conflicted: Bool) {
        for (id, var selection) in runSelections {
            guard var pending = selection.pendingPartyAgreements?[partyID], pending.commandID == commandID else { continue }
            if conflicted { selection.pendingPartyAgreements?.removeValue(forKey: partyID) }
            else { pending.acknowledged = true; selection.pendingPartyAgreements?[partyID] = pending }
            runSelections[id] = selection
        }
    }

    mutating func bindPrivateAgreement(partyID: UUID, memberEpochID: UUID, agreement: CampfireAgreement) {
        for (id, var selection) in runSelections {
            guard let pending = selection.pendingPartyAgreements?[partyID], pending.acknowledged,
                  pending.memberEpochID == memberEpochID, pending.revision == agreement.revision, agreement.permitsSharing else { continue }
            selection.partyAgreementIDs?[partyID] = agreement.id
            selection.partyStartedAt?[partyID] = CampfireVisibilityRules.sharingStart(requested: selection.effectiveAt, acceptedAt: agreement.acceptedAt)
            selection.pendingPartyAgreements?.removeValue(forKey: partyID)
            runSelections[id] = selection
        }
    }

    mutating func bindPublicAgreement(commandID: String, agreement: CampfireAgreement) {
        guard agreement.enabled, agreement.version == 2 else { return }
        if selection?.publicAgreementCommandID == commandID {
            selection?.publicAgreementID = agreement.id
            selection?.publicAgreementCommandID = nil
        }
        for (id, var selection) in runSelections where selection.publicAgreementCommandID == commandID {
            selection.publicAgreementID = agreement.id; selection.publicAgreementCommandID = nil
            selection.publicStartedAt = CampfireVisibilityRules.sharingStart(requested: selection.effectiveAt, acceptedAt: agreement.acceptedAt)
            runSelections[id] = selection
        }
    }

    @discardableResult mutating func enqueue(_ command: GlobalCampfireCommand, now: Date = Date()) -> Bool {
        // Expired public presence is already absent server-side. Keeping these
        // writes forever would let an offline queue crowd out a withdrawal.
        commands.removeAll { $0.command == "publish" && ($0.expiresAt ?? .distantFuture) <= now }
        guard !commands.contains(where: { $0.id == command.id }) else { return true }
        if command.command == "agreement", command.enabled == false {
            commands.removeAll { $0.command == "publish" || $0.command == "profile" || $0.command == "encourage" || ($0.command == "agreement" && $0.enabled == true) }
            if commands.contains(where: { $0.command == "agreement" && $0.enabled == false }) { return true }
        }
        if command.command == "profile" {
            commands.removeAll { $0.command == "profile" && $0.agreementID == command.agreementID }
        }
        if command.command == "publish" {
            let same: (GlobalCampfireCommand) -> Bool = { $0.command == "publish" && $0.sourceID == command.sourceID && $0.agreementID == command.agreementID }
            guard !commands.contains(where: { same($0) && ($0.ended == true || $0 == command) }) else { return true }
            commands.removeAll(where: same)
        }
        // Reserve space for consent/terminal writes when social actions are offline.
        guard commands.count < (["encourage", "report", "block"].contains(command.command) ? 60 : 64) else { return false }
        commands.append(command)
        return true
    }
}

/// Availability is separate from an empty, successfully observed gathering.
enum GlobalCampfireIssue: Equatable, Sendable {
    case unavailable, connection, signIn, unsupported

    static func forHTTPStatus(_ status: Int) -> Self {
        switch status {
        case 404: return .unavailable
        case 401, 403: return .signIn
        default: return .connection
        }
    }
    var title: String {
        switch self {
        case .unavailable: return "Global Campfire isn’t open right now"
        case .connection: return "The global campfire couldn’t be reached"
        case .signIn: return "Sign in again to visit Global Campfire"
        case .unsupported: return "Global Campfire needs an app update"
        }
    }
    var detail: String {
        switch self {
        case .unavailable: return "You can still use Wind Down and Phone Away, or visit a private party’s Campfire."
        case .connection: return "Please try again in a moment. Your session keeps running."
        case .signIn: return "Open Settings to reconnect your account."
        case .unsupported: return "Your private party and your own session are still here."
        }
    }
    var permitsAutomaticRetry: Bool { self == .connection }
}
