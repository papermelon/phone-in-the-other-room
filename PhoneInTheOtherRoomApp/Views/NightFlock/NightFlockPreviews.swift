import SwiftUI

private enum NightFlockPreviewData {
    static let myMember = NightFlockMember(id: UUID(), alias: "Mossy Wren", role: .keeper)
    static let peer = NightFlockMember(id: UUID(), alias: "Amber Clover", role: .member)
    static let challengeID = UUID()
    static let entry = NightFlockPastureEntry(
        id: UUID(),
        state: .morningQuietCompleted,
        reactions: [NightFlockReactionSummary(
            id: UUID(), kind: .warmWave, count: 2, reactedByMe: true
        )]
    )

    static func snapshot(status: NightFlockChallenge.Status = .active) -> NightFlockSnapshot {
        NightFlockSnapshot(
            profile: NightFlockProfile(alias: myMember.alias),
            flockID: UUID(),
            identity: .moonlitMeadow,
            myMemberID: myMember.id,
            members: [myMember, peer],
            challenge: NightFlockChallenge(
                id: challengeID,
                timeZoneIdentifier: TimeZone.current.identifier,
                startsOn: NightFlockLocalDate(year: 2026, month: 8, day: 12),
                status: status
            ),
            days: (1...7).map { day in
                NightFlockDaySummary(
                    day: day,
                    phoneTuckedCount: day == 1 ? 2 : 0,
                    morningQuietCompletedCount: day == 1 ? 1 : 0,
                    pasture: day == 1 ? [entry] : []
                )
            },
            sharingEnabled: true
        )
    }
}

@MainActor
private func previewModel(
    phase: NightFlockViewModel.Phase,
    snapshot: NightFlockSnapshot? = nil,
    account: NightFlockAccountState = .linked
) -> NightFlockViewModel {
    NightFlockViewModel(
        featureEnabled: true,
        previewSnapshot: snapshot,
        previewPhase: phase,
        previewAccountState: account
    )
}

#Preview("Slumber Party · active") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(
            phase: .ready,
            snapshot: NightFlockPreviewData.snapshot()
        ))
    }
}

#Preview("Slumber Party · completed · Large Type") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(
            phase: .ready,
            snapshot: NightFlockPreviewData.snapshot(status: .completed)
        ))
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Slumber Party · account entry") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(phase: .idle, account: .anonymous))
    }
}

#Preview("Slumber Party · empty") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(phase: .ready))
    }
}

#Preview("Slumber Party · loading") {
    NavigationStack { NightFlockHubView(viewModel: previewModel(phase: .loading)) }
}

#Preview("Slumber Party · offline") {
    NavigationStack { NightFlockHubView(viewModel: previewModel(phase: .offline)) }
}

#Preview("Slumber Party · expired invite") {
    NavigationStack { NightFlockHubView(viewModel: previewModel(phase: .expiredInvite)) }
}

#Preview("Slumber Party · full") {
    NavigationStack { NightFlockHubView(viewModel: previewModel(phase: .fullFlock)) }
}

#Preview("Slumber Party · blocked") {
    NavigationStack { NightFlockHubView(viewModel: previewModel(phase: .blocked)) }
}
