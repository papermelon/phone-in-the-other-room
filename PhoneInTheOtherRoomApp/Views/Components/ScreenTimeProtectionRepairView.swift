import SwiftUI
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

/// A focused repair route used from Home and Settings. It never starts a run;
/// the action that led here remains separate so repair cannot become an
/// accidental scheduled or manual start.
struct ScreenTimeProtectionRepairView: View {
    var repairsAutomaticStart = false
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showScreenTimePicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("APP PROTECTION")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(repairsAutomaticStart ? "Repair automatic Wind Down" : "Choose what can rest with your phone.")
                        .font(AppTypography.display(30))
                    Text(repairsAutomaticStart
                         ? "Check Screen Time access, review your selected apps or categories, then retry the schedule."
                         : "Counting Sheep uses only the private selection you make with Apple. It cannot see the names, and Counting Sheep stays available.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Label(viewModel.shieldingReadiness.title, systemImage: "shield.lefthalf.filled")
                            .font(AppTypography.headline)
                        Text(viewModel.shieldingReadiness.detail)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.secondaryText)
                        if viewModel.shieldingReadiness == .ready {
                            Text("Selected: \(viewModel.shieldingSelectionSummary)")
                                .font(AppTypography.caption.weight(.semibold))
                                .foregroundStyle(AppColors.grass)
                        }
                    }
                }

                Button { chooseApps() } label: {
                    Label(
                        viewModel.screenTimeAuthorization == .approved
                            ? "Choose apps or categories"
                            : "Allow Screen Time access",
                        systemImage: "apps.iphone"
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PixelPrimaryButtonStyle())

                if case .denied = viewModel.screenTimeAuthorization {
                    Button("Open Screen Time Settings", action: viewModel.openAppSettings)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .font(AppTypography.body.weight(.semibold))
                        .foregroundStyle(AppColors.grass)
                }

                if repairsAutomaticStart {
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(viewModel.automaticWindDownStatusPresentation.title)
                                .font(AppTypography.headline)
                            Text(viewModel.automaticWindDownStatusPresentation.detail)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.secondaryText)
                            Button("Retry automatic scheduling", action: viewModel.retryAutomaticWindDownScheduling)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                                .disabled(viewModel.shieldingReadiness != .ready || viewModel.isRunning)
                        }
                    }
                }

                Text(repairsAutomaticStart
                     ? "Review Screen Time access and your selection, then retry. Your next scheduled start will appear here."
                     : "When you return, review the selection here before starting your session.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("App protection")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refreshScreenTimeState() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            viewModel.refreshScreenTimeState()
        }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        .familyActivityPicker(
            headerText: "Choose apps to limit through Wind Down and Screen-Free Morning, including overnight, and during Phone Away.",
            footerText: "Counting Sheep stays available. Websites are ignored.",
            isPresented: $showScreenTimePicker,
            selection: $viewModel.bedtimeActivitySelection
        )
        .onChange(of: viewModel.bedtimeActivitySelection) { _, _ in
            viewModel.saveScreenTimeSelection(.bedtime)
            viewModel.refreshScreenTimeState()
        }
#endif
    }

    private func chooseApps() {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        Task { @MainActor in
            if viewModel.screenTimeAuthorization != .approved {
                guard await viewModel.requestScreenTimeAuthorization() else { return }
            }
            showScreenTimePicker = true
        }
#else
        viewModel.refreshScreenTimeState()
#endif
    }
}

#Preview("Protection repair") {
    NavigationStack {
        ScreenTimeProtectionRepairView()
            .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
}
