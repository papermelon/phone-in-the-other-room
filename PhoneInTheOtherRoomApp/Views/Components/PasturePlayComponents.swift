import SwiftUI

/// Compact pasture controls keep play deliberate, and leave the dashboard itself
/// free to keep scrolling and paging normally.
struct PasturePlayControls: View {
    let isPlayMode: Bool
    let isWindDownActive: Bool
    let hasBall: Bool
    let onTogglePlay: () -> Void
    let onFetch: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            if isWindDownActive {
                Label("Pasture is quiet during Wind Down", systemImage: "moon.stars.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Pasture play is quiet during Wind Down")
            } else {
                Button(action: onTogglePlay) {
                    Label(isPlayMode ? "Done playing" : "Play in the pasture", systemImage: isPlayMode ? "checkmark.circle.fill" : "hand.tap.fill")
                        .font(AppTypography.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(isPlayMode ? AppColors.grass : AppColors.paper.opacity(0.92), in: Capsule())
                        .foregroundStyle(isPlayMode ? AppColors.paper : AppColors.ink)
                        .overlay {
                            Capsule().stroke(AppColors.stroke.opacity(isPlayMode ? 0 : 0.28), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityHint(isPlayMode ? "Returns character taps to their usual destinations." : "Lets you pet, squish, and gently move Ollie and the sheep.")

                if isPlayMode {
                    Button(action: onFetch) {
                        Label(hasBall ? "Throw ball" : "Fetch", systemImage: "tennisball.fill")
                            .font(AppTypography.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(AppColors.paper.opacity(0.92), in: Capsule())
                            .foregroundStyle(AppColors.ink)
                            .overlay { Capsule().stroke(AppColors.stroke.opacity(0.28), lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .accessibilityHint("Invites Ollie to a short, gentle fetch.")
                }
            }
            Spacer(minLength: 0)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.18), lineWidth: 1)
        }
    }
}

struct PastureSelectedCharacterChip: View {
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.caption.weight(.bold))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button(action: action) {
                Text(actionTitle)
                    .font(AppTypography.caption.weight(.bold))
                    .multilineTextAlignment(.trailing)
            }
            .buttonStyle(.bordered)
            .tint(AppColors.grass)
            .frame(minHeight: 44)
            .accessibilityLabel(actionTitle)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.paper.opacity(0.96), in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.26), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

struct PastureSceneEffectsLayer: View {
    let effects: [PastureSceneEffect]
    let pasture: Int
    let size: CGSize
    let reduceMotion: Bool

    var body: some View {
        ForEach(effects.filter { effect in
            effect.entityID?.pastureIndex == pasture
        }) { effect in
            effectView(for: effect)
                .position(
                    x: size.width * effect.point.x,
                    y: size.height * effect.point.y
                )
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                .accessibilityHidden(true)
        }
        .animation(reduceMotion ? AppMotion.reducedFade : AppMotion.celebration, value: effects)
    }

    @ViewBuilder
    private func effectView(for effect: PastureSceneEffect) -> some View {
        switch effect.kind {
        case .heart:
            Image(systemName: "heart.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.berry)
                .shadow(color: AppColors.paper, radius: 1)
        case .sparkle:
            Image(systemName: "sparkle")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppColors.amber)
                .shadow(color: AppColors.paper, radius: 1)
        case .woolPuff:
            Image(systemName: "cloud.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.wool)
                .shadow(color: AppColors.bark.opacity(0.16), radius: 2, y: 1)
        case .pawprint:
            Image(systemName: "pawprint.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColors.bark.opacity(0.72))
        }
    }
}

struct PastureBallView: View {
    let ball: PastureSceneBall
    let size: CGSize
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(AppColors.amber)
                .overlay { Circle().stroke(AppColors.bark.opacity(0.7), lineWidth: 2) }
                .overlay {
                    Circle()
                        .stroke(AppColors.paper.opacity(0.8), lineWidth: 1)
                        .padding(5)
                }
                .frame(width: 27, height: 27)
                .shadow(color: AppShadows.cardColor, radius: 2, y: 2)
                .scaleEffect(ball.isCarried && !reduceMotion ? 0.86 : 1)
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .position(x: size.width * ball.position.x, y: size.height * ball.position.y)
        .animation(reduceMotion ? AppMotion.reducedFade : AppMotion.settle, value: ball.position)
        .accessibilityLabel(ball.isCarried ? "Ollie has the fetch ball" : "Fetch ball")
        .accessibilityHint("Double tap to invite Ollie to fetch again.")
        .accessibilityAction(named: "Fetch with Ollie", action)
    }
}

struct PastureCharacterHitTarget<Content: View>: View {
    let entity: PastureSceneEntityID
    let controller: PastureSceneController
    let canvasSize: CGSize
    let coordinateSpace: String
    let reduceMotion: Bool
    let isPlayMode: Bool
    let label: String
    let normalHint: String
    let playHint: String
    let openActionTitle: String
    let normalAction: () -> Void
    let playAction: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var beganPress = false
    @State private var pickedUp = false
    @GestureState private var gestureInProgress = false

    private var supportsPlay: Bool { entity.kind != .shepherd }

    var body: some View {
        content()
            .accessibilityHidden(true)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(visualScale)
            .rotationEffect(.degrees(visualRotation))
            .offset(y: visualOffset)
            .animation(reduceMotion ? AppMotion.reducedFade : AppMotion.stateChange, value: controller.behavior(for: entity))
            .onTapGesture(perform: tap)
            .simultaneousGesture(pressAndDragGesture)
            .onChange(of: gestureInProgress) { wasInProgress, isInProgress in
                guard wasInProgress, !isInProgress, beganPress else { return }
                abortInterruptedInteraction()
            }
            .onChange(of: isPlayMode) { _, enabled in
                guard !enabled, beganPress else { return }
                abortInterruptedInteraction()
            }
            .onDisappear {
                guard beganPress else { return }
                abortInterruptedInteraction()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(accessibilityHint)
            .accessibilityAction { primaryAccessibilityAction() }
            .modifier(PastureCharacterAccessibilityActions(
                enablesPlayActions: isPlayMode && supportsPlay,
                openActionTitle: openActionTitle,
                playAction: {
                    guard controller.shouldAcceptTap(for: entity) else { return }
                    controller.beginPress(entity)
                    controller.pet(entity)
                    controller.endPress(entity)
                    playAction()
                },
                openAction: normalAction
            ))
    }

    private var accessibilityHint: String {
        if isPlayMode, supportsPlay {
            return "\(playHint) Hold, then move a little to pet; move farther to gently pick up and place. Actions include \(openActionTitle)."
        }
        return normalHint
    }

    private func tap() {
        guard controller.shouldAcceptTap(for: entity) else { return }
        if isPlayMode, supportsPlay {
            controller.reactToTap(entity)
            playAction()
        } else {
            normalAction()
        }
    }

    private func primaryAccessibilityAction() {
        if isPlayMode, supportsPlay {
            guard controller.shouldAcceptTap(for: entity) else { return }
            controller.reactToTap(entity)
            playAction()
        } else {
            normalAction()
        }
    }

    private var pressAndDragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpace)))
            .updating($gestureInProgress) { value, state, _ in
                if case .second(true, _) = value {
                    state = true
                }
            }
            .onChanged { value in
                guard case let .second(true, drag) = value else { return }
                beginIfNeeded()
                guard let drag else { return }

                let translation = normalized(drag.translation)
                if isPlayMode, supportsPlay, !pickedUp, magnitude(of: translation) < 0.035 {
                    controller.pet(entity)
                } else {
                    if !pickedUp {
                        pickedUp = true
                        controller.beginDrag(entity)
                    }
                    controller.updateDrag(entity, translation: translation)
                }
            }
            .onEnded { value in
                defer { resetInteractionState() }
                guard case let .second(true, drag) = value, beganPress else {
                    controller.cancelInteraction()
                    return
                }
                if pickedUp {
                    let translation = normalized(drag?.translation ?? .zero)
                    let predicted = normalized(drag?.predictedEndTranslation ?? .zero)
                    controller.finishDrag(
                        entity,
                        predictedTranslation: PastureScenePoint(
                            x: predicted.x - translation.x,
                            y: predicted.y - translation.y
                        )
                    )
                } else if isPlayMode, supportsPlay {
                    controller.endPress(entity)
                } else {
                    controller.cancelInteraction()
                }
            }
    }

    private func beginIfNeeded() {
        guard !beganPress else { return }
        beganPress = true
        if isPlayMode, supportsPlay {
            controller.beginPress(entity)
        } else {
            pickedUp = true
            controller.beginDrag(entity)
        }
    }

    private func normalized(_ translation: CGSize) -> PastureScenePoint {
        PastureScenePoint(
            x: Double(translation.width / max(canvasSize.width, 1)),
            y: Double(translation.height / max(canvasSize.height, 1))
        )
    }

    private func magnitude(of point: PastureScenePoint) -> Double {
        hypot(point.x, point.y)
    }

    private func resetInteractionState() {
        beganPress = false
        pickedUp = false
    }

    private func abortInterruptedInteraction() {
        controller.cancelInteraction()
        resetInteractionState()
    }

    private var visualScale: CGFloat {
        guard !reduceMotion else { return controller.behavior(for: entity) == .dragging ? 1.02 : 1 }
        switch controller.behavior(for: entity) {
        case .dragging: return 1.05
        case .petting, .squishing: return 0.94
        case .landing: return 1.03
        case .greeting, .fetching, .chasing, .reacting: return 1.04
        case .ambient(.graze): return 0.98
        case .ambient(.tinyHop), .ambient(.wave): return 1.05
        default: return 1
        }
    }

    private var visualRotation: Double {
        guard !reduceMotion else { return 0 }
        switch controller.behavior(for: entity) {
        case .fetching, .chasing: return -4
        case .greeting, .reacting: return 4
        case .petting: return -2
        case .ambient(.wave): return 3
        case .ambient(.stanceShift): return -2
        default: return 0
        }
    }

    private var visualOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        switch controller.behavior(for: entity) {
        case .wandering, .chasing, .fetching: return -2
        case .landing: return 2
        case .ambient(.tinyHop), .greeting: return -5
        case .ambient(.sniff): return 2
        default: return 0
        }
    }
}

private struct PastureCharacterAccessibilityActions: ViewModifier {
    let enablesPlayActions: Bool
    let openActionTitle: String
    let playAction: () -> Void
    let openAction: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if enablesPlayActions {
            content
                .accessibilityAction(named: "Pet", playAction)
                .accessibilityAction(named: openActionTitle, openAction)
        } else {
            content.accessibilityAction(named: openActionTitle, openAction)
        }
    }
}

#Preview("Pasture play controls") {
    VStack {
        PasturePlayControls(isPlayMode: true, isWindDownActive: false, hasBall: false, onTogglePlay: {}, onFetch: {})
        PasturePlayControls(isPlayMode: false, isWindDownActive: true, hasBall: false, onTogglePlay: {}, onFetch: {})
    }.padding().background(AppColors.paper)
}
