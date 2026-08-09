import SwiftUI

struct OnboardingScheduleStep: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "YOUR NIGHT",
                title: "Set the edges of your night.",
                detail: "Wind Down starts before bedtime, keeps the phone away overnight, and continues through your morning quiet window. You can change the times later."
            )

            OnboardingTimeline(draft: draft)

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    DatePicker("Bedtime", selection: bedtimeBinding, displayedComponents: .hourAndMinute)
                    DatePicker("Wake time", selection: wakeBinding, displayedComponents: .hourAndMinute)
                }
            }

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    durationPicker("Quiet before bed", selection: $draft.windDownMinutes)
                    Divider().padding(.vertical, AppSpacing.xs)
                    durationPicker("Quiet after waking", selection: $draft.morningQuietMinutes)
                    Text("Thirty minutes is a gentle place to begin. Both quiet windows are editable later.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .padding(.top, AppSpacing.xs)
                }
            }
        }
    }

    private var bedtimeBinding: Binding<Date> {
        timeBinding(hour: draft.bedtimeHour, minute: draft.bedtimeMinute) { hour, minute in
            draft.bedtimeHour = hour
            draft.bedtimeMinute = minute
        }
    }

    private var wakeBinding: Binding<Date> {
        timeBinding(hour: draft.wakeHour, minute: draft.wakeMinute) { hour, minute in
            draft.wakeHour = hour
            draft.wakeMinute = minute
        }
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

    private func durationPicker(_ title: String, selection: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.headline)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(QuietTimeDurationOptions.including(selection.wrappedValue), id: \.self) { minutes in
                    Text(QuietTimeDurationOptions.label(for: minutes)).tag(minutes)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColors.grass)
        }
    }
}

#Preview("Schedule") {
    OnboardingScheduleStep(draft: .constant(OnboardingDraft()))
        .padding()
        .background(AppColors.paper)
}
