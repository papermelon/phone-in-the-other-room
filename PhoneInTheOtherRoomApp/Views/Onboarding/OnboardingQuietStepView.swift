import SwiftUI

struct OnboardingQuietStep: View {
    @Binding var draft: OnboardingDraft
    @State private var showsFullRoutine = false
    @State private var usesCustomActivity = false
    @State private var customActivity = ""

    private let firstIdeas: [PhoneFreeActivity] = [.read, .calmHobby, .stretch, .quietConversation]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "YOUR EVENING",
                title: "What would you like to make room for?",
                detail: "Choose one thing you would enjoy when the phone rests. You can leave this open and choose later."
            )

            if showsFullRoutine || draft.journeyRoute == .legacy {
                WindDownRoutineEditor(
                    eveningSteps: $draft.eveningRoutine,
                    morningSteps: $draft.morningRoutine,
                    onChange: syncLegacyFields
                )
            } else {
                firstActivityChoices
                Button("More ideas and morning routine") { showsFullRoutine = true }
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.grass)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }

            Text("These are invitations, not tasks to check off. You can revise your routine from Home.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            showsFullRoutine = showsFullRoutine || draft.eveningRoutine.count > 1 || !draft.morningRoutine.isEmpty
            usesCustomActivity = draft.eveningRoutine.first?.kind == .custom
            customActivity = usesCustomActivity ? draft.eveningRoutine.first?.customText ?? "" : ""
        }
        .onChange(of: customActivity) { _, text in
            guard usesCustomActivity else { return }
            replaceFirstIdea(with: PhoneFreeCue.normalized(text).map { .custom($0, phase: .evening) })
        }
    }

    private var firstActivityChoices: some View {
        VStack(spacing: AppSpacing.xs) {
            if let first = draft.eveningRoutine.first,
               !usesCustomActivity,
               !firstIdeas.contains(where: { $0 == first.activity }) {
                Label(first.title, systemImage: "checkmark.circle.fill")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.grass)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            ForEach(firstIdeas) { activity in
                OnboardingChoiceCard(
                    title: activity.shortTitle,
                    detail: "",
                    icon: activity.systemImage,
                    isSelected: !usesCustomActivity && draft.eveningRoutine.first?.activity == activity
                ) {
                    usesCustomActivity = false
                    replaceFirstIdea(with: .suggested(activity, phase: .evening))
                }
            }
            Button {
                usesCustomActivity = true
                replaceFirstIdea(with: PhoneFreeCue.normalized(customActivity).map { .custom($0, phase: .evening) })
            } label: {
                Label("Add my own", systemImage: "plus.circle")
                    .font(AppTypography.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PixelChipButtonStyle(isSelected: usesCustomActivity))
            if usesCustomActivity {
                TextField("Something you would enjoy", text: $customActivity, axis: .vertical)
                    .font(AppTypography.body)
                    .lineLimit(2...3)
                    .padding(AppSpacing.sm)
                    .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
                    .accessibilityLabel("Your evening activity")
                    .accessibilityHint("Optional. Up to 80 characters are saved.")
            }
            if !draft.eveningRoutine.isEmpty {
                Button("Leave the activity open for now") {
                    usesCustomActivity = false
                    draft.eveningRoutine = []
                    syncLegacyFields()
                }
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private func replaceFirstIdea(with step: WindDownRoutineStep?) {
        var steps = draft.eveningRoutine
        if !steps.isEmpty { steps.removeFirst() }
        if let step { steps.insert(step, at: 0) }
        draft.eveningRoutine = WindDownRoutineStep.normalized(steps, for: .evening)
        syncLegacyFields()
    }

    private func syncLegacyFields() {
        var updated = draft
        updated.eveningCueText = updated.eveningRoutine.first?.kind == .custom
            ? updated.eveningRoutine.first?.customText : nil
        if let activity = updated.eveningRoutine.first?.activity { updated.eveningActivity = activity }
        updated.morningCueText = updated.morningRoutine.first?.kind == .custom
            ? updated.morningRoutine.first?.customText : nil
        if let activity = updated.morningRoutine.first?.activity { updated.morningActivity = activity }
        draft = updated
    }
}

#Preview("One evening idea") {
    ScrollView {
        OnboardingQuietStep(draft: .constant(OnboardingDraft()))
            .padding()
    }
    .background(AppColors.paper)
}

#Preview("Existing routine · large text") {
    var draft = OnboardingDraft()
    draft.journeyRoute = .legacy
    draft.eveningRoutine = [.suggested(.read, phase: .evening), .custom("Leave room for a sketch", phase: .evening)]
    return ScrollView {
        OnboardingQuietStep(draft: .constant(draft))
            .padding()
    }
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
}
