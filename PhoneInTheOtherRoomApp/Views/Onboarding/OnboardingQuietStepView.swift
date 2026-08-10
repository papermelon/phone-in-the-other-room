import SwiftUI

struct OnboardingQuietStep: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "OPTIONAL CUES",
                title: "What should the quiet make room for?",
                detail: "Choose one small evening cue and one morning cue. Both are optional—leave either blank to skip it. Nothing is a checklist."
            )

            cueEditor(
                title: "In the evening",
                text: Binding(
                    get: { draft.eveningCueText ?? "" },
                    set: { draft.eveningCueText = PhoneFreeCue.normalized($0) }
                ),
                suggestions: PhoneFreeActivity.eveningChoices,
                selectedActivity: $draft.eveningActivity
            )
            cueEditor(
                title: "After waking",
                text: Binding(
                    get: { draft.morningCueText ?? "" },
                    set: { draft.morningCueText = PhoneFreeCue.normalized($0) }
                ),
                suggestions: PhoneFreeActivity.morningChoices,
                selectedActivity: $draft.morningActivity
            )
        }
    }

    private func cueEditor(
        title: String,
        text: Binding<String>,
        suggestions: [PhoneFreeActivity],
        selectedActivity: Binding<PhoneFreeActivity>
    ) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.headline)
                TextField("Optional: a book, a stretch, or a quiet moment", text: text)
                    .textFieldStyle(.roundedBorder)
                Text("A few ideas, if they help")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(suggestions) { activity in
                            Button(activity.title) {
                                selectedActivity.wrappedValue = activity
                                text.wrappedValue = activity.title
                            }
                            .font(AppTypography.caption)
                            .buttonStyle(PixelChipButtonStyle(isSelected: text.wrappedValue == activity.title))
                        }
                    }
                }
            }
        }
    }
}

#Preview("Optional cues") {
    var draft = OnboardingDraft()
    draft.eveningCueText = "Read a few pages"
    return OnboardingQuietStep(draft: .constant(draft))
        .padding()
        .background(AppColors.paper)
}
