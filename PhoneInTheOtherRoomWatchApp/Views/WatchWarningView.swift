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
            Text("Move away to keep Ollie running")
                .font(.caption2)
                .multilineTextAlignment(.center)
            Text(OllieFormat.timer(max(0, (viewModel.run?.plannedEndAt ?? now).timeIntervalSince(now))))
                .font(.title2)
                .monospacedDigit()
            Button("Ping Phone") { viewModel.pingPhone() }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { value in
            now = value
        }
    }
}

