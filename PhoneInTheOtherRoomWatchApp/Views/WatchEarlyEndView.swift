import SwiftUI

struct WatchEarlyEndView: View {
    @EnvironmentObject private var viewModel: WatchRunViewModel

    var body: some View {
        VStack(spacing: 8) {
            WatchOllieIconView(mood: .sad)
            Text("Ollie came back early")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("\(Int((viewModel.run?.actualDurationSeconds ?? 0) / 60)) / \(Int((viewModel.run?.plannedDurationSeconds ?? 0) / 60)) min")
                .font(.caption)
        }
    }
}

