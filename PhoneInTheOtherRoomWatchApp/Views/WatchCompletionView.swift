import SwiftUI

struct WatchCompletionView: View {
    @EnvironmentObject private var viewModel: WatchRunViewModel

    var body: some View {
        VStack(spacing: 8) {
            WatchOllieIconView(mood: .proud)
            Text("Run complete!")
                .font(.headline)
            Text("Ollie found:")
                .font(.caption2)
            Text(viewModel.reward?.title ?? "Focus Letter")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
    }
}

