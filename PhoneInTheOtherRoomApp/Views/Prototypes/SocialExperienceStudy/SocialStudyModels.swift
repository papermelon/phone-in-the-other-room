#if DEBUG
import Foundation

// Self-contained fixture state for the September 2026 social experience study.
// Nothing here is persisted, published or connected to a service. The study
// reuses production presentation types (Shepherd appearance, sheep catalog,
// Campfire activity and outcome enums) so the art and vocabulary stay real.

enum StudySessionKind: String, CaseIterable, Identifiable {
    case windDown, phoneAway
    var id: String { rawValue }
    var title: String { self == .windDown ? "Wind Down" : "Phone Away" }
}

/// Which audience a person is visible through. The private and public cases
/// deliberately share a card layout while never sharing a store.
enum StudyAudience: Equatable {
    case party(name: String)
    case publicCampfire
    var badge: String {
        switch self {
        case let .party(name): return "\(name) member"
        case .publicCampfire: return "Public · Campfire"
        }
    }
    var isPublic: Bool { self == .publicCampfire }
}

/// Proposed mutual-connection phases for public participants. Party members
/// already know each other and skip this ladder.
enum StudyConnection: Equatable {
    case none, requestedByMe, requestedByThem, accepted
}

struct StudyPerson: Identifiable, Equatable {
    let id: UUID
    var name: String
    var presentation: CountingSheepPublicPresentation
    var isMe = false
    var audience: StudyAudience
    var connection: StudyConnection = .none
    var sheepAvatarID: String? = nil
}

struct StudySession: Identifiable, Equatable {
    let id: UUID
    var personID: UUID
    var kind: StudySessionKind
    var activity: CampfireActivity? = nil
    /// Separately authored intention (agreement version 2, private only).
    var intention: String? = nil
    var startedAt: Date
    var endsAt: Date
    var asksForBuddy = false
    var buddyPersonID: UUID? = nil
    var encouragementCount = 0
    var encouragedByMe = false
    var checkInRequested = false
    var outcome: CampfireOutcome? = nil
    var reflection: String? = nil
    var ended = false

    var title: String { kind == .windDown ? "Wind Down" : (activity?.title ?? "Phone Away") }

    /// Public cards show a coarse band; exact times stay in the private projection.
    func remainingBand(at now: Date) -> String {
        let remaining = endsAt.timeIntervalSince(now)
        if ended || remaining <= 0 { return "finished" }
        if remaining < 30 * 60 { return "under half an hour left" }
        if remaining < 90 * 60 { return "about an hour left" }
        if remaining < 4 * 3600 { return "a few hours left" }
        return "through the night"
    }
}

struct StudyVisitingSheep: Identifiable, Equatable {
    let id: UUID
    var definitionID: String
    var name: String
    var ownerID: UUID
}

/// One of my own sheep, as the send-a-sheep row needs it.
struct StudyFlockSheep: Identifiable, Equatable {
    let id: UUID
    var definitionID: String
    var name: String
    var visitingPartyName: String? = nil
}

struct StudyRecord: Identifiable, Equatable {
    let id = UUID()
    var personID: UUID
    var kind: StudySessionKind
    /// nil means the record reached the party without a minute value. The
    /// prototype shows that as unknown instead of “0 min recorded”.
    var roundedMinutes: Int?
    var occurredAt: Date
}

struct StudyGroup: Equatable {
    var name: String
    var members: [StudyPerson]
    var myID: UUID
    var roundNight: Int?
    var visitingSheep: [StudyVisitingSheep]
    var lanternContributions: Int
    var lanternRequired = 12
    var recentRecords: [StudyRecord]
    var sessions: [StudySession]
    var partySharingOn = true

    func person(_ id: UUID) -> StudyPerson? { members.first { $0.id == id } }
    var me: StudyPerson? { person(myID) }
}

struct StudyGathering: Identifiable, Equatable {
    var id: String { title }
    var title: String
    var count: Int
}

enum StudyDataState: Equatable {
    case current(observedAt: Date)
    case loading
    case failed(reason: String)
    case stale(lastObservedAt: Date)

    var permitsLivePresence: Bool {
        if case .current = self { return true }
        return false
    }
}

enum StudyAudienceChoice: String, CaseIterable, Identifiable {
    case justMe, myParties, publicCampfire, both
    var id: String { rawValue }
    var title: String {
        switch self {
        case .justMe: return "Just me"
        case .myParties: return "My Slumber Parties"
        case .publicCampfire: return "Public Campfire"
        case .both: return "Parties and public"
        }
    }
    var detail: String {
        switch self {
        case .justMe: return "Your timer runs privately. Farm credit is unchanged."
        case .myParties: return "Only parties you already share with see this session."
        case .publicCampfire: return "Your public name, Shepherd and session kind sit at one fire."
        case .both: return "Parties and the public fire each receive their own copy."
        }
    }
    var includesPublic: Bool { self == .publicCampfire || self == .both }
}

struct StudyCampfire: Equatable {
    var totalWindDown: Int
    var totalPhoneAway: Int
    var gatherings: [StudyGathering]
    var selectedGathering: String
    var participants: [StudyPerson]
    var sessions: [StudySession]
    var state: StudyDataState
    var publicAgreementAccepted: Bool
    var savedAudience: StudyAudienceChoice
    var myPublicName: String
    var sharingNow: Int { totalWindDown + totalPhoneAway }
}

struct SocialStudyScenario: Equatable {
    var title: String
    var summary: String
    var now: Date
    var group: StudyGroup
    var groupState: StudyDataState
    var campfire: StudyCampfire
    var myFlock: [StudyFlockSheep]
    /// My own running session, if any. The phone remains authoritative; the
    /// study only reads it.
    var ownSession: StudySession?
    /// A finished session waiting for my optional check-in.
    var pendingCheckIn: StudySession?
}

// MARK: - Semantic actions

/// Every tap in the study resolves to one of these. Views send intents; the
/// harness records them. Real implementations belong to Astra's integration.
enum SocialStudyAction: Equatable {
    case startSession(StudySessionKind, StudyAudienceChoice?)
    case reviewAudience
    case acceptPublicAgreement
    case joinWithOwnSession(StudySession.ID, StudySessionKind)
    case backToRunningSession
    case encourage(StudySession.ID)
    case offerCheckIn(StudySession.ID)
    case askHowItWent(StudySession.ID)
    case acknowledgeResult(StudySession.ID)
    case shareCheckIn(StudySession.ID, CampfireOutcome)
    case openMembers
    case openMeadow
    case openImprovement
    case openPerson(UUID)
    case sendSheep(StudyFlockSheep.ID)
    case recallSheep(StudyVisitingSheep.ID)
    case requestConnection(UUID)
    case respondToConnection(UUID, accept: Bool)
    case inviteToParty(UUID)
    case block(UUID)
    case report(UUID)
    case retry
    case changeGathering(String)
    case suggestEveningPlan
    case adjustNextRound(String)

    enum Integration { case existing(String), proposal(String) }

    /// Existing behavior surfaced or new proposal, with the callback or
    /// contract Astra should connect. Kept beside the action so the
    /// interaction inventory and the views cannot drift apart.
    var integration: Integration {
        switch self {
        case .startSession: return .existing("Existing start sheet (WindDownStartSheet / Phone Away) via FocusRunViewModel; audience choice extends CampfireStartChoices")
        case .reviewAudience: return .existing("CampfireSharingSheet(social:partyID:) for party audience; public audience is new")
        case .acceptPublicAgreement: return .proposal("New public-sharing agreement record; see global-campfire plan consent contract")
        case .joinWithOwnSession: return .existing("FocusRunViewModel.startNewOneTimeAdditionalQuietNow() as CampfireBuddyCard.onJoin does")
        case .backToRunningSession: return .existing("NotificationCenter .countingSheepShowHome")
        case .encourage: return .existing("NightFlockViewModel.sendCampfireAction(\"encourage\", …) for parties; public encouragement is new")
        case .offerCheckIn: return .existing("sendCampfireAction(\"accept\", …); party-only, one volunteer buddy per session")
        case .askHowItWent: return .existing("sendCampfireAction(\"checkIn\", …) after checkInAfter")
        case .acknowledgeResult: return .existing("Fixed cheer on a completed record: sendSlumberPartyCheer / cheerMembershipSlumberPartyMember")
        case .shareCheckIn: return .existing("sendCampfireAction(\"reflect\", outcome, note); first accepted check-in wins")
        case .openMembers: return .existing("SlumberPartyV4GroupDetailsView (people, invitations, controls)")
        case .openMeadow: return .existing("SlumberPartyPastureView in Shared meadow mode")
        case .openImprovement: return .existing("SharedPastureLanternSheet(lantern:)")
        case .openPerson: return .existing("SlumberPartyMemberUpdatesView / CampfireBuddyCard sheet; public person card is new")
        case .sendSheep: return .existing("NightFlockViewModel.contributeSheep(_:partyID:)")
        case .recallSheep: return .existing("NightFlockViewModel.recallSheep(_:partyID:)")
        case .requestConnection, .respondToConnection: return .proposal("Mutual connection request; campfire-public-command connect/respond")
        case .inviteToParty: return .proposal("Explicit party invitation to an accepted connection using existing invite disclosure")
        case .block: return .existing("blockSlumberPartyMember(partyID:memberID:) for parties; public block is new")
        case .report: return .existing("reportSlumberPartyMember(partyID:memberID:reason:) for parties; public report is new")
        case .retry: return .existing("refreshSelectedSlumberParty() / refreshV4PartyObservation")
        case .changeGathering: return .proposal("Server-assigned gathering topics; campfire-public-state")
        case .suggestEveningPlan: return .proposal("Shared evening plan negotiation; each adult accepts or edits their own participation")
        case .adjustNextRound: return .proposal("Small next-round adjustment saved to my own plan only")
        }
    }

    var isProposal: Bool {
        if case .proposal = integration { return true }
        return false
    }
}

/// Records intents so a reviewer can see what a tap would have asked for.
@MainActor
final class SocialStudyActionLog: ObservableObject {
    @Published private(set) var entries: [String] = []
    @Published var latest: String?

    func record(_ action: SocialStudyAction) {
        let line = "\(action.isProposal ? "PROPOSAL" : "EXISTING") · \(String(describing: action))"
        entries.append(line)
        latest = line
    }
}
#endif
