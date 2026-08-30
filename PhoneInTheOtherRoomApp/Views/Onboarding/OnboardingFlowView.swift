import SwiftUI

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct OnboardingFlowView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var draft: OnboardingDraft
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
        // The removed advanced-reminders page now lands on the saved-plan screen.
        if normalizedDraft.step == .automaticStart {
            normalizedDraft.step = .ready
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
            .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
            .background(AppColors.paper.ignoresSafeArea())
            .toolbar {
                if let onCancel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                }
            }
            .foregroundStyle(AppColors.ink)
        }
        .onChange(of: draft) { _, updatedDraft in
            viewModel.saveOnboardingDraft(updatedDraft)
        }
        .onAppear { viewModel.refreshNotificationAuthorization() }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        .familyActivityPicker(
            headerText: "Choose 1–3 apps or categories to pause for Wind Down and the linked Screen-Free Morning.",
            footerText: "Counting Sheep limits this selection during Wind Down and always stays available. Websites are ignored.",
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
                protectedNightCount: viewModel.coordinator.progress.totalCompletedRuns
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
            return draft.welcomePage.normalizedForCurrentFlow == .ollie ? "Find my starting point" : "Meet Ollie"
        case .profile:
            return draft.profileQuestionIndex + 1 == CountingSheepOnboarding.profileQuestions.count
                ? "See my starting point"
                : "Next question"
        case .recommendation:
            return "Continue"
        case .gift:
            return viewModel.claimedWelcomeGiftItemID == nil ? "Wear now" : "Continue"
        case .ready:
            return isReplay ? "Save changes" : "Save and show me Home"
        default:
            return "Continue"
        }
    }

    private var skipButtonTitle: String? {
        if draft.step == .ready, !isReplay {
            return "Save and skip the tour"
        }
        if draft.step == .welcome {
            return "Skip intro"
        }
        if draft.step == .profile {
            return "Skip questions"
        }
        if draft.step == .gift, viewModel.claimedWelcomeGiftItemID == nil {
            return "Keep for later"
        }
        if draft.step == .protection {
            return nil
        }
        return nil
    }

    private var canGoBack: Bool {
        if draft.step == .welcome {
            return draft.welcomePage.normalizedForCurrentFlow != .countingSheep
        }
        return CountingSheepOnboardingStep.visibleSteps.firstIndex(of: draft.step) ?? 0 > 0
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
        guard let index = CountingSheepOnboardingStep.visibleSteps.firstIndex(of: draft.step), index > 0 else {
            return
        }
        var previous = CountingSheepOnboardingStep.visibleSteps[index - 1]
        if draft.profileSkipped, previous == .recommendation {
            previous = .profile
        }
        draft.step = previous
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
            finish(showTour: true)
            return
        }
        moveForward()
    }

    private func skipCurrent() {
        if draft.step == .ready {
            finish(showTour: false)
            return
        }
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
        guard let itemID = draft.selectedWelcomeGiftItemID,
              viewModel.claimWelcomeGift(itemID, wearNow: wearNow) else { return }
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
