import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var editingTemplate: NotificationTemplateID?

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
                    upcomingSection
                    timelineSection
                }

                messageLibrarySection

                authorizationSection
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refreshNotificationAuthorization() }
        .sheet(item: $editingTemplate) { templateID in
            NotificationMessageEditorView(templateID: templateID)
                .environmentObject(viewModel)
        }
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
                    ? "After three accumulated minutes in apps to rest, Ollie can send one quiet cue in each phase."
                    : "Usage-aware reminders need approved Screen Time access and at least one app or category to rest.")
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

    private var upcomingSection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("Next Wind Down", systemImage: "calendar.badge.clock")
                    .font(AppTypography.headline)
                Text("This is the complete set of ritual notifications currently scheduled for the next Wind Down.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)

                if upcomingNotifications.isEmpty {
                    Text("There are no future notifications with the current settings.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else {
                    ForEach(upcomingNotifications) { notification in
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(notification.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(AppTypography.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.grass)
                                Spacer()
                                Text(notification.importance == .active ? "Active" : "Quiet")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.muted)
                            }
                            Text(notification.title)
                                .font(AppTypography.body.weight(.semibold))
                            Text(notification.body)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        .padding(.vertical, AppSpacing.xs)
                        if notification.id != upcomingNotifications.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var messageLibrarySection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Message library", systemImage: "text.bubble")
                        .font(AppTypography.headline)
                    Spacer()
                    Button("Reset all") {
                        viewModel.resetAllNotificationCopies()
                    }
                    .font(AppTypography.caption)
                    .disabled(viewModel.notificationPreferences.copyOverrides.isEmpty)
                }
                Text("Edit the words Ollie uses. Messages marked fixed stay read-only so protection notices remain accurate.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)

                ForEach(NotificationTemplateID.allCases) { templateID in
                    Button {
                        editingTemplate = templateID
                    } label: {
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Image(systemName: templateID.isEditable ? "pencil" : "lock.fill")
                                .foregroundStyle(templateID.isEditable ? AppColors.grass : AppColors.muted)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(templateID.title)
                                    .font(AppTypography.body.weight(.semibold))
                                Text(templateID.detail)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.muted)
                            }
                            Spacer(minLength: 0)
                            if viewModel.notificationPreferences.copyOverride(for: templateID) != nil {
                                Text("Custom")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.grass)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!templateID.isEditable)
                }
            }
        }
    }

    private var upcomingNotifications: [PlannedNotification] {
        let now = Date()
        let start = viewModel.activeRun?.startedAt ?? viewModel.nightWatchPreferences.nextStart(after: now)
        let plan = viewModel.activeRun?.nightWatchPlan
            ?? viewModel.nightWatchPreferences.makePlan(startedAt: start)
        var notifications = NightWatchNotificationPlanBuilder.scheduledNotifications(
            for: plan,
            startedAt: start,
            cadence: viewModel.notificationPreferences.cadence,
            purpose: viewModel.offlinePurpose,
            seed: viewModel.activeRun?.id ?? UUID(),
            educationalTipsEnabled: viewModel.notificationPreferences.educationalTipsEnabled,
            soundsEnabled: viewModel.notificationPreferences.soundsEnabled,
            copyOverrides: viewModel.notificationPreferences.copyOverrides,
            now: now
        )
        if viewModel.notificationPreferences.morningReflectionReminderEnabled,
           let reflection = NightWatchNotificationPlanBuilder.reflectionNotification(
               at: plan.protectedUntil.addingTimeInterval(60 * 60),
               now: now,
               copyOverrides: viewModel.notificationPreferences.copyOverrides
           ) {
            notifications.append(reflection)
        }
        return notifications.sorted { $0.date < $1.date }
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

private struct NotificationMessageEditorView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    let templateID: NotificationTemplateID
    @State private var title: String
    @State private var messageBody: String

    init(templateID: NotificationTemplateID) {
        self.templateID = templateID
        let override = PhoneNotificationService.shared.preferences.copyOverride(for: templateID)
        let defaults = Self.defaultCopy(for: templateID)
        _title = State(initialValue: override?.title ?? defaults.title)
        _messageBody = State(initialValue: override?.body ?? defaults.body)
    }

    var bodyView: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                    .onChange(of: title) { _, value in
                        title = String(value.prefix(NotificationCopyOverride.maximumTitleLength))
                    }
                Text("\(title.count)/\(NotificationCopyOverride.maximumTitleLength)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Title")
            }

            Section {
                TextEditor(text: $messageBody)
                    .frame(minHeight: 140)
                    .onChange(of: messageBody) { _, value in
                        messageBody = String(value.prefix(NotificationCopyOverride.maximumBodyLength))
                    }
                Text("\(messageBody.count)/\(NotificationCopyOverride.maximumBodyLength)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Message")
            }

            Section("Optional placeholders") {
                Text("You can write freely. These helpers are optional: {activity}, {purpose}, {time}, and {minutes}.")
                    .font(.caption)
                Text(Self.previewCopy(templateID: templateID, title: title, body: messageBody).body)
                    .font(.body)
                    .padding(.vertical, 4)
            }

            if !NotificationCopyRenderer.unresolvedPlaceholders(in: title + " " + messageBody).isEmpty {
                Section {
                    Text("Remove unsupported placeholders before saving.")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Save message") {
                    viewModel.updateNotificationCopy(for: templateID, title: title, body: messageBody)
                    dismiss()
                }
                .disabled(!NotificationCopyRenderer.unresolvedPlaceholders(in: title + " " + messageBody).isEmpty)
                Button("Restore Ollie’s wording") {
                    viewModel.resetNotificationCopy(for: templateID)
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(templateID.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    var body: some View {
        NavigationStack { bodyView }
    }

    private static func defaultCopy(for id: NotificationTemplateID) -> NightWatchNotificationCopy {
        previewCopy(templateID: id, title: nil, body: nil)
    }

    private static func previewCopy(
        templateID: NotificationTemplateID,
        title: String?,
        body: String?
    ) -> NightWatchNotificationCopy {
        let moment: NightWatchNotificationMoment
        switch templateID {
        case .windDownLeadIn60: moment = .windDownLeadIn(minutes: 60)
        case .windDownLeadIn30: moment = .windDownLeadIn(minutes: 30)
        case .windDownLeadIn10: moment = .windDownLeadIn(minutes: 10)
        case .windDownStart: moment = .windDownReminder
        case .windDownMidpoint: moment = .windDownMidpoint
        case .sleepTime: moment = .sleepTime
        case .phoneFreeMorning: moment = .phoneFreeMorning
        case .morningMidpoint: moment = .morningMidpoint
        case .complete: moment = .complete
        case .morningReflection: moment = .morningReflection
        case .usageWindDown: moment = .usageCue(.windDown)
        case .usageOvernight: moment = .usageCue(.overnight)
        case .usageMorningQuiet: moment = .usageCue(.morningQuiet)
        case .quietPeriodComplete: moment = .quietPeriodComplete
        case .shieldingFailed: moment = .shieldingFailed
        }
        return NotificationCopyResolver.resolve(
            id: templateID,
            moment: moment,
            context: NotificationCopyContext(
                activityTitle: "Read",
                purpose: "quiet time",
                tip: "Make a little room for quiet.",
                date: Date(timeIntervalSince1970: 1_700_000_000),
                minutes: templateID.minutes
            ),
            overrides: title == nil && body == nil
                ? []
                : [NotificationCopyOverride(id: templateID, title: title, body: body)]
        )
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
            .environmentObject(FocusRunViewModel())
    }
}
