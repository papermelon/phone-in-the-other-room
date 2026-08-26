import SwiftUI

/// Uses the current storybook Ollie illustrations from iPhone so both apps feel
/// like one quiet ritual.
struct WatchOllieIconView: View {
    var mood: OllieMood
    var size: CGFloat = 92

    var body: some View {
        Image(assetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .padding(3)
            .frame(width: size, height: size)
            .background(
                RadialGradient(
                    colors: [background.opacity(0.48), background.opacity(0)],
                    center: .center,
                    startRadius: 4,
                    endRadius: size * 0.52
                )
            )
            .accessibilityHidden(true)
    }

    private var assetName: String {
        switch mood {
        case .proud: return "dog/dog_classic_proud"
        case .happy, .excited: return "dog/dog_classic_happy"
        case .alert, .sad: return "dog/dog_classic_concerned"
        case .sleepy: return "dog/dog_classic_sleeping"
        case .guarding, .running: return "dog/dog_classic_focused"
        case .waiting: return "dog/dog_classic_idle"
        }
    }

    private var background: Color {
        switch mood {
        case .proud, .happy, .excited: return WatchTheme.amber
        case .alert, .sad: return WatchTheme.amber
        default: return WatchTheme.moss
        }
    }
}

#Preview {
    ZStack {
        WatchTheme.nightBottom.ignoresSafeArea()
        WatchOllieIconView(mood: .guarding)
    }
}
