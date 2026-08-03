import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Notifications")
                        .font(AppTypography.display(32))
                    Text("Choose how Ollie keeps the edges of your night in view. The overnight period stays quiet unless usage-aware support is enabled.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Toggle("Wind Down reminders", isOn: preferenceBinding(\.remindersEnabled))
                            .font(AppTypography.headline)
                        Text("Scheduled cues are local to this iPhone and can be changed whenever your night changes.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }

                if viewModel.notificationPreferences.remindersEnabled {
                    if !viewModel.notificationPreferences.hasChosenCadence {
                        PixelCard {
                            Label("Choose your notification rhythm", systemImage: "sparkles")
                                .font(AppTypography.headline)
                            Text("Your existing reminder schedule is still in place. Pick a cadence below when you are ready; optional tips, usage-aware reminders, and reflection reminders stay off until you enable them.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                        }
                    }
                    cadenceSection
                    optionalChannelsSection
                    timelineSection
                }

                authorizationSection
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refreshNotificationAuthorization() }
    }

    private var cadenceSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Your notification rhythm")
                .font(AppTypography.headline)
            ForEach(NotificationCadence.allCases) { cadence in
                Button {
                    var updated = viewModel.notificationPreferences
                    updated.cadence = cadence
                    viewModel.updateNotificationPreferences(updated)
                } label: {
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Image(systemName: cadence == .quiet ? "bell.slash" : "bell")
                            .foregroundStyle(AppColors.grass)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("\(cadence.title) · \(cadence.scheduledTouchpointCount) cues")
                                .font(AppTypography.headline)
                            Text(cadence.detail)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: viewModel.notificationPreferences.cadence == cadence ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.notificationPreferences.cadence == cadence ? AppColors.grass : AppColors.muted)
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.md)
                            .stroke(viewModel.notificationPreferences.cadence == cadence ? AppColors.grass : AppColors.stroke.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var optionalChannelsSection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Optional support")
                    .font(AppTypography.headline)
                Toggle("Sounds at start and completion", isOn: preferenceBinding(\.soundsEnabled))
                Toggle("One gentle sleep tip per night", isOn: preferenceBinding(\.educationalTipsEnabled))
                Toggle("Morning reflection reminder", isOn: preferenceBinding(\.morningReflectionReminderEnabled))
                Toggle(
                    "Usage-aware reminders",
                    isOn: preferenceBinding(\.usageAwareRemindersEnabled)
                )
                .disabled(!viewModel.canUseUsageAwareReminders)
                Text(viewModel.canUseUsageAwareReminders
                    ? "After three accumulated minutes in selected apps, Ollie can send one quiet cue in each phase."
                    : "Usage-aware reminders need approved Screen Time access and at least one selected app or category.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            .font(AppTypography.caption)
        }
    }

    private var timelineSection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("Tonight's timeline", systemImage: "timeline.selection")
                    .font(AppTypography.headline)
                ForEach(timelineRows, id: \.self) { row in
                    HStack(spacing: AppSpacing.sm) {
                        Circle()
                            .fill(AppColors.grass)
                            .frame(width: 7, height: 7)
                        Text(row)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
                Text("Tips replace a midpoint cue; they never add another scheduled notification. Usage cues are event-based and may appear overnight only after selected-app activity.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private var authorizationSection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("Apple notification access", systemImage: "checkmark.shield")
                    .font(AppTypography.headline)
                Text(authorizationText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                if viewModel.notificationAuthorization == .denied {
                    Button("Open System Settings") {
                        viewModel.openNotificationSettings()
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else if viewModel.notificationAuthorization == .notDetermined {
                    Button("Allow notifications") {
                        Task { @MainActor in
                            _ = await viewModel.requestNotificationPermission()
                        }
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
            }
        }
    }

    private var timelineRows: [String] {
        let cadence = viewModel.notificationPreferences.cadence
        var rows = cadence.leadInMinutes.map { "\($0) minutes before Wind Down" }
        rows.append("Wind Down begins")
        if cadence.includesWindDownMidpoint { rows.append("Wind-down midpoint") }
        rows.append("Configured bedtime")
        rows.append("Configured wake time")
        if cadence.includesMorningMidpoint { rows.append("Morning-quiet midpoint") }
        rows.append("Morning quiet completes")
        return rows
    }

    private var authorizationText: String {
        switch viewModel.notificationAuthorization {
        case .authorized, .provisional, .ephemeral: return "Notifications are available."
        case .denied: return "Notifications are blocked by iPhone settings."
        case .notDetermined: return "Counting Sheep has not asked for permission yet."
        @unknown default: return "Notification access is unavailable."
        }
    }

    private func preferenceBinding<T>(_ keyPath: WritableKeyPath<NotificationPreferences, T>) -> Binding<T> {
        Binding(
            get: { viewModel.notificationPreferences[keyPath: keyPath] },
            set: { value in
                var updated = viewModel.notificationPreferences
                updated[keyPath: keyPath] = value
                viewModel.updateNotificationPreferences(updated)
            }
        )
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
            .environmentObject(FocusRunViewModel())
    }
}
