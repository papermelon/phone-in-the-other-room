import SwiftUI

struct WatchEarlyEndView: View {
    @EnvironmentObject private var viewModel: WatchRunViewModel

    var body: some View {
        WatchScreen { usesCompactLayout in
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    WatchOllieIconView(mood: .happy, size: usesCompactLayout ? 56 : 82)
                    VStack(alignment: .leading, spacing: 5) {
                        WatchStatusPill(title: "Ended", systemImage: "leaf.fill", tint: WatchTheme.mist)
                        Text("Ollie kept your spot warm")
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
        guard let run = viewModel.run else { return "Tonight can be a fresh start." }
        let minutes = run.isNightWatch ? run.creditedQuietMinutes : Int(run.actualDurationSeconds / 60)
        return minutes > 1 ? "\(minutes) quiet minutes are recorded." : "Every tuck-in is practice."
    }
}

#if DEBUG
#Preview("Ended early") {
    WatchEarlyEndView()
        .environmentObject(WatchRunViewModel(captureState: .earlyEnd))
}
#endif
