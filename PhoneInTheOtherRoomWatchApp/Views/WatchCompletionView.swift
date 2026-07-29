import SwiftUI

struct WatchCompletionView: View {
    @EnvironmentObject private var viewModel: WatchRunViewModel

    var body: some View {
        VStack(spacing: 8) {
            WatchOllieIconView(mood: .proud)
            Text("You woke up before your phone did")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Ollie found")
                .font(.caption2)
            Text(viewModel.reward?.title ?? "Night Watch Letter")
                .font(.caption)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Reward: \(viewModel.reward?.title ?? "Night Watch Letter")")
            Button("Done") { viewModel.clearRunSummary() }
                .accessibilityHint("Returns to the Watch start screen")
            Button("Ping Phone") { viewModel.pingPhone() }
                .accessibilityHint("Plays a sound on your iPhone")
        }
    }
}
