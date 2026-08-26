import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var optionalSupportExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                remindersCard

                if viewModel.notificationPreferences.remindersEnabled {
                    cadenceCard
                    optionalSupportCard
                    scheduleCard
                }

                messageWordingCard
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .settingsHelp(.remindersLockScreen)
        .onAppear { viewModel.refreshNotificationAuthorization() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Notifications")
                .font(AppTypography.display(32))
            Text("Choose how Ollie keeps the edges of your night in view.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
        }
    }

    private var remindersCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Toggle("Wind Down reminders", isOn: remindersBinding)
                    .font(AppTypography.headline)
                    .tint(AppColors.grass)

                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: authorizationIcon)
                        .foregroundStyle(authorizationColor)
                        .frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(authorizationText)
                            .font(AppTypography.caption)
                        if viewModel.notificationAuthorization == .denied {
                            Button("Open System Settings") {
                                viewModel.openNotificationSettings()
                            }
                            .font(AppTypography.caption)
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        } else if viewModel.notificationAuthorization == .notDetermined {
                            Button("Allow notifications") {
                                Task { @MainActor in
                                    _ = await viewModel.requestNotificationPermission()
                                }
                            }
                            .font(AppTypography.caption)
                            .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        }
                    }
                }

                Text("Cues stay on this iPhone and can be changed whenever your night changes.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private var cadenceCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Notification rhythm")
                    .font(AppTypography.headline)
                PixelSegmentedPicker(
                    title: "Notification rhythm",
                    selection: cadenceBinding,
                    label: { $0.title }
                )
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(viewModel.notificationPreferences.cadence.detail)
                        .font(AppTypography.body)
                    Text(String(viewModel.notificationPreferences.cadence.scheduledTouchpointCount) + " rhythm cues")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                    if viewModel.notificationPreferences.morningReflectionReminderEnabled {
                        Text("Morning reflection adds one more cue.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }
                if !viewModel.notificationPreferences.hasChosenCadence {
                    Text("Your existing reminder schedule stays in place until you choose a rhythm.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    private var optionalSupportCard: some View {
        PixelCard {
            DisclosureGroup(isExpanded: $optionalSupportExpanded) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Toggle("Sounds at start and completion", isOn: preferenceBinding(\.soundsEnabled))
                    Toggle("One gentle sleep tip per night", isOn: preferenceBinding(\.educationalTipsEnabled))
                    Toggle("Morning reflection reminder", isOn: preferenceBinding(\.morningReflectionReminderEnabled))
                    Toggle(
                        "Usage-aware reminders",
                        isOn: preferenceBinding(\.usageAwareRemindersEnabled)
                    )
                    .disabled(!viewModel.canUseUsageAwareReminders)

                    Text(viewModel.canUseUsageAwareReminders
                        ? "After three minutes in selected apps, Ollie can send one quiet cue in each phase."
                        : "Usage-aware reminders need Screen Time access and at least one selected app or category.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                .padding(.top, AppSpacing.sm)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                    Label("Optional support", systemImage: "sparkles")
                        .font(AppTypography.headline)
                    Spacer(minLength: AppSpacing.xs)
                    Text(optionalSupportSummary)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .multilineTextAlignment(.trailing)
                }
            }
            .tint(AppColors.ink)
        }
    }

    private var scheduleCard: some View {
        let preview = NotificationPreviewData.preview(for: viewModel)
        let notifications = preview.notifications
        return NavigationLink {
            NotificationSchedulePreviewView()
                .environmentObject(viewModel)
        } label: {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Label(preview.title, systemImage: "calendar.badge.clock")
                            .font(AppTypography.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.muted)
                    }
                    Text(OllieFormat.dateAndTime(preview.startDate))
                        .font(AppTypography.body)
                    HStack(alignment: .firstTextBaseline) {
                        Text(String(notifications.count) + " scheduled " + (notifications.count == 1 ? "cue" : "cues"))
                            .font(AppTypography.caption)
                        Spacer(minLength: AppSpacing.sm)
                        Text(cueSummary(notifications))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.grass)
                            .multilineTextAlignment(.trailing)
                    }
                    if preview.includesMorningReflection {
                        Text("Includes morning reflection")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                    Text("See scheduled cues")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows the cues planned for this phone-away time")
    }

    private var messageWordingCard: some View {
        NavigationLink {
            NotificationMessageLibraryView()
                .environmentObject(viewModel)
        } label: {
            PixelCard {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(AppColors.grass)
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Notification messages")
                            .font(AppTypography.headline)
                        Text(messageWordingSummary)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                    Spacer(minLength: AppSpacing.xs)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens notification message settings")
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { viewModel.notificationPreferences.remindersEnabled },
            set: { viewModel.setRemindersEnabled($0) }
        )
    }

    private var cadenceBinding: Binding<NotificationCadence> {
        Binding(
            get: { viewModel.notificationPreferences.cadence },
            set: { cadence in
                var updated = viewModel.notificationPreferences
                updated.cadence = cadence
                viewModel.updateNotificationPreferences(updated)
            }
        )
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

    private var optionalSupportSummary: String {
        let preferences = viewModel.notificationPreferences
        var enabled: [String] = []
        if preferences.soundsEnabled { enabled.append("sound") }
        if preferences.educationalTipsEnabled { enabled.append("tips") }
        if preferences.morningReflectionReminderEnabled { enabled.append("reflection") }
        if preferences.usageAwareRemindersEnabled { enabled.append("usage") }
        return enabled.isEmpty ? "None selected" : enabled.joined(separator: " · ")
    }

    private var messageWordingSummary: String {
        let count = viewModel.notificationPreferences.copyOverrides.count
        return count == 0 ? "Ollie’s defaults" : "\(count) customized"
    }

    private func cueSummary(_ notifications: [PlannedNotification]) -> String {
        guard let first = notifications.first, let last = notifications.last else {
            return "No future cues"
        }
        if first.id == last.id {
            return OllieFormat.time(first.date)
        }
        return OllieFormat.timeRange(from: first.date, to: last.date)
    }

    private var authorizationText: String {
        switch viewModel.notificationAuthorization {
        case .authorized, .provisional, .ephemeral: return "Apple notifications are available."
        case .denied: return "Apple notifications are blocked in iPhone settings."
        case .notDetermined: return "Counting Sheep has not asked for permission yet."
        @unknown default: return "Notification access is unavailable."
        }
    }

    private var authorizationIcon: String {
        switch viewModel.notificationAuthorization {
        case .authorized, .provisional, .ephemeral: return "checkmark.shield.fill"
        case .denied: return "bell.slash"
        default: return "bell.badge"
        }
    }

    private var authorizationColor: Color {
        switch viewModel.notificationAuthorization {
        case .authorized, .provisional, .ephemeral: return AppColors.grass
        case .denied: return AppColors.warning
        default: return AppColors.muted
        }
    }
}

/// View-layer preview support shared by the compact landing screen and the
/// schedule detail. The planner remains the single source of notification truth.
@MainActor
enum NotificationPreviewData {
    private static let fallbackSeed = UUID(uuid: (
        0x3A, 0x77, 0x8D, 0x45, 0x24, 0xCB, 0x46, 0x5F,
        0x91, 0x6E, 0xF0, 0x6E, 0xA5, 0x0D, 0xE3, 0x31
    ))

    struct Preview {
        let title: String
        let startDate: Date
        let notifications: [PlannedNotification]
        let includesMorningReflection: Bool
        let isAdditionalQuiet: Bool
    }

    static func preview(
        for viewModel: FocusRunViewModel,
        now: Date = Date()
    ) -> Preview {
        let activePlan = viewModel.activeRun?.nightWatchPlan
        let nextPeriod = activePlan == nil ? viewModel.nextUpcomingQuietPeriod : nil
        let start = viewModel.activeRun?.startedAt
            ?? nextPeriod?.occurrence.interval.start
            ?? viewModel.nightWatchPreferences.nextStart(after: now)
        let plan = activePlan
            ?? nextPeriod.map {
                WindDownScheduleEngine.plan(
                    for: $0,
                    preferences: viewModel.nightWatchPreferences,
                    startedAt: start
                )
            }
            ?? viewModel.nightWatchPreferences.makePlan(startedAt: start)
        let seed = viewModel.activeRun?.id
            ?? nextPeriod?.occurrence.id
            ?? fallbackSeed
        var notifications = NightWatchNotificationPlanBuilder.scheduledNotifications(
            for: plan,
            startedAt: start,
            cadence: viewModel.notificationPreferences.cadence,
            purpose: viewModel.offlinePurpose,
            seed: seed,
            educationalTipsEnabled: viewModel.notificationPreferences.educationalTipsEnabled,
            soundsEnabled: viewModel.notificationPreferences.soundsEnabled,
            copyOverrides: viewModel.notificationPreferences.copyOverrides,
            now: now
        )
        var includesReflection = false
        if plan.role == .primarySleepBookend,
           viewModel.notificationPreferences.morningReflectionReminderEnabled,
           let reflection = NightWatchNotificationPlanBuilder.reflectionNotification(
               at: plan.protectedUntil.addingTimeInterval(60 * 60),
               now: now,
               copyOverrides: viewModel.notificationPreferences.copyOverrides
           ) {
            notifications.append(reflection)
            includesReflection = true
        }
        let isAdditional = plan.role == .additionalQuiet
        let title: String
        if activePlan != nil {
            title = isAdditional ? "Current Phone Away" : "Current Wind Down"
        } else {
            title = isAdditional ? "Next Phone Away" : "Next Wind Down"
        }
        return Preview(
            title: title,
            startDate: start,
            notifications: notifications.sorted { $0.date < $1.date },
            includesMorningReflection: includesReflection,
            isAdditionalQuiet: isAdditional
        )
    }

    static func upcomingNotifications(
        for viewModel: FocusRunViewModel,
        now: Date = Date()
    ) -> [PlannedNotification] {
        preview(for: viewModel, now: now).notifications
    }
}

#Preview("Notifications · enabled") {
    NavigationStack {
        NotificationSettingsView()
            .environmentObject(FocusRunViewModel())
    }
}

#Preview("Notifications · disabled or denied") {
    NavigationStack {
        NotificationSettingsView()
            .environmentObject(makeDeniedNotificationViewModel())
    }
    .preferredColorScheme(.dark)
}

@MainActor
private func makeDeniedNotificationViewModel() -> FocusRunViewModel {
    let viewModel = FocusRunViewModel()
    viewModel.notificationPreferences.remindersEnabled = false
    viewModel.notificationAuthorization = .denied
    return viewModel
}
