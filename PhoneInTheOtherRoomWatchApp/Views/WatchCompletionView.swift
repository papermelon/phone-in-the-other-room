import SwiftUI

struct WatchCompletionView: View {
    @EnvironmentObject private var viewModel: WatchRunViewModel

    var body: some View {
        WatchScreen { usesCompactLayout in
            VStack(spacing: 5) {
                HStack(spacing: 4) {
                    WatchOllieIconView(mood: .proud, size: usesCompactLayout ? 56 : 72)
                    VStack(alignment: .leading, spacing: 5) {
                        WatchStatusPill(
                            title: "Ended",
                            systemImage: "checkmark.circle.fill"
                        )
                        Text(presentation?.headline ?? "The timer ended")
                            .font((usesCompactLayout ? Font.caption : Font.body).weight(.semibold))
                            .foregroundStyle(WatchTheme.cream)
                            .lineLimit(3)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(completionSummary)
                    .font(.caption2)
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

    private var completionSummary: String {
        presentation?.timerSummary ?? "The elapsed timer record is on iPhone."
    }

    private var presentation: RunTerminalPresentation? {
        guard let run = viewModel.run else { return nil }
        return RunTerminalPresentation(run: run)
    }
}

#if DEBUG
#Preview("Complete") {
    WatchCompletionView()
        .environmentObject(WatchRunViewModel(captureState: .complete))
}
#endif
