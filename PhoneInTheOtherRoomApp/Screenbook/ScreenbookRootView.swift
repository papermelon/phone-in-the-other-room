#if DEBUG
import SwiftUI

struct ScreenbookRootView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
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
                if request.exportsManifest || request.kind != nil {
                    try ScreenbookCaptureReadiness.reportReady(request)
                } else {
                    try ScreenbookCaptureReadiness.reportFailure(
                        request,
                        message: "Unknown Screenbook scenario: \(request.scenarioID ?? "missing")"
                    )
                }
            } catch {
                assertionFailure("Screenbook readiness write failed: \(error)")
            }
        }
    }

    @ViewBuilder
    private func scenarioView(_ kind: ScreenbookScenarioKind) -> some View {
        switch kind {
        case .onboardingWelcome:
            OnboardingFlowView(initialDraft: onboardingDraft, presentationMode: .fixture, onComplete: {})
        case .configuredHome:
            HomeView(
                initialTab: .home,
                farmVisitSeed: 41,
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
        case .earlyEnd:
            HomeView(
                initialTab: .home,
                farmVisitSeed: 43,
                activeRunNow: ScreenbookFixtures.now(for: kind),
                dashboardWatch: viewModel.coordinator.watch,
                allowsLaunchRouting: false
            )
        case .populatedFarm:
            HomeView(
                initialTab: .farm,
                farmVisitSeed: 44,
                activeRunNow: ScreenbookFixtures.now(for: kind),
                dashboardWatch: viewModel.coordinator.watch,
                allowsLaunchRouting: false
            )
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
        exportsManifest: false
    ))
    .environmentObject(ScreenbookFixtures.makeViewModel(for: kind))
}

#Preview("Screenbook · unknown scenario") {
    ScreenbookRootView(request: ScreenbookLaunchRequest(
        scenarioID: "iphone.unknown.default",
        runID: "preview-unknown",
        exportsManifest: false
    ))
    .environmentObject(ScreenbookFixtures.makeViewModel(for: nil))
}
#endif
