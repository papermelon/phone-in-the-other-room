import SwiftUI

struct OnboardingScheduleStep: View {
    @Binding var draft: OnboardingDraft
    @ObservedObject var viewModel: FocusRunViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "YOUR NIGHT",
                title: "Give your night a gentle shape.",
                detail: "Choose the usual times and quiet you want around sleep. When the time comes, you still begin Wind Down yourself."
            )

            OnboardingTimeline(draft: draft)

            planSection(
                number: 1,
                title: "When I usually sleep",
                detail: "Your intended bedtime and wake time."
            ) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    DatePicker("Bedtime", selection: bedtimeBinding, displayedComponents: .hourAndMinute)
                    DatePicker("Wake time", selection: wakeBinding, displayedComponents: .hourAndMinute)
                }
            }

            planSection(
                number: 2,
                title: "How much quiet I want",
                detail: "A phone-free stretch before bed and after waking."
            ) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    durationPicker("Quiet before bed", selection: $draft.windDownMinutes)
                    Divider().padding(.vertical, AppSpacing.xs)
                    durationPicker("Quiet after waking", selection: $draft.morningQuietMinutes)
                    Text("Thirty minutes is a gentle place to begin. You can change both later.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .padding(.top, AppSpacing.xs)
                }
            }

            planSection(
                number: 3,
                title: "Whether I want a reminder",
                detail: "Optional. A reminder never starts Wind Down for you."
            ) {
                reminderControls
            }
        }
    }

    private var reminderControls: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label("A gentle reminder", systemImage: "bell.badge")
                .font(AppTypography.headline)
            Text("Counting Sheep can let you know when your planned Wind Down is ready to begin.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button(draft.remindersEnabled ? "Turn reminders off" : "Enable Wind Down reminders") {
                if draft.remindersEnabled {
                    draft.remindersEnabled = false
                } else {
                    draft.remindersEnabled = true
                    if viewModel.notificationAuthorization == .notDetermined {
                        Task { @MainActor in
                            _ = await viewModel.requestNotificationPermission()
                        }
                    }
                }
            }
            .buttonStyle(PixelChipButtonStyle(isSelected: draft.remindersEnabled))
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityAddTraits(draft.remindersEnabled ? .isSelected : [])

            if draft.remindersEnabled, viewModel.notificationAuthorization == .denied {
                Text("Reminders are on, but notification permission is off. Allow notifications in Settings before they can be delivered.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open notification settings") { viewModel.openNotificationSettings() }
                    .font(AppTypography.caption.weight(.semibold))
                    .frame(minHeight: 44)
            } else if draft.remindersEnabled, notificationAuthorized {
                Label("Notifications allowed", systemImage: "checkmark.circle.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.grass)
            } else if !draft.remindersEnabled {
                Text("Off. You can turn reminders on later in Settings.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func planSection<Content: View>(
        number: Int,
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Text("\(number)")
                    .font(AppTypography.caption.weight(.bold))
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 28, height: 28)
                    .background(AppColors.grass.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title).font(AppTypography.headline)
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(number). \(title). \(detail)")
    }

    private var notificationAuthorized: Bool {
        switch viewModel.notificationAuthorization {
        case .authorized, .provisional, .ephemeral: true
        default: false
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
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title)
                    .font(AppTypography.headline)
                Spacer()
                durationMenu(title, selection: selection)
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                durationMenu(title, selection: selection)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
    }

    private func durationMenu(_ title: String, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(QuietTimeDurationOptions.including(selection.wrappedValue), id: \.self) { minutes in
                Text(QuietTimeDurationOptions.label(for: minutes)).tag(minutes)
            }
        }
        .pickerStyle(.menu)
        .tint(AppColors.grass)
    }
}

#Preview("Schedule") {
    OnboardingScheduleStep(draft: .constant(OnboardingDraft()), viewModel: FocusRunViewModel())
        .padding()
        .background(AppColors.paper)
}

#Preview("Schedule · large type") {
    ScrollView {
        OnboardingScheduleStep(draft: .constant(OnboardingDraft()), viewModel: FocusRunViewModel())
            .padding()
    }
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
}
