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
    var now: Date = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller = SharedMeadowSceneController()
    @State private var showsPeople = false

    private var members: [NightFlockV4Membership] { SlumberPartySharedFarmRules.members(in: party) }
    private var shepherdSize: CGFloat { (3...4).contains(members.count) ? 64 : 82 }
    private var sessions: [CampfireSession] {
        CampfireRules.currentSessions(party.pasture?.campfire, members: Set(members.map(\.memberID)), isFresh: statusIsFresh, at: now)
    }
    private let coordinateSpace = "ReleaseSharedPasture"

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("Campfire").font(AppTypography.headline)
                Spacer()
                Button(action: onCampfire) { Label("Sharing", systemImage: "person.2.wave.2") }
                    .font(AppTypography.caption).tint(AppColors.grass).frame(minHeight: 44)
            }
            ScrollViewReader { camera in
                VStack(spacing: AppSpacing.xs) {
                    GeometryReader { viewport in
                        ZStack {
                            // The distant landscape keeps its original wide framing
                            // while the foreground grazing area pans.
                            Image(AssetSlot.Farm.sharedMeadowDusk).resizable().interpolation(.high)
                                .frame(width: viewport.size.width, height: 280).accessibilityHidden(true)
                            ScrollView(.horizontal) {
                                scene(size: CGSize(width: members.count > 4 ? max(680, viewport.size.width) : viewport.size.width, height: 280))
                                    .id("meadow")
                            }
                            .defaultScrollAnchor(.center)
                            .scrollIndicators(.hidden)
                            .scrollDisabled(controller.isInteractionActive || members.count <= 4)
                        }
                    }
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                    if members.count > 4 {
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
            if !statusIsFresh {
                Text("Campfire updates are unavailable. Refresh to see shared sessions.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            } else if party.pasture?.campfire?.isSupported != true {
                Text("Live campfire sharing isn’t available on this server yet.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            } else if sessions.isEmpty {
                Text("The fire is here whenever you’re ready. No current shared sessions.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
            }
            ForEach(sessions) { session in
                if let member = members.first(where: { $0.memberID == session.memberID }) {
                    Button { onSelect(member.memberID) } label: {
                        Label("\(member.profile.displayName) · \(session.title)", systemImage: "flame")
                            .font(AppTypography.body).frame(minHeight: 44)
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
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AppSpacing.xs) { controls }
                VStack(alignment: .leading, spacing: AppSpacing.xs) { controls }
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
        .onAppear(perform: configure)
        .onChange(of: members.map(\.memberID)) { _, _ in configure() }
        .onChange(of: visits) { _, _ in configure() }
        .onChange(of: lantern) { _, _ in configure() }
        .onChange(of: arrangement) { _, _ in configure() }
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

    @ViewBuilder private var controls: some View {
        Button { showsPeople.toggle() } label: { Label("People", systemImage: "person.2") }
            .buttonStyle(PixelChipButtonStyle(isSelected: showsPeople)).frame(minHeight: 44)
        Button(action: onSheep) { Label("Sheep", systemImage: "pawprint") }
            .buttonStyle(PixelChipButtonStyle(isSelected: false)).frame(minHeight: 44)
        Button(action: onImprovement) { Label("Lantern", systemImage: "lamp.desk") }
            .buttonStyle(PixelChipButtonStyle(isSelected: false)).frame(minHeight: 44)
    }

    private func scene(size: CGSize) -> some View {
        ZStack {
            Color.clear.frame(width: size.width, height: size.height).accessibilityHidden(true)
            Button(action: onCampfire) { PaperCampfire().frame(width: 60, height: 60) }
                .buttonStyle(.plain).accessibilityLabel("Campfire sharing and details")
                .position(x: size.width * CampfireRules.fire.x, y: size.height * CampfireRules.fire.y - 20)
                .zIndex(CampfireRules.fire.y)
            if lantern?.isComplete == true {
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
            if let owner = studyCompanionOwner, let member = members.first(where: { $0.memberID == owner }) {
                let entity = SharedMeadowOccupant.companion(owner)
                let point = controller.position(for: entity)
                shadow(point, in: size, width: 28)
                PastureCharacterHitTarget(entity: entity, controller: controller, canvasSize: size,
                    coordinateSpace: coordinateSpace, reduceMotion: reduceMotion, label: "\(member.profile.displayName)’s Ollie",
                    hint: "Tap to play fetch. Hold and drag to move locally.", actionTitle: "Play fetch",
                    action: { controller.fetchWithCompanion(owner: owner) }) {
                        OllieFarmAvatar(accessoryItemID: member.profile.presentation.ollieOrnamentID, size: 55, motionEnabled: false)
                    }
                    .frame(width: 55, height: 55)
                    .position(x: point.x * size.width, y: point.y * size.height - 23).zIndex(point.y)
                    .animation(reduceMotion ? nil : AppMotion.settle, value: point)
                if let toy = controller.toyPosition {
                    Circle().fill(AppColors.amber).frame(width: 12, height: 12)
                        .position(x: toy.x * size.width, y: toy.y * size.height)
                }
            }
            ForEach(members) { member in
                let entity = SharedMeadowOccupant.member(member.memberID)
                let seatIndex = sessions.firstIndex { $0.memberID == member.memberID }
                let point = seatIndex.map { CampfireRules.seat(index: $0, count: sessions.count) } ?? controller.position(for: entity)
                shadow(point, in: size, width: 35)
                resident(entity, size: size, label: "\(member.profile.displayName), Shepherd", owner: member.memberID, isGathering: seatIndex != nil) {
                    SlumberPartySocialAvatarView(presentation: member.profile.presentation, avatarID: "shepherd", size: shepherdSize, showsBackdrop: false)
                }
                .position(x: point.x * size.width, y: point.y * size.height - shepherdSize * 0.43)
                .zIndex(point.y)
                Text(member.profile.displayName)
                    .font(AppTypography.caption.weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.large)
                    .foregroundStyle(AppColors.ink)
                    .padding(.horizontal, AppSpacing.xs)
                    .background(AppColors.paper.opacity(0.90), in: Capsule())
                    .position(x: point.x * size.width, y: point.y * size.height + 13)
                    .zIndex(2).allowsHitTesting(false).accessibilityHidden(true)
            }
            ForEach(visits) { visit in
                let entity = SharedMeadowOccupant.visitor(visit.id)
                let ownerSeat = sessions.firstIndex { $0.memberID == visit.memberID }
                let point = ownerSeat.map { CampfireRules.visitorSeat(index: $0, count: sessions.count) } ?? controller.position(for: entity)
                let owner = members.first { $0.memberID == visit.memberID }?.profile.displayName ?? "Member"
                shadow(point, in: size, width: 28)
                resident(entity, size: size, label: "\(visit.sheepDisplayName), visiting sheep belonging to \(owner)", owner: visit.memberID, isSheep: true, isGathering: ownerSeat != nil) {
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
                Button { if isSheep { onSheep() } else { onSelect(owner) } } label: { content().frame(minWidth: 44, minHeight: 44) }
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
            arrangement: arrangement, reduceMotion: reduceMotion, isQuiet: isQuiet || scenePhase != .active,
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
