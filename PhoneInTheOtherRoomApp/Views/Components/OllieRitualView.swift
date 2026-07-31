import SwiftUI

enum OllieRitualState: String, CaseIterable, Identifiable {
    case ready
    case tuckingIn
    case guarding
    case overnight
    case morningQuiet
    case completed
    case endedEarly

    var id: String { rawValue }

    fileprivate var assetName: String {
        switch self {
        case .ready: return AssetSlot.Dog.idle
        case .tuckingIn, .guarding: return AssetSlot.Dog.focused
        case .overnight: return AssetSlot.Dog.sleeping
        case .morningQuiet: return AssetSlot.Dog.happy
        case .completed: return AssetSlot.Dog.proud
        case .endedEarly: return AssetSlot.Dog.concerned
        }
    }

    fileprivate var previewTitle: String {
        switch self {
        case .ready: return "Ready"
        case .tuckingIn: return "Tuck-in"
        case .guarding: return "Guarding"
        case .overnight: return "Overnight"
        case .morningQuiet: return "Morning"
        case .completed: return "Complete"
        case .endedEarly: return "Fresh start"
        }
    }
}

/// Gives Wind Down one visual character state without creating a second
/// session state machine. The caller maps authoritative run state to a pose.
struct OllieRitualView: View {
    var state: OllieRitualState
    var size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(state: OllieRitualState, size: CGFloat = 88) {
        self.state = state
        self.size = size
    }

    var body: some View {
        ZStack {
            PixelAssetImage(name: state.assetName)
                .id(state)
                .transition(transition)
        }
        .frame(width: size, height: size)
        .animation(animation, value: state)
        .accessibilityHidden(true)
    }

    private var animation: Animation {
        guard !reduceMotion else { return AppMotion.reducedFade }
        switch state {
        case .completed:
            return AppMotion.celebration
        case .tuckingIn, .guarding, .morningQuiet:
            return AppMotion.settle
        case .ready, .overnight, .endedEarly:
            return AppMotion.stateChange
        }
    }

    private var transition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        switch state {
        case .completed:
            return .opacity.combined(with: .scale(scale: 0.92))
        case .tuckingIn, .guarding, .morningQuiet:
            return .opacity.combined(with: .scale(scale: 0.97))
        case .ready, .overnight, .endedEarly:
            return .opacity
        }
    }
}

#Preview("Ritual states") {
    ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: 18) {
            ForEach(OllieRitualState.allCases) { state in
                VStack {
                    OllieRitualView(state: state, size: 104)
                    Text(state.previewTitle)
                        .font(pixelFont(.caption2))
                }
                .frame(width: 112)
            }
        }
        .padding()
    }
    .background(AppColors.paper)
}

#Preview("Gentle early end") {
    OllieRitualView(state: .endedEarly, size: 160)
        .padding()
        .background(AppColors.paper)
}
