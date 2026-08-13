import SwiftUI

struct NotificationSchedulePreviewView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    private var notifications: [PlannedNotification] {
        preview.notifications
    }

    private var preview: NotificationPreviewData.Preview {
        NotificationPreviewData.preview(for: viewModel)
    }

    private var phaseGroups: [(phase: NightWatchPhase, notifications: [PlannedNotification])] {
        NightWatchPhase.allCases.compactMap { phase in
            let grouped = notifications.filter { $0.phase == phase }
            return grouped.isEmpty ? nil : (phase, grouped)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                intro
                if notifications.isEmpty {
                    emptyState
                } else {
                    ForEach(phaseGroups, id: \.phase) { group in
                        phaseSection(group.phase, notifications: group.notifications)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Scheduled cues")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(preview.title)
                .font(AppTypography.title)
            Text(introDetail)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
        }
    }

    private var introDetail: String {
        let date = OllieFormat.dateAndTime(preview.startDate)
        if preview.isAdditionalQuiet {
            return "Starts \(date). These cues end with this Phone Away period and stay separate from the overnight ritual."
        }
        return "Starts \(date). This is the finite cue schedule for this Wind Down. Usage-aware cues appear only after selected-app activity."
    }

    private func phaseSection(
        _ phase: NightWatchPhase,
        notifications: [PlannedNotification]
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(phase.title)
                .font(AppTypography.headline)
            PixelCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(notifications.enumerated()), id: \.element.id) { index, notification in
                        notificationRow(notification)
                        if index < notifications.count - 1 {
                            Divider()
                                .overlay(AppColors.stroke.opacity(0.16))
                                .padding(.vertical, AppSpacing.sm)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func notificationRow(_ notification: PlannedNotification) -> some View {
        let templateID = NotificationTemplateID.from(notificationID: notification.id)
        if let templateID, templateID.isEditable {
            NavigationLink {
                NotificationMessageEditorView(
                    templateID: templateID,
                    override: viewModel.notificationPreferences.copyOverride(for: templateID)
                )
                .environmentObject(viewModel)
            } label: {
                rowContent(notification, templateID: templateID, isNavigable: true)
            }
            .buttonStyle(.plain)
        } else {
            rowContent(notification, templateID: templateID, isNavigable: false)
        }
    }

    private func rowContent(
        _ notification: PlannedNotification,
        templateID: NotificationTemplateID?,
        isNavigable: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(notification.date.formatted(date: .abbreviated, time: .shortened))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                    Spacer(minLength: AppSpacing.sm)
                    Label(notification.playsSound ? "Sound" : "Silent", systemImage: notification.playsSound ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                Text(notification.title)
                    .font(AppTypography.body.weight(.bold))
                Text(notification.body)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let templateID, !templateID.isEditable {
                    Text("Fixed")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
            if isNavigable {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.muted)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isNavigable ? "Opens wording for this notification" : "This notification wording is fixed")
    }

    private var emptyState: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Image(systemName: "moon.zzz")
                    .font(.title2)
                    .foregroundStyle(AppColors.lavender)
                Text("The pasture is quiet tonight.")
                    .font(AppTypography.headline)
                Text("There are no future cues with the current reminder settings.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }
}

#Preview("Schedule preview") {
    NavigationStack {
        NotificationSchedulePreviewView()
            .environmentObject(FocusRunViewModel())
    }
}
