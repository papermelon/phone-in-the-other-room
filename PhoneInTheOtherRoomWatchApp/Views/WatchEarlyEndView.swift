import SwiftUI

struct WatchEarlyEndView: View {
    @EnvironmentObject private var viewModel: WatchRunViewModel

    var body: some View {
        VStack(spacing: 8) {
            WatchOllieIconView(mood: .happy)
            Text("Ollie kept your spot warm")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(summary)
                .font(.caption)
            Button("Done") { viewModel.clearRunSummary() }
                .accessibilityHint("Returns to the Watch start screen")
            Button("Ping Phone") { viewModel.pingPhone() }
                .accessibilityHint("Plays a sound on your iPhone")
        }
    }

    private var summary: String {
        guard let run = viewModel.run else { return "Tonight can be a fresh start." }
        let minutes = run.isNightWatch ? run.creditedQuietMinutes : Int(run.actualDurationSeconds / 60)
        return minutes > 1 ? "\(minutes) quiet minutes still count." : "Every tuck-in is practice."
    }
}
