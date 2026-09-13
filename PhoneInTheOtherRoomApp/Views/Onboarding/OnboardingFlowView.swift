import SwiftUI

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct OnboardingFlowView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var draft: OnboardingDraft
    @State private var showsReturningAccount = false
    @State private var showsHomeTour = false
    #if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    @State private var showScreenTimePicker = false
    #endif
    let onComplete: () -> Void
    let onCancel: (() -> Void)?
    private let presentationMode: OnboardingPresentationMode
    private var isReplay: Bool { presentationMode.preservesExistingSettings }

    init(
        initialDraft: OnboardingDraft? = nil,
        startsFresh: Bool = false,
        presentationMode: OnboardingPresentationMode = .firstRun,
        onComplete: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        let restoredDraft = startsFresh
            ? OnboardingDraft.defaults()
            : (initialDraft ?? PersistenceService.shared.onboardingDraft ?? OnboardingDraft.defaults())
        var normalizedDraft = restoredDraft
        // Raw values are preserved for Codable compatibility with the previous flow.
        // The removed advanced-reminders page now lands on plan review.
        if normalizedDraft.step == .automaticStart {
            normalizedDraft.step = .ready
        }
        if presentationMode.preservesExistingSettings {
            normalizedDraft.journeyRoute = .legacy
            normalizedDraft.accountInvitationSkipped = true
        }
        if presentationMode == .fixture,
           !CountingSheepOnboardingStep.visibleSteps.contains(normalizedDraft.step) {
            normalizedDraft.journeyRoute = .legacy
        }
        normalizedDraft.welcomePage = normalizedDraft.welcomePage.normalizedForCurrentFlow
        _draft = State(
            initialValue: normalizedDraft
        )
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.presentationMode = presentationMode
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    OnboardingProgressHeader(
                        draft: draft,
                        showsBack: canGoBack,
                        onBack: previousStep
                    )
                    .padding(.bottom, AppSpacing.lg)

                    stepContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xl)
            }
            .id("\(draft.step.rawValue)-\(draft.welcomePage.rawValue)-\(draft.profileQuestionIndex)-\(draft.profileSkipped)")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if draft.step != .account { actionBar }
            }
            .background(AppColors.paper.ignoresSafeArea())
            .toolbar {
                if let onCancel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                }
                if !isReplay,
                   draft.step == .welcome,
                   draft.welcomePage.normalizedForCurrentFlow == .countingSheep {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Sign in") { showsReturningAccount = true }
                    }
                }
            }
            .foregroundStyle(AppColors.ink)
        }
        .onChange(of: draft) { _, updatedDraft in
            viewModel.saveOnboardingDraft(updatedDraft)
        }
        .onAppear { viewModel.refreshNotificationAuthorization() }
        .onReceive(viewModel.farmBackupViewModel.$restoreSuccess) { success in
            guard success != nil,
                  CountingSheepOnboarding.acceptsCommittedRestoreRoute(
                    presentationMode: presentationMode,
                    onboardingVersion: PersistenceService.shared.onboardingVersion
                  ),
                  !draft.returningUserDeviceSetup else { return }
            draft.beginReturningUserDeviceSetup()
            showsReturningAccount = false
        }
        .sheet(isPresented: $showsReturningAccount) {
            NavigationStack {
                ScrollView {
                    OnboardingAccountStep(
                        kind: .returning,
                        model: viewModel.farmBackupViewModel,
                        farmState: viewModel.farmState,
                        protectedNightCount: viewModel.coordinator.progress.farmCompletedRuns,
                        onContinue: {
                            showsReturningAccount = false
                            draft.returningUserDeviceSetup = false
                            draft.step = draft.journeyRoute == .planFirst ? .schedule : .profile
                        }
                    )
                    .padding(AppSpacing.md)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Not now") { showsReturningAccount = false }
                    }
                }
            }
        }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        .familyActivityPicker(
            headerText: "Choose 1–3 apps or categories to limit from Wind Down start through Screen-Free Morning, including overnight.",
            footerText: "The same selection is used during Phone Away. Counting Sheep stays available. Websites are ignored.",
            isPresented: $showScreenTimePicker,
            selection: $viewModel.bedtimeActivitySelection
        )
        .onChange(of: viewModel.bedtimeActivitySelection) { _, _ in
            viewModel.saveScreenTimeSelection(.bedtime)
            draft.protectionSelectionSelfConfirmed = false
        }
#endif
    }

    @ViewBuilder
    private var stepContent: some View {
        switch draft.step {
        case .welcome:
            OnboardingWelcomeStep(
                page: draft.welcomePage,
                starterSheep: viewModel.farmState.activeSheep.first {
                    $0.definitionID == WelcomeRewardCatalog.starterSheepID
                },
                protectedNightCount: viewModel.coordinator.progress.farmCompletedRuns
            )
        case .profile:
            OnboardingProfileStep(draft: $draft)
        case .recommendation:
            OnboardingRecommendationStep(
                draft: $draft,
                answers: draft.profileAnswers,
                recommendation: draft.profileRecommendation
            )
        case .schedule:
            OnboardingScheduleStep(draft: $draft, viewModel: viewModel)
        case .quiet:
            OnboardingQuietStep(draft: $draft)
        case .protection:
            OnboardingProtectionStep(
                draft: $draft,
                viewModel: viewModel,
                onChooseApps: chooseShieldedApps,
                showsNFCChoice: isReplay
            )
        case .gift:
            OnboardingShepherdGiftStep(draft: $draft)
        case .account:
            OnboardingAccountStep(
                kind: .newUser,
                model: viewModel.farmBackupViewModel,
                farmState: viewModel.farmState,
                protectedNightCount: viewModel.coordinator.progress.farmCompletedRuns,
                onContinue: moveForward
            )
        case .automaticStart, .ready:
            OnboardingReadyStep(
                draft: draft,
                showsTourHandoff: !isReplay,
                showsSlumberParty: viewModel.nightFlockViewModel.featureEnabled,
                appProtectionReady: viewModel.shieldingReadiness == .ready,
                notificationAuthorization: viewModel.notificationAuthorization
            )
        }
    }

    private var primaryButtonTitle: String {
        switch draft.step {
        case .welcome:
            if draft.welcomePage.normalizedForCurrentFlow != .ollie { return "Get started" }
            return draft.journeyRoute == .planFirst ? "Make my evening plan" : "Find my starting point"
        case .profile:
            return draft.profileQuestionIndex + 1 == CountingSheepOnboarding.profileQuestions.count
                ? "See my starting point"
                : "Next question"
        case .recommendation:
            return "Continue"
        case .gift:
            return viewModel.claimedWelcomeGiftItemID == nil ? "Wear now" : "Continue"
        case .account:
            return "Continue without an account"
        case .ready:
            return isReplay ? "Save changes" : "Go to Home"
        default:
            return "Continue"
        }
    }

    private var skipButtonTitle: String? {
        if draft.step == .welcome {
            return "Skip intro"
        }
        if draft.step == .profile {
            return "Skip questions"
        }
        if draft.step == .gift, viewModel.claimedWelcomeGiftItemID == nil {
            return draft.selectedWelcomeGiftItemID == nil ? "Choose later" : "Keep for later"
        }
        if draft.step == .protection {
            return "Set up protection later"
        }
        return nil
    }

    private var canGoBack: Bool {
        if draft.step == .welcome {
            return draft.welcomePage.normalizedForCurrentFlow != .countingSheep
        }
        return draft.journeySteps.firstIndex(of: draft.step) ?? 0 > 0
    }

    private var canContinue: Bool {
        if draft.step == .profile {
            return draft.hasAnsweredCurrentProfileQuestion
        }
        if draft.step == .gift {
            return viewModel.claimedWelcomeGiftItemID != nil
                || draft.selectedWelcomeGiftItemID != nil
        }
        guard draft.step == .protection else { return true }
        guard draft.protectionChoice != .nfcAndAppShielding || viewModel.hasRegisteredNFCTag else { return false }
        return viewModel.shieldingReadiness == .ready && draft.protectionSelectionSelfConfirmed
    }

    private func previousStep() {
        if draft.step == .profile, draft.profileQuestionIndex > 0 {
            draft.profileQuestionIndex -= 1
            return
        }
        if draft.step == .welcome,
           draft.welcomePage.normalizedForCurrentFlow == .ollie {
            draft.welcomePage = .countingSheep
            return
        }
        let steps = draft.journeySteps
        guard let index = steps.firstIndex(of: draft.step), index > 0 else {
            return
        }
        draft.step = steps[index - 1]
        if draft.step == .welcome {
            draft.welcomePage = OnboardingWelcomePage.visiblePages.last ?? .ollie
        }
    }

    private func advance() {
        if draft.step == .gift {
            claimGiftAndContinue(wearNow: true)
            return
        }
        if draft.step == .protection {
            draft.shieldingEnabled = draft.shieldingEnabled && viewModel.hasSelectedShieldingApps
        }
        if draft.step == .ready {
            finish(showTour: showsHomeTour)
            return
        }
        moveForward()
    }

    private func skipCurrent() {
        if draft.step == .gift {
            claimGiftAndContinue(wearNow: false)
            return
        }
        let effect = draft.skipVisibleStep()
        if effect == .keepCompletedProfile {
            viewModel.applyWindDownStartingPoint(draft.profileAnswers)
        }
    }

    private func moveForward() {
        let effect = draft.continueVisibleStep()
        if effect == .grantStartingPoint {
            viewModel.applyWindDownStartingPoint(draft.profileAnswers)
        }
    }

    private func claimGiftAndContinue(wearNow: Bool) {
        if viewModel.claimedWelcomeGiftItemID != nil {
            draft.moveToNextVisibleStep()
            return
        }
        guard let itemID = draft.selectedWelcomeGiftItemID else {
            if !wearNow { draft.moveToNextVisibleStep() }
            return
        }
        guard viewModel.claimWelcomeGift(itemID, wearNow: wearNow) else { return }
        draft.moveToNextVisibleStep()
    }

    private func finish(showTour: Bool) {
        var completedDraft = draft
        if !isReplay {
            // A schedule describes eligibility. Beginning Wind Down remains manual.
            completedDraft.automaticStartEnabled = false
        }
        if isReplay {
            // Settings replay edits the ritual plan without silently resetting
            // notification choices or the person's private reason for quiet.
            let existingNotifications = viewModel.notificationPreferences
            completedDraft.notificationCadence = existingNotifications.cadence
            completedDraft.notificationSoundsEnabled = existingNotifications.soundsEnabled
            completedDraft.educationalTipsEnabled = existingNotifications.educationalTipsEnabled
            completedDraft.usageAwareRemindersEnabled = existingNotifications.usageAwareRemindersEnabled
            completedDraft.morningReflectionReminderEnabled = existingNotifications.morningReflectionReminderEnabled
            completedDraft.purposeCategory = viewModel.offlinePurpose.category
            completedDraft.customPurpose = viewModel.offlinePurpose.customText
            completedDraft.allowsCustomTextInNotifications = viewModel.offlinePurpose.allowsCustomTextInNotifications
        }
        viewModel.applyOnboardingDraft(
            completedDraft,
            preserveAdvancedNotifications: isReplay,
            showTourAfterOnboarding: isReplay ? nil : showTour
        )
        onComplete()
    }

    private func chooseShieldedApps() {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        showScreenTimePicker = true
#endif
    }

    private var actionBar: some View {
        VStack(spacing: AppSpacing.xxs) {
            if draft.step == .ready, !isReplay {
                Toggle("Show a short Home tour", isOn: $showsHomeTour)
                    .font(AppTypography.caption)
                    .tint(AppColors.grass)
                    .frame(minHeight: 44)
            }
            OnboardingPrimaryButton(
                title: primaryButtonTitle,
                action: advance,
                isEnabled: canContinue
            )

            if let skipTitle = skipButtonTitle {
                Button(skipTitle) {
                    skipCurrent()
                }
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.xs)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.35)
        }
    }
}

#Preview {
    OnboardingFlowView(onComplete: {})
        .environmentObject(FocusRunViewModel())
}

#Preview("Onboarding · questionnaire") {
    OnboardingFlowView(initialDraft: OnboardingDraft(step: .profile), presentationMode: .fixture, onComplete: {})
        .environmentObject(FocusRunViewModel())
}

#Preview("Onboarding · recommendation") {
    OnboardingFlowView(initialDraft: OnboardingDraft(step: .recommendation), presentationMode: .fixture, onComplete: {})
        .environmentObject(FocusRunViewModel())
}

#Preview("Onboarding · profile gift") {
    OnboardingFlowView(initialDraft: OnboardingDraft(step: .gift), presentationMode: .fixture, onComplete: {})
        .environmentObject(FocusRunViewModel())
}

#Preview("Onboarding · shielding declined") {
    let viewModel = FocusRunViewModel()
    viewModel.screenTimeAuthorization = .denied("Preview")
    var draft = OnboardingDraft(step: .protection)
    draft.shieldingEnabled = false
    return OnboardingFlowView(initialDraft: draft, presentationMode: .fixture, onComplete: {})
        .environmentObject(viewModel)
}

#Preview("Onboarding · dark · large type") {
    OnboardingFlowView(onComplete: {})
        .environmentObject(FocusRunViewModel())
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
