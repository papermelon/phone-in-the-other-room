import SwiftUI

struct EarlyEndView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        VStack(spacing: 16) {
            GamePanelView(title: "Back early", prominence: .hero) {
                HStack(alignment: .top, spacing: 14) {
                    OllieSpriteView(mood: .sad, size: 96)
                        .idleBob()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ollie came back early.")
                            .font(.title2.weight(.black))
                            .foregroundStyle(.white)
                        Text("You focused for \(actual) of \(planned) minutes.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                        Text("That still counts as practice. Try a shorter run next time.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer(minLength: 0)
                }
            }
            RewardRevealView(reward: viewModel.coordinator.latestReward)
            Button("Set up another run") { viewModel.resetSetup() }
                .buttonStyle(PixelButtonStyle(tint: OlliePalette.sadBlue))
        }
    }

    private var actual: Int {
        Int((viewModel.activeRun?.actualDurationSeconds ?? 0) / 60)
    }

    private var planned: Int {
        Int((viewModel.activeRun?.plannedDurationSeconds ?? 0) / 60)
    }
}
