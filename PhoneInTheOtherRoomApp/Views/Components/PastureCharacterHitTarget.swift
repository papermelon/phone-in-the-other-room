import SwiftUI

struct PastureCharacterHitTarget<Content: View>: View {
    let entity: PastureSceneEntityID
    let controller: PastureSceneController
    let canvasSize: CGSize
    let coordinateSpace: String
    let reduceMotion: Bool
    let label: String
    let hint: String
    let actionTitle: String
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var beganDrag = false
    @GestureState private var gestureInProgress = false

    var body: some View {
        content()
            .accessibilityHidden(true)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(visualScale)
            .rotationEffect(.degrees(visualRotation))
            .offset(y: visualOffset)
            .animation(
                reduceMotion ? AppMotion.reducedFade : AppMotion.stateChange,
                value: controller.behavior(for: entity)
            )
            .onTapGesture {
                guard controller.shouldAcceptTap(for: entity) else { return }
                action()
            }
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
