import SwiftUI

struct CompletionView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        VStack(spacing: 14) {
            GamePanelView(title: "Run complete", prominence: .hero) {
                HStack {
                    OllieSpriteView(mood: .proud, size: 90)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ollie completed the run!")
                            .font(.title2.weight(.black))
                            .foregroundStyle(.white)
                        Text("You stayed away for \(Int((viewModel.activeRun?.plannedDurationSeconds ?? 0) / 60)) minutes.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.70))
                    }
                }
            }
            RewardRevealView(reward: viewModel.coordinator.latestReward)
            HStack {
                NavigationLink("View Reward Shelf") { RewardShelfView() }
                Button("Start another run") { viewModel.resetSetup() }
            }
            .buttonStyle(PixelButtonStyle(tint: OlliePalette.success))
        }
    }
}
