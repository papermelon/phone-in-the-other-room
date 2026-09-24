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
    @State private var isRequestingAccess = false

#if DEBUG
    var previewReadiness: ShieldingReadiness?
#endif

    private var readiness: ShieldingReadiness {
#if DEBUG
        if let previewReadiness { return previewReadiness }
#endif
        return viewModel.shieldingReadiness
    }

    private var selectionSummary: String {
#if DEBUG
        if previewReadiness != nil { return "2 apps, 1 category" }
#endif
        return viewModel.shieldingSelectionSummary
    }

    private func refreshProtection() {
#if DEBUG
        guard previewReadiness == nil else { return }
#endif
        viewModel.refreshScreenTimeState()
    }

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
        case .primary, .none: return "WIND DOWN"
        }
    }

    private var startButtonTitle: String {
        if viewModel.isScanningNFCForStart { return "Waiting for your tag…" }
        if isManualPhoneAway { return "Start now" }
        if isAdHocQuiet {
            return "Start now"
        }
        if viewModel.pendingWindDownStartContext?.isPractice == true {
            let minutes = viewModel.pendingWindDownStartContext?.durationMinutes ?? 5
            return usesNFC ? "Tap tag to start practice" : "Start \(minutes)-minute practice"
        }
        if viewModel.pendingNightWatchIsAdditionalQuiet {
            return "Start now"
        }
        return "Put phone away"
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
            return "The timer begins when you tap Start now. Use the room beyond doomscrolling apps for reading, making, movement, cooking, conversation, rest, work, or anything else you value. Phone Away stays separate in Nights."
        }
        if isAdHocQuiet {
            return "This scheduled Phone Away period ends at \(adHocEndTime). Its saved end time stays in place while you confirm protection."
        }
        if viewModel.pendingNightWatchIsAdditionalQuiet {
            let end = viewModel.pendingNightWatchEndsAt.map(OllieFormat.time) ?? "the saved end time"
            let protection = " Counting Sheep requests limits for your chosen apps and categories until then."
            if viewModel.pendingWindDownStartContext?.isPractice == true {
                return "This practice ends at \(end). It creates a real Nights record without counting toward Wind Down search progress or the Phone Away meter. Finishing this one-time introduction lets Ollie bring home the second starter sheep.\(protection)"
            }
            return "This Phone Away period ends at \(end). Its minutes begin when you start, and it stays separate from Wind Down.\(protection)"
        }
        return usesNFC
            ? "After you choose Put phone away, tap your registered tag. Counting Sheep then requests limits for your selected apps and categories through Screen-Free Morning, including overnight. Counting Sheep stays available."
            : "Counting Sheep requests limits for your selected apps and categories from Wind Down start through Screen-Free Morning, including overnight. Counting Sheep stays available."
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
                    shieldingChoice

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

                    if !viewModel.pendingNightWatchIsAdditionalQuiet {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(viewModel.pendingWindDownHabitPlan.phonePlacement.actionCue)
                                .font(AppTypography.body.weight(.semibold))
                            if viewModel.pendingWindDownHabitPlan.phonePlacement == .accessibleNearby {
                                Text("Keep the communication and alerts you need available. Nearby placement uses the same selected-app limits; review your selection below.")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.muted)
                            }
                            if viewModel.pendingWindDownHabitPlan.useSmallerVersionNextTime,
                               let activity = WindDownHabitRules.smallerActivityInvitation(for: viewModel.pendingWindDownHabitPlan) {
                                Text("Smaller version: \(activity)")
                                    .font(AppTypography.body)
                                Text("One Wind Down only. Your timing and protection stay the same.")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.muted)
                            }
                        }
                    }

                    if viewModel.pendingNightWatchIsAdditionalQuiet {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("My tasks · optional").font(AppTypography.headline)
                            Text("Private to this session.").font(AppTypography.caption).foregroundStyle(AppColors.muted)
                            ForEach(0..<3, id: \.self) { index in
                                TextField("Task \(index + 1)", text: $viewModel.nextPhoneAwayTasks[index], axis: .vertical)
                                    .textFieldStyle(PixelTextFieldStyle())
                                    .font(AppTypography.body)
                                    .onChange(of: viewModel.nextPhoneAwayTasks[index]) { _, value in
                                        viewModel.nextPhoneAwayTasks[index] = String(value.prefix(120))
                                    }
                            }
                        }
                    }
                    nightFlockPrivacyChoice
                    if viewModel.pendingWindDownStartContext?.isPractice != true {
                        CampfireStartChoices(viewModel: viewModel)
                    }

                    Toggle(
                        isAdHocQuiet ? "Show on the Lock Screen" : "Show progress on the Lock Screen",
                        isOn: $viewModel.liveActivityChoiceForNextRun
                    )
                        .font(AppTypography.body)
                        .tint(AppColors.grass)
                }
                .padding(AppSpacing.lg)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { actions }
            .background(AppColors.paper.ignoresSafeArea())
        }
        .onAppear { refreshProtection() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshProtection()
        }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        .familyActivityPicker(
            headerText: viewModel.pendingNightWatchIsAdditionalQuiet
                ? "Choose apps to limit during this Phone Away period."
                : "Choose apps to limit from Wind Down start through Screen-Free Morning, including overnight.",
            footerText: "Counting Sheep stays available. Websites are ignored.",
            isPresented: $showScreenTimePicker,
            selection: $viewModel.bedtimeActivitySelection
        )
            .onChange(of: viewModel.bedtimeActivitySelection) { _, _ in
                viewModel.saveScreenTimeSelection(.bedtime)
                viewModel.appShieldingChoiceForNextRun = viewModel.shieldingReadiness == .ready
                viewModel.nightWatchStartStatus = ""
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

    private var shieldingChoice: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Label(readiness.title, systemImage: "apps.iphone")
                    .font(AppTypography.headline)
                if readiness == .ready {
                    Text("Selected: \(selectionSummary).")
                        .font(AppTypography.body)
                    Text("Ready for your next start. Limits have not been requested for this session yet.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Button("Review selection") { showScreenTimePicker = true }
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    Text("Counting Sheep cannot see the app names.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else {
                    Text(readiness.detail)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                    if readiness == .denied || readiness == .revoked {
                        Button("Open Settings", action: viewModel.openAppSettings)
                            .frame(minHeight: 44)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.grass)
                    }
                    if readiness == .runtimeFailure {
                        NavigationLink("Review protection setup") {
                            ScreenTimeProtectionRepairView()
                        }
                        .frame(minHeight: 44)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.grass)
                    }
                }
            }
        }
    }

    private var primaryActionTitle: String {
        if isRequestingAccess { return "Waiting for Screen Time…" }
        switch readiness.startSheetAction {
        case .requestAccess: return "Allow Screen Time access"
        case .restoreAccess: return "Restore Screen Time access"
        case .chooseApps: return "Choose apps or categories"
        case .retryProtection: return "Retry app protection"
        case .start: return startButtonTitle
        case .unavailable: return "App protection is unavailable"
        }
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.xs) {
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
            if readiness != .unavailable {
                Button(action: performPrimaryAction) {
                    Text(primaryActionTitle)
                        .font(AppTypography.body.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelPrimaryButtonStyle())
                .disabled(isRequestingAccess || viewModel.isScanningNFCForStart)
                .accessibilityHint(readiness == .ready
                    ? (usesNFC ? "Scan your registered tag to confirm this start." : "Starts the session you reviewed.")
                    : "Sets up protection. Your session will not start yet.")
            } else {
                Text(readiness.title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            Button("Not now") {
                viewModel.cancelNightWatchStart()
                dismiss()
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .font(AppTypography.body)
            .foregroundStyle(AppColors.muted)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.paper)
    }

    private func performPrimaryAction() {
        viewModel.nightWatchStartStatus = ""
        switch viewModel.shieldingReadiness.startSheetAction {
        case .requestAccess, .restoreAccess:
            isRequestingAccess = true
            Task { @MainActor in
                defer { isRequestingAccess = false }
                // Permission advances setup only. The picker and start each need a new tap.
                _ = await viewModel.requestScreenTimeAuthorization()
            }
        case .chooseApps:
            showScreenTimePicker = true
        case .retryProtection:
            viewModel.retryShielding()
            if viewModel.shieldingReadiness == .runtimeFailure {
                viewModel.nightWatchStartStatus = "Protection still needs repair. Review Screen Time access and your selection in Settings."
            }
        case .start:
            viewModel.confirmNightWatchStart()
        case .unavailable:
            break
        }
    }
}
