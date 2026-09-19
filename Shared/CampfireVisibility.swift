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
        visibility == .global && current?.version == 1 && current?.enabled == true
            && capturedAgreement != nil && capturedAgreement == current?.id
    }

    static func isFresh(observedAt: Date, now: Date) -> Bool {
        observedAt <= now.addingTimeInterval(5) && now.timeIntervalSince(observedAt) <= 45
    }
}

/// Only the Shepherd's chosen appearance crosses the public boundary.
/// No Farm inventory, sheep, Ollie, party identity or private text is encoded.
struct PublicCampfireAppearance: Codable, Equatable, Sendable {
    var skinToneID: String
    var hairStyleID: String
    var shepherdOutfitID: String
    var shepherdAccessoryID: String

    init(_ presentation: CountingSheepPublicPresentation = .defaultValue) {
        let safe = presentation.renderableAppearance
        skinToneID = safe.skinToneID; hairStyleID = safe.hairStyleID
        shepherdOutfitID = safe.shepherdOutfitID; shepherdAccessoryID = safe.shepherdAccessoryID
    }

    var presentation: CountingSheepPublicPresentation {
        .init(skinToneID: skinToneID, hairStyleID: hairStyleID, shepherdOutfitID: shepherdOutfitID,
              shepherdAccessoryID: shepherdAccessoryID, ollieOrnamentID: "none",
              featuredSheepDefinitionID: "none", pastureThemeID: "pasture_meadow")
    }
}

enum PublicCampfireName {
    /// Preset public names avoid publishing a private account name by default.
    static let choices = ["Fern", "Willow", "Clover", "River", "Sage", "Maple", "Robin", "Wren", "Hazel", "Rowan", "Juniper", "Aspen"]
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
    var title: String { CampfireRules.sessionTitle(kind: kind, activity: activity) }
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
}

struct GlobalCampfireResponse: Decodable, Sendable {
    var accepted: Bool
    var retryable: Bool?
    var conflict: Bool?
    var state: GlobalCampfireState?
    var agreement: CampfireAgreement?
}

struct CampfireVisibilityDocument: Codable, Equatable {
    var version = 1
    var selection: CampfireAudienceSelection?
    var runSelections: [UUID: CampfireAudienceSelection] = [:]
    var publicAgreement: CampfireAgreement?
    var publicName = PublicCampfireName.choices[0]
    var appearance = PublicCampfireAppearance()
    var commands: [GlobalCampfireCommand] = []

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
        guard agreement.enabled, agreement.version == 1 else { return }
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
            commands.removeAll { $0.command == "publish" || $0.command == "encourage" || ($0.command == "agreement" && $0.enabled == true) }
            if commands.contains(where: { $0.command == "agreement" && $0.enabled == false }) { return true }
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
