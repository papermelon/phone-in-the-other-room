import SwiftUI

struct SettingsHelpGuideView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsDetailHeader(title: "Help & app guide", detail: "Find a gentle introduction, practical help, and the small ideas behind Wind Down.")
                NavigationLink { WindDownHowItWorksView() } label: {
                    SettingsDetailRow(title: "How Counting Sheep works", detail: "The simple Wind Down ritual", icon: "moon.stars.fill")
                }
                .buttonStyle(.plain)
                Button { resumeOrReplayGuide() } label: {
                    SettingsDetailRow(title: viewModel.orientationState.canResume || viewModel.orientationState.isGuideActive ? "Resume app guide" : "Show app guide", detail: "A short guide across the app", icon: "map.fill")
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isRunning)
                Button {
                    NotificationCenter.default.post(name: .countingSheepShowHome, object: nil)
                    _ = viewModel.startOrientationPractice()
                } label: {
                    SettingsDetailRow(
                        title: viewModel.shieldingReadiness == .ready ? "5-minute practice" : "Set up app protection",
                        detail: viewModel.shieldingReadiness == .ready
                            ? "A real practice that does not count as Wind Down"
                            : viewModel.shieldingReadiness.detail,
                        icon: viewModel.shieldingReadiness == .ready ? "timer" : "shield.lefthalf.filled"
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isRunning || viewModel.shieldingReadiness != .ready)
                NavigationLink { WindDownGuideView() } label: {
                    SettingsDetailRow(title: "About these ideas and sources", detail: "Small sourced ideas for evenings and mornings", icon: "sparkles")
                }
                .buttonStyle(.plain)
                NavigationLink { FeedbackFormView().environmentObject(viewModel) } label: {
                    SettingsDetailRow(title: "Send feedback", detail: "Tell us what would help", icon: "bubble.left.and.text.bubble.right.fill")
                }
                .buttonStyle(.plain)
                Link(destination: URL(string: "mailto:countingsheep.sg@gmail.com?subject=Counting%20Sheep%20support")!) {
                    SettingsDetailRow(title: "Email support", detail: "Open a support email", icon: "envelope.fill")
                }
                .buttonStyle(.plain)
                Link(destination: URL(string: "https://countingsheepproject.com/")!) {
                    SettingsDetailRow(title: "Counting Sheep website", detail: "Open the project website", icon: "safari.fill")
                }
                .buttonStyle(.plain)
#if SLUMBER_PARTY_QA
                NavigationLink { NightFlockQADiagnosticsView(viewModel: viewModel.nightFlockViewModel) } label: {
                    SettingsDetailRow(title: "Slumber Party QA diagnostics", detail: "Internal build configuration only", icon: "stethoscope")
                }
                .buttonStyle(.plain)
#endif
                SettingsAppDetailsCard()
                SettingsBuildLaneCard()
#if DEBUG
                if internalPreviewsEnabled {
                    internalPreviewsCard
                }
#endif
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Help & app guide")
        .navigationBarTitleDisplayMode(.inline)
        .settingsHelp(.helpGuide)
        .contextualGuideTarget(.settings)
    }

    private func resumeOrReplayGuide() {
        if viewModel.orientationState.canResume || viewModel.orientationState.isGuideActive {
            viewModel.resumeOrientation()
        } else {
            viewModel.replayOrientation()
            NotificationCenter.default.post(name: .countingSheepShowHome, object: nil)
        }
    }

#if DEBUG
    private var internalPreviewsCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Internal previews").font(AppTypography.headline)
                NavigationLink("Farm mock") { FarmOverviewScreen(progress: viewModel.coordinator.progress) }
                NavigationLink("Friends mock") { FriendsOverviewScreen() }
                NavigationLink("Shop mock") { ShopPlaceholderScreen() }
                NavigationLink("Legacy keepsake shelf") { RewardShelfView().environmentObject(viewModel) }
            }
            .font(AppTypography.body)
        }
    }

    private var internalPreviewsEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-ollie.debug.enableMockScreens"), arguments.indices.contains(flagIndex + 1) else {
            return false
        }
        return arguments[flagIndex + 1].caseInsensitiveCompare("YES") == .orderedSame
    }
#endif
}

private struct SettingsAppDetailsCard: View {
    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Counting Sheep").font(AppTypography.headline)
                Text("Version \(version) (\(build))").font(AppTypography.caption).foregroundStyle(AppColors.muted)
                Text("Put your phone to bed. Wake up before it does.").font(AppTypography.body)
                Divider()
                Text("Acknowledgements").font(AppTypography.headline)
                Text("Built with Apple frameworks and the open-source Supabase Swift client.").font(AppTypography.caption).foregroundStyle(AppColors.muted)
            }
        }
    }

    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—" }
    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—" }
}

private struct SettingsBuildLaneCard: View {
    var body: some View {
#if DEBUG
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Development build").font(AppTypography.headline)
#if SLUMBER_PARTY_QA
                Text("Slumber Party QA · \(version) (\(build)) · \(partyStatus)")
                    .font(AppTypography.caption).foregroundStyle(AppColors.muted)
#else
                Text("Ordinary Debug · \(version) (\(build)) · \(partyStatus)")
                    .font(AppTypography.caption).foregroundStyle(AppColors.muted)
#endif
            }
        }
#else
        EmptyView()
#endif
    }

    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—" }
    private var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—" }
    private var partyStatus: String { SupabaseConfiguration.nightFlockFeatureFlag() == .enabled ? "Slumber Party enabled" : "Slumber Party off" }
}

#Preview("Help guide · ordinary") {
    NavigationStack {
        SettingsHelpGuideView()
    }
    .environmentObject(FocusRunViewModel(startsExternalServices: false))
}

#Preview("Help guide · accessibility") {
    NavigationStack {
        SettingsHelpGuideView()
    }
    .environmentObject(FocusRunViewModel(startsExternalServices: false))
    .environment(\.dynamicTypeSize, .accessibility3)
    .environment(\.colorScheme, .dark)
}
