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
                TextField("Add your own cue (optional)", text: text)
                    .textFieldStyle(.roundedBorder)
                Text("A few ideas, if they help")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 124), spacing: AppSpacing.xs)],
                    alignment: .leading,
                    spacing: AppSpacing.xs
                ) {
                    ForEach(suggestions) { activity in
                        Button {
                            selectedActivity.wrappedValue = activity
                            text.wrappedValue = activity.title
                        } label: {
                            Text(activity.title)
                                .font(AppTypography.caption)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                        .buttonStyle(PixelChipButtonStyle(isSelected: text.wrappedValue == activity.title))
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
