import SwiftUI

/// Optional starting-point and gift work is deliberately separate from committing
/// onboarding: revisiting it must never replace the person's routine or permissions.
struct OnboardingPersonalizationView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: OnboardingDraft
    @State private var loadedExistingChoices = false
    private let initialStep: OnboardingPersonalizationStep

    init(initialStep: OnboardingPersonalizationStep = .startingPoint) {
        self.initialStep = initialStep
        _draft = State(initialValue: OnboardingDraft(
            step: initialStep == .startingPoint ? .profile : .gift
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    content
                    if draft.step == .gift, let message = viewModel.farmActionMessage {
                        Text(message)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(AppSpacing.md)
            }
            .id("\(draft.step.rawValue)-\(draft.profileQuestionIndex)")
            .background(AppColors.paper.ignoresSafeArea())
            .foregroundStyle(AppColors.ink)
            .navigationTitle(draft.step == .gift ? "Your welcome gift" : "Your starting point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if draft.step == .profile, draft.profileQuestionIndex > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Back") { draft.profileQuestionIndex -= 1 }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        }
        .onAppear(perform: loadExistingChoices)
    }

    @ViewBuilder
    private var content: some View {
        switch draft.step {
        case .profile:
            OnboardingProfileStep(draft: $draft)
            Text("Optional and private. Your answers help describe a starting point; they do not change your plan.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
        case .recommendation:
            OnboardingRecommendationStep(
                draft: $draft,
                answers: draft.profileAnswers,
                recommendation: draft.profileRecommendation,
                showsSourcesLink: false
            )
            Button("Revisit my answers") {
                draft.profileQuestionIndex = 0
                draft.step = .profile
            }
            .font(AppTypography.caption.weight(.semibold))
            .frame(minHeight: 44)
        case .gift:
            OnboardingShepherdGiftStep(draft: $draft)
        default:
            EmptyView()
        }
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.xxs) {
            OnboardingPrimaryButton(title: primaryTitle, action: advance, isEnabled: canContinue)
            if let secondaryTitle {
                Button(secondaryTitle, action: skip)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .background(.ultraThinMaterial)
    }

    private var primaryTitle: String {
        switch draft.step {
        case .profile:
            return draft.profileQuestionIndex + 1 == CountingSheepOnboarding.profileQuestions.count
                ? "See my starting point" : "Next question"
        case .recommendation: return "Save starting point"
        case .gift: return viewModel.claimedWelcomeGiftItemID == nil ? "Wear now" : "Done"
        default: return "Done"
        }
    }

    private var secondaryTitle: String? {
        switch draft.step {
        case .profile: return "Skip questions"
        case .recommendation: return "Not now"
        case .gift:
            guard viewModel.claimedWelcomeGiftItemID == nil else { return nil }
            return draft.selectedWelcomeGiftItemID == nil ? "Choose later" : "Keep for later"
        default: return nil
        }
    }

    private var canContinue: Bool {
        switch draft.step {
        case .profile: return draft.hasAnsweredCurrentProfileQuestion
        case .recommendation: return draft.hasCompletedProfileQuestions
        case .gift:
            return viewModel.claimedWelcomeGiftItemID != nil || draft.selectedWelcomeGiftItemID != nil
        default: return true
        }
    }

    private func loadExistingChoices() {
        guard !loadedExistingChoices else { return }
        loadedExistingChoices = true
        draft.selectedWelcomeGiftItemID = viewModel.existingWelcomeGiftItemID
        if let record = viewModel.persistence.windDownProfileRecord {
            draft.profileAnswers = record.answers
            draft.completedProfileQuestions = Set(CountingSheepOnboarding.profileQuestions)
            if initialStep == .startingPoint { draft.step = .recommendation }
        }
    }

    private func advance() {
        switch draft.step {
        case .profile:
            draft.continueVisibleStep()
        case .recommendation:
            guard draft.hasCompletedProfileQuestions else { return }
            viewModel.applyWindDownStartingPoint(draft.profileAnswers)
            continueToGiftOrDismiss()
        case .gift:
            claimGift(wearNow: true)
        default:
            dismiss()
        }
    }

    private func skip() {
        if draft.step == .gift {
            claimGift(wearNow: false)
        } else {
            continueToGiftOrDismiss()
        }
    }

    private func continueToGiftOrDismiss() {
        if viewModel.claimedWelcomeGiftItemID == nil {
            draft.step = .gift
        } else {
            dismiss()
        }
    }

    private func claimGift(wearNow: Bool) {
        if viewModel.claimedWelcomeGiftItemID != nil {
            dismiss()
            return
        }
        guard let itemID = draft.selectedWelcomeGiftItemID else {
            if !wearNow { dismiss() }
            return
        }
        if viewModel.claimWelcomeGift(itemID, wearNow: wearNow) { dismiss() }
    }
}

#Preview("Optional starting point") {
    OnboardingPersonalizationView()
        .environmentObject(FocusRunViewModel())
}

#Preview("Optional welcome gift · large text") {
    OnboardingPersonalizationView(initialStep: .welcomeGift)
        .environmentObject(FocusRunViewModel())
        .environment(\.dynamicTypeSize, .accessibility3)
}
