import SwiftUI

struct OnboardingQuietStep: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "PRIVATE ROUTINE",
                title: "What comes after the phone goes away?",
                detail: "Pick a few things you already like doing — or add your own. Counting Sheep can gently bring them back when Wind Down begins."
            )

            WindDownRoutineEditor(
                eveningSteps: $draft.eveningRoutine,
                morningSteps: $draft.morningRoutine,
                onChange: syncLegacyFields
            )
        }
    }

    private func syncLegacyFields() {
        var updated = draft
        updated.eveningCueText = updated.eveningRoutine.first?.kind == .custom
            ? updated.eveningRoutine.first?.customText
            : nil
        if let activity = updated.eveningRoutine.first?.activity { updated.eveningActivity = activity }
        updated.morningCueText = updated.morningRoutine.first?.kind == .custom
            ? updated.morningRoutine.first?.customText
            : nil
        if let activity = updated.morningRoutine.first?.activity { updated.morningActivity = activity }
        draft = updated
    }
}

#Preview("Optional cues") {
    var draft = OnboardingDraft()
    draft.eveningRoutine = [
        .suggested(.read, phase: .evening),
        .custom("Leave room for a sketch", phase: .evening)
    ]
    draft.morningRoutine = []
    return OnboardingQuietStep(draft: .constant(draft))
        .padding()
        .background(AppColors.paper)
}

#Preview("Optional cues · three ideas") {
    var draft = OnboardingDraft()
    draft.eveningRoutine = [
        .suggested(.read, phase: .evening),
        .suggested(.stretch, phase: .evening),
        .custom("Put tomorrow's worries on paper", phase: .evening)
    ]
    return OnboardingQuietStep(draft: .constant(draft))
        .padding()
        .background(AppColors.paper)
        .environment(\.dynamicTypeSize, .accessibility3)
}
