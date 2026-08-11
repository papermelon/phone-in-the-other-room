import SwiftUI

struct WatchCompletionView: View {
    @EnvironmentObject private var viewModel: WatchRunViewModel

    var body: some View {
        VStack(spacing: 8) {
            WatchOllieIconView(mood: .proud)
            if viewModel.isAdditionalQuiet {
                Text("Quiet time complete")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Your quiet minutes are recorded.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            } else {
                Text("You woke up before your phone did")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Ollie found")
                    .font(.caption2)
                Text(viewModel.reward?.title ?? "Wind Down Letter")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Reward: \(viewModel.reward?.title ?? "Wind Down Letter")")
            }
            Button("Done") { viewModel.clearRunSummary() }
                .accessibilityHint("Returns to the Watch start screen")
            Button("Ping Phone") { viewModel.pingPhone() }
                .accessibilityHint("Plays a sound on your iPhone")
        }
    }
}
