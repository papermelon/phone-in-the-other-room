#if DEBUG
import Foundation

@MainActor
enum WatchPhysicalQAFixture {
    private static let launchArgument = "-watch-physical-qa"
    private static let suiteName = "com.ngawangchime.countingsheep.watch-physical-qa"

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static func makeViewModel(now: Date = Date()) -> FocusRunViewModel {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Could not create the isolated Watch QA defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        let persistence = PersistenceService(defaults: defaults)
        persistence.orientationState = CountingSheepOrientationState(status: .completed)

        let coordinator = FocusSessionCoordinator(
            persistence: persistence,
            liveActivity: FocusRunLiveActivityService(
                installationID: UUID(uuidString: "00000000-0000-0000-0000-000000000901") ?? UUID(),
                enabled: false
            )
        )
        let viewModel = FocusRunViewModel(
            coordinator: coordinator,
            persistence: persistence,
            nowProvider: { now },
            startsExternalServices: false
        )

        let bedtime = now.addingTimeInterval(30 * 60)
        let wakeTime = now.addingTimeInterval(8 * 60 * 60)
        let plan = NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: wakeTime,
            protectedUntil: wakeTime.addingTimeInterval(30 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        Task { @MainActor in
            // Give the paired Watch a moment to activate its connectivity session.
            try? await Task.sleep(for: .seconds(2))
            coordinator.start(
                configuration: FocusRunConfiguration(
                    nightWatchPlan: plan,
                    guardKind: .honorTimer
                ),
                focusAccepted: false,
                startedAt: now,
                appShieldingRequested: false,
                liveActivityRequested: false
            )
        }
        return viewModel
    }
}
#endif
