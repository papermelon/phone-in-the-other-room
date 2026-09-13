import SwiftUI

/// Prototype shared Farm: one meadow where every member's chosen character
/// stands with any sheep they have sent to visit. Touch here is local play
/// (hold to move, drop to nudge); tapping a friend opens their card, and only
/// a confirmed greeting or visit ever leaves the phone.
struct SlumberPartySharedMeadowView: View {
    let party: NightFlockV4PartyDetail
    var showsSocialAvatar: Bool
    @ObservedObject var store: SharedFarmPrototypeStore
    var isWindDownActive = false
    var onSelectMember: (UUID) -> Void
    var onGreetingCandidate: (UUID) -> Void
    var onSendVisit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var controller = SharedMeadowSceneController()
    @State private var showsArrangementNote = false

    private var members: [NightFlockV4Membership] { SlumberPartySharedFarmRules.members(in: party) }
    private var visits: [SharedFarmVisit] { store.currentVisits }
    private var sceneHeight: CGFloat { dynamicTypeSize.isAccessibilitySize ? 320 : 280 }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            header
            meadow
                .frame(height: sceneHeight)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                        .stroke(AppColors.stroke.opacity(0.28), lineWidth: 1)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Shared Farm, \(members.count) people and \(visits.count) visiting sheep")
            visitorStrip
            if showsArrangementNote {
                Text(SharedFarmSocialCopy.localArrangementNote)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
            DisclosureGroup("Everyone as a list") {
                ForEach(members) { member in
                    Button { onSelectMember(member.memberID) } label: {
                        HStack {
                            Text(member.profile.displayName).font(AppTypography.body)
                            if member.memberID == party.myMemberID {
                                Text("You").font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                            }
                            Spacer(minLength: AppSpacing.sm)
                            Image(systemName: "chevron.right").accessibilityHidden(true)
                        }
                        .frame(minHeight: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens their card with greetings and shared updates")
                }
            }
            .font(AppTypography.body)
            .tint(AppColors.grass)
        }
        .onAppear(perform: configureScene)
        .onChange(of: party.memberships.map(\.memberID)) { _, _ in configureScene() }
        .onChange(of: visits.map(\.id)) { _, _ in configureScene() }
        .onChange(of: reduceMotion) { _, _ in configureScene() }
        .onChange(of: isWindDownActive) { _, _ in configureScene() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { configureScene() } else { controller.stop() }
        }
        .onChange(of: controller.lastDrop) { _, drop in
            guard let drop else { return }
            controller.clearLastDrop()
            if drop.moved && !showsArrangementNote {
                withAnimation(reduceMotion ? nil : AppMotion.stateChange) { showsArrangementNote = true }
            }
            if let candidate = drop.greetingCandidate { onGreetingCandidate(candidate) }
        }
        .onDisappear { controller.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("OUR FARM")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
            Text("One meadow, everyone’s sheep")
                .font(AppTypography.headline)
            Text("Tap a friend to greet them. Hold to move anyone around; that part stays on your phone.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Scene

    private var meadow: some View {
        GeometryReader { proxy in
            ZStack {
                PixelAssetImage(name: AssetSlot.Farm.sharedMeadowDusk, contentMode: .fill)
                    .overlay(AppColors.paper.opacity(colorScheme == .dark ? 0.10 : 0))
                    .accessibilityHidden(true)
                ForEach(visits) { visit in
                    visitor(visit, in: proxy.size)
                }
                ForEach(members) { member in
                    memberCharacter(member, in: proxy.size)
                }
            }
            .coordinateSpace(name: coordinateSpaceName)
        }
    }

    private let coordinateSpaceName = "SharedMeadow"

    private func memberCharacter(_ member: NightFlockV4Membership, in size: CGSize) -> some View {
        let occupant = SharedMeadowOccupant.member(member.memberID)
        let point = controller.position(for: occupant)
        let isMe = member.memberID == party.myMemberID
        let avatar = showsSocialAvatar ? member.profile.presentation.avatarID : "shepherd"
        let characterSize: CGFloat = avatar == "shepherd" ? 84 : 66
        return Group {
            PastureCharacterHitTarget(
                entity: occupant,
                controller: controller,
                canvasSize: size,
                coordinateSpace: coordinateSpaceName,
                reduceMotion: reduceMotion,
                label: "\(member.profile.displayName)\(isMe ? ", you" : ""), \(SlumberPartySocialAvatarView.title(for: avatar))",
                hint: isMe ? "Double tap for your card and visiting sheep. Long press and drag to move." : "Double tap to greet \(member.profile.displayName). Long press and drag to move.",
                actionTitle: isMe ? "Open my card" : "Greet \(member.profile.displayName)",
                action: { onSelectMember(member.memberID) }
            ) {
                VStack(spacing: 0) {
                    SlumberPartySocialAvatarView(presentation: member.profile.presentation, avatarID: avatar,
                                                 size: characterSize, showsBackdrop: false)
                        .background(alignment: .bottom) {
                            Ellipse()
                                .fill(AppColors.farmContactShadow.opacity(0.32))
                                .frame(width: characterSize * 0.55, height: 8)
                                .offset(y: 2)
                        }
                }
            }
            .position(x: size.width * point.x, y: size.height * point.y)
            .animation(spatialAnimation(for: controller.behavior(for: occupant)), value: point)
            .zIndex(point.y)
            nameplate(member.profile.displayName, isMe: isMe, at: point, in: size, offset: characterSize / 2 + 8)
        }
    }

    private func visitor(_ visit: SharedFarmVisit, in size: CGSize) -> some View {
        let occupant = SharedMeadowOccupant.visitor(visit.id)
        let point = controller.position(for: occupant)
        let owner = members.first { $0.memberID == visit.memberID }
        let isMine = visit.memberID == party.myMemberID
        let ownerName = owner?.profile.displayName ?? "A group member"
        let line = SharedFarmSocialCopy.visitLine(sheepName: visit.sheepDisplayName, ownerName: ownerName, isMe: isMine,
                                                 nightsRemaining: visit.nightsRemaining(at: store.now()))
        return PastureCharacterHitTarget(
            entity: occupant,
            controller: controller,
            canvasSize: size,
            coordinateSpace: coordinateSpaceName,
            reduceMotion: reduceMotion,
            label: line,
            hint: isMine ? "Double tap to manage this visit. Long press and drag to move." : "Double tap to open \(ownerName)’s card. Long press and drag to move.",
            actionTitle: isMine ? "Manage visit" : "Open \(ownerName)’s card",
            action: { onSelectMember(visit.memberID) }
        ) {
            VStack(spacing: 0) {
                if let definition = SheepCatalog.definition(for: visit.sheepDefinitionID) {
                    PixelAssetImage(name: definition.assetName)
                        .frame(width: 46, height: 46)
                } else {
                    PixelAssetImage(name: AssetSlot.Sheep.common)
                        .frame(width: 46, height: 46)
                }
            }
            .background(alignment: .bottom) {
                Ellipse().fill(AppColors.farmContactShadow.opacity(0.3)).frame(width: 30, height: 6).offset(y: 1)
            }
        }
        .position(x: size.width * point.x, y: size.height * point.y)
        .animation(spatialAnimation(for: controller.behavior(for: occupant)), value: point)
        .zIndex(point.y)
    }

    private func nameplate(_ name: String, isMe: Bool, at point: PastureScenePoint, in size: CGSize, offset: CGFloat) -> some View {
        Text(isMe ? "\(name) · You" : name)
            .font(.caption2.weight(.bold))
            .dynamicTypeSize(...DynamicTypeSize.large)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: 110)
            .fixedSize()
            .foregroundStyle(AppColors.ink)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 2)
            .background(AppColors.paper.opacity(0.9), in: Capsule())
            .overlay { Capsule().stroke(AppColors.stroke.opacity(0.34), lineWidth: 1) }
            // Back-row plates float above the head so the front row never hides them.
            .position(x: size.width * point.x,
                      y: point.y < 0.7 ? size.height * point.y - offset : min(size.height - 12, size.height * point.y + offset))
            .animation(spatialAnimation(for: .idle), value: point)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .zIndex(point.y + 0.001)
    }

    // MARK: Visitors strip

    @ViewBuilder
    private var visitorStrip: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if visits.isEmpty {
                Text("No sheep are visiting yet. Send one of yours for \(SharedFarmVisit.stayNights) nights; friends see only its name and look.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(visits) { visit in
                    let owner = members.first { $0.memberID == visit.memberID }?.profile.displayName ?? "A group member"
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "pawprint")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.grass)
                            .accessibilityHidden(true)
                        Text(SharedFarmSocialCopy.visitLine(sheepName: visit.sheepDisplayName, ownerName: owner,
                                                            isMe: visit.memberID == party.myMemberID,
                                                            nightsRemaining: visit.nightsRemaining(at: store.now())))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if !isWindDownActive {
                Button(store.myVisit == nil ? "Send a sheep to visit" : "Change or bring home") { onSendVisit() }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    .frame(minHeight: 44)
                    .accessibilityHint("Sends one of your sheep to the shared Farm. Friends receive its name and look only.")
            }
        }
    }

    // MARK: Helpers

    private func configureScene() {
        var occupants: [SharedMeadowSceneController.Configuration.Occupant] = []
        let memberIndex = Dictionary(uniqueKeysWithValues: members.enumerated().map { ($1.memberID, $0) })
        for member in members {
            let avatar = showsSocialAvatar ? member.profile.presentation.avatarID : "shepherd"
            occupants.append(.init(occupant: .member(member.memberID), ownerMemberID: member.memberID,
                                   memberIndex: memberIndex[member.memberID] ?? 0, visitorIndex: 0,
                                   isCompanionLike: avatar != "shepherd"))
        }
        var visitorCounts: [UUID: Int] = [:]
        for visit in visits {
            let index = visitorCounts[visit.memberID, default: 0]
            visitorCounts[visit.memberID] = index + 1
            occupants.append(.init(occupant: .visitor(visit.id), ownerMemberID: visit.memberID,
                                   memberIndex: memberIndex[visit.memberID] ?? 0, visitorIndex: index, isCompanionLike: false))
        }
        controller.configure(
            .init(occupants: occupants, memberCount: members.count, myMemberID: party.myMemberID,
                  seed: PastureSceneLayout.stableHash(forKey: party.summary.partyID.uuidString)),
            arrangement: store.loadArrangement(),
            reduceMotion: reduceMotion,
            isQuiet: isWindDownActive || scenePhase != .active,
            onPersist: { store.saveArrangement($0) }
        )
    }

    private func spatialAnimation(for behavior: PastureSceneBehavior) -> Animation? {
        guard !reduceMotion, behavior != .dragging else { return nil }
        return behavior == .reacting ? AppMotion.celebration : AppMotion.settle
    }
}

#Preview("Shared meadow · two people, one visitor") {
    let store = SharedFarmPrototypeFixtures.store()
    return ScrollView {
        SlumberPartySharedMeadowView(party: SharedFarmPrototypeFixtures.party, showsSocialAvatar: true, store: store,
                                     onSelectMember: { _ in }, onGreetingCandidate: { _ in }, onSendVisit: {})
            .padding()
    }
    .background(AppColors.paper)
}

#Preview("Shared meadow · empty, large text") {
    let store = SharedFarmPrototypeFixtures.store(seeded: false)
    return ScrollView {
        SlumberPartySharedMeadowView(party: SharedFarmPrototypeFixtures.party, showsSocialAvatar: true, store: store,
                                     onSelectMember: { _ in }, onGreetingCandidate: { _ in }, onSendVisit: {})
            .padding()
    }
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility2)
}
