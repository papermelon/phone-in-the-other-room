import SwiftUI

enum FarmPasturePlayAction { case fetch, gather }

struct FarmPastureView: View {
    let state: FarmState
    let protectedNightCount: Int
    let layoutSeed: UInt64
    let onSelectSheep: (FlockSheep) -> Void
    var shepherdDisplayName: String = ""
    var isWindDownActive: Bool = false
    var persistedScene: PastureSceneSnapshot? = nil
    var onPersistScene: (PastureSceneSnapshot) -> Void = { _ in }
    var onSelectOllie: () -> Void = {}
    var onSelectShepherd: () -> Void = {}
    var scrollViewportSize = CGSize.zero
    var tracksScrollViewport = false
    var visitingSheepIDs: Set<UUID> = []
    var playRequest: Binding<FarmPasturePlayAction?> = .constant(nil)
    private var residentSheep: [FlockSheep] { state.activeSheep.filter { !visitingSheepIDs.contains($0.id) } }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var sceneController = PastureSceneController()
    @State private var selectedPasture = 0
    @State private var isInScrollViewport = false
    @State private var pastureFrame = CGRect.null
    @State private var isPresented = false

    private var pastureCount: Int { max(1, state.activeCapacity / 12) }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            pastureCard
            if sceneController.fetchGame.isPresented {
                PastureFetchActions(game: sceneController.fetchGame, onDone: sceneController.endFetch)
            }
        }
    }

    private var pastureCard: some View {
        VStack(spacing: 0) {
            if pastureCount == 1 {
                pasturePage(0)
            } else {
                TabView(selection: $selectedPasture) {
                    ForEach(0..<pastureCount, id: \.self) { pasture in
                        pasturePage(pasture)
                            .padding(.horizontal, 1)
                            .tag(pasture)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
        }
        .overlay(alignment: .topLeading) {
            Menu {
                Button("Ollie", action: onSelectOllie)
                Button("Your Shepherd", action: onSelectShepherd)
                ForEach(residentSheep) { sheep in
                    Button(sheep.displayName) { onSelectSheep(sheep) }
                }
            } label: {
                Label("Residents", systemImage: "person.2").font(AppTypography.caption).foregroundStyle(AppColors.ink)
                    .padding(.horizontal, AppSpacing.sm).frame(minHeight: 44)
                    .background(AppColors.paper.opacity(0.9), in: Capsule())
            }.padding(AppSpacing.xs).accessibilityHint("Open a resident’s details and actions")
                .opacity(sceneController.fetchGame.isPresented ? 0 : 1)
                .disabled(sceneController.fetchGame.isPresented)
        }
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Fetch with Ollie") { sceneController.fetch() }
                Button("Gather the sheep") { sceneController.gather() }
            } label: {
                Label("Play", systemImage: "tennisball").font(AppTypography.caption).foregroundStyle(AppColors.ink)
                    .padding(.horizontal, AppSpacing.sm).frame(minHeight: 44)
                    .background(AppColors.paper.opacity(0.9), in: Capsule())
            }.padding(AppSpacing.xs)
                .opacity(sceneController.fetchGame.isPresented ? 0 : 1)
                .disabled(sceneController.fetchGame.isPresented || isWindDownActive)
                .accessibilityLabel("Play with Ollie").accessibilityValue(sceneController.playMessage ?? "Choose fetch or gather")
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.28), lineWidth: 1)
        }
        .background {
            if tracksScrollViewport, !scrollViewportSize.equalTo(.zero) {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            updateScrollVisibility(
                                with: proxy.frame(in: .named(FarmScrollViewportCoordinateSpace.name))
                            )
                        }
                        .onChange(of: proxy.frame(in: .named(FarmScrollViewportCoordinateSpace.name))) { _, frame in
                            updateScrollVisibility(with: frame)
                        }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            isPresented = true
            configureScene()
            performRequestedPlay()
        }
        .task {
            #if DEBUG
            await PastureFetchNativeFixture.runReview(sceneController)
            #endif
        }
        .onChange(of: playRequest.wrappedValue) { _, _ in performRequestedPlay() }
        .onChange(of: visitingSheepIDs) { _, _ in configureScene() }
        .onChange(of: state) { _, _ in configureScene() }
        .onChange(of: layoutSeed) { _, _ in configureScene() }
        .onChange(of: reduceMotion) { _, _ in configureScene() }
        .onChange(of: selectedPasture) { _, _ in
            sceneController.cancelInteraction()
            configureScene()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { configureScene() } else { sceneController.stop() }
        }
        .onChange(of: isWindDownActive) { _, active in
            if active {
                sceneController.cancelInteraction()
            }
            configureScene()
        }
        .onChange(of: isInScrollViewport) { _, visible in
            if tracksScrollViewport, !visible { sceneController.stop() }
            else if scenePhase == .active { configureScene() }
        }
        .onChange(of: scrollViewportSize) { _, _ in
            updateScrollVisibility()
        }
        .onDisappear {
            isPresented = false
            isInScrollViewport = false
            sceneController.stop()
        }
    }

    private func pasturePage(_ pasture: Int) -> some View {
        let pageSheep = Array(residentSheep.dropFirst(pasture * 12).prefix(12))
        return GeometryReader { proxy in
            ZStack {
                PixelAssetImage(name: AssetSlot.Farm.backgroundDay, contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .trailing)
                    .clipped()
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
                        openActionTitle: "Open \(sheep.displayName) in The Barn",
                        normalAction: { onSelectSheep(sheep) }
                    ) {
                        FarmSheepSprite(
                            sheep: sheep,
                            protectedNightCount: protectedNightCount,
                            size: sheepSpriteSize(for: sceneController.position(for: entity).y),
                            showsStatusBadge: false
                        )
                    }
                }

                let ollieEntity = PastureSceneEntityID.ollie(pastureIndex: pasture)
                character(
                    entity: ollieEntity,
                    in: proxy.size,
                    coordinateSpace: coordinateSpace(for: pasture),
                    label: "Ollie in the pasture",
                    normalHint: "Open Ollie’s details, play and accessories. Long press and drag to place Ollie in the pasture.",
                    openActionTitle: "Open Ollie",
                    normalAction: onSelectOllie
                ) {
                    if sceneController.fetchGame.isPresented, pasture == selectedPasture {
                        PastureFetchOllie(game: sceneController.fetchGame,
                                          accessoryItemID: state.equipment.ollieAccessoryItemID)
                    } else {
                        OllieFarmAvatar(
                            accessoryItemID: state.equipment.ollieAccessoryItemID,
                            size: 72,
                            motionEnabled: selectedPasture == pasture
                                && pastureIsVisibleForMotion
                                && scenePhase == .active
                                && !reduceMotion
                                && !isWindDownActive
                                && sceneController.behavior(for: ollieEntity) != .dragging,
                            onPoseChanged: { sceneController.recordOlliePose($0, pasture: pasture) }
                        )
                    }
                }

                let shepherdEntity = PastureSceneEntityID.shepherd(pastureIndex: pasture)
                let shepherdPoint = sceneController.position(for: shepherdEntity)
                character(
                    entity: shepherdEntity,
                    in: proxy.size,
                    coordinateSpace: coordinateSpace(for: pasture),
                    label: shepherdAccessibilityLabel,
                    normalHint: "Double tap to customize Your Shepherd. Long press and drag to place Your Shepherd in the pasture.",
                    openActionTitle: "Open customization",
                    normalAction: onSelectShepherd
                ) { ShepherdAvatarView(profile: state.shepherd, size: 72) }
                shepherdNameplate(at: shepherdPoint, in: proxy.size)

                if pageSheep.isEmpty { emptyPastureMessage(pasture, in: proxy.size) }

                if pastureCount > 1 { Text("PASTURE \(pasture + 1)")
                    .font(pixelFont(.caption2))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .foregroundStyle(AppColors.bark)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xxs)
                    .background(AppColors.paper.opacity(0.84), in: Capsule())
                    .padding(.leading, AppSpacing.lg)
                    .padding(.top, AppSpacing.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .accessibilityHidden(true)
                }

                if sceneController.fetchGame.isPresented, selectedPasture == pasture {
                    PastureFetchOverlay(game: sceneController.fetchGame, size: proxy.size).zIndex(3)
                }
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
        openActionTitle: String,
        normalAction: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        let point = sceneController.position(for: entity)
        let behavior = sceneController.behavior(for: entity)
        return ZStack {
            Ellipse().fill(AppColors.farmContactShadow.opacity(0.3))
                .frame(width: entity.kind == .sheep ? 26 : 35, height: 7).offset(y: entity.kind == .sheep ? 20 : 32)
                .allowsHitTesting(false).accessibilityHidden(true)
            PastureCharacterHitTarget(
            entity: entity,
            controller: sceneController,
            canvasSize: size,
            coordinateSpace: coordinateSpace,
            reduceMotion: reduceMotion,
            label: label,
            hint: normalHint,
            actionTitle: openActionTitle,
            action: normalAction,
            content: content
        )
        }
        .frame(width: entity.kind == .sheep ? 60 : 72, height: entity.kind == .sheep ? 60 : 72)
        .position(x: size.width * point.x, y: size.height * point.y)
        .animation(spatialAnimation(for: behavior), value: point)
        .zIndex(point.y)
        .allowsHitTesting(!sceneController.fetchGame.isPresented)
        .accessibilityHidden(sceneController.fetchGame.isPresented)
    }

    private var pastureIsVisibleForMotion: Bool {
        !tracksScrollViewport || isInScrollViewport
    }

    private func updateScrollVisibility(with measuredPastureFrame: CGRect? = nil) {
        if let measuredPastureFrame {
            pastureFrame = measuredPastureFrame
        }
        let viewport = CGRect(origin: .zero, size: scrollViewportSize)
        isInScrollViewport = !scrollViewportSize.equalTo(.zero)
            && pastureFrame.intersects(viewport)
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
            Text(pasture == 0 ? "A completed Wind Down can help Ollie find a missing sheep." : "New arrivals can settle here when they come home.")
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
            activeSheep: residentSheep,
            pastureCount: pastureCount,
            layoutSeed: layoutSeed,
            activePastureIndex: selectedPasture,
            persistedSnapshot: persistedScene,
            reduceMotion: reduceMotion,
            isWindDownActive: isWindDownActive,
            onPersist: onPersistScene
        )
    }

    private func performRequestedPlay() {
        // A profile action plays in the visible pasture after navigation returns.
        guard isPresented, let request = playRequest.wrappedValue else { return }
        playRequest.wrappedValue = nil
        switch request {
        case .fetch: sceneController.fetch()
        case .gather: sceneController.gather()
        }
    }

    private func coordinateSpace(for pasture: Int) -> String { "FarmPasturePage-\(pasture)" }

    private func sheepSpriteSize(for normalizedY: Double) -> CGFloat {
        CGFloat(min(52, max(38, 38 + (normalizedY - 0.62) * 64)))
    }

    private func spatialAnimation(for behavior: PastureSceneBehavior) -> Animation? {
        guard !sceneController.fetchGame.isPresented, !reduceMotion, behavior != .dragging else { return nil }
        return AppMotion.settle
    }

    private func sheepAccessibilityLabel(_ sheep: FlockSheep) -> String {
        let ready = FarmEconomyRules.isWoolReady(for: sheep, protectedNightCount: protectedNightCount)
        return "\(sheep.displayName), \(sheep.rarity.title), \(ready ? "wool ready" : "wool regrowing")"
    }

    private var shepherdAccessibilityLabel: String {
        let name = shepherdDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Your Shepherd in the pasture" : "\(name)’s Shepherd in the pasture"
    }

    @ViewBuilder
    private func shepherdNameplate(at point: PastureScenePoint, in size: CGSize) -> some View {
        let name = shepherdDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            Text(name)
                .font(AppTypography.caption.weight(.bold))
                .dynamicTypeSize(...DynamicTypeSize.large)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(AppColors.ink)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xxs)
                .frame(maxWidth: 118)
                .background(AppColors.paper.opacity(0.92), in: Capsule())
                .overlay {
                    Capsule().stroke(AppColors.stroke.opacity(0.34), lineWidth: 1)
                }
                .position(
                    x: size.width * point.x,
                    y: min(size.height - 14, max(16, size.height * point.y + 48))
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
