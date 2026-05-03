import SwiftUI

struct WatchRunView: View {
    @EnvironmentObject private var viewModel: WatchRunViewModel
    @State private var now = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 7) {
                WatchOllieIconView(mood: viewModel.run?.state.ollieMood ?? .guarding)
                Text("Ollie Running")
                    .font(.headline)
                Text(OllieFormat.timer(max(0, (viewModel.run?.plannedEndAt ?? now).timeIntervalSince(now))))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .monospacedDigit()
                VStack(spacing: 2) {
                    Text(distanceHeadline)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text("NINearbyObject.distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(viewModel.proximity.bucket == .demo ? "Phone away" : viewModel.proximity.statusText)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("\(viewModel.proximity.confidence.rawValue.capitalized) confidence")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Ping Phone") { viewModel.pingPhone() }
                Button("End Run") { viewModel.endRun() }
                    .tint(.orange)
            }
            .padding(.vertical, 4)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { value in
            now = value
        }
    }

    private var distanceHeadline: String {
        guard let distance = viewModel.proximity.distanceMeters else {
            return "Waiting"
        }
        return "\(String(format: "%.1f", distance)) m"
    }
}
