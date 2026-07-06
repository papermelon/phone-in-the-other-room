import SwiftUI

struct ActiveRunView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var showTechnicalDetails = false

    private var proximity: ProximityState { viewModel.coordinator.proximityState }
    private var runState: FocusRunState { viewModel.activeRun?.state ?? .running }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                timerHero
                // Decorative pixel scene; the proximity card below carries the same
                // information as text for VoiceOver.
                IsometricFocusYardView(
                    state: runState,
                    bucket: proximity.bucket,
                    distanceMeters: proximity.distanceMeters
                )
                .accessibilityHidden(true)
                proximityCard
                if viewModel.activeRun?.state == .warningPhoneTooClose {
                    warningBanner
                }
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            LinearGradient(
                colors: [OlliePalette.appBackground, Color(red: 0.06, green: 0.10, blue: 0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var timerHero: some View {
        GamePanelView(title: "Leave me here", prominence: .hero) {
            VStack(alignment: .leading, spacing: 10) {
                Text(headline)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                Text("Your Watch has the run.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                Text(OllieFormat.timer(viewModel.coordinator.remainingSeconds))
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel(timerAccessibilityLabel)
                    .accessibilityAddTraits(.updatesFrequently)
                Text(runState.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
    }

    private var proximityCard: some View {
        GamePanelView(title: "Ollie's patrol") {
            VStack(alignment: .leading, spacing: 14) {
                Text(friendlyProximityTitle)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                ProximityMeter(bucket: proximity.bucket)
                Text(proximity.statusText)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text(proximity.detailText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                if !viewModel.coordinator.ollieMessage.isEmpty {
                    Text(viewModel.coordinator.ollieMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OlliePalette.amber)
                }
                DisclosureGroup("Technical details", isExpanded: $showTechnicalDetails) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(technicalDistanceLine)
                        Text("Confidence: \(proximity.confidence.rawValue)")
                        Text("Source: \(proximity.source.rawValue)")
                    }
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 6)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private var warningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(OlliePalette.amber)
                .accessibilityHidden(true)
            Text(warningBannerText)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OlliePalette.amber.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OlliePalette.amber.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var warningBannerText: String {
        switch remainingWarnings {
        case 0:
            return "Your phone wandered back. Walk it out to keep the run going."
        case 1:
            return "Your phone wandered back. Ollie can let it slide once more."
        default:
            return "Your phone wandered back. Ollie can let it slide \(remainingWarnings) more times."
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        ViewThatFits {
            HStack(spacing: 12) { buttons }
            VStack(spacing: 12) { buttons }
        }
        .buttonStyle(PixelButtonStyle(tint: OlliePalette.amber))
    }

    @ViewBuilder
    private var buttons: some View {
        Button {
            viewModel.coordinator.requestDistanceCheck()
        } label: {
            Label("Check Distance", systemImage: "dot.radiowaves.left.and.right")
        }
        .accessibilityHint("Asks your Watch for a fresh distance reading")
        Button {
            viewModel.coordinator.pingPhone()
        } label: {
            Label("Whistle at Phone", systemImage: "speaker.wave.2")
        }
        .accessibilityHint("Plays a sound on your phone so you can find it")
        Button {
            viewModel.coordinator.endEarly()
        } label: {
            Label("End Run", systemImage: "xmark")
        }
        .accessibilityHint("Ends this run early")
    }

    private var headline: String {
        switch runState {
        case .placementGrace, .demo:
            return "Put your phone in the other room."
        case .warningPhoneTooClose:
            return "Phone is getting too close."
        default:
            return "Ollie is guarding your focus."
        }
    }

    private var friendlyProximityTitle: String {
        switch proximity.bucket {
        case .waitingForDistance: return "Ollie is sniffing…"
        case .withYou, .sameRoom: return "Still too close"
        case .doorway: return "Heading out"
        case .probablyOtherRoom, .demo: return "Phone is away!"
        case .signalLost: return "Trail went cold"
        case .unsupported: return "Distance unavailable"
        }
    }

    private var technicalDistanceLine: String {
        guard let distance = proximity.distanceMeters else {
            return "Distance: waiting for UWB reading"
        }
        return "Distance: \(String(format: "%.1f", distance)) m"
    }

    private var remainingWarnings: Int {
        max(0, FocusRunRules.allowedCloseWarnings - (viewModel.activeRun?.warningCount ?? 0))
    }

    private var timerAccessibilityLabel: String {
        let remainingMinutes = OllieFormat.minutes(viewModel.coordinator.remainingSeconds)
        let plannedMinutes = OllieFormat.minutes(viewModel.activeRun?.plannedDurationSeconds ?? 0)
        guard remainingMinutes > 0 else {
            return "Less than a minute remaining of \(plannedMinutes)"
        }
        return "\(remainingMinutes) minutes remaining of \(plannedMinutes)"
    }
}

private struct ProximityMeter: View {
    var bucket: ProximityBucket

    private var fillIndex: Int {
        switch bucket {
        case .withYou: return 0
        case .sameRoom, .waitingForDistance: return 1
        case .doorway: return 2
        case .probablyOtherRoom, .demo: return 3
        case .signalLost, .unsupported: return 1
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index <= fillIndex ? meterColor(for: index) : Color.white.opacity(0.12))
                    .frame(height: 10)
            }
        }
        .overlay(alignment: .bottom) {
            HStack {
                Text("Near")
                Spacer()
                Text("Away")
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.45))
            .offset(y: 18)
        }
        .padding(.bottom, 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Phone distance")
        .accessibilityValue(bucket.label)
    }

    private func meterColor(for index: Int) -> Color {
        switch index {
        case 0, 1: return OlliePalette.amber
        case 2: return OlliePalette.sky
        default: return OlliePalette.success
        }
    }
}
