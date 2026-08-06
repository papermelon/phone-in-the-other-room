import SwiftUI

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct SettingsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var showImpactConsent = false
    @State private var showImpactDeletion = false
    @State private var showLocalProgressReset = false
    @State private var showReplaySetup = false
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    @State private var showScreenTimePicker = false
#endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                windDownSection
                guidanceSection
                connectionsSection
                dataAndPrivacySection
                helpSection
                aboutSection
#if DEBUG
                if internalPreviewsEnabled {
                    internalPreviewsSection
                }
#endif
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .sheet(isPresented: $showImpactConsent) {
            ImpactSharingConsentSheet {
                viewModel.setImpactSharingEnabled(true)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Delete shared impact data?",
            isPresented: $showImpactDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete shared data", role: .destructive) {
                viewModel.deleteSharedImpactData()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("This removes optional impact records from Counting Sheep's backend. Your detailed history stays on this iPhone.")
        }
        .confirmationDialog(
            "Reset local progress?",
            isPresented: $showLocalProgressReset,
            titleVisibility: .visible
        ) {
            Button("Reset local progress", role: .destructive) {
                viewModel.resetLocalProgress()
            }
            Button("Keep my progress", role: .cancel) {}
        } message: {
            Text("This clears your protected nights, flock, rewards, reflections, and local ritual history. Your Wind Down plan and NFC tag stay paired; setup will not reopen.")
        }
        .sheet(isPresented: $showReplaySetup) {
            NavigationStack {
                OnboardingFlowView(
                    initialDraft: OnboardingDraft.replay(from: viewModel.nightWatchPreferences),
                    onComplete: { showReplaySetup = false },
                    onCancel: { showReplaySetup = false }
                )
                .environmentObject(viewModel)
            }
        }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        .familyActivityPicker(
            headerText: "Choose only the apps or categories you want Counting Sheep to show around sleep.",
            footerText: "Your selection stays in Apple's Screen Time system. Website entries are ignored.",
            isPresented: $showScreenTimePicker,
            selection: $viewModel.bedtimeActivitySelection
        )
        .onChange(of: viewModel.bedtimeActivitySelection) { _, _ in
            viewModel.saveScreenTimeSelection(.bedtime)
        }
#endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Settings")
                .font(AppTypography.display(34))
            Text("Your Wind Down, connections, and a way to reach us.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
        }
    }

    private var windDownSection: some View {
        VStack(spacing: AppSpacing.md) {
            sectionHeader("Your Wind Down", icon: "moon.stars.fill")
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    NavigationLink {
                        FocusRunSetupView()
                            .environmentObject(viewModel)
                    } label: {
                        Label("Wind Down plan", systemImage: "slider.horizontal.3")
                            .font(AppTypography.headline)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    Divider()
                    Button {
                        showReplaySetup = true
                    } label: {
                        Label("Review Wind Down setup", systemImage: "arrow.counterclockwise")
                            .font(AppTypography.headline)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            WindDownProtectionPicker(
                selectedKind: viewModel.nightWatchPreferences.guardKind,
                isNFCTagReady: viewModel.hasRegisteredNFCTag,
                onSelect: viewModel.selectProtectionChoice
            )
        }
    }

    private var connectionsSection: some View {
        VStack(spacing: AppSpacing.md) {
            sectionHeader("Connections", icon: "link")
            connectionCard(
                title: "Apple Health",
                detail: healthDetail,
                icon: "bed.double.fill",
                actionTitle: viewModel.sleepAuthorization == .notRequested ? "Connect" : nil,
                action: viewModel.connectAppleHealthSleep
            )
            connectionCard(
                title: "Screen Time",
                detail: screenTimeDetail,
                icon: "iphone.slash",
                actionTitle: viewModel.screenTimeAuthorization == .notDetermined ? "Connect" : nil,
                action: viewModel.connectScreenTime
            )
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Toggle(
                        "Show Wind Down on my Lock Screen",
                        isOn: Binding(
                            get: { viewModel.liveActivityEnabled },
                            set: viewModel.setLiveActivityEnabled
                        )
                    )
                    .font(AppTypography.headline)
                    Text("A Live Activity is a glanceable reminder while Wind Down is active. Counting Sheep still works when it is off.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
            NavigationLink {
                LockScreenQuietNoteGuideView()
            } label: {
                settingsRow("Lock Screen Quiet Note", icon: "text.bubble.fill")
            }
            .buttonStyle(.plain)
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Toggle(
                        "Quiet appearance",
                        isOn: Binding(
                            get: { viewModel.quietAppearanceEnabled },
                            set: viewModel.setQuietAppearanceEnabled
                        )
                    )
                    .font(AppTypography.headline)
                    Text("Use a softer, lower-saturation palette inside the active Wind Down screen. iOS does not provide a public API for changing the whole phone to grayscale.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    NavigationLink("How to use iOS Color Filters") {
                        QuietAppearanceGuideView()
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.grass)
                }
            }
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
            if viewModel.screenTimeAuthorization == .approved {
                ScreenTimeBookendCard(
                    showAppPicker: $showScreenTimePicker,
                    mode: .settings
                )
                .environmentObject(viewModel)
            }
#endif
            NavigationLink {
                NotificationSettingsView()
                    .environmentObject(viewModel)
            } label: {
                settingsRow("Notifications", icon: "bell.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private var sheepSearchSection: some View {
        VStack(spacing: AppSpacing.md) {
            sectionHeader("Ollie's search", icon: "binoculars.fill")
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Toggle(
                        "Show exact search odds",
                        isOn: Binding(
                            get: { viewModel.sheepSearchState.showExactOdds },
                            set: viewModel.setSheepSearchExactOddsEnabled
                        )
                    )
                    .font(AppTypography.headline)
                    Text("By default, Ollie shows Faint, Promising, Strong, or Very strong trail conditions. Turn this on to see the percentage and the bonuses behind it.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Text("Optional Health, Screen Time, and habit signals can add bonuses. Missing data never lowers the trail.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    private var guidanceSection: some View {
        VStack(spacing: AppSpacing.md) {
            sectionHeader("Wind Down ideas", icon: "sparkles")
            NavigationLink {
                WindDownHowItWorksView()
            } label: {
                settingsRow("How Wind Down works", icon: "moon.stars.fill")
            }
            .buttonStyle(.plain)
            NavigationLink {
                WindDownGuideView()
            } label: {
                PixelCard {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "sparkles")
                            .font(.title2.weight(.black))
                            .foregroundStyle(AppColors.grass)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("Open the finite guide")
                                .font(AppTypography.headline)
                            Text("Small, sourced ideas for screens, settling, and mornings. Nothing to complete.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppColors.muted)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var dataAndPrivacySection: some View {
        VStack(spacing: AppSpacing.md) {
            sectionHeader("Data & Privacy", icon: "hand.raised.fill")
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Optional impact data")
                        .font(AppTypography.headline)
                    Text("Your detailed ritual and Apple Health history stays on this iPhone. Optional sharing uses a smaller, date-free record.")
                        .font(AppTypography.body)
                    if viewModel.impactSharingPreferences.isEnabled {
                        Text(impactSyncLabel)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.grass)
                        Button("Stop future sharing") {
                            viewModel.setImpactSharingEnabled(false)
                        }
                        .buttonStyle(.bordered)
                        Button("Delete shared data", role: .destructive) {
                            showImpactDeletion = true
                        }
                        .font(AppTypography.caption)
                    } else if viewModel.impactSharingAvailable {
                        Button("Review optional sharing") {
                            showImpactConsent = true
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Text("Optional sharing is not available in this build. Your local insights still work.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }
            }
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Start over locally")
                        .font(AppTypography.headline)
                    Text("Clear your protected nights, flock, rewards, reflections, and local ritual history. Your Wind Down plan and NFC tag stay ready.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Button("Reset local progress", role: .destructive) {
                        showLocalProgressReset = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            if let privacyURL = Self.privacyURL {
                Link(destination: privacyURL) {
                    settingsRow("Privacy policy", icon: "lock.shield.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var helpSection: some View {
        VStack(spacing: AppSpacing.md) {
            sectionHeader("Help", icon: "lifepreserver.fill")
            NavigationLink {
                FeedbackFormView()
                    .environmentObject(viewModel)
            } label: {
                settingsRow("Send feedback", icon: "bubble.left.and.text.bubble.right.fill")
            }
            .buttonStyle(.plain)
            if let supportEmailURL = Self.supportEmailURL {
                Link(destination: supportEmailURL) {
                    settingsRow("Email support", icon: "envelope.fill")
                }
                .buttonStyle(.plain)
            }
            if let websiteURL = Self.websiteURL {
                Link(destination: websiteURL) {
                    settingsRow("Counting Sheep website", icon: "safari.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var aboutSection: some View {
        VStack(spacing: AppSpacing.md) {
            sectionHeader("About", icon: "info.circle.fill")
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Counting Sheep")
                        .font(AppTypography.headline)
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Text("Put your phone to bed. Wake up before it does.")
                        .font(AppTypography.body)
                    Divider()
                    Text("Acknowledgements")
                        .font(AppTypography.headline)
                    Text("Built with Apple frameworks and the open-source Supabase Swift client.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

#if DEBUG
    private var internalPreviewsSection: some View {
        VStack(spacing: AppSpacing.md) {
            sectionHeader("Internal Previews", icon: "hammer.fill")
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    NavigationLink("Farm mock") {
                        FarmOverviewScreen(progress: viewModel.coordinator.progress)
                    }
                    NavigationLink("Friends mock") { FriendsOverviewScreen() }
                    NavigationLink("Shop mock") { ShopPlaceholderScreen() }
                    NavigationLink("Legacy keepsake shelf") {
                        RewardShelfView().environmentObject(viewModel)
                    }
                }
                .font(AppTypography.body)
            }
        }
    }

    private var internalPreviewsEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(
            of: "-ollie.debug.enableMockScreens"
        ), arguments.indices.contains(flagIndex + 1) else {
            return false
        }
        return arguments[flagIndex + 1].caseInsensitiveCompare("YES") == .orderedSame
    }
#endif

    private func connectionCard(
        title: String,
        detail: String,
        icon: String,
        actionTitle: String?,
        action: @escaping () -> Void
    ) -> some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title).font(AppTypography.headline)
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    if let actionTitle {
                        Button(actionTitle, action: action)
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppTypography.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsRow(_ title: String, icon: String) -> some View {
        PixelCard {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 24)
                Text(title).font(AppTypography.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColors.muted)
            }
            .frame(minHeight: 44)
        }
    }

    private var healthDetail: String {
        switch viewModel.sleepAuthorization {
        case .notRequested: return "Optional sleep duration and stages beside your protected-night history."
        case .requested: return "Connected. Sleep context appears in Nights when Apple Health has a sample."
        case .unavailable: return "Apple Health sleep data is unavailable on this device."
        case .error: return "Apple Health could not complete the request. You can try again later."
        }
    }

    private var screenTimeDetail: String {
        switch viewModel.screenTimeAuthorization {
        case .notDetermined: return "Optional selected-app reports for late evening and after waking."
        case .approved: return "Connected. Choose the apps and report windows shown in Nights."
        case .denied: return "Access is off. Counting Sheep keeps working without it."
        case .unavailable: return "Screen Time reports are unavailable on this device."
        }
    }

    private var impactSyncLabel: String {
        switch viewModel.impactDataSyncState {
        case .idle: return "Future eligible nights will be shared."
        case .syncing: return "Sharing the latest eligible nights…"
        case .synced: return "Optional impact data is up to date."
        case .unavailable: return "Sharing is waiting for the impact service."
        case .failed: return "Sharing could not finish. Your local history is safe."
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private static let privacyURL = URL(
        string: "https://countingsheepproject.com/app-privacy-policy.html"
    )
    private static let websiteURL = URL(string: "https://countingsheepproject.com/")
    private static let supportEmailURL = URL(
        string: "mailto:countingsheep.sg@gmail.com?subject=Counting%20Sheep%20support"
    )
}

#Preview("Settings") {
    NavigationStack {
        SettingsView()
            .environmentObject(FocusRunViewModel())
    }
}

/// Compatibility name for previews and older internal references. The release
/// navigation and copy use SettingsView.
typealias MoreView = SettingsView
