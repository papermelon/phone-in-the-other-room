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
            OnboardingFlowView(initialDraft: welcomeDraft, onComplete: {})
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

    private var welcomeDraft: OnboardingDraft {
        var draft = OnboardingDraft.defaults()
        draft.step = .welcome
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
