import SwiftUI

struct OnboardingQuietStep: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "PRIVATE ROUTINE",
                title: "Give the quiet a gentle shape.",
                detail: "Put the phone away first, then choose a few ideas for the evening and morning. They stay private and remain optional."
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
        if let custom = updated.eveningRoutine.first(where: { $0.kind == .custom }) {
            updated.eveningCueText = custom.customText
        } else {
            updated.eveningCueText = nil
        }
        if let activity = updated.eveningRoutine.first(where: { $0.kind == .suggestion })?.activity {
            updated.eveningActivity = activity
        }
        if let custom = updated.morningRoutine.first(where: { $0.kind == .custom }) {
            updated.morningCueText = custom.customText
        } else {
            updated.morningCueText = nil
        }
        if let activity = updated.morningRoutine.first(where: { $0.kind == .suggestion })?.activity {
            updated.morningActivity = activity
        }
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
