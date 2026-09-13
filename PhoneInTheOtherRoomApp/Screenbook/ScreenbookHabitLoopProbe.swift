#if DEBUG
import Foundation

/// Explicit smoke coverage for a disposable review Simulator. All Farm, habit,
/// social, guidance, and purpose data use a unique local fixture. Actual VM
/// admission still cancels this Simulator app's local reminders; no remote
/// service, real Screen Time protection, or notification delivery is enabled.
@MainActor
enum ScreenbookHabitLoopProbe {
    static var isRequested: Bool {
        #if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenbook-habit-probe"),
              arguments.indices.contains(index + 1) else { return false }
        return arguments[index + 1] == "YES"
        #else
        return false
        #endif
    }

    static func runIfRequested() async throws -> Bool? {
        guard isRequested else { return nil }
        let preferenceKey = QuietTimeShieldingService.enabledKey
        let originalShieldingPreference = UserDefaults.standard.object(forKey: preferenceKey)
        defer {
            if let originalShieldingPreference {
                UserDefaults.standard.set(originalShieldingPreference, forKey: preferenceKey)
            } else {
                UserDefaults.standard.removeObject(forKey: preferenceKey)
            }
        }
        let cases = [
            await runCase("meaningful-personalisation", work: meaningfulPersonalisation),
            await runCase("manual-primary-cancel-retry-snapshot", work: manualPrimaryStart),
            await runCase("corrupt-plan-preserves-healthy-reflections", work: corruptPlan),
            await runCase("corrupt-reflections-preserve-healthy-plan", work: corruptReflections)
        ]
        let report = Report(
            schemaVersion: 1,
            generatedAt: Date(),
            passed: cases.allSatisfy(\.passed),
            boundary: "Explicit disposable Simulator only. Shielding is simulated; Live Activity, Watch transport, remote services, and notification delivery are disabled. Existing VM paths may cancel this Simulator app’s local reminders.",
            cases: cases
        )
        try write(report)
        return report.passed
    }

    private static func meaningfulPersonalisation() async throws -> [String] {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let model = fixture.viewModel
        let persistence = fixture.persistence
        var checks: [Check] = []
        var preferences = model.nightWatchPreferences
        preferences.morningRoutine = [.suggested(.breakfast, phase: .morning), .suggested(.stretch, phase: .morning)]
        preferences.syncLegacyFieldsFromRoutine()
        persistence.nightWatchPreferences = preferences
        model.nightWatchPreferences = preferences
        let originalFarm = model.farmState
        let originalSettlement = persistence.windDownMorningSettlementJournal
        let goalToken = try persistence.personalisationEditToken()
        checks.append(check(model.saveRitualGoal(mode: .morning, kind: .lessRushed, wording: "", token: goalToken), "goal did not save"))
        guard let plan = model.personalisation.currentPlan else { return ["missing goal plan"] }
        for offset in [2, 1] {
            let day = plan.savedAt.addingTimeInterval(-Double(offset) * 86_400)
            var note = WindDownHabitReflection(day: day, obstacle: .tooMuch, mode: .morning)
            note.experience = RitualExperienceFeedback(planID: plan.id, answer: .partly,
                recordedAt: day, timeZoneIdentifier: TimeZone.current.identifier)
            checks.append(check(model.savePersonalisationReflection(note, token: try persistence.personalisationEditToken()), "reflection did not save"))
        }
        guard let suggestion = RitualPersonalisationRules.visibleSuggestion(model.personalisation, now: plan.savedAt) else { return ["missing repeated-feedback suggestion"] }
        let reviewToken = try persistence.personalisationEditToken()
        checks.append(check(model.reviewRitualPlan(activities: [plan.activities[0]], cue: "After opening the curtains", preparation: "",
            suggestionID: suggestion.id, token: reviewToken), "reviewed change did not save"))
        checks.append(check(model.nightWatchPreferences.morningRoutine.count == 1, "activity change not projected"))
        checks.append(check(model.nightWatchPreferences.morningQuietMinutes == preferences.morningQuietMinutes, "morning duration changed"))
        checks.append(check(model.nightWatchPreferences.guardKind == preferences.guardKind, "protection choice changed"))
        checks.append(check(model.farmState == originalFarm, "personalisation changed Farm"))
        checks.append(check(persistence.windDownMorningSettlementJournal == originalSettlement, "personalisation changed settlement"))
        checks.append(check(model.personalisation.adjustments.last?.applicationPending == false, "plan projection not confirmed"))
        checks.append(check(model.personalisation.suggestions.first?.status == .accepted, "acceptance not recorded"))
        checks.append(check(model.windDownHabitReflections.entries.allSatisfy { $0.experience?.planID == plan.id }, "old feedback reattributed"))
        checks.append(check(!model.saveRitualGoal(mode: .evening, kind: .unwind, wording: "", token: goalToken), "stale goal editor accepted"))
        // Simulate interruption after the durable reviewed intention, before
        // the device preference projection. Reopening must replay it only once.
        if let oldPlan = model.personalisation.currentPlan {
            var nextPreferences = oldPlan.preferences
            nextPreferences.morningRoutine = [.suggested(.makeBed, phase: .morning)]
            nextPreferences.syncLegacyFieldsFromRoutine()
            let nextPlan = RitualPlanRevision(goal: oldPlan.goal, preferences: nextPreferences, support: oldPlan.support, now: oldPlan.savedAt)
            var pending = model.personalisation
            pending.plans.append(nextPlan)
            pending.adjustments.append(RitualReviewedAdjustment(suggestionID: nil, oldPlan: oldPlan, newPlan: nextPlan, reviewedAt: oldPlan.savedAt))
            try persistence.savePersonalisation(pending, token: persistence.personalisationEditToken())
            model.reloadPersonalisation()
            checks.append(check(model.nightWatchPreferences == nextPreferences, "interrupted reviewed plan did not replay"))
            checks.append(check(model.personalisation.adjustments.last?.wasApplied == true, "projection evidence missing"))
            let count = model.personalisation.adjustments.count
            model.reloadPersonalisation()
            checks.append(check(model.personalisation.adjustments.count == count, "projection replay duplicated adjustment"))
        }
        let guestGoal = model.personalisation.goal
        let a = UUID(), b = UUID()
        try persistence.farmSaveStore.activate(.account(a))
        model.reloadWindDownHabitState()
        checks.append(check(model.personalisation.goal == nil, "guest goal leaked to A"))
        let tokenA = try persistence.personalisationEditToken()
        checks.append(check(model.saveRitualGoal(mode: .evening, kind: .personal, wording: "Account A private goal", token: tokenA), "A goal not saved"))
        try persistence.farmSaveStore.activate(.signedOut)
        model.reloadWindDownHabitState()
        checks.append(check(model.personalisation.goal == nil, "A goal remained after sign-out"))
        try persistence.farmSaveStore.finishCredentialRemoval()
        try persistence.farmSaveStore.activate(.account(b))
        model.reloadWindDownHabitState()
        checks.append(check(model.personalisation.goal == nil, "A goal leaked to B"))
        checks.append(check(!model.saveRitualGoal(mode: .evening, kind: .unwind, wording: "", token: tokenA), "A draft saved under B"))
        try persistence.farmSaveStore.activate(.guest)
        model.reloadWindDownHabitState()
        checks.append(check(model.personalisation.goal == guestGoal, "guest goal not restored"))
        return failures(checks)
    }

    private static func manualPrimaryStart() async throws -> [String] {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let model = fixture.viewModel
        let support = WindDownHabitPlan(
            cue: "After brushing my teeth",
            preparation: "Book beside the chair",
            smallerActivity: "Read one paragraph",
            phonePlacement: .accessibleNearby,
            useSmallerVersionNextTime: true
        )
        var checks: [Check] = []
        checks.append(check(model.saveWindDownHabitPlan(support), "initial support was not saved"))
        guard let occurrence = WindDownScheduleEngine.eligibleOccurrence(
            in: model.windDownSchedule, at: fixture.now, sourceID: fixture.period.id,
            primaryExtensionMinutes: model.nightWatchPreferences.morningQuietMinutes
        ) else { return ["fixture did not expose an eligible primary occurrence"] }
        let ordinaryPlan = WindDownScheduleEngine.plan(
            for: occurrence, preferences: model.nightWatchPreferences, startedAt: fixture.now
        )
        checks.append(check(model.requestStartNightWatch(sourceID: fixture.period.id), "first preflight was not presented"))
        checks.append(check(model.pendingWindDownHabitPlan == support, "preflight did not capture chosen support"))
        checks.append(check(model.pendingNightWatchEndsAt == ordinaryPlan.protectedUntil, "preflight changed protected timing"))
        checks.append(check(model.activeRun == nil && model.useSmallerWindDownNextTime, "preflight started or consumed the smaller choice"))
        model.cancelNightWatchStart()
        checks.append(check(!model.showNightWatchStartPrompt && model.pendingWindDownStartContext == nil, "cancel left pending presentation"))
        checks.append(check(model.activeRun == nil, "cancel admitted a run"))
        checks.append(check(try fixture.persistence.loadWindDownHabitPlan().useSmallerVersionNextTime, "cancel consumed the saved smaller choice"))

        // A cancelled preflight must not keep its former activity for the retry.
        let retrySupport = WindDownHabitPlan(
            cue: support.cue, preparation: support.preparation,
            smallerActivity: "Read one sentence", phonePlacement: .accessibleNearby,
            useSmallerVersionNextTime: true
        )
        checks.append(check(model.saveWindDownHabitPlan(retrySupport), "revised support was not saved"))
        checks.append(check(model.requestStartNightWatch(sourceID: fixture.period.id), "retry preflight was not presented"))
        checks.append(check(model.pendingWindDownHabitPlan == retrySupport, "retry retained cancelled support"))
        let expected = WindDownHabitRules.planForStart(ordinaryPlan, support: retrySupport, useSmallerVersion: true)
        model.confirmNightWatchStart()
        // Primary admission stages its private sharing decision asynchronously.
        for _ in 0..<100 {
            if model.activeRun != nil || !model.nightWatchStartStatus.isEmpty { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        guard let run = model.activeRun, let snapshot = run.nightWatchPlan else {
            return failures(checks) + ["primary admission produced no run: \(model.nightWatchStartStatus)"]
        }
        checks.append(check(run.state == .running, "manual primary was not running after admission"))
        checks.append(check(snapshot == expected, "admitted snapshot changed timing or lost placement/smaller activity"))
        checks.append(check(snapshot.phonePlacement == .accessibleNearby && snapshot.usesSmallerRoutine, "admitted snapshot omitted the selected variation"))
        checks.append(check(!model.useSmallerWindDownNextTime, "successful start did not consume the next-time choice"))
        checks.append(check(!(try fixture.persistence.loadWindDownHabitPlan().useSmallerVersionNextTime), "consumption was not persisted"))
        checks.append(check(!fixture.shielding.runIDs.isEmpty, "the injected shielding spy was not used"))
        checks.append(check(!model.showNightWatchStartPrompt, "successful admission retained the preflight"))

        let laterSupport = WindDownHabitPlan(
            cue: "After dinner", smallerActivity: "Sketch one line",
            phonePlacement: .anotherRoom, useSmallerVersionNextTime: true
        )
        checks.append(check(model.saveWindDownHabitPlan(laterSupport), "later plan could not be saved during the run"))
        model.reloadWindDownHabitState()
        checks.append(check(model.activeRun?.nightWatchPlan == snapshot, "editing the later plan mutated the active snapshot"))
        checks.append(check(model.windDownHabitPlan == laterSupport && model.useSmallerWindDownNextTime, "reloading the old run consumed a newly chosen smaller version"))
        return failures(checks)
    }

    private static func corruptPlan() async throws -> [String] {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let model = fixture.viewModel
        let note = WindDownHabitReflection(day: Calendar.current.startOfDay(for: fixture.now), ease: .mixed, obstacle: .tooMuch)
        var checks = [check(model.saveWindDownHabitReflection(note), "healthy reflection seed failed")]
        let corrupt = Data("{\"cue\":false}".utf8)
        try fixture.persistence.farmSaveStore.setLocalData(corrupt, for: WindDownHabitPlan.storageKey)
        model.reloadWindDownHabitState()
        checks.append(check(model.habitPlanLoadFailed && !model.habitReflectionsLoadFailed, "plan corruption also blocked healthy reflections"))
        checks.append(check(model.windDownHabitReflection(for: fixture.now) == note, "healthy reflection was hidden by corrupt plan"))
        checks.append(check(!model.saveWindDownHabitPlan(WindDownHabitPlan(cue: "Replacement")), "save overwrote unreadable plan"))
        checks.append(check(model.habitSaveMessage != nil, "failed plan save did not expose an error"))
        var revised = note
        revised.ease = .easy
        checks.append(check(model.saveWindDownHabitReflection(revised), "healthy reflection could not be revised independently"))
        checks.append(check(fixture.persistence.farmSaveStore.localData(for: WindDownHabitPlan.storageKey) == corrupt, "unreadable plan bytes changed"))
        checks.append(check(try fixture.persistence.loadWindDownHabitReflections().entry(for: fixture.now) == revised, "revised reflection was not persisted"))
        return failures(checks)
    }

    private static func corruptReflections() async throws -> [String] {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let model = fixture.viewModel
        let support = WindDownHabitPlan(cue: "After dinner", smallerActivity: "Read one paragraph")
        var checks = [check(model.saveWindDownHabitPlan(support), "healthy support seed failed")]
        let corrupt = Data("not a reflection history".utf8)
        try fixture.persistence.farmSaveStore.setLocalData(corrupt, for: WindDownHabitReflectionHistory.storageKey)
        model.reloadWindDownHabitState()
        checks.append(check(!model.habitPlanLoadFailed && model.habitReflectionsLoadFailed, "reflection corruption also blocked healthy support"))
        checks.append(check(model.windDownHabitPlan == support, "healthy support was hidden by corrupt reflections"))
        checks.append(check(!model.saveWindDownHabitReflection(WindDownHabitReflection(day: fixture.now, ease: .easy)), "save overwrote unreadable reflections"))
        checks.append(check(model.habitSaveMessage != nil, "failed reflection save did not expose an error"))
        var revised = support
        revised.preparation = "Book beside the chair"
        checks.append(check(model.saveWindDownHabitPlan(revised), "healthy support could not be revised independently"))
        checks.append(check(fixture.persistence.farmSaveStore.localData(for: WindDownHabitReflectionHistory.storageKey) == corrupt, "unreadable reflection bytes changed"))
        checks.append(check(try fixture.persistence.loadWindDownHabitPlan() == revised, "revised support was not persisted"))
        return failures(checks)
    }

    @MainActor
    private struct Fixture {
        let now = Date()
        let suite: String
        let defaults: UserDefaults
        let directory: URL
        let persistence: PersistenceService
        let coordinator: FocusSessionCoordinator
        let shielding: ShieldingSpy
        let viewModel: FocusRunViewModel
        let period: WindDownOneTimePeriod

        init() throws {
            suite = "com.ngawangchime.countingsheep.habit-probe.\(UUID().uuidString)"
            guard let isolated = UserDefaults(suiteName: suite) else { throw ProbeError.fixtureUnavailable }
            defaults = isolated
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
            persistence = PersistenceService(defaults: isolated, farmSaveDirectory: directory)
            let bedtime = Calendar.current.dateComponents([.hour, .minute], from: now.addingTimeInterval(30 * 60))
            let wake = Calendar.current.dateComponents([.hour, .minute], from: now.addingTimeInterval(8 * 60 * 60))
            persistence.nightWatchPreferences = NightWatchPreferences(
                bedtimeHour: bedtime.hour ?? 23, bedtimeMinute: bedtime.minute ?? 0,
                wakeHour: wake.hour ?? 7, wakeMinute: wake.minute ?? 0,
                windDownMinutes: 30, morningQuietMinutes: 30,
                eveningActivity: .read, morningActivity: .openCurtains,
                guardKind: .honorTimer, isConfigured: true, automaticStartEnabled: false
            )
            period = WindDownOneTimePeriod(
                title: "Habit probe Wind Down", role: .primarySleepBookend,
                interval: DateInterval(start: now.addingTimeInterval(-60), end: now.addingTimeInterval(30 * 60))
            )
            persistence.windDownSchedule = WindDownScheduleState(oneTimePeriods: [period])
            shielding = ShieldingSpy()
            coordinator = FocusSessionCoordinator(
                persistence: persistence,
                liveActivity: FocusRunLiveActivityService(installationID: UUID(), enabled: false),
                shielding: shielding, watch: .inactiveForDeterministicCapture(),
                notificationEffectsEnabled: false
            )
            let social = NightFlockViewModel(
                featureEnabled: false,
                orientationStore: NightFlockOrientationStore(defaults: isolated),
                defaults: isolated
            )
            let fixedNow = now
            viewModel = FocusRunViewModel(
                coordinator: coordinator, persistence: persistence, nowProvider: { fixedNow },
                guidanceDismissalStore: WindDownGuidanceDismissalStore(defaults: isolated),
                guidanceDisplayStore: WindDownGuidanceDisplayStore(defaults: isolated),
                startsExternalServices: false, nightFlockViewModel: social,
                quietTimeShielding: shielding, purposeCueDefaults: isolated
            )
            viewModel.notificationPreferences.remindersEnabled = false
            viewModel.enableScreenbookStartReadiness(keepsShielding: true)
        }

        func cleanUp() {
            coordinator.resetToSetup()
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private static func runCase(_ name: String, work: () async throws -> [String]) async -> CaseResult {
        do {
            let failures = try await work()
            return CaseResult(name: name, passed: failures.isEmpty, failures: failures)
        } catch {
            return CaseResult(name: name, passed: false, failures: ["Probe threw: \(error)"])
        }
    }

    private static func check(_ passed: Bool, _ message: String) -> Check { Check(passed: passed, message: message) }
    private static func failures(_ checks: [Check]) -> [String] { checks.filter { !$0.passed }.map(\.message) }

    private static func write(_ report: Report) throws {
        let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = documents.appendingPathComponent("screenbook", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(report).write(to: directory.appendingPathComponent("habit-probe.json"), options: .atomic)
    }

    private enum ProbeError: Error { case fixtureUnavailable }
    private struct Check { let passed: Bool; let message: String }
    private struct Report: Codable {
        let schemaVersion: Int
        let generatedAt: Date
        let passed: Bool
        let boundary: String
        let cases: [CaseResult]
    }
    private struct CaseResult: Codable { let name: String; let passed: Bool; let failures: [String] }

    private final class ShieldingSpy: QuietTimeShieldingProviding {
        var runIDs: [UUID] = []
        func reconcile(for run: FocusRun?, at date: Date) -> QuietTimeShieldingOutcome {
            guard let run else { return .cleared }
            runIDs.append(run.id)
            return .scheduled
        }
        func reconcile(for occurrence: MorningQuietOccurrence, at date: Date) -> QuietTimeShieldingOutcome { .scheduled }
        func clear() {}
        func clear(occurrenceID: UUID) {}
        func scheduleAutomatic(for schedule: AutomaticWindDownSchedule, at date: Date) -> QuietTimeShieldingOutcome { .scheduled }
        func cancelAutomaticSchedule() {}
        func resetLocalState() {}
        func protectionSummary(for run: FocusRun, at date: Date) -> QuietTimeShieldProtectionSummary { .none }
        func briefAccessUseCount(for run: FocusRun) -> Int { 0 }
        func briefAccessTrackerSummary(for run: FocusRun) -> QuietTimeBriefAccessTrackerSummary { .init() }
        func briefAccessTrackerSummary(forOccurrenceID occurrenceID: UUID) -> QuietTimeBriefAccessTrackerSummary { .init() }
    }
}
#endif
