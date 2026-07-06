import SwiftUI

struct WatchWarningView: View {
    @EnvironmentObject private var viewModel: WatchRunViewModel
    @State private var now = Date()

    var body: some View {
        VStack(spacing: 8) {
            WatchOllieIconView(mood: .alert)
            Text("Phone nearby")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("Move it away before Ollie ends this run.")
                .font(.caption2)
                .multilineTextAlignment(.center)
            Text("\(max(0, FocusRunRules.allowedCloseWarnings - (viewModel.run?.warningCount ?? 0))) warnings left")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(OllieFormat.timer(max(0, (viewModel.run?.plannedEndAt ?? now).timeIntervalSince(now))))
                .font(.title2)
                .monospacedDigit()
            Button("Check Again") { viewModel.requestDistanceCheck() }
            Button("Ping Phone") { viewModel.pingPhone() }
            Button("End Run") { viewModel.endRun() }
                .tint(.orange)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { value in
            now = value
        }
    }
}
