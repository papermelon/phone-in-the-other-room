import SwiftUI

struct WatchEarlyEndView: View {
    @EnvironmentObject private var viewModel: WatchRunViewModel

    var body: some View {
        WatchScreen { usesCompactLayout in
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    WatchOllieIconView(mood: .happy, size: usesCompactLayout ? 56 : 82)
                    VStack(alignment: .leading, spacing: 5) {
                        WatchStatusPill(title: "Ended early", systemImage: "timer", tint: WatchTheme.mist)
                        Text(presentation?.headline ?? "The timer ended early")
                            .font((usesCompactLayout ? Font.caption : Font.body).weight(.semibold))
                            .foregroundStyle(WatchTheme.cream)
                            .lineLimit(3)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(WatchTheme.mist)
                    .multilineTextAlignment(.center)
                Button { viewModel.clearRunSummary() } label: {
                    Text("Done")
                }
                .buttonStyle(WatchPrimaryButtonStyle())
                .accessibilityHint("Returns to the Watch start screen")
            }
        }
    }

    private var summary: String {
        presentation?.timerSummary ?? "The elapsed timer record is on iPhone."
    }

    private var presentation: RunTerminalPresentation? {
        guard let run = viewModel.run else { return nil }
        return RunTerminalPresentation(run: run)
    }
}

#if DEBUG
#Preview("Ended early") {
    WatchEarlyEndView()
        .environmentObject(WatchRunViewModel(captureState: .earlyEnd))
}
#endif
