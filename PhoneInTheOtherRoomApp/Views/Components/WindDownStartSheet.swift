import SwiftUI
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct WindDownStartSheet: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showScreenTimePicker = false
    @State private var selectionConfirmed = false

    private var usesNFC: Bool { viewModel.selectedGuardKind == .nfcTag }

    private var isAdHocQuiet: Bool {
        viewModel.pendingWindDownStartContext?.kind == .oneTimeQuiet
    }

    private var adHocEndTime: String {
        viewModel.pendingNightWatchEndsAt.map(OllieFormat.time) ?? "later"
    }

    private var eyebrow: String {
        switch viewModel.pendingWindDownStartContext?.kind {
        case .practice:
            return "PRACTICE QUIET · \(viewModel.pendingWindDownStartContext?.durationMinutes ?? 5) MIN"
        case .oneTimeQuiet: return "PHONE AWAY"
        case .repeatingQuiet: return "PHONE AWAY"
        case .primary, .none: return "START WIND DOWN"
        }
    }

    private var startButtonTitle: String {
        if viewModel.isScanningNFCForStart { return "Waiting for your tag…" }
        if isAdHocQuiet { return "Start now" }
        if viewModel.pendingWindDownStartContext?.isPractice == true {
            let minutes = viewModel.pendingWindDownStartContext?.durationMinutes ?? 5
            return usesNFC ? "Tap tag to start practice" : "Start \(minutes)-minute practice"
        }
        if viewModel.pendingNightWatchIsAdditionalQuiet {
            return usesNFC ? "Tap tag to start Phone Away" : "Start now"
        }
        return usesNFC ? "Tap Wind Down tag to start" : "Start now"
    }

    private var heading: String {
        if isAdHocQuiet {
            return "Phone Away until \(adHocEndTime)"
        }
        if viewModel.pendingWindDownStartContext?.isPractice == true {
            return "Your practice quiet is ready."
        }
        if viewModel.pendingNightWatchIsAdditionalQuiet {
            return viewModel.pendingNightWatchTitle ?? "A little Phone Away."
        }
        return usesNFC ? "Tap in when you are ready." : "Give the evening a little room."
    }

    private var explanation: String {
        if isAdHocQuiet {
            return "The minutes begin when you tap Start. Phone Away stays separate from Wind Down and appears in Nights."
        }
        if viewModel.pendingNightWatchIsAdditionalQuiet {
            let end = viewModel.pendingNightWatchEndsAt.map(OllieFormat.time) ?? "the saved end time"
            let protection = " Your chosen apps and categories will pause until then."
            if viewModel.pendingWindDownStartContext?.isPractice == true {
                return "This practice ends at \(end). It creates a real Nights record. It is not a protected night, and it does not add to the usual Phone Away search meter. Finishing this one-time introduction lets Ollie bring home the second starter sheep.\(protection)"
            }
            return "This Phone Away period ends at \(end). Its minutes begin when you start, and it stays separate from Wind Down.\(protection)"
        }
        return usesNFC
            ? "Your chosen apps and categories will pause after you tap your Wind Down tag. Counting Sheep stays available."
            : "Your chosen apps and categories will pause from Wind Down start. Counting Sheep stays available."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(eyebrow)
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(heading)
                        .font(AppTypography.title)
                    Text(explanation)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)

                    if isAdHocQuiet, usesNFC {
                        Text("Tap your registered Phone Away tag after choosing Start now.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }

                    shieldingChoice

                    nightFlockPrivacyChoice

                    Toggle(
                        isAdHocQuiet ? "Show on the Lock Screen" : "Show progress on the Lock Screen",
                        isOn: $viewModel.liveActivityChoiceForNextRun
                    )
                        .font(AppTypography.body)
                        .tint(AppColors.grass)

                    if !viewModel.nfcStatus.isEmpty {
                        Text(viewModel.nfcStatus)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }

                    Button {
                        viewModel.confirmNightWatchStart()
                    } label: {
                        Label(
                            startButtonTitle,
                            systemImage: usesNFC ? "dot.radiowaves.left.and.right" : "iphone.slash"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .disabled(
                        viewModel.isScanningNFCForStart
                            || !viewModel.shieldingReadiness.canStartProtectedSession
                            || !selectionConfirmed
                    )

                    Button("Not now") {
                        viewModel.cancelNightWatchStart()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.paper.ignoresSafeArea())
        }
        .onDisappear {
            viewModel.cancelNightWatchStart()
        }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        .familyActivityPicker(
            headerText: viewModel.pendingNightWatchIsAdditionalQuiet
                ? "Choose apps to limit during this Phone Away period."
                : "Choose apps to limit during Wind Down.",
            footerText: "Counting Sheep stays available. Websites are ignored.",
            isPresented: $showScreenTimePicker,
            selection: $viewModel.bedtimeActivitySelection
        )
            .onChange(of: viewModel.bedtimeActivitySelection) { _, _ in
                viewModel.saveScreenTimeSelection(.bedtime)
                viewModel.appShieldingChoiceForNextRun = viewModel.shieldingReadiness == .ready
                selectionConfirmed = false
        }
#endif
    }

    @ViewBuilder
    private var nightFlockPrivacyChoice: some View {
        if viewModel.pendingWindDownStartContext?.kind == .primary,
           viewModel.nightFlockViewModel.canOfferSharingForNextPrimaryRun {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Toggle(
                        "Keep tonight private",
                        isOn: Binding(
                            get: { !viewModel.nightFlockViewModel.shareNextPrimaryRun },
                            set: { viewModel.nightFlockViewModel.shareNextPrimaryRun = !$0 }
                        )
                    )
                    .font(AppTypography.body)
                    .tint(AppColors.grass)
                    .disabled(!viewModel.nightFlockViewModel.isChallengeSharingEnabled)

                    Text(viewModel.nightFlockViewModel.isChallengeSharingEnabled
                        ? "When this is on, nothing from tonight is shared. When it is off, your Slumber Party sharing choices apply independently."
                        : "Slumber Party sharing is already off in your privacy settings.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    @ViewBuilder
    private var shieldingChoice: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Label("App protection", systemImage: "apps.iphone")
                    .font(AppTypography.headline)

                switch viewModel.shieldingReadiness {
                case .ready:
                    Text("App protection is ready")
                        .font(AppTypography.body.weight(.semibold))
                    Text("Selected: \(viewModel.shieldingSelectionSummary). Does this include the apps that pull you back most often?")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                    HStack {
                        Button("Review", action: chooseAppsToRest)
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        Button(selectionConfirmed ? "Yes" : "Yes, continue") {
                            selectionConfirmed = true
                        }
                        .buttonStyle(PixelChipButtonStyle(isSelected: selectionConfirmed))
                    }
                    Text("Counting Sheep cannot verify named apps. Your answer is revisitable here or in Settings.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                case .authorizationRequired, .noSelection, .revoked, .runtimeFailure:
                    Text("Start with social feeds and short-form video, then add video, news, games, shopping, or other apps you open on autopilot. Counting Sheep can show only the private item count.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Button("Set up app protection", action: chooseAppsToRest)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                case .denied:
                    Text("Screen Time access is off. Restore it, then choose at least one app or category to continue.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Button("Set up app protection", action: chooseAppsToRest)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                case .unavailable:
                    Text("App protection is unavailable on this device. It must be ready before a new session can start.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    private func chooseAppsToRest() {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        Task { @MainActor in
            guard await viewModel.requestScreenTimeAuthorization() else { return }
            showScreenTimePicker = true
        }
#endif
    }
}

#Preview("Start requires app protection") {
    WindDownStartSheet()
        .environmentObject(FocusRunViewModel())
}

#Preview("One-time quiet start · Dynamic Type") {
    let viewModel = FocusRunViewModel()
    let now = Date()
    viewModel.windDownSchedule = WindDownScheduleState(oneTimePeriods: [
        WindDownOneTimePeriod(
            title: "Phone Away",
            interval: DateInterval(start: now, end: now.addingTimeInterval(30 * 60))
        )
    ])
    viewModel.requestStartNightWatch()
    return WindDownStartSheet()
        .environmentObject(viewModel)
        .environment(\.dynamicTypeSize, .accessibility2)
}
