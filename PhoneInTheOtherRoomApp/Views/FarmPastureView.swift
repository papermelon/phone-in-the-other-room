import SwiftUI

struct FarmPastureView: View {
    let state: FarmState
    let protectedNightCount: Int
    let layoutSeed: UInt64
    let onSelectSheep: (FlockSheep) -> Void
    var persistedScene: PastureSceneSnapshot? = nil
    var onPersistScene: (PastureSceneSnapshot) -> Void = { _ in }
    var onSelectOllie: () -> Void = {}
    var onSelectShepherd: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sceneController = PastureSceneController()
    @State private var selectedPasture = 0

    private var pastureCount: Int { max(1, state.activeCapacity / 12) }

    var body: some View {
        TabView(selection: $selectedPasture) {
            ForEach(0..<pastureCount, id: \.self) { pasture in
                pasturePage(pasture)
                    .padding(.horizontal, 1)
                    .tag(pasture)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: pastureCount > 1 ? .always : .never))
        .frame(height: 280)
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
        .onChange(of: selectedPasture) { _, _ in configureScene() }
        .onDisappear { sceneController.stop() }
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
                        hint: "Double tap to open \(sheep.displayName) in The Barn. Long press and drag to place them in the pasture.",
                        action: { onSelectSheep(sheep) }
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
                    hint: "Double tap to open Ollie’s Farm Shop items. Long press and drag to place Ollie in the pasture.",
                    action: onSelectOllie
                ) { OllieFarmAvatar(accessoryItemID: state.equipment.ollieAccessoryItemID, size: 72) }

                character(
                    entity: .shepherd(pastureIndex: pasture),
                    in: proxy.size,
                    coordinateSpace: coordinateSpace(for: pasture),
                    label: "Your Shepherd in the pasture",
                    hint: "Double tap to customize Your Shepherd. Long press and drag to place Your Shepherd in the pasture.",
                    action: onSelectShepherd
                ) { ShepherdAvatarView(profile: state.shepherd, size: 72) }

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
        hint: String,
        action: @escaping () -> Void,
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
            hint: hint,
            action: action,
            content: content
        )
        .position(x: size.width * point.x, y: size.height * point.y)
        .animation(spatialAnimation(for: behavior), value: point)
        .zIndex(point.y)
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
}

private struct PastureCharacterHitTarget<Content: View>: View {
    let entity: PastureSceneEntityID
    let controller: PastureSceneController
    let canvasSize: CGSize
    let coordinateSpace: String
    let reduceMotion: Bool
    let label: String
    let hint: String
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .accessibilityHidden(true)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(visualScale)
            .rotationEffect(.degrees(visualRotation))
            .offset(y: visualOffset)
            .animation(reduceMotion ? AppMotion.reducedFade : AppMotion.stateChange, value: controller.behavior(for: entity))
            .onTapGesture {
                if controller.shouldAcceptTap(for: entity) { action() }
            }
            .simultaneousGesture(dragGesture)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAction {
                guard controller.shouldAcceptTap(for: entity) else { return }
                action()
            }
    }

    private var dragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpace)))
            .onChanged { value in
                guard case let .second(true, drag?) = value else { return }
                controller.beginDrag(entity)
                controller.updateDrag(
                    entity,
                    translation: PastureScenePoint(
                        x: Double(drag.translation.width / max(canvasSize.width, 1)),
                        y: Double(drag.translation.height / max(canvasSize.height, 1))
                    )
                )
            }
            .onEnded { value in
                if case .second(true, _) = value { controller.finishDrag(entity) }
                else { controller.cancelInteraction() }
            }
    }

    private var visualScale: CGFloat {
        guard !reduceMotion else { return controller.behavior(for: entity) == .dragging ? 1.02 : 1 }
        switch controller.behavior(for: entity) {
        case .dragging: return 1.04
        case .chasing, .reacting: return 1.03
        case .ambient(.graze): return 0.98
        case .ambient(.tinyHop), .ambient(.wave): return 1.05
        default: return 1
        }
    }

    private var visualRotation: Double {
        guard !reduceMotion else { return 0 }
        switch controller.behavior(for: entity) {
        case .chasing: return -4
        case .reacting: return 4
        case .ambient(.wave): return 3
        case .ambient(.stanceShift): return -2
        default: return 0
        }
    }

    private var visualOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        switch controller.behavior(for: entity) {
        case .wandering, .chasing: return -2
        case .ambient(.tinyHop): return -5
        case .ambient(.sniff): return 2
        default: return 0
        }
    }
}
