import SwiftUI

/// One ground plane, shared by the release screen and disposable native fixtures.
/// A person is always their Shepherd. Selection never sends a response.
struct SlumberPartyPastureView: View {
    let party: NightFlockV4PartyDetail
    var visits: [SharedPastureVisit] = []
    var arrangement: SharedMeadowArrangement? = nil
    var lantern: SharedPastureLantern? = nil
    var canArrange = false
    var isQuiet = false
    var statusIsFresh = true
    var studyCompanionOwner: UUID? = nil
    var onMove: (SharedMeadowArrangement) -> Void = { _ in }
    var onSelect: (UUID) -> Void
    var onSheep: () -> Void = {}
    var onImprovement: () -> Void = {}
    var onCampfire: () -> Void = {}
    var onSelectSession: ((UUID) -> Void)? = nil
    var buddyCard: ((CampfireSession) -> AnyView)? = nil
    var onRefreshLiveSessions: () -> Void = {}
    var refreshRevision = 0
    var now: Date = Date()
    var meadowOnly = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller = SharedMeadowSceneController()
    @State private var showsPeople = false
    @State private var showsLiveSessions = true

    private var members: [NightFlockV4Membership] { SlumberPartySharedFarmRules.members(in: party) }
    private var sceneMembers: [NightFlockV4Membership] {
        showsLiveSessions ? CampfireRules.participants(in: members, sessions: sessions) : members
    }
    private var needsWideScene: Bool { sceneMembers.count > 4 }
    private var sceneHeight: CGFloat { showsLiveSessions && needsWideScene ? 360 : 280 }
    private var shepherdSize: CGFloat { (3...4).contains(sceneMembers.count) ? 64 : 82 }
    private var sessions: [CampfireSession] {
        CampfireRules.currentSessions(party.pasture?.campfire, members: Set(members.map(\.memberID)), isFresh: statusIsFresh, at: now)
    }
    private let coordinateSpace = "ReleaseSharedPasture"

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if !meadowOnly {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Campfire").font(AppTypography.headline)
                    sharingButton
                }
            } else {
                HStack {
                    Text("Campfire").font(AppTypography.headline)
                    Spacer()
                    sharingButton
                }
            }
            if dynamicTypeSize >= .xxxLarge {
                VStack(spacing: AppSpacing.xs) {
                    meadowViewButton("Live sessions", isLive: true)
                    meadowViewButton("Shared meadow", isLive: false)
                }
            } else {
                Picker("Meadow view", selection: $showsLiveSessions) {
                    Text("Live sessions").tag(true)
                    Text("Shared meadow").tag(false)
                }.pickerStyle(.segmented)
            }
            }
            if !showsLiveSessions {
                Text("Everyone’s saved place and visiting sheep. These positions don’t indicate an active session.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            ScrollViewReader { camera in
                VStack(spacing: AppSpacing.xs) {
                    GeometryReader { viewport in
                        ZStack {
                            // The distant landscape keeps its original wide framing
                            // while the foreground grazing area pans.
                            Image(AssetSlot.Farm.sharedMeadowDusk).resizable().interpolation(.high)
                                .frame(width: viewport.size.width, height: sceneHeight).accessibilityHidden(true)
                            ScrollView(.horizontal) {
                                scene(size: CGSize(width: needsWideScene ? max(680, viewport.size.width) : viewport.size.width, height: sceneHeight))
                                    .id("meadow")
                            }
                            .defaultScrollAnchor(.center)
                            .scrollIndicators(.hidden)
                            .scrollDisabled(controller.isInteractionActive || !needsWideScene)
                        }
                    }
                    .frame(height: sceneHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    if needsWideScene {
                        HStack {
                            Button { pan(camera, to: .leading) } label: {
                                Label("Near meadow", systemImage: "arrow.left").frame(minHeight: 44)
                            }
                            Spacer(minLength: AppSpacing.xs)
                            Button { pan(camera, to: .trailing) } label: {
                                Label("Far meadow", systemImage: "arrow.right").frame(minHeight: 44)
                            }
                        }
                        .font(AppTypography.caption)
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                        .disabled(controller.isInteractionActive)
                    }
                }
            }
            if showsLiveSessions && !statusIsFresh {
                Text("Campfire updates are unavailable. Refresh to see shared sessions.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            } else if showsLiveSessions && party.pasture?.campfire?.isSupported != true {
                Text("Live campfire sharing isn’t available on this server yet.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            } else if showsLiveSessions && sessions.isEmpty {
                Text("No shared sessions right now. The campfire lights when someone shares a Wind Down or Phone Away session.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            ForEach(showsLiveSessions ? sessions : []) { session in
                if let buddyCard { buddyCard(session) }
                else if let member = members.first(where: { $0.memberID == session.memberID }) {
                    Button { onSelect(member.memberID) } label: {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Label("\(member.profile.displayName) · \(session.title)", systemImage: "flame")
                                .font(AppTypography.body)
                            Text("Until \(session.expiresAt, style: .time)")
                                .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain)
                    .accessibilityHint("App-reported intention. Opens their shared updates.")
                }
            }
            if let owner = studyCompanionOwner {
                Button("Fetch with \(members.first { $0.memberID == owner }?.profile.displayName ?? "your Shepherd")’s Ollie") {
                    controller.fetchWithCompanion(owner: owner)
                }.font(AppTypography.caption).frame(minHeight: 44)
                if let message = controller.playMessage { Text(message).font(AppTypography.caption) }
            }
            if dynamicTypeSize >= .xxxLarge {
                VStack(alignment: .leading, spacing: AppSpacing.xs) { controls }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.xs) { controls.fixedSize(horizontal: true, vertical: false) }
                    VStack(alignment: .leading, spacing: AppSpacing.xs) { controls }
                }
            }
            if showsPeople || dynamicTypeSize.isAccessibilitySize {
                ForEach(members) { member in
                    Button { onSelect(member.memberID) } label: {
                        HStack {
                            Text(member.profile.displayName).font(AppTypography.body)
                            if member.memberID == party.myMemberID { Text("You").font(AppTypography.caption) }
                            Spacer()
                            Image(systemName: "chevron.right").accessibilityHidden(true)
                        }.frame(minHeight: 48)
                    }.buttonStyle(.plain)
                }
            }
        }
        .task(id: scenePhase == .active ? party.summary.partyID : nil) {
            guard scenePhase == .active else { return }
            // Realtime prompts remain primary. A visible-screen fallback heals
            // a lost socket without background polling or manual refresh.
            while !Task.isCancelled {
                onRefreshLiveSessions()
                do { try await Task.sleep(for: .seconds(CampfireRules.foregroundRefreshInterval)) }
                catch { return }
            }
        }
        .onAppear { if meadowOnly { showsLiveSessions = false }; configure() }
        .onChange(of: members.map(\.memberID)) { _, _ in configure() }
        .onChange(of: showsLiveSessions) { _, _ in configure() }
        .onChange(of: visits) { _, _ in configure() }
        .onChange(of: lantern) { _, _ in configure() }
        .onChange(of: arrangement) { _, _ in configure() }
        .onChange(of: refreshRevision) { _, _ in configure() }
        .onChange(of: reduceMotion) { _, _ in configure() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { configure() } else { controller.stop() }
        }
        .onDisappear { controller.stop() }
    }

    private func pan(_ camera: ScrollViewProxy, to anchor: UnitPoint) {
        withAnimation(reduceMotion ? nil : AppMotion.settle) {
            camera.scrollTo("meadow", anchor: anchor)
        }
    }

    private var sharingButton: some View {
        Button(action: onCampfire) { Label("Sharing", systemImage: "person.2.wave.2") }
            .font(AppTypography.caption).tint(AppColors.grass).frame(minHeight: 44)
    }

    private func meadowViewButton(_ title: String, isLive: Bool) -> some View {
        Button { showsLiveSessions = isLive } label: {
            Text(title).font(AppTypography.body).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppSpacing.sm).frame(minHeight: 44)
        }
        .buttonStyle(PixelChipButtonStyle(isSelected: showsLiveSessions == isLive))
        .accessibilityAddTraits(showsLiveSessions == isLive ? .isSelected : [])
    }

    @ViewBuilder private var controls: some View {
        if !meadowOnly {
            Button { showsPeople.toggle() } label: { controlLabel("People", symbol: "person.2") }
                .buttonStyle(PixelChipButtonStyle(isSelected: showsPeople)).frame(minHeight: 44)
        }
        Button(action: onSheep) { controlLabel("Send a sheep", symbol: "pawprint") }
            .buttonStyle(PixelChipButtonStyle(isSelected: false)).frame(minHeight: 44)
        Button(action: onImprovement) { controlLabel("Our lantern", symbol: "lamp.desk") }
            .buttonStyle(PixelChipButtonStyle(isSelected: false)).frame(minHeight: 44)
    }

    private func controlLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(AppTypography.body)
            .fixedSize(horizontal: false, vertical: true).padding(.horizontal, AppSpacing.sm)
    }

    private func scene(size: CGSize) -> some View {
        ZStack {
            Color.clear.frame(width: size.width, height: size.height).accessibilityHidden(true)
            if showsLiveSessions && !sessions.isEmpty {
                Button(action: onCampfire) { PaperCampfire().frame(width: 60, height: 60) }
                    .buttonStyle(.plain).accessibilityLabel("Campfire sharing and details")
                    .position(x: size.width * CampfireRules.fire.x, y: size.height * CampfireRules.fire.y - 20)
                    .zIndex(CampfireRules.fire.y)
            }
            if !showsLiveSessions && lantern?.isComplete == true {
                let entity = SharedMeadowOccupant.lantern(party.summary.partyID)
                let point = controller.position(for: entity)
                shadow(point, in: size, width: 30)
                Group {
                    if canArrange {
                        PastureCharacterHitTarget(entity: entity, controller: controller, canvasSize: size,
                            coordinateSpace: coordinateSpace, reduceMotion: reduceMotion, label: "Earned meadow lantern",
                            hint: "Tap for project details. Hold and drag to arrange.", actionTitle: "Open lantern",
                            action: onImprovement) { PaperPastureLantern(isLit: true).frame(width: 55, height: 75) }
                    } else {
                        Button(action: onImprovement) { PaperPastureLantern(isLit: true).frame(width: 55, height: 75) }
                            .buttonStyle(.plain)
                    }
                }
                .frame(width: 55, height: 75)
                .position(x: point.x * size.width, y: point.y * size.height - 32).zIndex(point.y)
            }
            if !showsLiveSessions, let owner = studyCompanionOwner, let member = members.first(where: { $0.memberID == owner }) {
                let entity = SharedMeadowOccupant.companion(owner)
                let point = controller.position(for: entity)
                shadow(point, in: size, width: 28)
                PastureCharacterHitTarget(entity: entity, controller: controller, canvasSize: size,
                    coordinateSpace: coordinateSpace, reduceMotion: reduceMotion, label: "\(member.profile.displayName)’s Ollie",
                    hint: "Tap to play fetch. Hold and drag to move locally.", actionTitle: "Play fetch",
                    action: { controller.fetchWithCompanion(owner: owner) }) {
                        OllieFarmAvatar(accessoryItemID: member.profile.presentation.ollieOrnamentID, size: 55, motionEnabled: false)
                            .environment(\.ollieCoat, OllieCoatStyle(rawValue: member.profile.presentation.renderableAppearance.ollieCoatID ?? "") ?? .classic)
                    }
                    .frame(width: 55, height: 55)
                    .position(x: point.x * size.width, y: point.y * size.height - 23).zIndex(point.y)
                    .animation(reduceMotion ? nil : AppMotion.settle, value: point)
                if let toy = controller.toyPosition {
                    Circle().fill(AppColors.amber).frame(width: 12, height: 12)
                        .position(x: toy.x * size.width, y: toy.y * size.height)
                }
            }
            ForEach(sceneMembers) { member in
                let entity = SharedMeadowOccupant.member(member.memberID)
                let seatIndex = showsLiveSessions ? sessions.firstIndex { $0.memberID == member.memberID } : nil
                let point = seatIndex.map { CampfireRules.seat(index: $0, count: sessions.count) } ?? controller.position(for: entity)
                shadow(point, in: size, width: 35)
                resident(entity, size: size, label: "\(member.profile.displayName), \(showsLiveSessions ? sessions.first(where: { $0.memberID == member.memberID }).map { "\($0.title), \($0.pose(at: now).accessibilityDescription)" } ?? "Shared session" : "Shepherd in the shared meadow")", owner: member.memberID, isGathering: seatIndex != nil) {
                    CampfireShepherdView(presentation: member.profile.presentation,
                        pose: showsLiveSessions ? sessions.first(where: { $0.memberID == member.memberID })?.pose(at: now) ?? .awake : .awake,
                        size: shepherdSize).accessibilityHidden(true)
                }
                .position(x: point.x * size.width, y: point.y * size.height - shepherdSize * 0.43)
                .zIndex(point.y)
                if showsLiveSessions, let session = sessions.first(where: { $0.memberID == member.memberID }) {
                    Button { onSelect(member.memberID) } label: {
                        Label(session.title, systemImage: "ellipsis.bubble.fill")
                            .font(AppTypography.caption).lineLimit(2)
                            .padding(AppSpacing.xs).background(AppColors.paper, in: Capsule())
                    }.buttonStyle(.plain).frame(minHeight: 44)
                        .accessibilityLabel("\(member.profile.displayName), \(session.title). Open profile")
                        .position(x: point.x * size.width, y: point.y * size.height - shepherdSize - AppSpacing.lg)
                        .zIndex(3)
                }
                Text(member.profile.displayName)
                    .font(AppTypography.caption.weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.large)
                    .lineLimit(1)
                    .foregroundStyle(AppColors.ink)
                    .padding(.horizontal, AppSpacing.xs)
                    .background(AppColors.paper.opacity(0.90), in: Capsule())
                    .frame(maxWidth: min(140, size.width / CGFloat(min(sceneMembers.count, 4) + 1) - 8))
                    .position(x: point.x * size.width, y: point.y * size.height + 13)
                    .zIndex(2).allowsHitTesting(false).accessibilityHidden(true)
            }
            ForEach(showsLiveSessions ? [] : visits) { visit in
                let entity = SharedMeadowOccupant.visitor(visit.id)
                let point = controller.position(for: entity)
                let owner = members.first { $0.memberID == visit.memberID }?.profile.displayName ?? "Member"
                shadow(point, in: size, width: 28)
                resident(entity, size: size, label: "\(visit.sheepDisplayName), visiting sheep belonging to \(owner)", owner: visit.memberID, isSheep: true) {
                    PixelAssetImage(name: SheepCatalog.definition(for: visit.sheepDefinitionID)?.assetName ?? AssetSlot.Sheep.common)
                        .frame(width: 48, height: 48)
                }
                .position(x: point.x * size.width, y: point.y * size.height - 20)
                .zIndex(point.y)
            }
        }
        .frame(width: size.width, height: size.height)
        .coordinateSpace(name: coordinateSpace)
    }

    private func resident<Content: View>(_ entity: SharedMeadowOccupant, size: CGSize, label: String,
                                         owner: UUID, isSheep: Bool = false, isGathering: Bool = false, @ViewBuilder content: @escaping () -> Content) -> some View {
        Group {
            if canArrange && !isGathering {
                PastureCharacterHitTarget(entity: entity, controller: controller, canvasSize: size,
                    coordinateSpace: coordinateSpace, reduceMotion: reduceMotion, label: label,
                    hint: "Tap to open their card. Double tap for a gentle nudge. Hold and drag to arrange the shared pasture.",
                    actionTitle: "Open card", action: { if isSheep { onSheep() } else { onSelect(owner) } }, content: content)
            } else {
                Button { if isSheep { onSheep() } else if isGathering, let onSelectSession { onSelectSession(owner) } else { onSelect(owner) } } label: { content().frame(minWidth: 44, minHeight: 44) }
                    .buttonStyle(.plain).accessibilityLabel(label).accessibilityHint("Opens their card")
            }
        }
        .frame(width: isSheep ? 48 : shepherdSize, height: isSheep ? 48 : shepherdSize)
        .animation(reduceMotion || controller.behavior(for: entity) == .dragging ? nil : AppMotion.settle,
                   value: controller.position(for: entity))
    }

    private func shadow(_ point: PastureScenePoint, in size: CGSize, width: CGFloat) -> some View {
        Ellipse().fill(AppColors.farmContactShadow.opacity(0.3))
            .frame(width: width, height: 7)
            .position(x: point.x * size.width, y: point.y * size.height)
            .zIndex(point.y - 0.01).allowsHitTesting(false).accessibilityHidden(true)
    }

    private func configure() {
        var occupants = members.enumerated().map { index, member in
            SharedMeadowSceneController.Configuration.Occupant(occupant: .member(member.memberID),
                ownerMemberID: member.memberID, memberIndex: index, visitorIndex: 0, isCompanionLike: false)
        }
        occupants += visits.map { visit in
            .init(occupant: .visitor(visit.id), ownerMemberID: visit.memberID,
                  memberIndex: members.firstIndex { $0.memberID == visit.memberID } ?? 0,
                  visitorIndex: 0, isCompanionLike: true)
        }
        if let owner = studyCompanionOwner {
            occupants.append(.init(occupant: .companion(owner), ownerMemberID: owner,
                                   memberIndex: members.firstIndex { $0.memberID == owner } ?? 0, visitorIndex: 0, isCompanionLike: true))
        }
        if lantern?.isComplete == true {
            occupants.append(.init(occupant: .lantern(party.summary.partyID), ownerMemberID: party.summary.partyID,
                                   memberIndex: 0, visitorIndex: 0, isCompanionLike: false))
        }
        controller.configure(.init(occupants: occupants, memberCount: members.count, myMemberID: party.myMemberID,
            seed: PastureSceneLayout.stableHash(forKey: party.summary.partyID.uuidString)),
            arrangement: arrangement, reduceMotion: reduceMotion, isQuiet: showsLiveSessions || isQuiet || scenePhase != .active,
            onPersist: { changed in
                // Only an intentional drop is shared; neighbouring reactions stay local.
                guard let key = controller.lastMovedKey, let point = changed.positions[key] else { return }
                var next = arrangement ?? SharedMeadowArrangement()
                next.positions[key] = point
                onMove(next)
            })
    }
}

#Preview("Lantern courtyard · two Shepherds") {
    SlumberPartyPastureView(party: SlumberPartySharedFarmFixtures.party, onSelect: { _ in }).padding()
}
