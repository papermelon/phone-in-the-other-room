import SwiftUI

struct ActiveRunView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        VStack(spacing: 16) {
            GamePanelView(title: "Leave me here", prominence: .hero) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(headline)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.78)
                    Text("Your Watch has the run.")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(OllieFormat.timer(viewModel.coordinator.remainingSeconds))
                        .font(.system(size: 70, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(viewModel.activeRun?.state.label ?? "")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            GamePanelView(title: "Phone Status") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(distanceHeadline)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.72)
                    Text("NINearbyObject.distance")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OlliePalette.success)
                    Text(viewModel.coordinator.proximityState.statusText)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Confidence: \(viewModel.coordinator.proximityState.confidence.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                    Text(distanceStatus)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                    Text(viewModel.coordinator.proximityState.detailText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            ViewThatFits {
                HStack(spacing: 12) {
                    actionButtons
                }
                VStack(spacing: 12) {
                    actionButtons
                }
            }
            .buttonStyle(PixelButtonStyle(tint: OlliePalette.amber))
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button {
            viewModel.coordinator.pingPhone()
        } label: {
            Label("Test Ping", systemImage: "speaker.wave.2")
        }
        Button {
            viewModel.coordinator.endEarly()
        } label: {
            Label("End Run", systemImage: "xmark")
        }
    }

    private var headline: String {
        switch viewModel.activeRun?.state {
        case .placementGrace, .demo:
            return "Put your phone in the other room."
        case .warningPhoneTooClose:
            return "Phone is getting too close."
        default:
            return "Ollie is guarding your focus."
        }
    }

    private var distanceStatus: String {
        let state = viewModel.coordinator.proximityState
        let source = state.source.rawValue
        guard let distance = state.distanceMeters else {
            return "Distance: waiting for UWB reading - source \(source)"
        }
        return "Distance: \(String(format: "%.1f", distance)) m - source \(source)"
    }

    private var distanceHeadline: String {
        guard let distance = viewModel.coordinator.proximityState.distanceMeters else {
            return "Waiting for distance"
        }
        return "\(String(format: "%.1f", distance)) m"
    }
}
