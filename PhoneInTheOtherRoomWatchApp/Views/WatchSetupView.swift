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
                    Button("Join Run") { viewModel.requestCurrentRun() }
                    Button("Ping Phone") { viewModel.pingPhone() }
                    Text("Start a Focus Run on iPhone, then keep both apps open.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 4)
            }
        }
    }
}
