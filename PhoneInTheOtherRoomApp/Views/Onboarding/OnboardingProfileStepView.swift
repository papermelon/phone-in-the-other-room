import SwiftUI

struct OnboardingProfileStep: View {
    @Binding var draft: OnboardingDraft

    private var question: WindDownProfileQuestion { draft.currentProfileQuestion }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "YOUR STARTING POINT",
                title: question.title,
                detail: question.detail
            )

            Text("QUESTION \(draft.profileQuestionIndex + 1) OF \(CountingSheepOnboarding.profileQuestions.count)")
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.grass)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            VStack(spacing: AppSpacing.xs) { questionChoices }

        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var questionChoices: some View {
        switch question {
        case .bedtimeDelay:
            ForEach(WindDownBedtimeDelay.allCases) { value in
                choice(value.title, icon: "moon.stars", selected: draft.profileAnswers.bedtimeDelay == value) {
                    draft.profileAnswers.bedtimeDelay = value
                    markAnswered()
                }
            }
        case .automaticReaching:
            ForEach(WindDownAutomaticReach.allCases) { value in
                choice(value.title, icon: "hand.tap", selected: draft.profileAnswers.automaticReaching == value) {
                    draft.profileAnswers.automaticReaching = value
                    markAnswered()
                }
            }
        case .morningChecking:
            ForEach(WindDownMorningCheck.allCases) { value in
                choice(value.title, icon: "sunrise", selected: draft.profileAnswers.morningChecking == value) {
                    draft.profileAnswers.morningChecking = value
                    markAnswered()
                }
            }
        case .overnightLocation:
            ForEach(WindDownOvernightLocation.allCases) { value in
                choice(value.title, icon: "bed.double", selected: draft.profileAnswers.overnightLocation == value) {
                    draft.profileAnswers.overnightLocation = value
                    markAnswered()
                }
            }
        case .awayFriction:
            ForEach(WindDownAwayFriction.questionnaireChoices) { value in
                choice(value.title, icon: icon(for: value), selected: frictionSelectionMatches(value)) {
                    draft.profileAnswers.mainFriction = value
                    draft.profileAnswers.awayFriction = value
                    markAnswered()
                }
            }
        case .desiredChange:
            ForEach(WindDownDesiredChange.questionnaireChoices) { value in
                choice(value.title, icon: "leaf", selected: draft.profileAnswers.desiredChange == value) {
                    draft.profileAnswers.desiredChange = value
                    markAnswered()
                }
            }
        case .usualSchedule, .phoneUsePattern, .eveningActivities,
             .morningActivities, .desiredWindDownLength:
            EmptyView()
        }
    }

    private func choice(
        _ title: String,
        icon: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        OnboardingChoiceCard(
            title: title,
            detail: "",
            icon: icon,
            isSelected: selected,
            action: action
        )
    }

    private func markAnswered() {
        draft.completedProfileQuestions.insert(question)
    }

    private func icon(for friction: WindDownAwayFriction) -> String {
        switch friction {
        case .habitReach: return "hand.tap.fill"
        case .unfinishedEvening: return "ellipsis.circle.fill"
        case .morningCheck: return "sun.max.fill"
        case .irregularDays: return "calendar.badge.clock"
        case .hardToStopFeed: return "rectangle.stack.fill"
        case .messages: return "message.fill"
        case .noDifficulty: return "leaf.fill"
        case .somethingElse: return "ellipsis"
        }
    }

    private func frictionSelectionMatches(_ value: WindDownAwayFriction) -> Bool {
        draft.profileAnswers.mainFriction == value
            || (value == .somethingElse && draft.profileAnswers.mainFriction == .noDifficulty)
    }
}

#Preview("Starting point · one question") {
    ScrollView {
        OnboardingProfileStep(draft: .constant(OnboardingDraft(step: .profile)))
            .padding()
    }
    .background(AppColors.paper)
}

#Preview("Questionnaire · narrow · large type") {
    var draft = OnboardingDraft(step: .profile)
    draft.profileQuestionIndex = 4
    return ScrollView {
        OnboardingProfileStep(draft: .constant(draft))
            .padding()
    }
    .frame(width: 320)
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}
