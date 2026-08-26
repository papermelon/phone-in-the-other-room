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
                            title: viewModel.isAdditionalQuiet ? "Complete" : "Protected",
                            systemImage: "checkmark.seal.fill"
                        )
                        Text(viewModel.isAdditionalQuiet ? "Phone Away is complete" : "Your phone slept in the other room")
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

                if !viewModel.isAdditionalQuiet {
                    Text("Your Search Journal is waiting on iPhone.")
                        .font(.caption2)
                        .foregroundStyle(WatchTheme.mist)
                        .multilineTextAlignment(.center)
                }

                Button { viewModel.clearRunSummary() } label: {
                    Text("Done")
                }
                .buttonStyle(WatchPrimaryButtonStyle())
                .accessibilityHint("Returns to the Watch start screen")
            }
        }
    }

    private var completionSummary: String {
        let minutes = viewModel.run?.creditedQuietMinutes ?? 0
        return minutes == 1 ? "1 quiet minute recorded" : "\(minutes) quiet minutes recorded"
    }
}

#if DEBUG
#Preview("Complete") {
    WatchCompletionView()
        .environmentObject(WatchRunViewModel(captureState: .complete))
}
#endif
