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

#Preview("Night Flock · active") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(
            phase: .ready,
            snapshot: NightFlockPreviewData.snapshot()
        ))
    }
}

#Preview("Night Flock · completed · Large Type") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(
            phase: .ready,
            snapshot: NightFlockPreviewData.snapshot(status: .completed)
        ))
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Night Flock · account entry") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(phase: .idle, account: .anonymous))
    }
}

#Preview("Night Flock · empty") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(phase: .ready))
    }
}

#Preview("Night Flock · loading") {
    NavigationStack { NightFlockHubView(viewModel: previewModel(phase: .loading)) }
}

#Preview("Night Flock · offline") {
    NavigationStack { NightFlockHubView(viewModel: previewModel(phase: .offline)) }
}

#Preview("Night Flock · expired invite") {
    NavigationStack { NightFlockHubView(viewModel: previewModel(phase: .expiredInvite)) }
}

#Preview("Night Flock · full") {
    NavigationStack { NightFlockHubView(viewModel: previewModel(phase: .fullFlock)) }
}

#Preview("Night Flock · blocked") {
    NavigationStack { NightFlockHubView(viewModel: previewModel(phase: .blocked)) }
}
