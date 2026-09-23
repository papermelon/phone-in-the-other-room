import SwiftUI

/// The touch contract shared by the personal pasture and the shared meadow:
/// tap opens, long-press then drag moves, and a controller decides whether a
/// tap that follows a drag should be swallowed.
@MainActor
protocol PastureInteractionControlling: AnyObject {
    associatedtype Entity: Hashable
    func behavior(for entity: Entity) -> PastureSceneBehavior
    func beginDrag(_ entity: Entity)
    func updateDrag(_ entity: Entity, translation: PastureScenePoint)
    func finishDrag(_ entity: Entity)
    func cancelInteraction()
    func shouldAcceptTap(for entity: Entity) -> Bool
}

extension PastureSceneController: PastureInteractionControlling {
    func cancelInteraction() { cancelInteraction(restartAutonomy: true) }
}

struct PastureCharacterHitTarget<Controller: PastureInteractionControlling, Content: View>: View {
    let entity: Controller.Entity
    let controller: Controller
    let canvasSize: CGSize
    let coordinateSpace: String
    let reduceMotion: Bool
    let label: String
    let hint: String
    let actionTitle: String
    var accessibleStep: Double = 0.06
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var responseStarted: Date?
    @State private var beganDrag = false
    @GestureState private var gestureInProgress = false

    var body: some View {
        TimelineView(.animation(paused: responseStarted == nil || reduceMotion)) { context in
        let response = PasturePlay.response(elapsed: responseStarted.map { context.date.timeIntervalSince($0) } ?? 1, reduceMotion: reduceMotion)
        content()
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(x: visualScale, y: visualScale * CGFloat(response.squash))
            .rotationEffect(.degrees(visualRotation + response.tilt))
            .offset(y: visualOffset - CGFloat(response.lift))
            .animation(
                reduceMotion ? AppMotion.reducedFade : AppMotion.stateChange,
                value: controller.behavior(for: entity)
            )
            .gesture(TapGesture(count: 2).exclusively(before: TapGesture()).onEnded { value in
                guard controller.shouldAcceptTap(for: entity) else { return }
                switch value {
                case .first: responseStarted = Date()
                case .second: action()
                }
            })
            .simultaneousGesture(pressAndDragGesture)
            .onChange(of: gestureInProgress) { wasInProgress, isInProgress in
                guard wasInProgress, !isInProgress, beganDrag else { return }
                abortInterruptedDrag()
            }
            .onDisappear {
                guard beganDrag else { return }
                abortInterruptedDrag()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAction(named: actionTitle) {
                guard controller.shouldAcceptTap(for: entity) else { return }
                action()
            }
            .accessibilityAction(named: "Gentle nudge") { responseStarted = Date() }
            .accessibilityAction(named: "Move left") { moveAccessibly(x: -accessibleStep, y: 0) }
            .accessibilityAction(named: "Move right") { moveAccessibly(x: accessibleStep, y: 0) }
            .accessibilityAction(named: "Move toward the hills") { moveAccessibly(x: 0, y: -accessibleStep) }
            .accessibilityAction(named: "Move forward") { moveAccessibly(x: 0, y: accessibleStep) }
        }
        .accessibilityRepresentation {
            Button(label) {
                guard controller.shouldAcceptTap(for: entity) else { return }
                action()
            }
            .accessibilityHint(hint)
            .accessibilityAction(named: "Gentle nudge") { responseStarted = Date() }
            .accessibilityAction(named: "Move left") { moveAccessibly(x: -accessibleStep, y: 0) }
            .accessibilityAction(named: "Move right") { moveAccessibly(x: accessibleStep, y: 0) }
            .accessibilityAction(named: "Move toward the hills") { moveAccessibly(x: 0, y: -accessibleStep) }
            .accessibilityAction(named: "Move forward") { moveAccessibly(x: 0, y: accessibleStep) }
        }
        .task(id: responseStarted) {
            guard responseStarted != nil else { return }
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            responseStarted = nil
        }
    }

    private func moveAccessibly(x: Double, y: Double) {
        controller.beginDrag(entity)
        controller.updateDrag(entity, translation: .init(x: x, y: y))
        controller.finishDrag(entity)
        responseStarted = Date()
    }

    private var pressAndDragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpace)))
            .updating($gestureInProgress) { value, state, _ in
                if case .second(true, _) = value { state = true }
            }
            .onChanged { value in
                guard case let .second(true, drag?) = value else { return }
                if !beganDrag {
                    beganDrag = true
                    controller.beginDrag(entity)
                }
                controller.updateDrag(
                    entity,
                    translation: PastureScenePoint(
                        x: Double(drag.translation.width / max(canvasSize.width, 1)),
                        y: Double(drag.translation.height / max(canvasSize.height, 1))
                    )
                )
            }
            .onEnded { value in
                defer { beganDrag = false }
                if case .second(true, _) = value, beganDrag {
                    controller.finishDrag(entity)
                    responseStarted = Date()
                } else {
                    controller.cancelInteraction()
                }
            }
    }

    private func abortInterruptedDrag() {
        controller.cancelInteraction()
        beganDrag = false
    }

    private var visualScale: CGFloat {
        guard !reduceMotion else {
            return controller.behavior(for: entity) == .dragging ? 1.02 : 1
        }
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
