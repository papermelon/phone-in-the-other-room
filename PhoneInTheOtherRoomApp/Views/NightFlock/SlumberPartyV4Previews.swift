import SwiftUI

@MainActor
private enum SlumberPartyV4PreviewData {
    static let hostID = UUID()
    static let memberID = UUID()

    static var now: Date { Date() }

    static var today: NightFlockLocalDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        return NightFlockLocalDate(
            year: components.year ?? 2026,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
    }

    static func round(
        status: NightFlockV4RoundStatus,
        start: NightFlockLocalDate? = nil
    ) -> NightFlockV4Round {
        let start = start ?? today
        return NightFlockV4Round(
            roundID: UUID(),
            number: 2,
            timeZoneIdentifier: TimeZone.current.identifier,
            startsOn: start,
            status: status
        )
    }

    static var party: NightFlockV4PartyDetail {
        let round = round(status: .active)
        let summary = NightFlockV4PartySummary(
            partyID: UUID(),
            name: "Moonlit Neighbours",
            memberCount: 2,
            myRole: .host,
            currentRound: round,
            revision: 1
        )
        let host = NightFlockV4Membership(
            memberID: hostID,
            profile: CountingSheepUserProfile(displayName: "Clover"),
            role: .host,
            joinedAt: now.addingTimeInterval(-86_400)
        )
        let member = NightFlockV4Membership(
            memberID: memberID,
            profile: CountingSheepUserProfile(displayName: "Moss"),
            role: .member,
            joinedAt: now.addingTimeInterval(-86_400)
        )
        let activity = NightFlockV4Activity(
            activityID: UUID(),
            partyID: summary.partyID,
            roundID: round.roundID,
            memberID: memberID,
            day: 1,
            kind: .windDown,
            status: .completed,
            roundedMinutes: 30,
            occurredAt: now
        )
        return NightFlockV4PartyDetail(
            summary: summary,
            myMemberID: hostID,
            memberships: [host, member],
            activities: [activity],
            liveStatuses: [
                NightFlockV4LiveStatus(
                    partyID: summary.partyID,
                    roundID: round.roundID,
                    memberID: memberID,
                    status: .phoneAwayActive,
                    revision: 1,
                    observedAt: now,
                    expiresAt: now.addingTimeInterval(900)
                )
            ],
            cheers: [
                NightFlockV4CheerSummary(
                    activityID: activity.activityID,
                    cheer: .warmWave,
                    count: 1,
                    sentByMe: true
                )
            ]
        )
    }

    static var pendingHost: NightFlockV4PartyDetail {
        detail(role: .host, round: nil, name: "Family Wind Down")
    }

    static var pendingMember: NightFlockV4PartyDetail {
        detail(role: .member, round: nil, name: "Family Wind Down")
    }

    static var elapsed: NightFlockV4PartyDetail {
        detail(role: .host, round: round(status: .completed), name: "Family Wind Down")
    }

    static var activeNoUpdate: NightFlockV4PartyDetail {
        detail(role: .member, round: round(status: .active), name: "Quiet Neighbours")
    }

    static var activeExpiredStatus: NightFlockV4PartyDetail {
        var result = activeNoUpdate
        if let round = result.summary.currentRound {
            result.liveStatuses = [NightFlockV4LiveStatus(
                partyID: result.summary.partyID,
                roundID: round.roundID,
                memberID: memberID,
                status: .phoneAwayActive,
                revision: 2,
                observedAt: now.addingTimeInterval(-900),
                expiresAt: now.addingTimeInterval(-1)
            )]
        }
        return result
    }

    static var terminalWithCheers: NightFlockV4PartyDetail {
        var result = party
        result.activities[0].status = .partlyCompleted
        result.activities[0].roundedMinutes = 18
        result.activities[0].occurredAt = now
        if let round = result.summary.currentRound {
            result.liveStatuses = [NightFlockV4LiveStatus(
                partyID: result.summary.partyID,
                roundID: round.roundID,
                memberID: memberID,
                status: .phoneAwayActive,
                revision: 2,
                observedAt: now.addingTimeInterval(-120),
                expiresAt: now.addingTimeInterval(600)
            )]
            result.liveCheers = [NightFlockV4LiveCheerSummary(
                memberID: memberID,
                cheer: .warmWave,
                count: 2,
                sentByMe: true
            )]
        }
        return result
    }

    static var partyWithFeaturedSheep: NightFlockV4PartyDetail {
        var result = party
        if let definition = SheepCatalog.all.first,
           let index = result.memberships.firstIndex(where: { $0.memberID == memberID }) {
            var profile = result.memberships[index].profile
            profile.presentation.featuredSheepDefinitionID = definition.id
            profile.presentation.pastureThemeID = "pasture_moonlit"
            result.memberships[index].profile = profile
        }
        return result
    }

    static func listModels(
        parties: [NightFlockV4PartySummary]
    ) -> (NightFlockViewModel, FocusRunViewModel) {
        let partyObjects = parties.map { party in
            try! JSONSerialization.jsonObject(with: JSONEncoder().encode(party))
        }
        let data = try! JSONSerialization.data(withJSONObject: [
            "schemaVersion": NightFlockV4Rules.schemaVersion,
            "parties": partyObjects,
            "grantInbox": []
        ])
        let social = NightFlockViewModel(
            featureEnabled: true,
            previewPhase: .ready,
            previewAccountState: .linked
        )
        social.v4ListState = try! JSONDecoder().decode(
            NightFlockV4ListStateResponse.self,
            from: data
        )
        let app = FocusRunViewModel(
            startsExternalServices: false,
            nightFlockViewModel: social
        )
        return (social, app)
    }

    static var solo: NightFlockV4PartyDetail {
        let host = NightFlockV4Membership(
            memberID: hostID,
            profile: CountingSheepUserProfile(displayName: "Clover"),
            role: .host,
            joinedAt: now.addingTimeInterval(-86_400)
        )
        let summary = NightFlockV4PartySummary(
            partyID: UUID(), name: "Family Wind Down", memberCount: 1,
            myRole: .host, currentRound: nil, revision: 1
        )
        return NightFlockV4PartyDetail(
            summary: summary,
            myMemberID: hostID,
            memberships: [host],
            invitation: NightFlockV4InvitationMetadata(
                inviteID: UUID(), partyID: summary.partyID, createdAt: now,
                expiresAt: now.addingTimeInterval(86_400), status: .active
            )
        )
    }

    static var bridgeSummaries: [(String, NightFlockHomeSummary)] {
        let singleParty = NightFlockV4PartySummary(
            partyID: UUID(), name: "Family Wind Down", memberCount: 2,
            myRole: .member, currentRound: nil, revision: 1
        )
        let secondParty = NightFlockV4PartySummary(
            partyID: UUID(), name: "Sunday Soft Landing", memberCount: 3,
            myRole: .host, currentRound: nil, revision: 1
        )
        return [
            ("No parties", NightFlockHomeSummary.make(from: [] as [NightFlockV4PartySummary])),
            ("One party", NightFlockHomeSummary.make(from: [singleParty])),
            ("Multiple parties", NightFlockHomeSummary.make(from: [singleParty, secondParty]))
        ]
    }

    private static func detail(
        role: NightFlockV4Role,
        round: NightFlockV4Round?,
        name: String
    ) -> NightFlockV4PartyDetail {
        let summary = NightFlockV4PartySummary(
            partyID: UUID(), name: name, memberCount: 2,
            myRole: role, currentRound: round, revision: 1
        )
        let host = NightFlockV4Membership(
            memberID: hostID,
            profile: CountingSheepUserProfile(displayName: "Clover"),
            role: .host,
            joinedAt: now.addingTimeInterval(-86_400)
        )
        let member = NightFlockV4Membership(
            memberID: memberID,
            profile: CountingSheepUserProfile(displayName: "Moss"),
            role: .member,
            joinedAt: now.addingTimeInterval(-86_400)
        )
        return NightFlockV4PartyDetail(
            summary: summary,
            myMemberID: role == .host ? hostID : memberID,
            memberships: [host, member]
        )
    }

    static func model(for party: NightFlockV4PartyDetail) -> NightFlockViewModel {
        let model = NightFlockViewModel(
            featureEnabled: true,
            previewPhase: .ready,
            previewAccountState: .linked
        )
#if DEBUG
        model.installV4ObservedPartyPreview(party)
#endif
        return model
    }
}

#Preview("Slumber Party v4 detail · accessibility", traits: .fixedLayout(width: 390, height: 844)) {
    let party = SlumberPartyV4PreviewData.party
    NavigationStack {
        SlumberPartyV4PartyDetailView(
            viewModel: SlumberPartyV4PreviewData.model(for: party),
            summary: party.summary
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Slumber Party v4 detail · dark") {
    let party = SlumberPartyV4PreviewData.party
    NavigationStack {
        SlumberPartyV4PartyDetailView(
            viewModel: SlumberPartyV4PreviewData.model(for: party),
            summary: party.summary
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Slumber Party v4 landing · no parties · start", traits: .fixedLayout(width: 390, height: 844)) {
    let models = SlumberPartyV4PreviewData.listModels(parties: [])
    NavigationStack {
        SlumberPartyV4ListView(viewModel: models.0, initialAcquisition: "create")
    }
    .environmentObject(models.1)
}

#Preview("Slumber Party v4 landing · no parties · join", traits: .fixedLayout(width: 390, height: 844)) {
    let models = SlumberPartyV4PreviewData.listModels(parties: [])
    NavigationStack {
        SlumberPartyV4ListView(viewModel: models.0, initialAcquisition: "join")
    }
    .environmentObject(models.1)
}

#Preview("Slumber Party v4 landing · existing parties · dark") {
    let first = SlumberPartyV4PreviewData.party.summary
    let second = NightFlockV4PartySummary(
        partyID: UUID(), name: "Sunday Soft Landing", memberCount: 3,
        myRole: .member, currentRound: nil, revision: 1
    )
    let models = SlumberPartyV4PreviewData.listModels(parties: [first, second])
    NavigationStack {
        SlumberPartyV4ListView(viewModel: models.0)
    }
    .environmentObject(models.1)
    .preferredColorScheme(.dark)
}

#Preview("Slumber Party v4 detail · pending host") {
    let party = SlumberPartyV4PreviewData.pendingHost
    NavigationStack {
        SlumberPartyV4PartyDetailView(
            viewModel: SlumberPartyV4PreviewData.model(for: party),
            summary: party.summary
        )
    }
}

#Preview("Slumber Party v4 detail · pending member") {
    let party = SlumberPartyV4PreviewData.pendingMember
    NavigationStack {
        SlumberPartyV4PartyDetailView(
            viewModel: SlumberPartyV4PreviewData.model(for: party),
            summary: party.summary
        )
    }
}

#Preview("Slumber Party v4 detail · solo host") {
    let party = SlumberPartyV4PreviewData.solo
    NavigationStack {
        SlumberPartyV4PartyDetailView(
            viewModel: SlumberPartyV4PreviewData.model(for: party),
            summary: party.summary
        )
    }
}

#Preview("Slumber Party v4 detail · elapsed") {
    let party = SlumberPartyV4PreviewData.elapsed
    NavigationStack {
        SlumberPartyV4PartyDetailView(
            viewModel: SlumberPartyV4PreviewData.model(for: party),
            summary: party.summary
        )
    }
}

#Preview("Slumber Party v4 detail · terminal activity and historical cheers") {
    let party = SlumberPartyV4PreviewData.terminalWithCheers
    NavigationStack {
        SlumberPartyV4PartyDetailView(
            viewModel: SlumberPartyV4PreviewData.model(for: party),
            summary: party.summary
        )
    }
}

#Preview("Slumber Party v4 member · compact identities") {
    let party = SlumberPartyV4PreviewData.partyWithFeaturedSheep
    let member = party.memberships[1]
    SlumberPartyV4MemberCard(
        member: member,
        isYou: false,
        presentation: NightFlockV4Presentation.member(member, in: party)
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Slumber Party v4 member · no shared update · AX3", traits: .fixedLayout(width: 390, height: 500)) {
    let party = SlumberPartyV4PreviewData.activeExpiredStatus
    let member = party.memberships[1]
    SlumberPartyV4MemberCard(
        member: member,
        isYou: false,
        presentation: NightFlockV4Presentation.member(member, in: party)
    )
    .padding()
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Slumber Party v4 bridges · Home and Farm") {
    ScrollView {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            ForEach(SlumberPartyV4PreviewData.bridgeSummaries, id: \.0) { label, summary in
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(label)
                        .font(AppTypography.headline)
                    NightFlockHomeCard(summary: summary, context: .home, action: {})
                    NightFlockHomeCard(summary: summary, context: .farm, action: {})
                }
            }
        }
        .padding()
    }
    .background(AppColors.paper)
}
