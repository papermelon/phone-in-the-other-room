import SwiftUI

extension Notification.Name {
    static let countingSheepShowCampfire = Notification.Name("countingSheepShowCampfire")
}

struct CampfireHomeEntry: View {
    @ObservedObject var social: NightFlockViewModel
    var body: some View {
        PixelCard {
            HStack(spacing: AppSpacing.xs) {
                Button { NotificationCenter.default.post(name: .countingSheepShowCampfire, object: nil) } label: {
                    HStack(spacing: AppSpacing.sm) {
                        PaperCampfire().frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("Campfire").font(AppTypography.headline)
                            Text("My visibility · \(social.campfireVisibility.title)").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        }.fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: AppSpacing.xs)
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                    }.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                }.buttonStyle(.plain)
                    .foregroundStyle(AppColors.ink)
                    .accessibilityHint("Browse your party or the global campfire. Opening it doesn’t share your session.")
                HomeSocialInfoButton.campfire
            }
        }
        .task(id: social.campfireOwnerForNewRun) { _ = social.restoreCampfireVisibility() }
    }
}

struct CampfireView: View {
    @ObservedObject var social: NightFlockViewModel
    var partyID: UUID? = nil
    @EnvironmentObject private var app: FocusRunViewModel
    var onStart: (NightFlockV4ActivityKind) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView { CampfirePanel(social: social, partyID: partyID ?? (social.globalCampfireState?.isSupported == true ? nil : social.slumberParties.first?.partyID), onStart: onStart).padding(AppSpacing.md) }
                .background(AppColors.paper.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .bottomBar) {
                        if app.isRunning {
                            Button("Back to your session") {
                                NotificationCenter.default.post(name: .countingSheepShowHome, object: nil)
                            }
                        }
                    }
                }
        }
    }
}

/// The same live-session surface is used from a private group and Home.
/// View scope is local UI state; it is never written to the audience journal.
struct CampfirePanel: View {
    @ObservedObject var social: NightFlockViewModel
    var onStart: (NightFlockV4ActivityKind) -> Void
    @EnvironmentObject private var app: FocusRunViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var viewedPartyID: UUID?
    @State private var gathering = "all"
    @State private var showsPeople = false
    @State private var selectedPrivateSession: CampfireSession?
    @State private var selectedPublicPerson: GlobalCampfireParticipant?
    @State private var pendingStart: NightFlockV4ActivityKind?

    init(social: NightFlockViewModel, partyID: UUID? = nil, onStart: @escaping (NightFlockV4ActivityKind) -> Void) {
        self.social = social; self.onStart = onStart; _viewedPartyID = State(initialValue: partyID)
    }
    private var party: NightFlockV4PartyDetail? { viewedPartyID.flatMap { social.v4ObservedPartyDetail(for: $0) } }
    private var isRefreshing: Bool {
        guard let viewedPartyID else { return social.globalCampfireLoading }
        if case .refreshing = social.v4ObservedPartyObservationState(for: viewedPartyID) { return true }
        return false
    }
    private var viewTitle: String { viewedPartyID == nil ? "Global" : party?.summary.name ?? "My Slumber Party" }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Campfire").font(AppTypography.title)
            if textSize.isAccessibilitySize {
                viewingChoice
                if viewedPartyID == nil { gatheringChoice }
            } else {
                HStack(spacing: AppSpacing.md) {
                    viewingChoice
                    if viewedPartyID == nil { gatheringChoice }
                }
            }
            HStack(spacing: AppSpacing.sm) {
                CampfireVisibilityButton(social: social, run: app.isRunning ? app.activeRun : nil, compact: true)
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }.tint(AppColors.grass).accessibilityLabel("Refresh Campfire")
                    .disabled(isRefreshing || social.accountState != .linked)
            }
            if let viewedPartyID {
                SlumberPartyV4PresentationClock(party: party) { date in
                    privateFire(partyID: viewedPartyID, at: date)
                }
            } else {
                TimelineView(.periodic(from: .now, by: 15)) { context in globalFire(at: context.date) }
            }
            if !app.isRunning { startActions }
        }
        .onAppear { if textSize.isAccessibilitySize { showsPeople = true } }
        .onChange(of: textSize) { _, size in if size.isAccessibilitySize { showsPeople = true } }
        .sheet(item: $selectedPrivateSession, onDismiss: finishJoin) { session in
            if let viewedPartyID {
                CampfirePrivatePersonView(social: social, partyID: viewedPartyID, sourceID: session.id, memberID: session.memberID) { kind in
                    pendingStart = kind; selectedPrivateSession = nil
                }.environmentObject(app)
            }
        }
        .sheet(item: $selectedPublicPerson, onDismiss: finishJoin) { person in
            CampfirePublicPersonView(social: social, participantID: person.id) { kind in
                pendingStart = kind; selectedPublicPerson = nil
            }.environmentObject(app)
        }
        .task(id: "\(viewedPartyID?.uuidString ?? gathering)-\(social.campfireOwnerForNewRun?.uuidString ?? "guest")-\(scenePhase == .active)") {
            guard scenePhase == .active else { return }
            _ = social.restoreCampfireVisibility()
            social.drainGlobalCampfireCommands(retry: true)
            refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(CampfireRules.foregroundRefreshInterval)) }
                catch { return }
                social.drainGlobalCampfireCommands(retry: true)
                if !isRefreshing && (viewedPartyID != nil || social.globalCampfireFailure?.permitsAutomaticRetry != false) {
                    refresh()
                }
            }
        }
    }

    private var viewingChoice: some View {
        Menu {
            Button(social.globalCampfireFailure == .unavailable ? "Global · unavailable" : "Global") { viewedPartyID = nil }
                .disabled(social.globalCampfireFailure == .unavailable)
            if social.globalCampfireFailure == .unavailable {
                Button("Check Global availability") { social.refreshGlobalCampfire() }
            }
            ForEach(social.slumberParties, id: \.partyID) { party in
                Button(party.name) { viewedPartyID = party.partyID }
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Viewing").font(AppTypography.caption)
                    Text(viewTitle).font(AppTypography.body)
                }
                Image(systemName: "chevron.down").font(AppTypography.caption)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge).accessibilityHidden(true)
            }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }.tint(AppColors.grass).accessibilityHint("Changes whose sessions you see. Your visibility stays the same.")
    }

    private var gatheringChoice: some View {
        Picker("Gathering", selection: $gathering) {
            Text("Everyone").tag("all")
            Text("Wind Down").tag("windDown")
            ForEach(CampfireActivity.allCases) { Text($0.title).tag($0.rawValue) }
        }.pickerStyle(.menu).font(AppTypography.body).tint(AppColors.grass)
            .frame(minHeight: 44)
    }

    private func finishJoin() {
        if let kind = pendingStart { pendingStart = nil; onStart(kind) }
    }
    private func refresh() {
        if let viewedPartyID { social.refreshV4PartyObservation(viewedPartyID, refreshListAfterward: false) }
        else { social.refreshGlobalCampfire(gathering: gathering) }
    }
    private var startActions: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Button { onStart(.windDown) } label: { Text("Start Wind Down").frame(maxWidth: .infinity) }
                .buttonStyle(PixelPrimaryButtonStyle())
            Button("Start Phone Away") { onStart(.phoneAway) }.buttonStyle(PixelChipButtonStyle(isSelected: false))
        }
    }

    @ViewBuilder private func privateFire(partyID: UUID, at date: Date) -> some View {
        let observation = social.v4ObservedPartyObservationState(for: partyID)
        let fresh = party != nil && observation.permitsLivePresence
        let updating: Bool = {
            if case .refreshing = observation { return true }
            return false
        }()
        let sessions = CampfireRules.currentSessions(party?.pasture?.campfire,
            members: Set(party?.memberships.map(\.memberID) ?? []), isFresh: fresh, at: date)
        let phase = CampfireScenePhase.resolve(hasCurrentSnapshot: fresh, isRefreshing: updating, hasPeople: !sessions.isEmpty)
        let people: [CampfireScenePerson] = sessions.compactMap { session in
            guard let party, let member = party.memberships.first(where: { $0.memberID == session.memberID }) else { return nil }
            return .init(id: session.id, name: member.profile.displayName, appearance: member.profile.presentation,
                detail: session.title, pose: session.pose(at: date), seatID: session.memberID,
                buddyCue: buddy(for: session, in: party)?.participationCue, thought: buddy(for: session, in: party)?.publicIntention)
        }
        CampfireSceneView(people: phase.showsPeople ? people : [],
            notice: phase == .populated ? nil : phase.isUpdating ? (fresh ? "Updating…" : "Opening your party’s campfire…")
                : phase == .empty ? "A quiet spot is waiting" : "The campfire needs an update",
            detail: phase.isUpdating ? nil : phase == .empty ? "Shared Wind Down and Phone Away sessions appear here."
                : phase == .unavailable ? "We couldn’t confirm who’s here. Try an update." : nil,
            isUpdating: phase.isUpdating, retry: phase == .unavailable ? refresh : nil
        ) { id in selectedPrivateSession = sessions.first { $0.id == id } }
        .id("\(partyID)-\(social.campfireOwnerForNewRun?.uuidString ?? "guest")")
        if phase.showsPeople, let party, !sessions.isEmpty {
            DisclosureGroup(isExpanded: $showsPeople) {
                ForEach(sessions) { session in
                    if let member = party.memberships.first(where: { $0.memberID == session.memberID }) {
                        Button { selectedPrivateSession = session } label: {
                            CampfirePersonRow(name: member.profile.displayName, appearance: member.profile.presentation,
                                detail: "\(session.title) · planned until \(session.expiresAt.formatted(date: .omitted, time: .shortened))", pose: session.pose(at: date),
                                buddyCue: buddy(for: session, in: party)?.participationCue, intention: buddy(for: session, in: party)?.publicIntention)
                        }.buttonStyle(.plain)
                    }
                }
            } label: {
                Text("People here · \(sessions.count)").frame(minHeight: 44)
            }.font(AppTypography.body).tint(AppColors.grass)
        }
    }

    private func buddy(for session: CampfireSession, in party: NightFlockV4PartyDetail) -> CampfireBuddySession? {
        guard party.pasture?.campfire?.agreement?.version == 2,
              party.pasture?.campfire?.buddies?.isSupported == true else { return nil }
        return party.pasture?.campfire?.buddies?.sessions.first {
            $0.sourceID == session.id && $0.memberID == session.memberID
        }
    }

    @ViewBuilder private func globalFire(at date: Date) -> some View {
        let state = social.globalCampfireState
        let linked = social.accountState == .linked
        let issue = social.globalCampfireFailure ?? (state?.available == false ? GlobalCampfireIssue.unavailable : nil)
        let fresh = linked && social.globalCampfireFailure == nil && state?.isSupported == true
            && state.map { CampfireVisibilityRules.isFresh(observedAt: $0.observedAt, now: date) } == true
        let updating = linked && social.globalCampfireLoading
        let phase = CampfireScenePhase.resolve(hasCurrentSnapshot: fresh, isRefreshing: updating,
            hasPeople: state?.participants.isEmpty == false)
        let people: [CampfireScenePerson] = phase.showsPeople ? (state?.participants ?? []).map {
            .init(id: $0.id, name: $0.name, appearance: $0.appearance.presentation, detail: $0.title, thought: $0.thought)
        } : []
        CampfireSceneView(people: people,
            notice: !linked ? "Company beyond your party" : phase.isUpdating ? (fresh ? "Updating…" : "Opening Campfire…")
                : phase == .populated ? nil : phase == .empty ? "There’s room by the campfire"
                : issue?.title ?? "The campfire needs an update",
            detail: !linked ? "Sign in from Settings to browse Global Campfire."
                : phase.isUpdating || phase == .populated ? nil
                : phase == .empty ? "Start a session whenever you’re ready. Your visibility is your choice."
                : issue?.detail ?? "We couldn’t confirm who’s here. Try an update.",
            isUpdating: phase.isUpdating, retry: linked && phase == .unavailable ? refresh : nil
        ) { id in selectedPublicPerson = state?.participants.first { $0.id == id } }
        .id("global-\(social.globalCampfireChannel)-\(gathering)-\(social.campfireOwnerForNewRun?.uuidString ?? "guest")")
        if fresh, let state {
            if let channels = state.channels, let channelID = state.channelID {
                Menu {
                    ForEach(channels) { channel in
                        Button(channel.title + (channel.isFull ? " · Full" : "")) { social.changeGlobalCampfireChannel(channel.id) }
                            .disabled(state.ownSourceID != nil && channel.isFull && channel.id != state.ownChannelID)
                    }
                } label: {
                    Label(channels.first(where: { $0.id == channelID })?.title ?? "Channel \(channelID)", systemImage: "arrow.left.arrow.right")
                        .font(AppTypography.body).frame(minHeight: 44)
                }.tint(AppColors.grass).disabled(social.globalCampfireChannelChanging)
                    .accessibilityHint(state.ownSourceID == nil ? "Browse another channel." : "Move your shared session to another channel.")
            }
            if let message = social.globalCampfireChannelMessage {
                Text(message).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            if state.channels == nil {
                Text(state.approximateCount == 0 ? "No shared sessions in this gathering" : "Up to \(state.approximateCount) sharing in this gathering")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            if let count = state.ownEncouragementCount, count > 0 {
                Text(count == 1 ? "Someone sent encouragement for your latest shared session." : "\(count) people sent encouragement for your latest shared session.")
                    .font(AppTypography.body).fixedSize(horizontal: false, vertical: true)
            }
            if !state.participants.isEmpty {
                DisclosureGroup(isExpanded: $showsPeople) {
                    ForEach(state.participants) { person in
                        Button { selectedPublicPerson = person } label: {
                            CampfirePersonRow(name: person.isMe ? "You · \(person.name)" : person.name, appearance: person.appearance.presentation,
                                detail: "\(person.title) · \(person.remaining.title)", intention: person.thought)
                        }.buttonStyle(.plain)
                    }
                    if state.channels == nil, let cursor = state.nextCursor {
                        Button("More people") { social.refreshGlobalCampfire(gathering: gathering, cursor: cursor) }
                            .font(AppTypography.body).frame(minHeight: 44).disabled(social.globalCampfireLoading)
                    }
                } label: {
                    Text("People here · \(state.participants.count)").frame(minHeight: 44)
                }.font(AppTypography.body).tint(AppColors.grass)
            }
        }
    }

}

struct CampfireScenePerson: Identifiable {
    var id: UUID
    var name: String
    var appearance: CountingSheepPublicPresentation
    var detail: String
    var pose: CampfireShepherdPose = .awake
    var seatID: UUID? = nil
    var buddyCue: String? = nil
    var thought: String? = nil
    var placementID: UUID { seatID ?? id }
}

struct CampfirePersonRow: View {
    var name: String
    var appearance: CountingSheepPublicPresentation
    var detail: String
    var pose: CampfireShepherdPose = .awake
    var buddyCue: String? = nil
    var intention: String? = nil
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            CampfireShepherdView(presentation: appearance, pose: pose, size: 44).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(name).font(AppTypography.headline)
                Text(detail).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                if let intention = CampfirePlanText.normalized(intention) { Text(intention).font(AppTypography.body) }
                if let buddyCue { Label(buddyCue, systemImage: "person.2.fill").font(AppTypography.caption).foregroundStyle(AppColors.grass) }
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(.vertical, AppSpacing.xs)
            .accessibilityElement(children: .combine)
            .accessibilityValue(pose.accessibilityDescription)
    }
}

#Preview("Campfire scene · Wind Down and Phone Away") {
    CampfireSceneView(people: [.init(id: UUID(), name: "Willow", appearance: .defaultValue, detail: "Wind Down"),
        .init(id: UUID(), name: "Fern", appearance: .defaultValue, detail: "Phone Away")], onSelect: { _ in }).padding().background(AppColors.paper)
}
