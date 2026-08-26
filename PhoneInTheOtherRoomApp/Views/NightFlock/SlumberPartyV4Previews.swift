import SwiftUI

@MainActor
private enum SlumberPartyV4PreviewData {
    static let hostID = UUID()
    static let memberID = UUID()

    static var party: NightFlockV4PartyDetail {
        let round = NightFlockV4Round(
            roundID: UUID(),
            number: 2,
            timeZoneIdentifier: TimeZone.current.identifier,
            startsOn: NightFlockLocalDate(year: 2026, month: 8, day: 25),
            status: .active
        )
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
            joinedAt: Date().addingTimeInterval(-86_400)
        )
        let member = NightFlockV4Membership(
            memberID: memberID,
            profile: CountingSheepUserProfile(displayName: "Moss"),
            role: .member,
            joinedAt: Date().addingTimeInterval(-86_400)
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
            occurredAt: Date()
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
                    status: .windDownCompleted,
                    revision: 1,
                    observedAt: Date(),
                    expiresAt: Date().addingTimeInterval(900)
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

    static func model(for party: NightFlockV4PartyDetail) -> NightFlockViewModel {
        let model = NightFlockViewModel(
            featureEnabled: true,
            previewPhase: .ready,
            previewAccountState: .linked
        )
        model.selectedV4Party = party
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
