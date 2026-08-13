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
            WatchScreen { usesCompactLayout in
                VStack(spacing: 7) {
                    HStack(spacing: 4) {
                        WatchOllieIconView(mood: .waiting, size: usesCompactLayout ? 56 : 78)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Counting Sheep")
                                .font((usesCompactLayout ? Font.body : Font.headline).weight(.bold))
                                .foregroundStyle(WatchTheme.cream)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                            Text("Ready when your iPhone is")
                                .font(.caption2)
                                .foregroundStyle(WatchTheme.mist)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    WatchStatusPill(
                        title: connectionStatus.title,
                        systemImage: connectionStatus.systemImage,
                        tint: connectionStatus.tint
                    )

                    Button { viewModel.requestCurrentRun() } label: {
                        Label("Check iPhone", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(WatchPrimaryButtonStyle())
                    .accessibilityHint("Checks the iPhone for an active Wind Down or Phone Away")

                    Button { viewModel.pingPhone() } label: {
                        Label("Ping iPhone", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .buttonStyle(WatchQuietButtonStyle())
                        .accessibilityHint("Plays a sound on your iPhone")

                    Text("Start Wind Down or Phone Away on iPhone. Ollie will meet you here.")
                        .font(.caption2)
                        .foregroundStyle(WatchTheme.mist)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var connectionStatus: (title: String, systemImage: String, tint: Color) {
        let status = viewModel.connectionText.lowercased()
        if status.contains("connected") || status.contains("heard") {
            return ("iPhone connected", "checkmark.circle.fill", WatchTheme.moss)
        }
        if status.contains("not reachable") || status.contains("open the iphone") {
            return ("iPhone out of reach", "iphone.slash", WatchTheme.amber)
        }
        return ("Checking for iPhone", "wave.3.right", WatchTheme.mist)
    }
}

#if DEBUG
#Preview("Ready") {
    WatchSetupView()
        .environmentObject(WatchRunViewModel(captureState: .setup))
}
#endif
