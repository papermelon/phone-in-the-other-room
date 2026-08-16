import SwiftUI

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct SettingsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var showImpactConsent = false
    @State private var showImpactDeletion = false
    @State private var showStartOver = false
    @State private var showAppShieldInfo = false
    @State private var contextualTip: CountingSheepContextualTip?
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    @State private var showScreenTimePicker = false
#endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                windDownSection
                connectionsSection
                helpAndGuideSection
#if DEBUG
                if internalPreviewsEnabled {
                    internalPreviewsSection
                }
#endif
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .onAppear {
            viewModel.markOrientation(.settingsExplored)
            contextualTip = viewModel.contextualTip(from: [.settings])
        }
        .contextualGuideOverlay(
            tip: $contextualTip,
            onAcknowledge: viewModel.acknowledgeContextualTip,
            onSkipAll: viewModel.disableContextualTips
        )
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
            "Start over from the beginning?",
            isPresented: $showStartOver,
            titleVisibility: .visible
        ) {
            Button("Erase and start over", role: .destructive) {
                viewModel.eraseLocalDataAndStartOver()
            }
            Button("Keep my data", role: .cancel) {}
        } message: {
            Text("This erases your Wind Down plan, protected nights, flock, rewards, reflections, local history, app selection, and paired NFC tag. Counting Sheep will return to the Welcome screen. System permissions already granted by iOS cannot be revoked here.")
        }
        .sheet(isPresented: $showAppShieldInfo) {
            AppShieldExplainerSheet {
                showAppShieldInfo = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
            Text("Your Wind Down, connections, and a little help when you need it.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
        }
    }

    private var helpAndGuideSection: some View {
        VStack(spacing: AppSpacing.md) {
            sectionHeader("Help & app guide", icon: "lifepreserver.fill")
            NavigationLink {
                WindDownHowItWorksView()
            } label: {
                settingsRow("How Counting Sheep works", icon: "moon.stars.fill", detail: "The simple Wind Down ritual")
            }
            .buttonStyle(.plain)
            settingsButton(
                title: viewModel.orientationState.canResume ? "Resume app guide" : "Show app guide",
                icon: "map.fill",
                detail: "A short map of Home and the four tabs."
            ) {
                        if viewModel.orientationState.canResume {
                            viewModel.resumeOrientation()
                        } else {
                            viewModel.replayOrientation()
                        }
                        NotificationCenter.default.post(name: .countingSheepShowHome, object: nil)
            }
            .disabled(viewModel.isRunning)
            settingsButton(
                title: "5-minute practice",
                icon: "timer",
                detail: "A real practice in Nights. It never counts as a Wind Down."
            ) {
                        NotificationCenter.default.post(name: .countingSheepShowHome, object: nil)
                        _ = viewModel.startOrientationPractice()
            }
            .disabled(viewModel.isRunning)
            NavigationLink {
                WindDownGuideView()
            } label: {
                settingsRow("About these ideas and sources", icon: "sparkles", detail: "Small, sourced ideas for settling and mornings")
            }
            .buttonStyle(.plain)
        }
        .contextualGuideTarget(.settings)
    }

    private var appearanceSection: some View {
        VStack(spacing: AppSpacing.md) {
            subsectionHeader("Appearance", icon: "circle.lefthalf.filled")
            AppearancePreferenceCard(
                preference: viewModel.appearancePreference,
                onSelect: viewModel.setAppearancePreference
            )
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
                        settingsRow("Plan & routine", icon: "slider.horizontal.3", detail: "Bedtime, bookends, and private routine ideas")
                    }
                    .buttonStyle(.plain)
                }
            }
            WindDownProtectionPicker(
                selectedKind: viewModel.nightWatchPreferences.guardKind,
                isNFCTagReady: viewModel.hasRegisteredNFCTag,
                shieldingReadiness: viewModel.shieldingReadiness,
                selectedAppsSummary: selectedShieldingAppsSummary,
                onSelect: viewModel.selectProtectionChoice,
                onAllowScreenTime: viewModel.connectScreenTime,
                onChooseApps: chooseShieldingAppsAction,
                onSetUpNFCTag: { viewModel.provisionNFCTag() },
                onShowAppShieldInfo: { showAppShieldInfo = true }
            )
            appearanceSection
            NavigationLink {
                NotificationSettingsView()
                    .environmentObject(viewModel)
            } label: {
                settingsRow("Reminders", icon: "bell.fill", detail: "Wind Down cues and quiet-time reminders")
            }
            .buttonStyle(.plain)
        }
    }

    private var chooseShieldingAppsAction: () -> Void {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        return { showScreenTimePicker = true }
#else
        return {}
#endif
    }

    private var selectedShieldingAppsSummary: String? {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        guard viewModel.hasSelectedShieldingApps else { return nil }
        return viewModel.bedtimeActivitySelection.phoneOtherSelectionSummary
#else
        return nil
#endif
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
            #if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
            if viewModel.screenTimeAuthorization == .approved {
                ScreenTimeBookendCard(
                    showAppPicker: $showScreenTimePicker,
                    mode: .settings
                )
                .environmentObject(viewModel)
            }
#endif
            privacyAndSharingSection
            supportAndDetailsSection
            localDataSection
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
                    Text("A sheep search happens only after an eligible completed protected night. Turn this on to see the search percentage and what can shape it.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Text("Optional signals can shape an eligible search. Missing data never lowers it.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    private var privacyAndSharingSection: some View {
        VStack(spacing: AppSpacing.md) {
            subsectionHeader("Privacy & optional sharing", icon: "hand.raised.fill")
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
            if let privacyURL = Self.privacyURL {
                Link(destination: privacyURL) {
                    settingsRow("Privacy policy", icon: "lock.shield.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var localDataSection: some View {
        VStack(spacing: AppSpacing.md) {
            subsectionHeader("Local data", icon: "arrow.counterclockwise")
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Erase local data and start over")
                        .font(AppTypography.headline)
                    Text("Return Counting Sheep to the Welcome screen and begin with a clean local ritual.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Button("Erase local data and start over", role: .destructive) {
                        showStartOver = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var supportAndDetailsSection: some View {
        VStack(spacing: AppSpacing.md) {
            subsectionHeader("Support & app details", icon: "info.circle.fill")
#if SLUMBER_PARTY_QA
            NavigationLink {
                NightFlockQADiagnosticsView(
                    viewModel: viewModel.nightFlockViewModel
                )
            } label: {
                settingsRow(
                    "Slumber Party QA diagnostics",
                    icon: "stethoscope",
                    detail: "Internal build configuration only; no network checks"
                )
            }
            .buttonStyle(.plain)
#endif
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
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppTypography.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func subsectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppTypography.caption.weight(.bold))
            .foregroundStyle(AppColors.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsRow(_ title: String, icon: String, detail: String? = nil) -> some View {
        PixelCard {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title).font(AppTypography.headline)
                    if let detail {
                        Text(detail)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColors.muted)
            }
            .frame(minHeight: 44)
        }
    }

    private func settingsButton(
        title: String,
        icon: String,
        detail: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            settingsRow(title, icon: icon, detail: detail)
        }
        .buttonStyle(.plain)
    }

    private var healthDetail: String {
        switch viewModel.sleepAuthorization {
        case .notRequested: return "Optional sleep duration and stages beside your Wind Down history."
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
    let viewModel = FocusRunViewModel()
    viewModel.appearancePreference = .automatic
    return NavigationStack {
        SettingsView()
            .environmentObject(viewModel)
    }
}

#Preview("Settings · explicit dark") {
    let viewModel = FocusRunViewModel()
    viewModel.appearancePreference = .dark
    return NavigationStack {
        SettingsView()
            .environmentObject(viewModel)
    }
    .preferredColorScheme(.dark)
}

#Preview("Settings · explicit light") {
    let viewModel = FocusRunViewModel()
    viewModel.appearancePreference = .light
    return NavigationStack {
        SettingsView()
            .environmentObject(viewModel)
    }
    .preferredColorScheme(.light)
}

#Preview("Settings · three groups · accessibility") {
    let viewModel = FocusRunViewModel()
    viewModel.orientationState = CountingSheepOrientationState(
        status: .dismissed,
        milestones: [.homeExplained, .windDownSaved]
    )
    return NavigationStack {
        SettingsView()
            .environmentObject(viewModel)
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}

/// Compatibility name for previews and older internal references. The release
/// navigation and copy use SettingsView.
typealias MoreView = SettingsView
