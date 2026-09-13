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

                if let feedback = viewModel.slumberPartyCheer {
                    Label(
                        feedback.presentation.message,
                        systemImage: feedback.presentation.symbol
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WatchTheme.cream)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(feedback.presentation.message)
                    .transition(.opacity)
                }

                if needsWatchPlacement {
                    Label("Continue this older setup on iPhone", systemImage: "iphone")
                        .font(.caption2)
                        .foregroundStyle(WatchTheme.mist)
                        .multilineTextAlignment(.center)
                }

                if let activity {
                    WatchDetailCard(title: activity.title, systemImage: activity.systemImage)
                        .accessibilityLabel("Suggested Wind Down idea: \(activity.title)")
                }

                if viewModel.run?.guardKind == .nfcTag {
                    Label("End with your registered tag on iPhone", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption2)
                        .foregroundStyle(WatchTheme.mist)
                        .multilineTextAlignment(.center)
                } else {
                    Button { viewModel.endRun() } label: {
                        Label("End early", systemImage: "stop.circle")
                    }
                    .buttonStyle(WatchQuietButtonStyle())
                    .accessibilityHint("Ends the \(isAdditionalQuiet ? "Phone Away" : "Wind Down") timer early")
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
        if let morning = viewModel.prioritizedScreenFreeMorning {
            switch morning.status {
            case .active: return "Timer is running"
            case .scheduled: return "Planned on iPhone"
            case .skipped: return "Skipped today"
            case .finished: return "Timer ended on iPhone"
            }
        }
        if isLegacyWarning {
            return "Continue on iPhone"
        }
        if needsWatchPlacement {
            return "Older setup"
        }
        if isAdditionalQuiet {
            return "Phone Away timer is running"
        }
        switch phase {
        case .windDown: return "Wind Down timer: evening phase"
        case .overnight: return "Wind Down timer: overnight phase"
        case .morningQuiet: return "Screen-Free Morning timer is running"
        case .complete: return "Wind Down timer ended"
        case nil: return "Wind Down timer is running"
        }
    }

    private var countdownCaption: String {
        if let morning = viewModel.prioritizedScreenFreeMorning {
            return morning.isActive ? "until Screen-Free Morning ends" : "Screen-Free Morning"
        }
        if needsWatchPlacement { return "Continue on iPhone" }
        if isLegacyWarning { return "Open Counting Sheep on iPhone" }
        if isAdditionalQuiet { return "remaining" }
        switch phase {
        case .windDown: return "until bedtime"
        case .overnight: return "until Screen-Free Morning"
        case .morningQuiet: return "until Wind Down ends"
        case .complete, nil: return "Wind Down timer ended"
        }
    }

    private var phaseTitle: String {
        if let morning = viewModel.prioritizedScreenFreeMorning {
            return morning.status == .active ? "Screen-Free Morning" : "Planned"
        }
        if isLegacyWarning { return "iPhone" }
        if needsWatchPlacement { return "Older setup" }
        if isAdditionalQuiet { return "Phone Away" }
        switch phase {
        case .windDown: return "Evening"
        case .overnight: return "Overnight"
        case .morningQuiet: return "Screen-Free Morning"
        case .complete: return "Ended"
        case nil: return "Wind Down"
        }
    }

    private var phaseSymbol: String {
        if viewModel.prioritizedScreenFreeMorning != nil { return "sunrise.fill" }
        if isLegacyWarning { return "iphone" }
        if needsWatchPlacement { return "iphone" }
        if isAdditionalQuiet { return "timer" }
        switch phase {
        case .windDown: return "moon.stars.fill"
        case .overnight: return "moon.fill"
        case .morningQuiet: return "sunrise.fill"
        case .complete: return "checkmark.seal.fill"
        case nil: return "timer"
        }
    }

    private var phaseTint: Color {
        isLegacyWarning ? WatchTheme.amber : WatchTheme.moss
    }

    private var ollieMood: OllieMood {
        if viewModel.prioritizedScreenFreeMorning?.isActive == true { return .happy }
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
        if let morning = viewModel.prioritizedScreenFreeMorning {
            return max(0, morning.endsAt.timeIntervalSince(now))
        }
        let transition = viewModel.run?.nightWatchPlan?.nextTransition(after: now)
            ?? viewModel.run?.plannedEndAt
            ?? now
        return max(0, transition.timeIntervalSince(now))
    }

    private var nextTransitionDate: Date? {
        if let morning = viewModel.prioritizedScreenFreeMorning { return morning.endsAt }
        return viewModel.run?.nightWatchPlan?.nextTransition(after: phaseReferenceDate)
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
        if let morning = viewModel.prioritizedScreenFreeMorning {
            return morning.isActive
                ? "\(minutes) minutes until Screen-Free Morning ends"
                : "Screen-Free Morning planned for \(OllieFormat.time(morning.startsAt))"
        }
        if isAdditionalQuiet {
            return "\(minutes) minutes until Phone Away ends"
        }
        let destination: String
        switch phase {
        case .windDown: destination = "bedtime"
        case .overnight: destination = "Screen-Free Morning"
        case .morningQuiet: destination = "the end of Wind Down"
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
