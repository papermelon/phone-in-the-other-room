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
    private let isReplay: Bool

    init(
        initialDraft: OnboardingDraft? = nil,
        startsFresh: Bool = false,
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
        _draft = State(
            initialValue: normalizedDraft
        )
        self.onComplete = onComplete
        self.onCancel = onCancel
        self.isReplay = initialDraft != nil && !startsFresh
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressHeader(step: draft.step, onBack: previousStep)
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)

            ScrollView {
                stepContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
            }
            .id(draft.step)

            OnboardingPrimaryButton(
                title: primaryButtonTitle,
                action: advance,
                isEnabled: canContinue
            )
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)

            if draft.step == .ready, !isReplay {
                Button("Save and skip the tour") {
                    finish(showTour: false)
                }
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, AppSpacing.md)
            }

            Color.clear
                .frame(height: AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .toolbar {
            if let onCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .foregroundStyle(AppColors.ink)
        .onChange(of: draft) { _, updatedDraft in
            viewModel.saveOnboardingDraft(updatedDraft)
        }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        .familyActivityPicker(
            headerText: "Choose 1–3 apps or categories to rest during Wind Down, from the start through your morning quiet window.",
            footerText: "Counting Sheep limits this selection during Wind Down and always stays available. Websites are ignored.",
            isPresented: $showScreenTimePicker,
            selection: $viewModel.bedtimeActivitySelection
        )
        .onChange(of: viewModel.bedtimeActivitySelection) { _, _ in
            viewModel.saveScreenTimeSelection(.bedtime)
        }
#endif
    }

    @ViewBuilder
    private var stepContent: some View {
        switch draft.step {
        case .welcome:
            OnboardingWelcomeStep()
        case .schedule:
            OnboardingScheduleStep(draft: $draft)
        case .quiet:
            OnboardingQuietStep(draft: $draft)
        case .protection:
            OnboardingProtectionStep(
                draft: $draft,
                viewModel: viewModel,
                onChooseApps: chooseShieldedApps,
                showsNFCChoice: isReplay
            )
        case .automaticStart:
            OnboardingReadyStep(draft: draft, showsTourHandoff: !isReplay)
        case .ready:
            OnboardingReadyStep(draft: draft, showsTourHandoff: !isReplay)
        }
    }

    private var primaryButtonTitle: String {
        switch draft.step {
        case .welcome: return "Set up my Wind Down"
        case .ready: return isReplay ? "Save changes" : "Save and show me Home"
        default: return "Continue"
        }
    }

    private var canContinue: Bool {
        guard draft.step == .protection else { return true }
        guard draft.protectionChoice != .nfcAndAppShielding || viewModel.hasRegisteredNFCTag else { return false }
        return !draft.shieldingEnabled || viewModel.shieldingReadiness == .ready
    }

    private func previousStep() {
        guard let index = CountingSheepOnboardingStep.visibleSteps.firstIndex(of: draft.step), index > 0 else {
            return
        }
        draft.step = CountingSheepOnboardingStep.visibleSteps[index - 1]
    }

    private func advance() {
        if draft.step == .protection {
            draft.shieldingEnabled = draft.shieldingEnabled && viewModel.hasSelectedShieldingApps
        }

        if draft.step == .ready {
            finish(showTour: true)
            return
        }

        moveForward()
    }

    private func moveForward() {
        guard let index = CountingSheepOnboardingStep.visibleSteps.firstIndex(of: draft.step),
              index + 1 < CountingSheepOnboardingStep.visibleSteps.count else {
            return
        }
        draft.step = CountingSheepOnboardingStep.visibleSteps[index + 1]
    }

    private func finish(showTour: Bool) {
        var completedDraft = draft
        if !isReplay {
            // Reminders, automatic start, cadence, and sounds are chosen later in Settings.
            completedDraft.automaticStartEnabled = false
            completedDraft.remindersEnabled = false
        }
        if isReplay {
            // Settings replay edits the ritual plan without silently resetting
            // notification choices or the person's private reason for quiet.
            let existingNotifications = viewModel.notificationPreferences
            completedDraft.remindersEnabled = existingNotifications.remindersEnabled
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
}

#Preview {
    OnboardingFlowView(onComplete: {})
        .environmentObject(FocusRunViewModel())
}

#Preview("Onboarding · dark · large type") {
    OnboardingFlowView(onComplete: {})
        .environmentObject(FocusRunViewModel())
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
