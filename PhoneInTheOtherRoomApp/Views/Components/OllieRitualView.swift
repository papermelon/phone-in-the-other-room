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
        case .tuckingIn: return "Wind Down"
        case .guarding: return "Guarding"
        case .overnight: return "Overnight"
        case .morningQuiet: return "Morning"
        case .completed: return "Complete"
        case .endedEarly: return "Fresh start"
        }
    }
}

/// Semantic presentation sizes keep the visible Ollie silhouette consistent even
/// though the images share a transparent 512×512 export canvas. Upright ritual
/// assets are normalized to approximately 436 px of visible height with a
/// shared y=470 paw baseline; Farm base artwork is intentionally separate.
enum OllieRitualPresentation {
    case inline
    case cardCompanion
    case homeCompact
    case onboardingHero
    case journeyAnimation

    var canvasSize: CGFloat {
        switch self {
        case .inline: return 96
        case .cardCompanion: return 164
        case .homeCompact: return 54
        case .onboardingHero: return 188
        case .journeyAnimation: return 112
        }
    }
}

/// Gives Wind Down one visual character state without creating a second
/// session state machine. The caller maps authoritative run state to a pose.
struct OllieRitualView: View {
    var state: OllieRitualState
    var presentation: OllieRitualPresentation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(state: OllieRitualState, presentation: OllieRitualPresentation = .inline) {
        self.state = state
        self.presentation = presentation
    }

    var body: some View {
        ZStack {
            PixelAssetImage(name: state.assetName)
                .id(state)
                .transition(transition)
        }
        .frame(width: presentation.canvasSize, height: presentation.canvasSize)
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

/// A low-key Home idle loop that gives Ollie character without turning the
/// dashboard into a constantly moving bedtime surface.
struct HomeOllieIdleView: View {
    var presentation: OllieRitualPresentation = .cardCompanion
    var accessoryItemID: String? = nil
    var isMotionEnabled = true
    @State private var actionCapabilities: [OllieCompanionAction: Bool] = [:]
    @State private var capabilityRevision = 0

    var body: some View {
        OllieCompanionAnimationView(
            schedule: animationSchedule,
            isMotionEnabled: isMotionEnabled,
            detailRevision: capabilityRevision,
            nextDetailFrameTransition: nextFrameChange(after:)
        ) { animationFrame, _ in
            OllieCompanionSpriteRenderer(
                animationFrame: animationFrame,
                accessoryItemID: renderedAccessoryItemID,
                size: presentation.canvasSize,
                actionCapabilities: $actionCapabilities,
                capabilityRevision: $capabilityRevision
            ) { motionOverlayName in
                ZStack {
                    PixelAssetImage(name: NightJourneyAssets.ollieHomeIdleFrames[0])
                    if let motionOverlayName {
                        PixelAssetImage(name: motionOverlayName)
                    } else if let legacyOverlayName = ollieNeutralAccessoryOverlayAssetName(for: renderedAccessoryItemID) {
                        PixelAssetImage(name: legacyOverlayName)
                    }
                }
            }
        }
        .frame(width: presentation.canvasSize, height: presentation.canvasSize)
        .accessibilityHidden(true)
    }

    private func nextFrameChange(after animationFrame: OllieCompanionAnimationFrame) -> TimeInterval? {
        guard actionCapabilities[animationFrame.action] == true else { return nil }
        return OllieCompanionSpriteManifest.production
            .sequence(for: animationFrame.action)?
            .nextFrameTransition(after: animationFrame.actionElapsed)
    }

    private var animationSchedule: OllieCompanionAnimationSchedule {
        #if DEBUG
        return ScreenbookOllieMotionReview.configuration?.schedule ?? .gentle
        #else
        return .gentle
        #endif
    }

    private var renderedAccessoryItemID: String? {
        #if DEBUG
        if let configuration = ScreenbookOllieMotionReview.configuration {
            return configuration.accessoryItemID(default: accessoryItemID)
        }
        return accessoryItemID
        #else
        return accessoryItemID
        #endif
    }
}

#Preview("Ritual states") {
    ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: 18) {
            ForEach(OllieRitualState.allCases) { state in
                VStack {
                    OllieRitualView(state: state, presentation: .cardCompanion)
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
    OllieRitualView(state: .endedEarly, presentation: .onboardingHero)
        .padding()
        .background(AppColors.paper)
}

#Preview("Home idle") {
    HomeOllieIdleView()
        .padding()
        .background(AppColors.activeWindDownBackground)
}
