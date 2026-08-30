import SwiftUI

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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var sceneController = PastureSceneController()
    @State private var selectedPasture = 0
    @State private var isInScrollViewport = false
    @State private var pastureFrame = CGRect.null

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
        .accessibilityLabel("Farm pasture, \(state.activeSheep.count) active sheep across \(pastureCount) pastures")
        .onAppear(perform: configureScene)
        .onChange(of: state) { _, _ in configureScene() }
        .onChange(of: layoutSeed) { _, _ in configureScene() }
        .onChange(of: reduceMotion) { _, _ in configureScene() }
        .onChange(of: selectedPasture) { _, _ in
            sceneController.cancelInteraction()
            configureScene()
        }
        .onChange(of: isWindDownActive) { _, active in
            if active {
                sceneController.cancelInteraction()
            }
            configureScene()
        }
        .onChange(of: scrollViewportSize) { _, _ in
            updateScrollVisibility()
        }
        .onDisappear {
            isInScrollViewport = false
            sceneController.stop()
        }
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
                    normalHint: "Double tap to open Ollie’s Farm Shop items. Long press and drag to place Ollie in the pasture.",
                    openActionTitle: "Open Ollie’s Shop",
                    normalAction: onSelectOllie
                ) {
                    OllieFarmAvatar(
                        accessoryItemID: state.equipment.ollieAccessoryItemID,
                        size: 72,
                        motionEnabled: selectedPasture == pasture
                            && pastureIsVisibleForMotion
                            && scenePhase == .active
                            && !reduceMotion
                            && !isWindDownActive
                            && sceneController.behavior(for: ollieEntity) != .dragging
                    )
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
        return PastureCharacterHitTarget(
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
        .position(x: size.width * point.x, y: size.height * point.y)
        .animation(spatialAnimation(for: behavior), value: point)
        .zIndex(point.y)
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
        guard !reduceMotion, behavior != .dragging else { return nil }
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
