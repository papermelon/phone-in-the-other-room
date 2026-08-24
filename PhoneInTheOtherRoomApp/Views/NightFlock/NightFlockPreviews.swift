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
                status: status,
                sharedGoal: NightFlockSharedGoal(kind: .phoneAway),
                hostStartedAt: status == .pending ? nil : Date()
            ),
            days: (1...7).map { day in
                NightFlockDaySummary(
                    day: day,
                    phoneTuckedCount: day == 1 ? 2 : 0,
                    morningQuietCompletedCount: day == 1 ? 1 : 0,
                    pasture: day == 1 ? [entry] : []
                )
            },
            sharingEnabled: true,
            memberSetups: [
                NightFlockMemberSetup(memberID: myMember.id, goalAccepted: true, setupReady: true, sharingEnabled: true, shareRoutineIdeas: true, shieldingEvidence: .notRequested),
                NightFlockMemberSetup(memberID: peer.id, goalAccepted: status != .pending, setupReady: status != .pending, sharingEnabled: true, shareRoutineIdeas: false, shieldingEvidence: .notRequested)
            ]
        )
    }
}

@MainActor
private func previewModel(
    phase: NightFlockViewModel.Phase,
    snapshot: NightFlockSnapshot? = nil,
    account: NightFlockAccountState = .linked,
    recovery: NightFlockAuthenticationAction = .none
) -> NightFlockViewModel {
    let model = NightFlockViewModel(
        featureEnabled: true,
        previewSnapshot: snapshot,
        previewPhase: phase,
        previewAccountState: account
    )
    model.pendingAuthenticationRecovery = recovery
    return model
}

#Preview("Slumber Party · active") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(
            phase: .ready,
            snapshot: NightFlockPreviewData.snapshot()
        ))
        .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
}

#Preview("Slumber Party · completed · Large Type") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(
            phase: .ready,
            snapshot: NightFlockPreviewData.snapshot(status: .completed)
        ))
        .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Slumber Party · account entry") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(phase: .idle, account: .anonymous))
    }
}

#Preview("Slumber Party · linking Apple account") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(phase: .loading, account: .linking))
    }
}

#Preview("Slumber Party · Apple link error") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(
            phase: .error("Apple sign-in finished, but account linking is not available yet. Your current account and local data were left unchanged."),
            account: .anonymous
        ))
    }
}

#Preview("Slumber Party · reconnect Apple account") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(
            phase: .error("Your connection needs to be checked again."),
            recovery: .reauthenticateApple
        ))
    }
}

#Preview("Slumber Party · link existing anonymous account") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(
            phase: .error("This account needs Apple sign-in."),
            account: .anonymous,
            recovery: .linkCurrentAnonymousApple
        ))
    }
}

#Preview("Slumber Party · account mismatch stayed closed") {
    NavigationStack {
        NightFlockHubView(viewModel: previewModel(
            phase: .error("Counting Sheep could not prove this is the original account."),
            recovery: .failClosed
        ))
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
