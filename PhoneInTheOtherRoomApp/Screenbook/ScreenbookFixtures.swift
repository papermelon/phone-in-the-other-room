#if DEBUG
import Foundation

@MainActor
enum ScreenbookFixtures {
    static let suiteName = "com.ngawangchime.countingsheep.screenbook-fixtures"
    static let timeZone = TimeZone(identifier: "Asia/Singapore") ?? .gmt

    static func now(for kind: ScreenbookScenarioKind?) -> Date {
        switch kind {
        case .activeWindDown: return date(hour: 22, minute: 15)
        case .earlyEnd: return date(hour: 22, minute: 20)
        case .configuredHome: return date(hour: 22, minute: 40)
        default: return date(hour: 20, minute: 0)
        }
    }

    static func makeViewModel(for kind: ScreenbookScenarioKind?) -> FocusRunViewModel {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Could not create the isolated Screenbook defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        let persistence = PersistenceService(defaults: defaults)
        let fixedNow = now(for: kind)

        if kind != .onboardingWelcome {
            persistence.nightWatchPreferences = configuredPreferences
            persistence.offlinePurpose = OfflinePurposeProfile(category: .read)
            persistence.orientationState = CountingSheepOrientationState(status: .completed)
            persistence.progress = progress
            persistence.sheepSearchState = searchState
            persistence.farmState = farmState
        }

        let liveActivity = FocusRunLiveActivityService(
            installationID: uuid(990),
            enabled: true
        )
        let coordinator = FocusSessionCoordinator(
            persistence: persistence,
            liveActivity: liveActivity,
            watch: .inactiveForDeterministicCapture()
        )
        let viewModel = FocusRunViewModel(
            coordinator: coordinator,
            persistence: persistence,
            nowProvider: { fixedNow },
            startsExternalServices: false
        )

        switch kind {
        case .activeWindDown:
            coordinator.run = activeRun(state: .running, endedAt: nil)
        case .earlyEnd:
            var run = activeRun(state: .endedEarly, endedAt: fixedNow)
            run.actualDurationSeconds = 20 * 60
            run.completedSuccessfully = false
            run.endedEarlyReason = .userEnded
            coordinator.run = run
        default:
            break
        }
        return viewModel
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_SG")
        calendar.timeZone = timeZone
        return calendar
    }

    private static var configuredPreferences: NightWatchPreferences {
        NightWatchPreferences(
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            guardKind: .honorTimer,
            isConfigured: true,
            automaticStartEnabled: false
        )
    }

    private static var progress: UserProgress {
        UserProgress(
            totalCompletedRuns: 8,
            totalFocusMinutes: 465,
            currentStreak: 3,
            longestStreak: 5,
            rewardsCollected: 8,
            ollieLevel: 3,
            dailyFocusRecords: [
                DailyFocusRecord(day: date(day: 10, hour: 7), completedFocusMinutes: 60, successfulRuns: 1, rewardsEarned: 1, calendar: calendar),
                DailyFocusRecord(day: date(day: 9, hour: 7), completedFocusMinutes: 55, successfulRuns: 1, rewardsEarned: 1, calendar: calendar)
            ],
            sheepBalance: 6,
            totalSheepEarned: 6
        )
    }

    private static var searchState: SheepSearchState {
        var state = SheepSearchState.empty
        for (index, definition) in SheepCatalog.all.prefix(6).enumerated() {
            state.append(SheepSearchOutcome(
                id: uuid(index + 1),
                runID: uuid(index + 101),
                protectedNightNumber: index + 1,
                result: .found,
                sheepID: definition.id,
                rarity: definition.rarity,
                habitat: definition.habitat,
                trailStrength: 62 + index,
                encounterOdds: index < 3 ? 1 : 0.62,
                trailDistance: Double(index + 3),
                consecutiveNoFinds: 0,
                bonusPoints: 0,
                createdAt: date(day: 4 + index, hour: 7)
            ))
        }
        state.trailMap.credit(runID: uuid(900), minutes: 30)
        return state
    }

    private static var farmState: FarmState {
        var state = FarmMigration.migrated(existing: nil, searchState: searchState)
        state.woolBalance = 34
        if !state.sheep.isEmpty { state.sheep[0].isFavorite = true }
        if state.sheep.count > 1 { state.sheep[1].lastShearedProtectedNight = 5 }
        state.ownedShopItemIDs = ["farm_lanterns", "ollie_moss_bandana"]
        // Equipped pasture decorations can briefly inherit TabView's pre-layout geometry.
        // Keep the capture fixed while still representing an owned Farm cosmetic.
        state.equipment.ollieAccessoryItemID = "ollie_moss_bandana"
        return state
    }

    private static func activeRun(state: FocusRunState, endedAt: Date?) -> FocusRun {
        let start = date(hour: 22, minute: 0)
        let bedtime = date(hour: 23, minute: 0)
        let wake = date(day: 12, hour: 7, minute: 0)
        let protectedUntil = date(day: 12, hour: 7, minute: 30)
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
            id: uuid(700),
            plannedDurationSeconds: protectedUntil.timeIntervalSince(start),
            startedAt: start,
            state: state,
            guardKind: .honorTimer,
            nightWatchPlan: plan,
            appShieldingRequested: false,
            liveActivityRequested: false
        )
        run.phoneAwayValidatedAt = start
        run.endedAt = endedAt
        return run
    }

    private static func date(day: Int = 11, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: 2026,
            month: 8,
            day: day,
            hour: hour,
            minute: minute
        )) ?? Date(timeIntervalSince1970: 1_786_464_000)
    }

    private static func uuid(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))
            ?? UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    }
}
#endif
