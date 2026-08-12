import SwiftUI
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct WindDownStartSheet: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showScreenTimePicker = false

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
        case .oneTimeQuiet: return "ONE-TIME QUIET"
        case .repeatingQuiet: return "EXTRA QUIET"
        case .primary, .none: return "START WIND DOWN"
        }
    }

    private var startButtonTitle: String {
        if viewModel.isScanningNFCForStart { return "Waiting for your tag…" }
        if isAdHocQuiet { return "Start quiet time" }
        if viewModel.pendingWindDownStartContext?.isPractice == true {
            let minutes = viewModel.pendingWindDownStartContext?.durationMinutes ?? 5
            return usesNFC ? "Tap tag to start practice" : "Start \(minutes)-minute practice"
        }
        if viewModel.pendingNightWatchIsAdditionalQuiet {
            return usesNFC ? "Tap tag to start quiet time" : "Start quiet time"
        }
        return usesNFC ? "Tap Wind Down tag to start" : "Start now"
    }

    private var heading: String {
        if isAdHocQuiet {
            return "Quiet time until \(adHocEndTime)"
        }
        if viewModel.pendingWindDownStartContext?.isPractice == true {
            return "Your practice quiet is ready."
        }
        if viewModel.pendingNightWatchIsAdditionalQuiet {
            return viewModel.pendingNightWatchTitle ?? "A little one-time quiet."
        }
        return usesNFC ? "Tap in when you are ready." : "Give the evening a little room."
    }

    private var explanation: String {
        if isAdHocQuiet {
            return "Only the minutes after you start count. This appears in Nights, but it isn’t a protected night and won’t find a sheep."
        }
        if viewModel.pendingNightWatchIsAdditionalQuiet {
            let end = viewModel.pendingNightWatchEndsAt.map(OllieFormat.time) ?? "the saved end time"
            let protection = viewModel.willShieldPendingNightWatch
                ? " Selected apps will be limited until then."
                : " No apps will be limited."
            if viewModel.pendingWindDownStartContext?.isPractice == true {
                return "This practice ends at \(end). It will appear in Nights, but it stays separate from protected nights and Ollie’s sheep search.\(protection)"
            }
            return "This quiet time ends at \(end). Only the time from when you start is counted. It stays separate from protected nights and Ollie’s sheep search.\(protection)"
        }
        guard viewModel.willShieldPendingNightWatch else {
            return "Wind Down will keep time and record your quiet. No apps will be limited."
        }
        return usesNFC
            ? "Selected apps will be limited after you tap your Wind Down tag and through morning quiet. Counting Sheep stays available."
            : "Selected apps will be limited from Wind Down start through morning quiet. Counting Sheep stays available."
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
                        Text("Tap your registered phone-bed tag after choosing Start quiet time.")
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
                    .disabled(viewModel.isScanningNFCForStart)

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
            headerText: "Choose apps to limit during this quiet time.",
            footerText: "Counting Sheep stays available. Websites are ignored.",
            isPresented: $showScreenTimePicker,
            selection: $viewModel.bedtimeActivitySelection
        )
        .onChange(of: viewModel.bedtimeActivitySelection) { _, _ in
            viewModel.saveScreenTimeSelection(.bedtime)
            viewModel.appShieldingChoiceForNextRun = viewModel.shieldingReadiness == .ready
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
                        ? "If off, only positive phone-tucked and quiet-morning states can be shared."
                        : "Slumber Party sharing is already off in your privacy settings.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    @ViewBuilder
    private var shieldingChoice: some View {
        if viewModel.pendingStartNeedsShieldingSetup {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Label(
                        "Selected apps aren’t set up",
                        systemImage: "apps.iphone"
                    )
                        .font(AppTypography.headline)
                    Text(
                        isAdHocQuiet
                            ? "You can start without app limits, or choose apps and categories first."
                            : "You can start this quiet time without app limits, or choose apps first."
                    )
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Button("Choose apps to limit", action: chooseAppsToRest)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
            }
        } else if viewModel.shieldingEnabled, viewModel.shieldingReadiness == .ready {
            Toggle(
                "Limit selected apps",
                isOn: $viewModel.appShieldingChoiceForNextRun
            )
                .font(AppTypography.body)
                .tint(AppColors.grass)
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

#Preview("Start without app limits") {
    WindDownStartSheet()
        .environmentObject(FocusRunViewModel())
}

#Preview("One-time quiet start · Dynamic Type") {
    let viewModel = FocusRunViewModel()
    let now = Date()
    viewModel.windDownSchedule = WindDownScheduleState(oneTimePeriods: [
        WindDownOneTimePeriod(
            title: "One-time quiet period",
            interval: DateInterval(start: now, end: now.addingTimeInterval(30 * 60))
        )
    ])
    viewModel.requestStartNightWatch()
    return WindDownStartSheet()
        .environmentObject(viewModel)
        .environment(\.dynamicTypeSize, .accessibility2)
}
