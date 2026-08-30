import SwiftUI
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct WindDownStartSheet: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showScreenTimePicker = false
    @State private var showPhoneAwayDurationChoices = false

    private var usesNFC: Bool { viewModel.selectedGuardKind == .nfcTag }

    private var isAdHocQuiet: Bool {
        viewModel.pendingWindDownStartContext?.kind == .oneTimeQuiet
    }

    private var isManualPhoneAway: Bool {
        guard let context = viewModel.pendingWindDownStartContext else { return false }
        return context.kind == .oneTimeQuiet && context.sourceID == nil
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
        if isManualPhoneAway { return "Start now" }
        if isAdHocQuiet {
            return usesNFC ? "Tap tag to start Phone Away" : "Start Phone Away"
        }
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
        if isManualPhoneAway {
            let minutes = viewModel.pendingWindDownStartContext?.durationMinutes ?? PhoneAwayDurationPolicy.defaultMinutes
            return "Phone Away · \(minutes) minutes"
        }
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
        if isManualPhoneAway {
            return "The minutes begin when you tap Start. Phone Away stays separate from Wind Down and appears in Nights."
        }
        if isAdHocQuiet {
            return "This scheduled Phone Away period ends at \(adHocEndTime). Its saved end time stays in place while you confirm protection."
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

                    if isManualPhoneAway, usesNFC {
                        Text("Tap your registered Phone Away tag after choosing Start now.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }

                    if isManualPhoneAway {
                        phoneAwayDurationChoice
                    }

                    shieldingChoice

                    nightFlockPrivacyChoice

                    Toggle(
                        isAdHocQuiet ? "Show on the Lock Screen" : "Show progress on the Lock Screen",
                        isOn: $viewModel.liveActivityChoiceForNextRun
                    )
                        .font(AppTypography.body)
                        .tint(AppColors.grass)

                    if !viewModel.startNFCStatus.isEmpty {
                        Text(viewModel.startNFCStatus)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }

                    if !viewModel.nightWatchStartStatus.isEmpty {
                        Text(viewModel.nightWatchStartStatus)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.warning)
                            .accessibilityAddTraits(.updatesFrequently)
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
        .onAppear { viewModel.refreshScreenTimeState() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            viewModel.refreshScreenTimeState()
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
        }
#endif
        .confirmationDialog(
            "Phone Away duration",
            isPresented: $showPhoneAwayDurationChoices,
            titleVisibility: .visible
        ) {
            ForEach(PhoneAwayDurationPolicy.options, id: \.self) { minutes in
                Button(PhoneAwayDurationPolicy.label(for: minutes)) {
                    viewModel.changePendingPhoneAwayDuration(to: minutes)
                }
            }
            Button("Keep \(viewModel.pendingWindDownStartContext?.durationMinutes ?? PhoneAwayDurationPolicy.defaultMinutes) minutes", role: .cancel) {}
        } message: {
            Text("Choose how long Phone Away should last after you start.")
        }
    }

    private var phoneAwayDurationChoice: some View {
        PixelCard {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Phone Away duration")
                        .font(AppTypography.body.weight(.semibold))
                    Text("Starts when you confirm. Choose 5–30 minutes.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                Spacer(minLength: AppSpacing.sm)
                Button("Change") {
                    showPhoneAwayDurationChoices = true
                }
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColors.grass)
                .accessibilityHint("Changes the manual Phone Away duration")
                Text("\(viewModel.pendingWindDownStartContext?.durationMinutes ?? PhoneAwayDurationPolicy.defaultMinutes) min")
                    .font(AppTypography.body.weight(.semibold))
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
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
                    Text("Selected: \(viewModel.shieldingSelectionSummary).")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                    Button("Review selection", action: chooseAppsToRest)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    Text("Counting Sheep cannot see the app names. You can revisit this selection here or in Settings.")
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
                    Button("Open Screen Time Settings", action: viewModel.openAppSettings)
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(AppColors.grass)
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
            if viewModel.screenTimeAuthorization != .approved {
                guard await viewModel.requestScreenTimeAuthorization() else {
                    viewModel.nightWatchStartStatus = viewModel.shieldingReadiness.detail
                    return
                }
            } else {
                viewModel.refreshScreenTimeState()
            }
            showScreenTimePicker = true
        }
#else
        viewModel.nightWatchStartStatus = viewModel.shieldingReadiness.detail
#endif
    }
}

/// A focused repair route used from Home and Settings. It never starts a run;
/// the action that led here remains separate so repair cannot become an
/// accidental scheduled or manual start.
struct ScreenTimeProtectionRepairView: View {
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
                    Text("Choose what can rest with your phone.")
                        .font(AppTypography.display(30))
                    Text("Counting Sheep uses only the private selection you make with Apple. It cannot see the names, and Counting Sheep stays available.")
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

                Text("When you return, review the selection here. Nothing starts automatically.")
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
            headerText: "Choose apps to limit during Wind Down and Phone Away.",
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

#Preview("Protection repair") {
    NavigationStack {
        ScreenTimeProtectionRepairView()
            .environmentObject(FocusRunViewModel(startsExternalServices: false))
    }
}
