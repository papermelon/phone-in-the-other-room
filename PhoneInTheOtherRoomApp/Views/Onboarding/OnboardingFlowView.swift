import SwiftUI

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct OnboardingFlowView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var draft: OnboardingDraft
    @State private var isRequestingPermission = false
    #if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    @State private var showScreenTimePicker = false
    #endif
    let onComplete: () -> Void
    let onCancel: (() -> Void)?

    init(
        initialDraft: OnboardingDraft? = nil,
        onComplete: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        _draft = State(
            initialValue: initialDraft
                ?? PersistenceService.shared.onboardingDraft
                ?? OnboardingDraft.defaults()
        )
        self.onComplete = onComplete
        self.onCancel = onCancel
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
                title: draft.step == .ready ? "Save my Wind Down" : "Continue",
                action: advance,
                isEnabled: canContinue && !isRequestingPermission
            )
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.md)
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
            headerText: "Choose the apps or categories that can rest during Wind Down.",
            footerText: "Counting Sheep uses this selection only for the two quiet windows. Websites are ignored.",
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
        case .quiet:
            OnboardingQuietStep(draft: $draft)
        case .schedule:
            OnboardingScheduleStep(draft: $draft)
        case .protection:
            OnboardingProtectionStep(
                draft: $draft,
                viewModel: viewModel,
                onChooseApps: chooseShieldedApps
            )
        case .automaticStart:
            OnboardingAutomaticStartStep(draft: $draft)
        case .ready:
            OnboardingReadyStep(draft: draft)
        }
    }

    private var canContinue: Bool {
        guard draft.step == .protection else { return true }
        guard draft.protectionChoice != .nfcAndAppShielding || viewModel.hasRegisteredNFCTag else { return false }
        return !draft.shieldingEnabled || viewModel.shieldingReadiness == .ready
    }

    private func previousStep() {
        guard let previous = CountingSheepOnboardingStep(rawValue: draft.step.rawValue - 1) else { return }
        draft.step = previous
    }

    private func advance() {
        if draft.step == .protection {
            draft.shieldingEnabled = draft.shieldingEnabled && viewModel.hasSelectedShieldingApps
        }

        if draft.step == .automaticStart, draft.remindersEnabled, draft.automaticStartEnabled {
            isRequestingPermission = true
            Task { @MainActor in
                _ = await viewModel.requestNotificationPermission()
                isRequestingPermission = false
                moveForward()
            }
            return
        }

        if draft.step == .ready {
            viewModel.applyOnboardingDraft(draft)
            onComplete()
            return
        }

        moveForward()
    }

    private func moveForward() {
        guard let next = CountingSheepOnboardingStep(rawValue: draft.step.rawValue + 1) else { return }
        draft.step = next
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
