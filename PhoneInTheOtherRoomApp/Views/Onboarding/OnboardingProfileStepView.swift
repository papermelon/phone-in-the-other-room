import SwiftUI

struct OnboardingProfileStep: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "WIND DOWN STARTING POINT",
                title: "A few questions, kept on this iPhone.",
                detail: "These answers help choose a starting point. They do not diagnose a sleep condition or name a disorder."
            )

            questionCard(.usualSchedule) {
                DatePicker("Bedtime", selection: bedtimeBinding, displayedComponents: .hourAndMinute)
                DatePicker("Wake time", selection: wakeBinding, displayedComponents: .hourAndMinute)
            }

            questionCard(.phoneUsePattern) {
                ForEach(WindDownPhoneUsePattern.allCases) { pattern in
                    OnboardingChoiceCard(
                        title: pattern.title,
                        detail: pattern.detail,
                        icon: "iphone",
                        isSelected: draft.profileAnswers.phoneUsePattern == pattern
                    ) {
                        updateAnswers { $0.phoneUsePattern = pattern }
                    }
                }
            }

            questionCard(.awayFriction) {
                ForEach(WindDownAwayFriction.allCases) { friction in
                    OnboardingChoiceCard(
                        title: friction.title,
                        detail: friction.detail,
                        icon: "moon.stars.fill",
                        isSelected: draft.profileAnswers.awayFriction == friction
                    ) {
                        updateAnswers { $0.awayFriction = friction }
                    }
                }
            }

            questionCard(.eveningActivities) {
                activityPicker(
                    choices: PhoneFreeActivity.eveningChoices,
                    selected: draft.profileAnswers.eveningActivities,
                    limit: WindDownRoutineStep.maximumEveningCount
                ) { activities in
                    updateAnswers { $0.eveningActivities = activities }
                }
            }

            questionCard(.morningActivities) {
                activityPicker(
                    choices: PhoneFreeActivity.morningChoices,
                    selected: draft.profileAnswers.morningActivities,
                    limit: WindDownRoutineStep.maximumMorningCount
                ) { activities in
                    updateAnswers { $0.morningActivities = activities }
                }
            }

            questionCard(.desiredWindDownLength) {
                Picker("Quiet before bed", selection: windDownMinutesBinding) {
                    ForEach(WindDownProfileAnswer.allowedWindDownMinutes, id: \.self) { minutes in
                        Text(QuietTimeDurationOptions.label(for: minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
            }
        }
    }

    private func questionCard<Content: View>(
        _ question: WindDownProfileQuestion,
        @ViewBuilder content: () -> Content
    ) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(question.title)
                    .font(AppTypography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(question.detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
                content()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(question.title)
    }

    private func activityPicker(
        choices: [PhoneFreeActivity],
        selected: [PhoneFreeActivity],
        limit: Int,
        onChange: @escaping ([PhoneFreeActivity]) -> Void
    ) -> some View {
        VStack(spacing: AppSpacing.xs) {
            ForEach(choices) { activity in
                let isSelected = selected.contains(activity)
                Button {
                    var next = selected
                    if isSelected {
                        next.removeAll { $0 == activity }
                    } else if next.count < limit {
                        next.append(activity)
                    }
                    onChange(next)
                } label: {
                    HStack {
                        Text(activity.title)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? AppColors.grass : AppColors.muted)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var bedtimeBinding: Binding<Date> {
        timeBinding(
            hour: draft.profileAnswers.bedtimeHour,
            minute: draft.profileAnswers.bedtimeMinute
        ) { hour, minute in
            updateAnswers {
                $0.bedtimeHour = hour
                $0.bedtimeMinute = minute
            }
        }
    }

    private var wakeBinding: Binding<Date> {
        timeBinding(
            hour: draft.profileAnswers.wakeHour,
            minute: draft.profileAnswers.wakeMinute
        ) { hour, minute in
            updateAnswers {
                $0.wakeHour = hour
                $0.wakeMinute = minute
            }
        }
    }

    private var windDownMinutesBinding: Binding<Int> {
        Binding(
            get: { draft.profileAnswers.desiredWindDownMinutes },
            set: { minutes in updateAnswers { $0.desiredWindDownMinutes = minutes } }
        )
    }

    private func timeBinding(
        hour: Int,
        minute: Int,
        onChange: @escaping (Int, Int) -> Void
    ) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                onChange(components.hour ?? hour, components.minute ?? minute)
            }
        )
    }

    private func updateAnswers(_ mutate: (inout WindDownProfileAnswer) -> Void) {
        var answers = draft.profileAnswers
        mutate(&answers)
        draft.profileAnswers = WindDownProfileAnswer(
            bedtimeHour: answers.bedtimeHour,
            bedtimeMinute: answers.bedtimeMinute,
            wakeHour: answers.wakeHour,
            wakeMinute: answers.wakeMinute,
            phoneUsePattern: answers.phoneUsePattern,
            awayFriction: answers.awayFriction,
            eveningActivities: answers.eveningActivities,
            morningActivities: answers.morningActivities,
            desiredWindDownMinutes: answers.desiredWindDownMinutes
        )
    }
}

#Preview("Questionnaire") {
    ScrollView {
        OnboardingProfileStep(draft: .constant(OnboardingDraft()))
            .padding()
    }
    .background(AppColors.paper)
}

#Preview("Questionnaire · dark · large type") {
    ScrollView {
        OnboardingProfileStep(draft: .constant(OnboardingDraft()))
            .padding()
    }
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}
