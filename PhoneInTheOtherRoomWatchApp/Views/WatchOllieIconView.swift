import SwiftUI

/// Uses the same pixel Ollie illustrations as iPhone so the companion feels like
/// one product, while keeping the Watch treatment glanceable.
struct WatchOllieIconView: View {
    var mood: OllieMood

    var body: some View {
        Image(assetName)
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .scaledToFit()
            .padding(5)
            .frame(width: 70, height: 70)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.2), lineWidth: 1))
            .accessibilityHidden(true)
    }

    private var assetName: String {
        switch mood {
        case .proud: return "dog/dog_proud"
        case .happy: return "dog/dog_happy"
        case .alert, .sad: return "dog/dog_concerned"
        case .sleepy: return "dog/dog_sleeping"
        default: return "dog/dog_idle"
        }
    }

    private var background: Color {
        switch mood {
        case .proud, .happy: return Color(red: 0.15, green: 0.38, blue: 0.22)
        case .alert, .sad: return Color(red: 0.31, green: 0.25, blue: 0.12)
        default: return Color(red: 0.11, green: 0.18, blue: 0.12)
        }
    }
}
