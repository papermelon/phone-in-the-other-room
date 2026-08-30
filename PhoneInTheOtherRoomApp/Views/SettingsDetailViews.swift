import SwiftUI

#if SCREEN_TIME_REPORTS && canImport(FamilyControls) && canImport(DeviceActivity)
import DeviceActivity
import FamilyControls
#endif

enum SettingsHelpTopic: String {
    case settings, planRoutine, protectionTags, remindersLockScreen, appearance, connections, privacyData, helpGuide

    var title: String {
        switch self {
        case .settings: return "Settings map"
        case .planRoutine: return "Plan & routine"
        case .protectionTags: return "Protection & tags"
        case .remindersLockScreen: return "Reminders & Lock Screen"
        case .appearance: return "Appearance"
        case .connections: return "Connections"
        case .privacyData: return "Privacy & data"
        case .helpGuide: return "Help & app guide"
        }
    }

    var message: String {
        switch self {
        case .settings: return "Your Wind Down holds your plan, protection, reminders, and appearance. Connections, privacy, and help each have their own details."
        case .planRoutine: return "These choices shape the next run when one is already active. Routine ideas are private and optional."
        case .protectionTags: return "App limits use only your consented Screen Time selection. A paired tag is the normal NFC start and early-end credential."
        case .remindersLockScreen: return "Reminders and Lock Screen choices are optional. They never start a run by themselves."
        case .appearance: return "Choose the display that feels most comfortable in the evening."
        case .connections: return "Connections are optional. Counting Sheep still works when they are unavailable or declined."
        case .privacyData: return "Detailed ritual history stays on this iPhone. Optional sharing uses a smaller, date-free record."
        case .helpGuide: return "The guide and practice are optional ways to get familiar with Counting Sheep."
        }
    }
}

struct SettingsHelpButton: View {
    let topic: SettingsHelpTopic
    @State private var showsHelp = false

    var body: some View {
        Button { showsHelp = true } label: {
            Image(systemName: "questionmark.circle")
        }
        .accessibilityLabel("Help for \(topic.title)")
        .sheet(isPresented: $showsHelp) {
            NavigationStack {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(topic.title).font(AppTypography.display(28))
                    Text(topic.message).font(AppTypography.body).foregroundStyle(AppColors.muted)
                    Spacer()
                }
                .padding(AppSpacing.lg)
                .background(AppColors.paper.ignoresSafeArea())
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showsHelp = false } } }
            }
            .presentationDetents([.medium])
        }
    }
}

extension View {
    func settingsHelp(_ topic: SettingsHelpTopic) -> some View {
        toolbar { ToolbarItem(placement: .topBarTrailing) { SettingsHelpButton(topic: topic) } }
    }
}

struct SettingsProtectionTagsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var showShieldInfo = false
    @State private var selectionConfirmed = false
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    @State private var showPicker = false
#endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsDetailHeader(title: "Protection & tags", detail: "Choose app limits and manage the tags that start and end NFC runs.")
                PixelCard {
                    Toggle("Start Wind Down automatically", isOn: Binding(
                        get: { viewModel.nightWatchPreferences.automaticStartEnabled },
                        set: viewModel.setAutomaticStartEnabled
                    ))
                    .font(AppTypography.headline)
                }
                WindDownProtectionPicker(
                    selectedKind: viewModel.nightWatchPreferences.guardKind,
                    isNFCTagReady: viewModel.hasRegisteredNFCTag,
                    shieldingReadiness: viewModel.shieldingReadiness,
                    selectedAppsSummary: selectedAppsSummary,
                    onSelect: viewModel.selectProtectionChoice,
                    onAllowScreenTime: viewModel.connectScreenTime,
                    onChooseApps: chooseApps,
                    onSetUpNFCTag: { viewModel.provisionNFCTag() },
                    onShowAppShieldInfo: { showShieldInfo = true }
                )
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(viewModel.shieldingReadiness.title)
                            .font(AppTypography.headline)
                        Text(viewModel.shieldingReadiness.detail)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                        if viewModel.shieldingReadiness == .ready {
                            Text("Does this include the apps that pull you back most often?")
                                .font(AppTypography.caption)
                            Button(selectionConfirmed ? "Yes" : "Yes, this is right") {
                                selectionConfirmed = true
                            }
                            .buttonStyle(PixelChipButtonStyle(isSelected: selectionConfirmed))
                        } else {
                            Button("Why this matters") { showShieldInfo = true }
                                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                            Button("Open Settings") { viewModel.openAppSettings() }
                                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        }
                    }
                }
                WindDownTagManagementCard().environmentObject(viewModel)
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Protection & tags")
        .navigationBarTitleDisplayMode(.inline)
        .settingsHelp(.protectionTags)
        .sheet(isPresented: $showShieldInfo) { AppShieldExplainerSheet(onDone: { showShieldInfo = false }) }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        .familyActivityPicker(headerText: "Choose apps or categories to limit during Wind Down.", footerText: "Counting Sheep stays available.", isPresented: $showPicker, selection: $viewModel.bedtimeActivitySelection)
        .onChange(of: viewModel.bedtimeActivitySelection) { _, _ in
            viewModel.saveScreenTimeSelection(.bedtime)
            selectionConfirmed = false
        }
#endif
    }

    private var selectedAppsSummary: String? {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        viewModel.hasSelectedShieldingApps ? viewModel.bedtimeActivitySelection.phoneOtherSelectionSummary : nil
#else
        nil
#endif
    }

    private var chooseApps: () -> Void {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        { showPicker = true }
#else
        {}
#endif
    }
}

struct SettingsRemindersLockScreenView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsDetailHeader(title: "Reminders & Lock Screen", detail: "Keep gentle cues nearby without changing the ritual itself.")
                NavigationLink { NotificationSettingsView().environmentObject(viewModel) } label: {
                    SettingsDetailRow(title: "Reminders", detail: "Timing, sounds, and message wording", icon: "bell.fill")
                }.buttonStyle(.plain)
                PixelCard {
                    Toggle("Show Wind Down on my Lock Screen", isOn: Binding(get: { viewModel.liveActivityEnabled }, set: viewModel.setLiveActivityEnabled))
                        .font(AppTypography.headline)
                    Text("A Live Activity is optional and only appears while Wind Down is active.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.muted)
                }
                NavigationLink { LockScreenQuietNoteGuideView() } label: {
                    SettingsDetailRow(title: "Lock Screen Quiet Note", detail: "Set a small private reminder", icon: "text.bubble.fill")
                }.buttonStyle(.plain)
            }.padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Reminders & Lock Screen")
        .navigationBarTitleDisplayMode(.inline)
        .settingsHelp(.remindersLockScreen)
    }
}

struct SettingsAppearanceView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            SettingsDetailHeader(title: "Appearance", detail: "Choose a comfortable look for the evenings you spend with Ollie.")
            AppearancePreferenceCard(preference: viewModel.appearancePreference, onSelect: viewModel.setAppearancePreference)
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .settingsHelp(.appearance)
    }
}

struct SettingsConnectionsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
    @State private var showScreenTimePicker = false
#endif
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsDetailHeader(title: "Connections", detail: "Optional Apple services add context without changing your local ritual.")
                HealthConnectionStatusCard(
                    presentation: viewModel.healthSleepConnectionPresentation,
                    onConnect: viewModel.connectAppleHealthSleep,
                    onRefresh: viewModel.retryAppleHealthConnection
                )
                ScreenTimeConnectionStatusCard(
                    presentation: viewModel.screenTimeConnectionPresentation,
                    onConnect: viewModel.connectScreenTime,
                    onChooseSelection: {
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
                        showScreenTimePicker = true
#endif
                    }
                )
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
                if viewModel.screenTimeAuthorization == .approved {
                    ScreenTimeBookendCard(showAppPicker: $showScreenTimePicker, mode: .settings).environmentObject(viewModel)
                }
#endif
                if viewModel.nightFlockViewModel.featureEnabled {
                    NavigationLink { NightFlockHubView(viewModel: viewModel.nightFlockViewModel) } label: { SettingsDetailRow(title: "Slumber Party", detail: "Invite-only shared ritual settings", icon: "moon.haze.fill") }.buttonStyle(.plain)
                }
            }.padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Connections")
        .navigationBarTitleDisplayMode(.inline)
        .settingsHelp(.connections)
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
        .familyActivityPicker(
            headerText: "Choose apps or categories for reports and future Wind Down or Phone Away app protection.",
            footerText: "Changing this does not alter a current session. Your selection stays in Apple’s Screen Time system; website entries are ignored.",
            isPresented: $showScreenTimePicker,
            selection: $viewModel.bedtimeActivitySelection
        )
        .onChange(of: viewModel.bedtimeActivitySelection) { _, _ in
            viewModel.saveScreenTimeSelection(.bedtime)
        }
#endif
    }
}

struct SettingsDetailHeader: View {
    let title: String; let detail: String
    var body: some View { VStack(alignment: .leading, spacing: AppSpacing.xs) { Text(title).font(AppTypography.display(30)); Text(detail).font(AppTypography.body).foregroundStyle(AppColors.muted) } }
}

struct SettingsDetailRow: View {
    let title: String; let detail: String; let icon: String
    var body: some View { PixelCard { HStack(spacing: AppSpacing.md) { Image(systemName: icon).foregroundStyle(AppColors.grass).frame(width: 24); VStack(alignment: .leading, spacing: AppSpacing.xxs) { Text(title).font(AppTypography.headline); Text(detail).font(AppTypography.caption).foregroundStyle(AppColors.muted) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(AppColors.muted) }.frame(minHeight: 44) } }
}

private struct SettingsConnectionRow: View {
    let title: String; let detail: String; let icon: String; let actionTitle: String?; let action: (() -> Void)?
    var body: some View { PixelCard { HStack(alignment: .top, spacing: AppSpacing.md) { Image(systemName: icon).foregroundStyle(AppColors.grass).frame(width: 24); VStack(alignment: .leading, spacing: AppSpacing.xxs) { Text(title).font(AppTypography.headline); Text(detail).font(AppTypography.caption).foregroundStyle(AppColors.muted); if let actionTitle, let action { Button(actionTitle, action: action).buttonStyle(PixelChipButtonStyle(isSelected: false)) } }; Spacer() } } }
}

struct SettingsPrivacyDataView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var showConsent = false
    @State private var showDeletion = false
    @State private var showReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsDetailHeader(title: "Privacy & data", detail: "Your detailed history stays local unless you separately choose optional sharing.")
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Optional impact data").font(AppTypography.headline)
                        Text("Shared records omit exact dates, apps, source names, and raw Health samples.").font(AppTypography.caption).foregroundStyle(AppColors.muted)
                        if viewModel.impactSharingPreferences.isEnabled {
                            Text(impactSyncLabel).font(AppTypography.caption).foregroundStyle(AppColors.grass)
                            Button("Stop future sharing") { viewModel.setImpactSharingEnabled(false) }.buttonStyle(PixelChipButtonStyle(isSelected: false))
                            Button("Delete shared data", role: .destructive) { showDeletion = true }.buttonStyle(.bordered)
                        } else if viewModel.impactSharingAvailable {
                            Button("Review optional sharing") { showConsent = true }.buttonStyle(PixelPrimaryButtonStyle())
                        } else {
                            Text("Optional sharing is unavailable in this build. Local insights still work.").font(AppTypography.caption).foregroundStyle(AppColors.muted)
                        }
                    }
                }
                Link(destination: URL(string: "https://countingsheepproject.com/app-privacy-policy.html")!) { SettingsDetailRow(title: "Privacy policy", detail: "Read the current policy", icon: "lock.shield.fill") }.buttonStyle(.plain)
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Local data").font(AppTypography.headline)
                        Text("Erase this iPhone’s plan, history, Farm, local selection, and paired tag.").font(AppTypography.caption).foregroundStyle(AppColors.muted)
                        Button("Erase local data and start over", role: .destructive) { showReset = true }.buttonStyle(.bordered)
                    }
                }
            }.padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Privacy & data")
        .navigationBarTitleDisplayMode(.inline)
        .settingsHelp(.privacyData)
        .sheet(isPresented: $showConsent) { ImpactSharingConsentSheet { viewModel.setImpactSharingEnabled(true) } }
        .confirmationDialog("Delete shared impact data?", isPresented: $showDeletion, titleVisibility: .visible) { Button("Delete shared data", role: .destructive) { viewModel.deleteSharedImpactData() }; Button("Keep it", role: .cancel) {} } message: { Text("This removes optional impact records from Counting Sheep’s backend. Local history stays here.") }
        .confirmationDialog("Start over from the beginning?", isPresented: $showReset, titleVisibility: .visible) { Button("Erase and start over", role: .destructive) { viewModel.eraseLocalDataAndStartOver() }; Button("Keep my data", role: .cancel) {} } message: { Text("System permissions already granted by iOS cannot be revoked here.") }
    }

    private var impactSyncLabel: String {
        switch viewModel.impactDataSyncState {
        case .idle: return "Future eligible nights will be shared."
        case .syncing: return "Sharing the latest eligible nights…"
        case .synced: return "Optional impact data is up to date."
        case .unavailable: return "Sharing is waiting for the impact service."
        case .failed: return "Sharing could not finish. Local history is safe."
        }
    }
}

#Preview("Connections · unavailable") {
    let viewModel = FocusRunViewModel(startsExternalServices: false)
    viewModel.sleepAuthorization = .unavailable
    viewModel.screenTimeAuthorization = .unavailable
    return NavigationStack {
        SettingsConnectionsView()
            .environmentObject(viewModel)
    }
}

#Preview("Connections · permission needed") {
    let viewModel = FocusRunViewModel(startsExternalServices: false)
    viewModel.sleepAuthorization = .error("Preview")
    viewModel.screenTimeAuthorization = .denied("Preview")
    return NavigationStack {
        SettingsConnectionsView()
            .environmentObject(viewModel)
    }
}
