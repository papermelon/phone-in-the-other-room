import SwiftUI

extension Notification.Name {
    static let countingSheepShowCampfire = Notification.Name("countingSheepShowCampfire")
}

struct CampfireHomeEntry: View {
    @ObservedObject var social: NightFlockViewModel
    var body: some View {
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
        }.buttonStyle(PixelChipButtonStyle(isSelected: false))
            .accessibilityHint("Browse your party or the global fire. Opening it doesn’t share your session.")
            .task(id: social.campfireOwnerForNewRun) { _ = social.restoreCampfireVisibility() }
    }
}

struct CampfireView: View {
    @ObservedObject var social: NightFlockViewModel
    var onStart: (NightFlockV4ActivityKind) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView { CampfirePanel(social: social, onStart: onStart).padding(AppSpacing.md) }
                .background(AppColors.paper.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
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
    @State private var selectedPrivateSession: CampfireSession?
    @State private var selectedPublicPerson: GlobalCampfireParticipant?
    @State private var pendingStart: NightFlockV4ActivityKind?

    init(social: NightFlockViewModel, partyID: UUID? = nil, onStart: @escaping (NightFlockV4ActivityKind) -> Void) {
        self.social = social; self.onStart = onStart; _viewedPartyID = State(initialValue: partyID)
    }
    private var party: NightFlockV4PartyDetail? { viewedPartyID.flatMap { social.v4ObservedPartyDetail(for: $0) } }
    private var viewTitle: String { viewedPartyID == nil ? "Global" : party?.summary.name ?? "My Slumber Party" }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Campfire").font(AppTypography.title)
            if textSize.isAccessibilitySize { startActions }
            Menu {
                Button("Global") { viewedPartyID = nil }
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
            CampfireVisibilityButton(social: social, run: app.isRunning ? app.activeRun : nil)
            if !textSize.isAccessibilitySize { startActions }
            TimelineView(.periodic(from: .now, by: 15)) { context in
                if let viewedPartyID { privateFire(partyID: viewedPartyID, at: context.date) }
                else { globalFire(at: context.date) }
            }
        }
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
        .task(id: "\(viewedPartyID?.uuidString ?? gathering)-\(scenePhase == .active)") {
            guard scenePhase == .active else { return }
            _ = social.restoreCampfireVisibility()
            social.drainGlobalCampfireCommands(retry: true)
            while !Task.isCancelled {
                social.drainGlobalCampfireCommands(retry: true)
                refresh()
                do { try await Task.sleep(for: .seconds(CampfireRules.foregroundRefreshInterval)) }
                catch { return }
            }
        }
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
            if app.isRunning {
                Button { NotificationCenter.default.post(name: .countingSheepShowHome, object: nil) } label: {
                    Label("Back to your session", systemImage: "moon.stars")
                }.buttonStyle(PixelPrimaryButtonStyle())
            } else {
                Button { onStart(.windDown) } label: { Text("Start Wind Down").frame(maxWidth: .infinity) }
                    .buttonStyle(PixelPrimaryButtonStyle())
                Button("Start Phone Away") { onStart(.phoneAway) }.buttonStyle(PixelChipButtonStyle(isSelected: false))
            }
        }
    }

    @ViewBuilder private func privateFire(partyID: UUID, at date: Date) -> some View {
        if let party {
            let fresh = social.v4ObservedPartyObservationState(for: partyID).permitsLivePresence
            let sessions = CampfireRules.currentSessions(party.pasture?.campfire, members: Set(party.memberships.map(\.memberID)), isFresh: fresh, at: date)
            if !fresh { empty("This fire needs an update", detail: "Refresh to see current sessions.") }
            else if sessions.isEmpty { empty("A quiet spot is waiting", detail: "Shared Wind Down and Phone Away sessions appear here.") }
            else {
                CampfireSceneView(people: sessions.compactMap { session in
                    party.memberships.first { $0.memberID == session.memberID }.map {
                        CampfireScenePerson(id: session.id, name: $0.profile.displayName, appearance: $0.profile.presentation, detail: session.title)
                    }
                }) { id in selectedPrivateSession = sessions.first { $0.id == id } }
                ForEach(sessions) { session in
                    if let member = party.memberships.first(where: { $0.memberID == session.memberID }) {
                        Button { selectedPrivateSession = session } label: {
                            CampfirePersonRow(name: member.profile.displayName, appearance: member.profile.presentation,
                                detail: "\(session.title) · planned until \(session.expiresAt.formatted(date: .omitted, time: .shortened))")
                        }.buttonStyle(.plain)
                    }
                }
                Text("Shared by your party members. A session doesn’t show sleep or where a phone is.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
        } else { empty("Opening your party’s fire…", detail: "Your visibility stays the same while it loads.") }
        Button("Refresh Campfire", action: refresh).font(AppTypography.caption).frame(minHeight: 44).tint(AppColors.grass)
    }

    @ViewBuilder private func globalFire(at date: Date) -> some View {
        if social.accountState != .linked {
            empty("Company beyond your party", detail: "Sign in from Settings to browse Global Campfire. You don’t need a Slumber Party.")
        } else if let failure = social.globalCampfireFailure {
            empty("The global fire couldn’t be reached", detail: failure)
        } else if let state = social.globalCampfireState, state.isSupported,
                  CampfireVisibilityRules.isFresh(observedAt: state.observedAt, now: date) {
            Picker("Gathering", selection: $gathering) {
                Text("Everyone").tag("all")
                Text("Wind Down").tag("windDown")
                ForEach(CampfireActivity.allCases) { Text($0.title).tag($0.rawValue) }
            }.font(AppTypography.body).pickerStyle(.menu).tint(AppColors.grass)
            Text(state.approximateCount == 0 ? "No shared sessions in this gathering" : "Up to \(state.approximateCount) sharing in this gathering")
                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            if let count = state.ownEncouragementCount, count > 0 {
                Text(count == 1 ? "Someone sent encouragement for your latest shared session." : "\(count) people sent encouragement for your latest shared session.")
                    .font(AppTypography.body).fixedSize(horizontal: false, vertical: true)
            }
            if state.participants.isEmpty { empty("There’s room by the fire", detail: "Start a session whenever you’re ready. Your visibility is your choice.") }
            else {
                CampfireSceneView(people: state.participants.map {
                    .init(id: $0.id, name: $0.name, appearance: $0.appearance.presentation, detail: $0.title)
                }) { id in selectedPublicPerson = state.participants.first { $0.id == id } }
                ForEach(state.participants) { person in
                    Button { selectedPublicPerson = person } label: {
                        CampfirePersonRow(name: person.isMe ? "You · \(person.name)" : person.name, appearance: person.appearance.presentation,
                                          detail: "\(person.title) · \(person.remaining.title)")
                    }.buttonStyle(.plain)
                }
                if let cursor = state.nextCursor {
                    Button("More people") { social.refreshGlobalCampfire(gathering: gathering, cursor: cursor) }
                        .font(AppTypography.body).frame(minHeight: 44)
                }
            }
        } else {
            empty(social.globalCampfireLoading ? "Checking the global fire…" : "Global Campfire isn’t available right now",
                  detail: "Your private party and your own session are still here.")
        }
        Button("Refresh Global Campfire", action: refresh).font(AppTypography.caption).frame(minHeight: 44).tint(AppColors.grass)
    }

    private func empty(_ title: String, detail: String) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                PaperCampfire().frame(width: 48, height: 48)
                Text(title).font(AppTypography.headline)
                Text(detail).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }.fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct CampfireScenePerson: Identifiable {
    var id: UUID
    var name: String
    var appearance: CountingSheepPublicPresentation
    var detail: String
}

struct CampfireSceneView: View {
    var people: [CampfireScenePerson]
    var onSelect: (UUID) -> Void
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(AssetSlot.Farm.sharedMeadowDusk).resizable().scaledToFill().accessibilityHidden(true)
                PaperCampfire().frame(width: 54, height: 54).position(x: geometry.size.width / 2, y: geometry.size.height * 0.85)
                ForEach(Array(people.prefix(8).enumerated()), id: \.element.id) { index, person in
                    let point = CampfireRules.seat(index: index, count: min(people.count, 8))
                    Button { onSelect(person.id) } label: {
                        VStack(spacing: AppSpacing.xxs) {
                            SlumberPartySocialAvatarView(presentation: person.appearance, avatarID: "shepherd", size: 58, showsBackdrop: false)
                            Text(person.name).font(AppTypography.caption).dynamicTypeSize(...DynamicTypeSize.large).lineLimit(1)
                                .padding(.horizontal, AppSpacing.xxs).background(AppColors.paper.opacity(0.94), in: Capsule())
                        }
                    }.buttonStyle(.plain).accessibilityLabel("\(person.name), \(person.detail)")
                        .accessibilityHint("Opens their session card")
                        .position(x: geometry.size.width * point.x, y: geometry.size.height * point.y - 24)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.frame(height: people.count > 4 ? 270 : 230).clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
    }
}

struct CampfirePersonRow: View {
    var name: String
    var appearance: CountingSheepPublicPresentation
    var detail: String
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            SlumberPartySocialAvatarView(presentation: appearance, avatarID: "shepherd", size: 44).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(name).font(AppTypography.headline)
                Text(detail).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }.fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(.vertical, AppSpacing.xs)
            .accessibilityElement(children: .combine)
    }
}

#Preview("Campfire scene · Wind Down and Phone Away") {
    CampfireSceneView(people: [.init(id: UUID(), name: "Willow", appearance: .defaultValue, detail: "Wind Down"),
        .init(id: UUID(), name: "Fern", appearance: .defaultValue, detail: "Phone Away")], onSelect: { _ in }).padding().background(AppColors.paper)
}
