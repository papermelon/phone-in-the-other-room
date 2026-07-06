import SwiftUI

struct EarlyEndView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        VStack(spacing: 16) {
            GamePanelView(title: "Back early", prominence: .hero) {
                HStack(alignment: .top, spacing: 14) {
                    // A sad Ollie reads as punishment; early ends get a warm welcome
                    // (product principle: no shame states).
                    OllieSpriteView(mood: .happy, size: 96)
                        .idleBob()
                        .accessibilityLabel("Ollie, happy to see you")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome back. Ollie kept your spot warm.")
                            .font(.title2.weight(.black))
                            .foregroundStyle(.white)
                        Text(minutesAwayText)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                        Text("Coming back early is okay. Every minute away counts.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer(minLength: 0)
                }
            }
            RewardRevealView(reward: viewModel.coordinator.latestReward)
            Button("Start fresh when you're ready") { viewModel.resetSetup() }
                .buttonStyle(PixelButtonStyle(tint: OlliePalette.sadBlue))
                .accessibilityHint("Sets up a new run")
        }
    }

    private var actual: Int {
        Int((viewModel.activeRun?.actualDurationSeconds ?? 0) / 60)
    }

    private var minutesAwayText: String {
        switch actual {
        case 0: return "Your phone got a little time away."
        case 1: return "Your phone was away for a minute."
        default: return "Your phone was away for \(actual) minutes."
        }
    }
}
