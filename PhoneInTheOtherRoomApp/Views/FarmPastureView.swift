import SwiftUI

struct FarmPastureView: View {
    let state: FarmState
    let protectedNightCount: Int
    let layoutSeed: UInt64
    let onSelectSheep: (FlockSheep) -> Void
    var isWindDownActive: Bool = false
    var persistedScene: PastureSceneSnapshot? = nil
    var onPersistScene: (PastureSceneSnapshot) -> Void = { _ in }
    var onSelectOllie: () -> Void = {}
    var onSelectShepherd: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sceneController = PastureSceneController()
    @State private var selectedPasture = 0
    @State private var selectedCharacter: PastureSceneEntityID?

    private var pastureCount: Int { max(1, state.activeCapacity / 12) }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedPasture) {
                ForEach(0..<pastureCount, id: \.self) { pasture in
                    pasturePage(pasture)
                        .padding(.horizontal, 1)
                        .tag(pasture)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: pastureCount > 1 ? .always : .never))
        }
        .frame(height: sceneController.isPlayMode ? 420 : 280)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.28), lineWidth: 1)
        }
        .accessibilityLabel("Farm pasture, \(state.activeSheep.count) active sheep across \(pastureCount) pastures")
        .onAppear(perform: configureScene)
        .onChange(of: state) { _, _ in configureScene() }
        .onChange(of: layoutSeed) { _, _ in configureScene() }
        .onChange(of: reduceMotion) { _, _ in configureScene() }
        .onChange(of: selectedPasture) { _, _ in
            selectedCharacter = nil
            sceneController.cancelInteraction()
            configureScene()
        }
        .onChange(of: isWindDownActive) { _, active in
            if active {
                selectedCharacter = nil
                sceneController.setPlayMode(false)
                sceneController.cancelInteraction()
            }
            configureScene()
        }
        .onDisappear {
            selectedCharacter = nil
            sceneController.stop()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: sceneController.feedbackTick)
    }

    private func pasturePage(_ pasture: Int) -> some View {
        let pageSheep = Array(state.activeSheep.dropFirst(pasture * 12).prefix(12))
        return GeometryReader { proxy in
            ZStack {
                PixelAssetImage(name: AssetSlot.Farm.backgroundDay, contentMode: .fill)
                    .accessibilityHidden(true)
                LinearGradient(
                    colors: [.clear, AppColors.grass.opacity(0.16), AppColors.bark.opacity(0.34)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                if pasture == 0 { decorations(in: proxy.size) }

                ForEach(pageSheep) { sheep in
                    let entity = PastureSceneEntityID.sheep(sheep.id, pastureIndex: pasture)
                    character(
                        entity: entity,
                        in: proxy.size,
                        coordinateSpace: coordinateSpace(for: pasture),
                        label: sheepAccessibilityLabel(sheep),
                        normalHint: "Double tap to open \(sheep.displayName) in The Barn. Long press and drag to place them in the pasture.",
                        playHint: "Play with \(sheep.displayName), then use the pasture card to open their Barn details.",
                        openActionTitle: "Open \(sheep.displayName) in The Barn",
                        normalAction: { onSelectSheep(sheep) },
                        playAction: { selectedCharacter = entity }
                    ) {
                        FarmSheepSprite(
                            sheep: sheep,
                            protectedNightCount: protectedNightCount,
                            size: sheepSpriteSize(for: sceneController.position(for: entity).y),
                            showsStatusBadge: false
                        )
                    }
                }

                character(
                    entity: .ollie(pastureIndex: pasture),
                    in: proxy.size,
                    coordinateSpace: coordinateSpace(for: pasture),
                    label: "Ollie in the pasture",
                    normalHint: "Double tap to open Ollie’s Farm Shop items. Long press and drag to place Ollie in the pasture.",
                    playHint: "Play with Ollie, then use the pasture card to open Ollie’s Shop.",
                    openActionTitle: "Open Ollie’s Shop",
                    normalAction: onSelectOllie,
                    playAction: { selectedCharacter = .ollie(pastureIndex: pasture) }
                ) { OllieFarmAvatar(accessoryItemID: state.equipment.ollieAccessoryItemID, size: 72) }

                character(
                    entity: .shepherd(pastureIndex: pasture),
                    in: proxy.size,
                    coordinateSpace: coordinateSpace(for: pasture),
                    label: "Your Shepherd in the pasture",
                    normalHint: "Double tap to customize Your Shepherd. Long press and drag to place Your Shepherd in the pasture.",
                    playHint: "Double tap to customize Your Shepherd.",
                    openActionTitle: "Open customization",
                    normalAction: onSelectShepherd,
                    playAction: onSelectShepherd
                ) { ShepherdAvatarView(profile: state.shepherd, size: 72) }

                PastureSceneEffectsLayer(
                    effects: sceneController.effects,
                    pasture: pasture,
                    size: proxy.size,
                    reduceMotion: reduceMotion
                )

                if sceneController.isPlayMode, let ball = sceneController.ball {
                    PastureBallView(ball: ball, size: proxy.size, reduceMotion: reduceMotion) {
                        sceneController.tossBall()
                    }
                }

                if pageSheep.isEmpty { emptyPastureMessage(pasture, in: proxy.size) }

                Text("PASTURE \(pasture + 1)")
                    .font(pixelFont(.caption2))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(AppColors.bark)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xxs)
                    .background(AppColors.paper.opacity(0.84), in: Capsule())
                    .padding(.leading, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .accessibilityHidden(true)

                pastureChrome(for: pasture, sheep: pageSheep)
                    .padding(.leading, 96)
                    .padding(.trailing, AppSpacing.sm)
                    .padding(.top, AppSpacing.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .coordinateSpace(name: coordinateSpace(for: pasture))
        }
    }

    private func character<Content: View>(
        entity: PastureSceneEntityID,
        in size: CGSize,
        coordinateSpace: String,
        label: String,
        normalHint: String,
        playHint: String,
        openActionTitle: String,
        normalAction: @escaping () -> Void,
        playAction: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let point = sceneController.position(for: entity)
        let behavior = sceneController.behavior(for: entity)
        return PastureCharacterHitTarget(
            entity: entity,
            controller: sceneController,
            canvasSize: size,
            coordinateSpace: coordinateSpace,
            reduceMotion: reduceMotion,
            isPlayMode: sceneController.isPlayMode,
            label: label,
            normalHint: normalHint,
            playHint: playHint,
            openActionTitle: openActionTitle,
            normalAction: normalAction,
            playAction: playAction,
            content: content
        )
        .position(x: size.width * point.x, y: size.height * point.y)
        .animation(spatialAnimation(for: behavior), value: point)
        .zIndex(point.y)
    }

    @ViewBuilder
    private func pastureChrome(for pasture: Int, sheep: [FlockSheep]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if sceneController.isPlayMode, let selectedCharacter, selectedCharacter.pastureIndex == pasture {
                selectedCharacterChip(for: selectedCharacter, sheep: sheep)
            }
            PasturePlayControls(
                isPlayMode: sceneController.isPlayMode,
                isWindDownActive: isWindDownActive,
                hasBall: sceneController.ball != nil,
                onTogglePlay: togglePlayMode,
                onFetch: { sceneController.tossBall() }
            )
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    @ViewBuilder
    private func selectedCharacterChip(for entity: PastureSceneEntityID, sheep: [FlockSheep]) -> some View {
        switch entity.kind {
        case .sheep:
            if let sheepID = entity.sheepID, let sheep = sheep.first(where: { $0.id == sheepID }) {
                PastureSelectedCharacterChip(
                    title: sheep.displayName,
                    detail: personalityDetail(for: entity),
                    actionTitle: "Open in The Barn",
                    action: { onSelectSheep(sheep) }
                )
            }
        case .ollie:
            PastureSelectedCharacterChip(
                title: "Ollie",
                detail: "A wag and a gentle play bow. Fetch stays just for fun.",
                actionTitle: "Ollie’s Shop",
                action: onSelectOllie
            )
        case .shepherd:
            EmptyView()
        }
    }

    private func personalityDetail(for entity: PastureSceneEntityID) -> String {
        switch sceneController.personality(for: entity) {
        case .gentle: return "Gentle today — small scratches bring a soft hop."
        case .curious: return "Curious today — Ollie may come over to see."
        case .bouncy: return "Bouncy today — a little squish earns a happy hop."
        case .brave: return "Brave today — ready for a careful toss and landing."
        case .dreamy: return "Dreamy today — quiet pets suit them best."
        }
    }

    private func togglePlayMode() {
        guard !isWindDownActive else { return }
        selectedCharacter = nil
        sceneController.cancelInteraction()
        sceneController.setPlayMode(!sceneController.isPlayMode)
    }

    @ViewBuilder
    private func decorations(in size: CGSize) -> some View {
        ForEach(FarmDecorationZone.allCases, id: \.self) { zone in
            if let itemID = state.equipment.decorationPlacements[zone], let item = FarmShopCatalog.item(for: itemID) {
                let anchor = FarmShopCatalog.decorationAnchor(for: zone)
                FarmDecorationSceneImage(item: item, size: CGFloat(anchor.size))
                    .position(x: size.width * CGFloat(anchor.normalizedCenterX), y: size.height * CGFloat(anchor.normalizedGroundY) - CGFloat(anchor.size) / 2)
                    .accessibilityHidden(true)
            }
        }
    }

    private func emptyPastureMessage(_ pasture: Int, in size: CGSize) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(pasture == 0 ? "The pasture is quiet." : "This pasture is open.")
                .font(AppTypography.headline)
            Text(pasture == 0 ? "A completed Wind Down gives Ollie a trail to follow." : "New arrivals can settle here when they come home.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.md)
        .background(AppColors.paper.opacity(0.88), in: RoundedRectangle(cornerRadius: AppRadius.md))
        .position(x: size.width * 0.52, y: size.height * 0.42)
        .accessibilityElement(children: .combine)
    }

    private func configureScene() {
        sceneController.configure(
            activeSheep: state.activeSheep,
            pastureCount: pastureCount,
            layoutSeed: layoutSeed,
            activePastureIndex: selectedPasture,
            persistedSnapshot: persistedScene,
            reduceMotion: reduceMotion,
            isWindDownActive: isWindDownActive,
            onPersist: onPersistScene
        )
    }

    private func coordinateSpace(for pasture: Int) -> String { "FarmPasturePage-\(pasture)" }

    private func sheepSpriteSize(for normalizedY: Double) -> CGFloat {
        if normalizedY < 0.69 { return 38 }
        if normalizedY < 0.80 { return 46 }
        return 52
    }

    private func spatialAnimation(for behavior: PastureSceneBehavior) -> Animation? {
        guard !reduceMotion, behavior != .dragging, behavior != .squishing else { return nil }
        return AppMotion.settle
    }

    private func sheepAccessibilityLabel(_ sheep: FlockSheep) -> String {
        let ready = FarmEconomyRules.isWoolReady(for: sheep, protectedNightCount: protectedNightCount)
        return "\(sheep.displayName), \(sheep.rarity.title), \(ready ? "wool ready" : "wool regrowing")"
    }

}
