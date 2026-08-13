import SwiftUI

struct WatchRunView: View {
    @EnvironmentObject private var viewModel: WatchRunViewModel
    @State private var phaseReferenceDate = Date()

    var body: some View {
        WatchScreen { usesCompactLayout in
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    WatchOllieIconView(mood: ollieMood, size: usesCompactLayout ? 56 : 72)

                    VStack(alignment: .leading, spacing: 5) {
                        WatchStatusPill(
                            title: phaseTitle,
                            systemImage: phaseSymbol,
                            tint: phaseTint
                        )

                        Text(statusText)
                            .font((usesCompactLayout ? Font.caption : Font.body).weight(.semibold))
                            .foregroundStyle(WatchTheme.cream)
                            .lineLimit(3)
                            .minimumScaleFactor(0.82)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(
                    timerInterval: countdownInterval,
                    countsDown: true,
                    showsHours: true
                )
                    .font(.system(size: usesCompactLayout ? 31 : 34, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.cream)
                    .monospacedDigit()
                    .accessibilityLabel(timerAccessibilityLabel)

                Text(countdownCaption)
                    .font(.caption2)
                    .foregroundStyle(WatchTheme.mist)
                    .multilineTextAlignment(.center)

                if needsWatchPlacement {
                    Button { viewModel.requestDistanceCheck() } label: {
                        Label("Check placement", systemImage: "location.fill")
                    }
                    .buttonStyle(WatchPrimaryButtonStyle())
                    .accessibilityHint("Makes one brief Apple Watch placement check")
                }

                if let activity {
                    WatchDetailCard(title: activity.title, systemImage: activity.systemImage)
                        .accessibilityLabel("Suggested phone-free activity: \(activity.title)")
                }

                if viewModel.run?.guardKind == .nfcTag {
                    Label("End with your phone-bed tag on iPhone", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption2)
                        .foregroundStyle(WatchTheme.mist)
                        .multilineTextAlignment(.center)
                } else {
                    Button { viewModel.endRun() } label: {
                        Label("End early", systemImage: "stop.circle")
                    }
                    .buttonStyle(WatchQuietButtonStyle())
                    .accessibilityHint("Ends this Phone Break early")
                }

                Button { viewModel.pingPhone() } label: {
                    Label("Ping iPhone", systemImage: "iphone.radiowaves.left.and.right")
                }
                .buttonStyle(WatchQuietButtonStyle())
                .accessibilityHint("Plays a sound on your iPhone")
            }
        }
        .task(id: nextTransitionDate) {
            guard let nextTransitionDate else { return }
            let delay = nextTransitionDate.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled else { return }
            phaseReferenceDate = Date()
        }
    }

    private var needsWatchPlacement: Bool {
        viewModel.run?.guardKind == .watchPlacement && viewModel.run?.placementStatus == .awaitingConfirmation
    }

    private var statusText: String {
        if isLegacyWarning {
            return "Your phone wandered back"
        }
        if needsWatchPlacement {
            return "Walk the phone to its bed"
        }
        if isAdditionalQuiet {
            return "Phone Break"
        }
        switch phase {
        case .windDown: return "Let the evening get quieter"
        case .overnight: return "Your phone is tucked away"
        case .morningQuiet: return "Wake before your phone does"
        case .complete: return "Both quiet bookends are protected"
        case nil: return "Ollie is keeping watch"
        }
    }

    private var countdownCaption: String {
        if needsWatchPlacement { return viewModel.connectionText }
        if isLegacyWarning { return "Open Counting Sheep on iPhone" }
        if isAdditionalQuiet { return "remaining" }
        switch phase {
        case .windDown: return "until bedtime"
        case .overnight: return "until morning quiet"
        case .morningQuiet: return "until your phone wakes"
        case .complete, nil: return "Wind Down complete"
        }
    }

    private var phaseTitle: String {
        if isLegacyWarning { return "Nearby" }
        if needsWatchPlacement { return "Check" }
        if isAdditionalQuiet { return "Phone Break" }
        switch phase {
        case .windDown: return "Evening"
        case .overnight: return "Asleep"
        case .morningQuiet: return "Morning"
        case .complete: return "Protected"
        case nil: return "Wind Down"
        }
    }

    private var phaseSymbol: String {
        if isLegacyWarning { return "iphone.gen3.radiowaves.left.and.right" }
        if needsWatchPlacement { return "location.fill" }
        if isAdditionalQuiet { return "leaf.fill" }
        switch phase {
        case .windDown: return "moon.stars.fill"
        case .overnight: return "bed.double.fill"
        case .morningQuiet: return "sunrise.fill"
        case .complete: return "checkmark.seal.fill"
        case nil: return "moon.fill"
        }
    }

    private var phaseTint: Color {
        isLegacyWarning ? WatchTheme.amber : WatchTheme.moss
    }

    private var ollieMood: OllieMood {
        if isLegacyWarning { return .alert }
        if needsWatchPlacement { return .guarding }
        if isAdditionalQuiet { return .guarding }
        switch phase {
        case .windDown: return .guarding
        case .overnight: return .sleepy
        case .morningQuiet: return .happy
        case .complete: return .proud
        case nil: return .waiting
        }
    }

    private var isLegacyWarning: Bool {
        switch viewModel.run?.state {
        case .warningPhoneTooClose, .signalLost, .unsupported: return true
        default: return false
        }
    }

    private var phase: NightWatchPhase? {
        viewModel.run?.nightWatchPhase(at: phaseReferenceDate)
    }

    private var isAdditionalQuiet: Bool {
        viewModel.isAdditionalQuiet
    }

    private var transitionRemainingSeconds: TimeInterval {
        let now = Date()
        let transition = viewModel.run?.nightWatchPlan?.nextTransition(after: now)
            ?? viewModel.run?.plannedEndAt
            ?? now
        return max(0, transition.timeIntervalSince(now))
    }

    private var nextTransitionDate: Date? {
        viewModel.run?.nightWatchPlan?.nextTransition(after: phaseReferenceDate)
            ?? viewModel.run?.plannedEndAt
    }

    private var countdownInterval: ClosedRange<Date> {
        let now = Date()
        return now...max(now, nextTransitionDate ?? now)
    }

    private var activity: PhoneFreeActivity? {
        guard let plan = viewModel.run?.nightWatchPlan else { return nil }
        if isAdditionalQuiet {
            return nil
        }
        switch phase {
        case .windDown: return plan.eveningActivity
        case .morningQuiet: return plan.morningActivity
        case .overnight, .complete, nil: return nil
        }
    }

    private var timerAccessibilityLabel: String {
        let minutes = OllieFormat.minutes(transitionRemainingSeconds)
        if isAdditionalQuiet {
            return "\(minutes) minutes until Phone Break ends"
        }
        let destination: String
        switch phase {
        case .windDown: destination = "bedtime"
        case .overnight: destination = "the phone-free morning"
        case .morningQuiet: destination = "the phone's wake time"
        case .complete, nil: destination = "the end of Wind Down"
        }
        return "\(minutes) minutes until \(destination)"
    }
}

#if DEBUG
#Preview("Evening quiet") {
    WatchRunView()
        .environmentObject(WatchRunViewModel(captureState: .windDown))
}

#Preview("Placement") {
    WatchRunView()
        .environmentObject(WatchRunViewModel(captureState: .placement))
}
#endif
