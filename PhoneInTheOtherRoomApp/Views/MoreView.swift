import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var contextualTip: CountingSheepContextualTip?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                settingsNavigation
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
            Task { @MainActor in
                await Task.yield()
                contextualTip = viewModel.contextualTip(from: [.settings])
            }
        }
        .contextualGuideOverlay(
            tip: $contextualTip,
            onAcknowledge: viewModel.acknowledgeContextualTip,
            onSkipAll: viewModel.disableContextualTips
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Settings")
                    .font(AppTypography.display(34))
                Text("Your Wind Down, connections, and a little help when you need it.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)
            }
            Spacer(minLength: AppSpacing.sm)
            SettingsHelpButton(topic: .settings)
        }
    }

    private var settingsNavigation: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            sectionHeader("Your Wind Down", icon: "moon.stars.fill")
            NavigationLink { FocusRunSetupView().environmentObject(viewModel) } label: {
                settingsRow("Plan & routine", icon: "slider.horizontal.3", detail: "Schedule, quiet windows, and private ideas")
            }.buttonStyle(.plain).orientationTourTarget(.settingsWindDown)
            NavigationLink { SettingsProtectionTagsView().environmentObject(viewModel) } label: {
                settingsRow("Protection & tags", icon: "lock.shield.fill", detail: protectionSummary)
            }.buttonStyle(.plain)
            NavigationLink { SettingsRemindersLockScreenView().environmentObject(viewModel) } label: {
                settingsRow("Reminders & Lock Screen", icon: "bell.fill", detail: "Cues, Live Activity, and Quiet Note")
            }.buttonStyle(.plain)
            NavigationLink { SettingsAppearanceView().environmentObject(viewModel) } label: {
                settingsRow("Appearance", icon: "circle.lefthalf.filled", detail: "Choose a comfortable evening display")
            }.buttonStyle(.plain)
            sectionHeader("Connections", icon: "link")
            NavigationLink { SettingsConnectionsView().environmentObject(viewModel) } label: {
                settingsRow("Connections", icon: "link", detail: connectionsSummary)
            }.buttonStyle(.plain)
            sectionHeader("Privacy & data", icon: "hand.raised.fill")
            NavigationLink { SettingsPrivacyDataView().environmentObject(viewModel) } label: {
                settingsRow("Privacy & data", icon: "hand.raised.fill", detail: "Sharing choices, policy, and local reset")
            }.buttonStyle(.plain)
            sectionHeader("Help & app guide", icon: "lifepreserver.fill")
            NavigationLink { SettingsHelpGuideView().environmentObject(viewModel) } label: {
                settingsRow("Help & app guide", icon: "lifepreserver.fill", detail: "Guide, practice, sources, and support")
            }.buttonStyle(.plain).contextualGuideTarget(.settings)
        }
    }

    private var protectionSummary: String {
        viewModel.selectedGuardKind == .nfcTag ? "NFC tag and app limits" : "App limits with a timer"
    }

    private var connectionsSummary: String {
        viewModel.screenTimeAuthorization == .approved ? "Screen Time connected" : "Apple Health and Screen Time options"
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

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppTypography.headline)
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

}

#Preview("Settings") {
    let viewModel = FocusRunViewModel(startsExternalServices: false)
    viewModel.appearancePreference = .automatic
    return NavigationStack {
        SettingsView()
            .environmentObject(viewModel)
    }
}

#Preview("Settings · explicit dark") {
    let viewModel = FocusRunViewModel(startsExternalServices: false)
    viewModel.appearancePreference = .dark
    return NavigationStack {
        SettingsView()
            .environmentObject(viewModel)
    }
    .preferredColorScheme(.dark)
}

#Preview("Settings · explicit light") {
    let viewModel = FocusRunViewModel(startsExternalServices: false)
    viewModel.appearancePreference = .light
    return NavigationStack {
        SettingsView()
            .environmentObject(viewModel)
    }
    .preferredColorScheme(.light)
}

#Preview("Settings · three groups · accessibility") {
    let viewModel = FocusRunViewModel(startsExternalServices: false)
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
