import SwiftUI

struct WatchRunView: View {
    @EnvironmentObject private var viewModel: WatchRunViewModel
    @State private var phaseReferenceDate = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                WatchOllieIconView(mood: .guarding)
                Text(phase?.title ?? "Ollie is on watch")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(
                    timerInterval: countdownInterval,
                    countsDown: true,
                    showsHours: true
                )
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .accessibilityLabel(timerAccessibilityLabel)
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let activity {
                    Label(activity.shortTitle, systemImage: activity.systemImage)
                        .font(.caption2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Suggested phone-free activity: \(activity.title)")
                }

                if needsWatchPlacement {
                    Button("Check placement") { viewModel.requestDistanceCheck() }
                        .accessibilityHint("Makes one brief Apple Watch placement check")
                }
                Button("Ping Phone") { viewModel.pingPhone() }
                    .accessibilityHint("Plays a sound on your iPhone")
                if viewModel.run?.guardKind == .nfcTag {
                    Text("To end, open Counting Sheep on iPhone and tap your phone-bed tag.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Button("End Wind Down") { viewModel.endRun() }
                        .tint(.orange)
                        .accessibilityHint("Ends this Wind Down early")
                }
            }
            .padding(.vertical, 4)
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
        if needsWatchPlacement {
            return "A quick check helps Ollie see the phone tuck in. After that, your iPhone keeps time."
        }
        switch phase {
        case .windDown: return "Let the evening get quieter. Your iPhone keeps time."
        case .overnight: return "The phone is tucked away. There is nothing else to do."
        case .morningQuiet: return "Wake up before your phone does."
        case .complete: return "Both phone-free windows are protected."
        case nil: return "Your iPhone keeps time."
        }
    }

    private var phase: NightWatchPhase? {
        viewModel.run?.nightWatchPhase(at: phaseReferenceDate)
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
        switch phase {
        case .windDown: return plan.eveningActivity
        case .morningQuiet: return plan.morningActivity
        case .overnight, .complete, nil: return nil
        }
    }

    private var timerAccessibilityLabel: String {
        let minutes = OllieFormat.minutes(transitionRemainingSeconds)
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
