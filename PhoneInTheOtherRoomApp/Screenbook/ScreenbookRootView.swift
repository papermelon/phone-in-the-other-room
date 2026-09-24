#if DEBUG
import SwiftUI
import ActivityKit

struct ScreenbookRootView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dynamicTypeSize) private var preferredTextSize
    @State private var didReportReadiness = false
    let request: ScreenbookLaunchRequest

    var body: some View {
        Group {
            if request.exportsManifest {
                registryExportSurface
            } else if let kind = request.kind {
                scenarioView(kind)
            } else {
                errorSurface
            }
        }
        .environment(\.dynamicTypeSize, ProcessInfo.processInfo.arguments.contains("-screenbook-habit-accessibility") ? .accessibility3 : preferredTextSize)
        .environment(\.locale, Locale(identifier: "en_SG"))
        .environment(\.calendar, ScreenbookFixtures.calendar)
        .environment(\.timeZone, ScreenbookFixtures.timeZone)
        .transaction { transaction in
            transaction.animation = nil
        }
        .task {
            guard !didReportReadiness else { return }
            didReportReadiness = true
            await Task.yield()
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(350))
            do {
                if ProcessInfo.processInfo.arguments.contains("-screenbook-live-activity") {
                    try startLiveActivityDisplayProbe()
                }
                if let habitPassed = try await ScreenbookHabitLoopProbe.runIfRequested(), !habitPassed {
                    try ScreenbookCaptureReadiness.reportFailure(request, message: "Habit probe failed; inspect Documents/screenbook/habit-probe.json")
                } else if let probePassed = try ScreenbookRecoveryProbe.runIfRequested(), !probePassed {
                    try ScreenbookCaptureReadiness.reportFailure(
                        request,
                        message: "Recovery probe failed; inspect Documents/screenbook/recovery-probe.json"
                    )
                } else if request.exportsManifest || request.kind != nil || request.runsRecoveryProbe {
                    try ScreenbookCaptureReadiness.reportReady(request)
                } else {
                    try ScreenbookCaptureReadiness.reportFailure(
                        request,
                        message: "Unknown Screenbook scenario: \(request.scenarioID ?? "missing")"
                    )
                }
            } catch {
                do {
                    try ScreenbookCaptureReadiness.reportFailure(
                        request,
                        message: "Recovery probe/readiness error: \(error.localizedDescription)"
                    )
                } catch {
                    assertionFailure("Screenbook readiness write failed: \(error)")
                }
            }
        }
    }

    /// An isolated, local-only system-rendering probe. No session, Farm or
    /// shielding state is created, and no APNs token is requested.
    private func startLiveActivityDisplayProbe() throws {
        let now = Date()
        let state = FocusRunLiveActivityAttributes.ContentState(
            plannedEndAt: now.addingTimeInterval(600), isComplete: false, phase: .windDown,
            bedtimeAt: now.addingTimeInterval(45), wakeAt: now.addingTimeInterval(600),
            morningQuietEndsAt: now.addingTimeInterval(900),
            eveningRoutineTitles: [PhoneFreeActivity.sleepwear, .brushTeeth, .relaxation].map(\.title)
        )
        _ = try Activity.request(
            attributes: FocusRunLiveActivityAttributes(runID: UUID(), plannedDurationSeconds: 600),
            content: ActivityContent(state: state, staleDate: state.nextContentRefreshDate(at: now)),
            pushType: nil
        )
    }

    @ViewBuilder
    private func scenarioView(_ kind: ScreenbookScenarioKind) -> some View {
        switch kind {
        case .onboardingWelcome:
            OnboardingFlowView(initialDraft: onboardingDraft, presentationMode: .fixture, onComplete: {})
        case .configuredHome:
            if ProcessInfo.processInfo.arguments.contains("-screenbook-personal-shield") {
                ScreenbookPersonalShieldView()
            } else if ProcessInfo.processInfo.arguments.contains("-screenbook-goal-picker") {
                NavigationStack { RitualPersonalisationView() }
            } else if ProcessInfo.processInfo.arguments.contains("-screenbook-personalisation") {
                ScreenbookPersonalisationView()
            } else if ProcessInfo.processInfo.arguments.contains("-screenbook-habit-plan") {
                NavigationStack { FocusRunSetupView(initialHabitFocus: .access) }
            } else if ProcessInfo.processInfo.arguments.contains("-screenbook-habit-reflection") {
                NavigationStack { ScrollView { WindDownHabitReflectionCard(day: ScreenbookFixtures.now(for: kind)).padding(AppSpacing.md) } }
            } else if ProcessInfo.processInfo.arguments.contains("-screenbook-protection-repair") {
                NavigationStack { ScreenTimeProtectionRepairView(repairsAutomaticStart: true) }
            } else if ProcessInfo.processInfo.arguments.contains("-screenbook-slumber-entry") {
                NavigationStack { NightFlockHubView(viewModel: viewModel.nightFlockViewModel) }
            } else if ProcessInfo.processInfo.arguments.contains("-screenbook-account") {
                AccountScreenbookView(model: viewModel.farmBackupViewModel, account: viewModel.nightFlockViewModel)
            } else {
                HomeView(
                    initialTab: .home,
                    farmVisitSeed: 41,
                    activeRunNow: ScreenbookFixtures.now(for: kind),
                    dashboardWatch: viewModel.coordinator.watch,
                    allowsLaunchRouting: false
                )
            }
        case .interactiveHome:
            HomeView(
                initialTab: .home,
                farmVisitSeed: 46,
                activeRunNow: ScreenbookFixtures.now(for: kind),
                dashboardWatch: viewModel.coordinator.watch,
                allowsLaunchRouting: false
            )
        case .activeWindDown:
            HomeView(
                initialTab: .home,
                farmVisitSeed: 42,
                activeRunNow: ScreenbookFixtures.now(for: kind),
                dashboardWatch: viewModel.coordinator.watch,
                allowsLaunchRouting: false
            )
        case .activePhoneAway:
            HomeView(
                initialTab: .home,
                farmVisitSeed: 45,
                activeRunNow: ScreenbookFixtures.now(for: kind),
                dashboardWatch: viewModel.coordinator.watch,
                allowsLaunchRouting: false
            )
        case .slumberPartyNoRound, .slumberPartyBetweenRounds:
            slumberPartyHomeScenario
        case .slumberPartySharedHabitsSummary, .slumberPartySharedHabitsConsent:
            if let summary = viewModel.nightFlockViewModel.v4ListState?.parties.first {
                NavigationStack {
                    SlumberPartyV4PartyDetailView(
                        viewModel: viewModel.nightFlockViewModel,
                        summary: summary
                    )
                }
            } else {
                Text("Shared habit fixture unavailable")
            }
        case .earlyEnd:
            HomeView(
                initialTab: .home,
                farmVisitSeed: 43,
                activeRunNow: ScreenbookFixtures.now(for: kind),
                dashboardWatch: viewModel.coordinator.watch,
                allowsLaunchRouting: false
            )
        case .populatedFarm:
            if ProcessInfo.processInfo.arguments.contains("-screenbook-search-trail") {
                ScrollView {
                    CumulativeFarmProgressCard(credit: CumulativeFarmCredit(
                        windDownSeconds: 256 * 60, phoneAwaySeconds: 300,
                        bedtimeBonus: BedtimeSearchBonus(remainingSearchSeconds: 5040)),
                        initiallyExpanded: ProcessInfo.processInfo.arguments.contains("-search-trail-expanded"))
                        .padding(AppSpacing.md)
                }.background(AppColors.background)
            } else {
                HomeView(
                    initialTab: .farm,
                    farmVisitSeed: 44,
                    activeRunNow: ScreenbookFixtures.now(for: kind),
                    dashboardWatch: viewModel.coordinator.watch,
                    allowsLaunchRouting: false
                )
            }
        }
    }

    /// These fixtures exercise Home's production social component directly.
    /// A full unscrolled Home capture can hide the card below the fold and
    /// make distinct round states produce the same screenshot.
    private var slumberPartyHomeScenario: some View {
        ZStack {
            AppColors.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if ProcessInfo.processInfo.arguments.contains("-screenbook-home-controls") {
                        AutomaticWindDownCard()
                        CampfireHomeEntry(social: viewModel.nightFlockViewModel)
                    }
                    Text("HOME · SLUMBER PARTY")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.muted)
                    SlumberPartyHomeSection(
                        viewModel: viewModel.nightFlockViewModel,
                        openParty: { _ in }
                    )
                }
                .padding(AppSpacing.md)
            }
        }
    }

    /// Keeps visual refinement states inside the existing fixture route. These
    /// launch-only variants never affect first-run persistence or page routing.
    private var onboardingDraft: OnboardingDraft {
        var draft = OnboardingDraft.defaults()
        switch ProcessInfo.processInfo.screenbookOnboardingState {
        case "welcome-ollie":
            draft.step = .welcome
            draft.welcomePage = .ollie
        case "question-five":
            draft.step = .profile
            draft.profileQuestionIndex = 4
        case "recommendation":
            draft.step = .recommendation
            draft.profileAnswers.mainFriction = .irregularDays
            draft.profileAnswers.overnightLocation = .inBed
        case "gift":
            draft.step = .gift
            draft.selectedWelcomeGiftItemID = "shepherd_moon_coat"
        case "schedule":
            draft.step = .schedule
            draft.remindersEnabled = false
        case "routine":
            draft.step = .quiet
            draft.eveningRoutine = [
                .suggested(.journal, phase: .evening),
                .suggested(.read, phase: .evening)
            ]
            draft.morningRoutine = [.suggested(.openCurtains, phase: .morning)]
        default:
            draft.step = .welcome
        }
        return draft
    }

    private var registryExportSurface: some View {
        ZStack {
            AppColors.paper.ignoresSafeArea()
            VStack(spacing: AppSpacing.sm) {
                ProgressView()
                Text("Preparing the local Screenbook")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private var errorSurface: some View {
        ZStack {
            AppColors.paper.ignoresSafeArea()
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("SCREENBOOK FIXTURE ERROR")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("Unknown scenario")
                        .font(AppTypography.title)
                    Text(request.scenarioID ?? "No scenario identifier was supplied.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            .padding(AppSpacing.lg)
        }
    }
}

private extension ProcessInfo {
    var screenbookOnboardingState: String? {
        guard let index = arguments.firstIndex(of: "-screenbook-onboarding-state"),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

#Preview("Screenbook · welcome") {
    let kind = ScreenbookScenarioKind.onboardingWelcome
    ScreenbookRootView(request: ScreenbookLaunchRequest(
        scenarioID: kind.rawValue,
        runID: "preview-welcome",
        exportsManifest: false,
        runsRecoveryProbe: false
    ))
    .environmentObject(ScreenbookFixtures.makeViewModel(for: kind))
}

#Preview("Screenbook · unknown scenario") {
    ScreenbookRootView(request: ScreenbookLaunchRequest(
        scenarioID: "iphone.unknown.default",
        runID: "preview-unknown",
        exportsManifest: false,
        runsRecoveryProbe: false
    ))
    .environmentObject(ScreenbookFixtures.makeViewModel(for: nil))
}
#endif
