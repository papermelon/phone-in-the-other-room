#if DEBUG
import Foundation

enum WatchCaptureState: String {
    case setup
    case windDown = "wind-down"
    case overnight
    case morning
    case placement
    case complete
    case earlyEnd = "early-end"
}

@MainActor
enum WatchCaptureFixture {
    static func requestedState(arguments: [String] = CommandLine.arguments) -> WatchCaptureState? {
        guard let flagIndex = arguments.firstIndex(of: "-watch-capture-state"),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return WatchCaptureState(rawValue: arguments[flagIndex + 1])
    }

    @discardableResult
    static func applyIfRequested(to viewModel: WatchRunViewModel) -> Bool {
        guard let state = requestedState() else { return false }
        apply(state, to: viewModel)
        return true
    }

    static func apply(_ state: WatchCaptureState, to viewModel: WatchRunViewModel, now: Date = Date()) {
        viewModel.reward = nil
        viewModel.proximity = .initial
        viewModel.connectionText = "Connected to iPhone"

        switch state {
        case .setup:
            viewModel.run = nil
        case .windDown:
            viewModel.run = makeRun(
                now: now,
                bedtime: now.addingTimeInterval(42 * 60),
                wake: now.addingTimeInterval(8 * 60 * 60),
                protectedUntil: now.addingTimeInterval(8.5 * 60 * 60),
                startedAt: now.addingTimeInterval(-8 * 60),
                state: .running,
                guardKind: .nfcTag
            )
        case .overnight:
            viewModel.run = makeRun(
                now: now,
                bedtime: now.addingTimeInterval(-48 * 60),
                wake: now.addingTimeInterval(7 * 60 * 60),
                protectedUntil: now.addingTimeInterval(7.5 * 60 * 60),
                startedAt: now.addingTimeInterval(-78 * 60),
                state: .running,
                guardKind: .honorTimer
            )
        case .morning:
            viewModel.run = makeRun(
                now: now,
                bedtime: now.addingTimeInterval(-8 * 60 * 60),
                wake: now.addingTimeInterval(-8 * 60),
                protectedUntil: now.addingTimeInterval(22 * 60),
                startedAt: now.addingTimeInterval(-8.5 * 60 * 60),
                state: .running,
                guardKind: .honorTimer
            )
        case .placement:
            viewModel.run = makeRun(
                now: now,
                bedtime: now.addingTimeInterval(30 * 60),
                wake: now.addingTimeInterval(8 * 60 * 60),
                protectedUntil: now.addingTimeInterval(8.5 * 60 * 60),
                startedAt: now.addingTimeInterval(-2 * 60),
                state: .waitingForPhoneAway,
                guardKind: .watchPlacement,
                placementConfirmed: false
            )
            viewModel.connectionText = "Ready for one quick check"
        case .complete:
            var run = makeRun(
                now: now,
                bedtime: now.addingTimeInterval(-8.5 * 60 * 60),
                wake: now.addingTimeInterval(-35 * 60),
                protectedUntil: now.addingTimeInterval(-5 * 60),
                startedAt: now.addingTimeInterval(-9 * 60 * 60),
                state: .completed,
                guardKind: .honorTimer
            )
            run.endedAt = run.plannedEndAt
            run.actualDurationSeconds = run.plannedEndAt.timeIntervalSince(run.startedAt)
            run.completedSuccessfully = true
            viewModel.run = run
        case .earlyEnd:
            var run = makeRun(
                now: now,
                bedtime: now.addingTimeInterval(25 * 60),
                wake: now.addingTimeInterval(8 * 60 * 60),
                protectedUntil: now.addingTimeInterval(8.5 * 60 * 60),
                startedAt: now.addingTimeInterval(-14 * 60),
                state: .endedEarly,
                guardKind: .honorTimer
            )
            run.endedAt = now
            run.actualDurationSeconds = 14 * 60
            run.endedEarlyReason = .userEnded
            viewModel.run = run
        }
    }

    private static func makeRun(
        now: Date,
        bedtime: Date,
        wake: Date,
        protectedUntil: Date,
        startedAt: Date,
        state: FocusRunState,
        guardKind: SessionGuardKind,
        placementConfirmed: Bool = true
    ) -> FocusRun {
        let plan = NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: wake,
            protectedUntil: protectedUntil,
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        var run = FocusRun(
            plannedDurationSeconds: max(60, protectedUntil.timeIntervalSince(startedAt)),
            startedAt: startedAt,
            state: state,
            guardKind: guardKind,
            nightWatchPlan: plan
        )
        run.plannedEndAt = protectedUntil
        if placementConfirmed {
            run.placementStatus = .confirmed
            run.phoneAwayValidatedAt = min(now, bedtime)
        }
        return run
    }
}
#endif
