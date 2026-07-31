import SwiftUI

struct WatchSetupView: View {
    @EnvironmentObject private var viewModel: WatchRunViewModel

    var body: some View {
        if let run = viewModel.run {
            switch run.state {
            case .completed:
                WatchCompletionView()
            case .endedEarly:
                WatchEarlyEndView()
            case .warningPhoneTooClose:
                WatchWarningView()
            default:
                WatchRunView()
            }
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    WatchOllieIconView(mood: .waiting)
                    Text("Counting Sheep")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text(viewModel.connectionText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Join Wind Down") { viewModel.requestCurrentRun() }
                        .accessibilityHint("Checks the iPhone for an active Wind Down")
                    Button("Ping Phone") { viewModel.pingPhone() }
                        .accessibilityHint("Plays a sound on your iPhone")
                    Text("Begin Wind Down on iPhone. The iPhone keeps time, so the Watch can rest too.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 4)
            }
        }
    }
}
