import SwiftUI

/// Disposable data for ordinary previews and the isolated native capture entry.
enum SlumberPartySharedFarmFixtures {
    static let partyID = UUID(uuidString: "91000000-0000-4000-8000-000000000001")!
    static let me = UUID(uuidString: "91000000-0000-4000-8000-000000000002")!
    static let friend = UUID(uuidString: "91000000-0000-4000-8000-000000000003")!
    static let now = Date(timeIntervalSince1970: 1788912000)
    static var party: NightFlockV4PartyDetail {
        var clover = CountingSheepPublicPresentation.defaultValue
        clover.headShapeID = "round"
        clover.hairStyleID = "long"
        clover.shepherdOutfitID = "shepherd_moon_coat"
        clover.shepherdAccessoryID = "shepherd_moon_beanie"
        var moss = CountingSheepPublicPresentation.defaultValue
        moss.avatarID = "ollie"
        moss.ollieOrnamentID = "ollie_moss_bandana"
        let members: [NightFlockV4Membership] = [
            .init(memberID: me, profile: .init(displayName: "Clover", presentation: clover), role: .host, joinedAt: now.addingTimeInterval(-86400 * 3)),
            .init(memberID: friend, profile: .init(displayName: "Moss", presentation: moss), role: .member, joinedAt: now.addingTimeInterval(-86400 * 2))
        ]
        let updates = members.enumerated().map { index, member in
            NightFlockV4SharedActivity(activityID: UUID(uuidString: "92000000-0000-4000-8000-00000000000\(index + 1)")!,
                partyID: partyID, memberID: member.memberID, kind: .windDown, status: .completed,
                roundedMinutes: index == 0 ? 30 : 45, occurredAt: now.addingTimeInterval(-3600))
        }
        var party = NightFlockV4PartyDetail(summary: .init(partyID: partyID, name: "Moonlit Neighbours", memberCount: 2,
            myRole: .host, currentRound: nil, revision: 1, sharingScope: .membership), myMemberID: me,
            memberships: members, sharedActivities: updates,
            sharedCheers: [.init(activityID: updates[0].id, cheer: .moonGlow, count: 1, sentByMe: false)])
        party.updateCheerReceiptVersion = 1
        party.updateCheerReceipts = [.init(reactionID: UUID(uuidString: "93000000-0000-4000-8000-000000000001")!,
            activityID: updates[0].id, senderMemberID: friend, recipientMemberID: me,
            cheer: .moonGlow, acceptedAt: now, receivedByAppAt: now)]
        return party
    }
}

#if DEBUG
struct SlumberPartySharedFarmNativeFixture: View {
    @StateObject private var model: NightFlockViewModel
    @StateObject private var appModel: FocusRunViewModel
    private let party: NightFlockV4PartyDetail
    private let mode: String

    init() {
        let args = ProcessInfo.processInfo.arguments
        mode = args.first(where: { $0.hasPrefix("--farm-state=") })?.replacingOccurrences(of: "--farm-state=", with: "") ?? "farm"
        var party = SlumberPartySharedFarmFixtures.party
        if mode == "empty" { party.sharedActivities = [] }
        if mode == "old-server" { party.updateCheerReceiptVersion = nil; party.updateCheerReceipts = []; party.memberships[0].profile.presentation.headShapeID = nil }
        if mode == "unsupported" { party.memberships[0].profile.presentation.headShapeID = "future"; party.updateCheerReceiptVersion = nil }
        if mode == "large-party" {
            for index in 2..<8 {
                var member = party.memberships[index % 2]
                member.memberID = UUID()
                member.profile.displayName = ["Juniper", "Fern", "Rowan", "Willow", "Hazel", "River"][index - 2]
                member.joinedAt = member.joinedAt.addingTimeInterval(Double(index))
                if index == 7 { member.profile.presentation.avatarID = "sheep:juniper" }
                party.memberships.append(member)
            }
            party.summary.memberCount = 8
        }
        self.party = party
        let defaults = UserDefaults(suiteName: "SlumberPartyNativeFixture.\(UUID())")!
        let model = NightFlockViewModel(featureEnabled: true, previewPhase: .ready, previewAccountState: .linked, defaults: defaults)
        model.v4ListState = .init(parties: [party.summary], profileAvatarVersion: 1, sharedHabitsVersion: 1)
        model.sharedHabitsStates[party.summary.partyID] = .init(agreement: .init(agreementID: UUID(), memberEpochID: UUID(),
            acceptedAt: SlumberPartySharedFarmFixtures.now, timeZoneIdentifier: "UTC", firstEligibleSleepNight: nil),
            records: [], nextCursor: nil, snapshotRevision: 1, periods: [])
        model.v4ObservedPartyDetails[party.summary.partyID] = party
        model.v4ObservedPartyObservationStates[party.summary.partyID] = .current(lastReceivedAt: Date())
        if mode == "stale" { model.v4ObservedPartyObservationStates[party.summary.partyID] = .stale(lastReceivedAt: Date().addingTimeInterval(-86400)) }
        if mode == "pending", let update = party.sharedActivities.last {
            model.v4CheerSendStates[.init(partyID: party.summary.partyID, target: .membershipActivity(update.id), cheer: .warmWave)] = .pending
        }
        _model = StateObject(wrappedValue: model)
        _appModel = StateObject(wrappedValue: FocusRunViewModel(persistence: PersistenceService(defaults: defaults),
            startsExternalServices: false, nightFlockViewModel: model, purposeCueDefaults: defaults))
    }
    var body: some View {
        Group {
            if mode == "recipient" || mode == "friend" || mode == "empty" || mode == "unsupported" || mode == "pending" || mode == "old-server" {
                SlumberPartyMemberUpdatesView(viewModel: model, partyID: party.summary.partyID,
                    memberID: ["friend", "pending", "old-server"].contains(mode) ? SlumberPartySharedFarmFixtures.friend : SlumberPartySharedFarmFixtures.me,
                    showsSocialAvatar: true)
            } else {
                NavigationStack { SlumberPartyV4PartyDetailView(viewModel: model, summary: party.summary) }
                    .environmentObject(appModel)
            }
        }
        .dynamicTypeSize(ProcessInfo.processInfo.arguments.contains("--farm-accessibility") ? .accessibility3 : .large)
    }
}
#endif
