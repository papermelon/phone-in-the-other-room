#if DEBUG
import SwiftUI

/// Disposable Simulator only: real persistence, coordinator, Home and sheet UI;
/// a local shielding spy keeps Screen Time and all network services out of the fixture.
@MainActor
enum ScreenbookPersonalShieldProbe {
    static func fixture(phoneAway: Bool = false, overnight: Bool = false) throws -> FocusRunViewModel {
        let suite = "ollie.personal-shield-probe.\(UUID())"
        guard let defaults = UserDefaults(suiteName: suite) else { throw FarmSaveError.unavailable }
        let persistence = PersistenceService(defaults: defaults,
            farmSaveDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(suite))
        var preferences = NightWatchPreferences.defaults
        preferences.isConfigured = true
        preferences.automaticStartEnabled = false
        preferences.guardKind = .honorTimer
        preferences.eveningRoutine = [.custom("Brush my teeth", phase: .evening), .custom("Read 10 pages", phase: .evening), .custom("Set out tomorrow’s clothes", phase: .evening)]
        persistence.nightWatchPreferences = preferences
        persistence.orientationState = CountingSheepOrientationState(status: .completed)
        let shielding = ShieldingSpy(defaults: defaults)
        let coordinator = FocusSessionCoordinator(persistence: persistence,
            liveActivity: FocusRunLiveActivityService(installationID: UUID(), enabled: false),
            shielding: shielding, watch: .inactiveForDeterministicCapture(), notificationEffectsEnabled: false)
        let model = FocusRunViewModel(coordinator: coordinator, persistence: persistence,
            startsExternalServices: false,
            nightFlockViewModel: NightFlockViewModel(featureEnabled: false, defaults: defaults),
            quietTimeShielding: shielding, purposeCueDefaults: defaults)
        model.notificationPreferences.remindersEnabled = false
        model.enableScreenbookStartReadiness(keepsShielding: true)
        let now = Date()
        var plan = preferences.makePlan(startedAt: now)
        plan.intendedBedtime = now.addingTimeInterval(overnight ? -60 : 1800)
        plan.wakeTime = now.addingTimeInterval(8 * 3600)
        plan.protectedUntil = now.addingTimeInterval(8.5 * 3600)
        if phoneAway { plan = .additionalQuiet(start: now, end: now.addingTimeInterval(1800), activity: .read, cueText: nil) }
        let id = UUID()
        try model.preparePersonalShield(id: id, plan: plan, startedAt: now,
            tasks: phoneAway ? ["Finish the project outline", "Read 10 pages", "Make dinner"] : [])
        _ = coordinator.start(configuration: FocusRunConfiguration(nightWatchPlan: plan, guardKind: .honorTimer),
            focusAccepted: false, startedAt: now, autoConfirmPlacement: true,
            appShieldingRequested: true, liveActivityRequested: false, runID: id)
        model.refreshPersonalShield()
        return model
    }

    static func run() throws -> [String] {
        let model = try fixture()
        guard let defaults = model.purposeCueDefaults, let first = model.personalShieldSession,
              let spy = model.quietTimeShielding as? ShieldingSpy else { return ["fixture unavailable"] }
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) { if !condition { failures.append(message) } }
        let farm = model.farmState
        model.togglePersonalShieldStep(first.steps[0].id)
        check(model.personalShieldSession?.steps[0].checked == true, "check not saved")
        check(try model.persistence.personalShieldSessions().first(where: { $0.id == first.id })?.steps[0].checked == true, "check did not survive reload")
        check(PersonalShieldStorage.projection(from: defaults)?.session.steps[0].checked == true, "shield check not updated")
        check(model.farmState == farm, "check changed Farm")
        check(PersonalShieldStorage.request(.checklist, in: defaults, at: Date()), "route not created")
        model.consumePersonalShieldRoute()
        check(model.personalShieldSheet?.action == .checklist, "shield route did not open list")
        model.dismissPersonalShield()
        model.consumePersonalShieldRoute()
        check(model.personalShieldSheet == nil, "ordinary reopen replayed route")
        model.openPersonalShield(.briefAccess)
        if let request = model.personalShieldSheet {
            check(!model.confirmPersonalShield(request, entry: "wrong"), "wrong phrase granted access")
            check(spy.grants == 0, "grant happened before confirmation")
            spy.allowsGrant = false
            check(!model.confirmPersonalShield(request, entry: request.phrase), "failed restore granted access")
            spy.allowsGrant = true
            check(model.confirmPersonalShield(request, entry: request.phrase), "correct phrase did not grant")
            check(!model.confirmPersonalShield(request, entry: request.phrase), "access request replayed")
            check(spy.grants == 1, "access counted twice")
        } else { failures.append("access sheet missing") }
        check(!model.coordinator.endEarly(reason: .userEnded), "direct exit bypassed challenge")
        model.openPersonalShield(.endSession)
        if let request = model.personalShieldSheet {
            check(model.coordinator.emergencyExitChallenge?.canConfirm == false, "access confirmation authorized ending")
            check(!model.confirmPersonalShield(request, entry: "wrong"), "wrong phrase ended run")
            check(model.confirmPersonalShield(request, entry: request.phrase), "personal exit failed")
            check(model.activeRun?.state == .endedEarly, "coordinator did not settle exit")
            check(!model.coordinator.confirmEmergencyExit(), "exit replayed")
        } else { failures.append("exit sheet missing") }
        check(model.personalShieldSheet == nil, "terminal receipt covered by sheet")
        check(PersonalShieldStorage.projection(from: defaults) == nil, "terminal projection retained")
        model.coordinator.resetToSetup()
        let a = UUID(), b = UUID()
        try model.persistence.farmSaveStore.activate(.account(a))
        model.reloadWindDownHabitState()
        check(try model.persistence.personalShieldSessions().isEmpty, "guest tasks leaked into account A")
        try model.persistence.farmSaveStore.activate(.signedOut)
        model.reloadWindDownHabitState()
        try model.persistence.farmSaveStore.finishCredentialRemoval()
        try model.persistence.farmSaveStore.activate(.account(b))
        model.reloadWindDownHabitState()
        check(PersonalShieldStorage.projection(from: defaults) == nil, "projection crossed owner boundary")
        check(try model.persistence.personalShieldSessions().isEmpty, "tasks leaked into account B")
        let overnight = try fixture(overnight: true)
        check(overnight.coordinator.transitionToEarlyMorning(intent: .skipToday, reason: .userEnded) == nil,
            "early wake bypassed phrase")
        overnight.chooseEarlyWake(.skipToday)
        if let request = overnight.personalShieldSheet {
            check(overnight.confirmPersonalShield(request, entry: request.phrase), "early wake phrase failed")
            check(overnight.screenFreeMorningOccurrences.contains { $0.outcome == .skipped }, "early wake choice lost")
        } else { failures.append("early wake phrase sheet missing") }
        let corrupt = try fixture()
        try corrupt.persistence.farmSaveStore.setLocalData(Data("unreadable".utf8), for: PersonalShieldSession.storageKey)
        corrupt.openPersonalShield(.endSession)
        if let request = corrupt.personalShieldSheet {
            check(corrupt.confirmPersonalShield(request, entry: request.phrase), "unreadable optional list trapped exit")
        } else { failures.append("unreadable optional list trapped exit sheet") }
        let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let output = documents.appendingPathComponent("screenbook/personal-shield-probe.json")
        try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: ["passed": failures.isEmpty, "failures": failures], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output, options: .atomic)
        return failures
    }

    private final class ShieldingSpy: QuietTimeShieldingProviding {
        let defaults: UserDefaults
        var grants = 0
        var allowsGrant = true
        init(defaults: UserDefaults) { self.defaults = defaults }
        func reconcile(for run: FocusRun?, at date: Date) -> QuietTimeShieldingOutcome {
            guard let run, let snapshot = QuietTimeShieldScheduleBuilder.snapshot(for: run, revision: 1, updatedAt: date),
                  let data = try? JSONEncoder().encode(snapshot) else { return .cleared }
            defaults.set(data, forKey: QuietTimeShieldPresentationStorage.scheduleKey)
            return .applied
        }
        func reconcile(for occurrence: MorningQuietOccurrence, at date: Date) -> QuietTimeShieldingOutcome { .scheduled }
        func clear() { PersonalShieldStorage.clear(from: defaults) }
        func clear(occurrenceID: UUID) { clear() }
        func scheduleAutomatic(for schedule: AutomaticWindDownSchedule, at date: Date) -> QuietTimeShieldingOutcome { .scheduled }
        func cancelAutomaticSchedule() { clear() }
        func resetLocalState() { clear() }
        func protectionSummary(for run: FocusRun, at date: Date) -> QuietTimeShieldProtectionSummary { .none }
        func briefAccessUseCount(for run: FocusRun) -> Int { grants }
        func briefAccessTrackerSummary(for run: FocusRun) -> QuietTimeBriefAccessTrackerSummary { .init() }
        func briefAccessTrackerSummary(forOccurrenceID occurrenceID: UUID) -> QuietTimeBriefAccessTrackerSummary { .init() }
        func grantBriefAccess(for projection: PersonalShieldProjection, at date: Date) -> Bool {
            guard allowsGrant else { return false }
            grants += 1
            return true
        }
    }
}

struct ScreenbookPersonalShieldView: View {
    @State private var model: FocusRunViewModel?
    @State private var failure: String?

    var body: some View {
        Group {
            if let model { HomeView(allowsLaunchRouting: false).environmentObject(model) }
            else { Text(failure ?? "Preparing personal shield fixture…") }
        }
        .task {
            guard model == nil else { return }
            do {
                if ProcessInfo.processInfo.arguments.contains("-personal-shield-probe") { _ = try ScreenbookPersonalShieldProbe.run() }
                let fixture = try ScreenbookPersonalShieldProbe.fixture(
                    phoneAway: ProcessInfo.processInfo.arguments.contains("-personal-shield-tasks"),
                    overnight: ProcessInfo.processInfo.arguments.contains("-personal-shield-overnight"))
                model = fixture
                await Task.yield()
                if ProcessInfo.processInfo.arguments.contains("-personal-shield-complete"), let session = fixture.personalShieldSession {
                    session.steps.forEach { fixture.togglePersonalShieldStep($0.id) }
                }
                if !ProcessInfo.processInfo.arguments.contains("-personal-shield-home") {
                    fixture.openPersonalShield(ProcessInfo.processInfo.arguments.contains("-personal-shield-access") ? .briefAccess
                        : ProcessInfo.processInfo.arguments.contains("-personal-shield-end") ? .endSession : .checklist)
                }
            } catch { failure = "Personal shield fixture failed: \(error)" }
        }
    }
}
#endif
