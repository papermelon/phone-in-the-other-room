import SwiftUI

struct RewardShelfView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(viewModel.coordinator.rewards) { reward in
                    RewardRevealView(reward: reward)
                }
                if viewModel.coordinator.rewards.isEmpty {
                    GamePanelView(title: "Empty shelf") {
                        Text("Ollie has not brought anything back yet.")
                            .font(.caption)
                    }
                }
            }
            .padding()
        }
        .background(OlliePalette.appBackground)
        .navigationTitle("Reward Shelf")
        .toolbarBackground(OlliePalette.appBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
