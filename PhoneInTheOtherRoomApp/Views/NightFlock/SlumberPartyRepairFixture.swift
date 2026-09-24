#if DEBUG
import SwiftUI

/// Uses production views with local fixture state and no network service.
struct SlumberPartyRepairFixture: View {
    @StateObject private var social: NightFlockViewModel
    @StateObject private var app = FocusRunViewModel(startsExternalServices: false)
    private let party: NightFlockV4PartyDetail
    private let mode: String
    private let person: SlumberPartyPerson

    init(mode: String? = nil) {
        let arguments = ProcessInfo.processInfo.arguments
        let selectedMode = mode ?? arguments.firstIndex(of: "--repair-mode").flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } ?? "create"
        self.mode = selectedMode
        let partyID = UUID(), memberID = UUID(), recipientID = UUID()
        let summary = NightFlockV4PartySummary(partyID: partyID, name: "Night Owls", memberCount: 1, myRole: .host,
            currentRound: nil, revision: 1, sharingScope: .membership)
        party = NightFlockV4PartyDetail(summary: summary, myMemberID: memberID, memberships: [
            .init(memberID: memberID, profile: .init(displayName: "Willow"), role: .host, joinedAt: .now)
        ])
        person = .init(userID: recipientID, name: "Fern", handle: "fern_meadow", isMember: false, isInvited: selectedMode == "invited")
        let model = NightFlockViewModel(featureEnabled: true, previewPhase: .ready, previewAccountState: .linked)
        model.installV4ObservedPartyPreview(party)
        model.v4ListState?.sharedHabitsVersion = 1
        model.v4ListState?.directInvitationsVersion = 1
        model.sharedHabitsStates[partyID] = .init(agreement: .init(agreementID: UUID(), memberEpochID: UUID(), acceptedAt: .now,
            timeZoneIdentifier: "Asia/Singapore", firstEligibleSleepNight: nil), records: [], nextCursor: nil, snapshotRevision: 1, periods: [])
        if selectedMode == "create" || selectedMode == "creating" { model.v4ListState?.parties = [] }
        if selectedMode == "creating" { _ = model.v4Acquisition.begin(.create(name: "Night Owls", timeZone: "Asia/Singapore")) }
        if selectedMode == "created" { model.v4Acquisition.finish(partyID: partyID) }
        if selectedMode == "refreshing" || selectedMode == "campfire" { model.v4ObservedPartyObservationStates[partyID] = .refreshing(lastReceivedAt: nil) }
        if selectedMode == "campfire-error" { model.v4ObservedPartyObservationStates[partyID] = .stale(lastReceivedAt: nil) }
        model.partyConnections = .init(version: 1, userID: memberID, handle: "willow", invitations: selectedMode == "invited" ? [
            .init(id: UUID(), partyID: partyID, partyName: "Night Owls", senderName: "Willow", recipientName: "Fern", recipientID: recipientID,
                isIncoming: false, canRevoke: true, expiresAt: Date().addingTimeInterval(7 * 86_400))
        ] : [])
        if selectedMode == "error" { model.partyConnectionsError = SlumberPartyConnectionError.offline.errorDescription }
        if selectedMode == "searching" { model.partyConnectionsBusy = true }
        if ["load-error", "load-offline", "load-timeout", "refresh-error"].contains(selectedMode) {
            if selectedMode != "refresh-error" { model.v4ListState = nil }
            let error: NightFlockRemoteError
            switch selectedMode {
            case "load-offline": error = .network(reason: .notConnectedToInternet)
            case "load-timeout": error = .network(reason: .timedOut)
            default: error = .init(statusCode: 500, code: .internalError, requestID: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
            }
            model.presentListRefreshError(error)
        }
        _social = StateObject(wrappedValue: model)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case "load-error", "load-offline", "load-timeout", "refresh-error": NightFlockHubView(viewModel: social)
                case "campfire", "campfire-error": CampfireView(social: social, partyID: party.summary.partyID, onStart: { _ in })
                case "loader":
                    ScrollView {
                        SheepLoadingView("Syncing live updates…").padding(AppSpacing.md)
                    }.background(AppColors.paper).navigationTitle("Campfire")
                case "automatic": FocusRunSetupView()
                case "party", "refreshing": SlumberPartyV4PartyDetailView(viewModel: social, summary: party.summary)
                case "group": SlumberPartyV4GroupDetailsView(viewModel: social, party: party)
                case "search", "invited", "searching", "error":
                    SlumberPartyInvitePeopleView(social: social, partyID: party.summary.partyID,
                        initialPerson: mode == "search" || mode == "invited" ? person : nil)
                default:
                    ScrollView {
                        SlumberPartyV4ListView(viewModel: social, initialAcquisition: mode == "created" ? nil : "create")
                            .padding(AppSpacing.md)
                    }.background(AppColors.paper).navigationTitle("Slumber Party").navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .environmentObject(app)
        .environment(\.dynamicTypeSize, ProcessInfo.processInfo.arguments.contains("--large-text") ? .accessibility3 : .large)
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--light") ? .light : .dark)
        .onAppear { _ = app.saveShepherdDisplayName("Willow") }
    }
}

#Preview("Party · server error") { SlumberPartyRepairFixture(mode: "load-error") }
#Preview("Party · cached refresh error") { SlumberPartyRepairFixture(mode: "refresh-error") }
#Preview("Party · offline") { SlumberPartyRepairFixture(mode: "load-offline") }
#Preview("Party · timeout") { SlumberPartyRepairFixture(mode: "load-timeout") }
#Preview("Party · created") { SlumberPartyRepairFixture(mode: "created") }
#Preview("Party · invitation sent") { SlumberPartyRepairFixture(mode: "invited") }
#Preview("Party · invitation error") { SlumberPartyRepairFixture(mode: "error") }
#endif
