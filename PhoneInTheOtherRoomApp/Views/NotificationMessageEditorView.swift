import SwiftUI

struct NotificationMessageEditorView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss

    let templateID: NotificationTemplateID
    @State private var title: String
    @State private var messageBody: String
    @State private var placeholdersExpanded = false

    init(templateID: NotificationTemplateID, override: NotificationCopyOverride? = nil) {
        self.templateID = templateID
        let defaults = Self.defaultCopy(for: templateID)
        _title = State(initialValue: override?.title ?? defaults.title)
        _messageBody = State(initialValue: override?.body ?? defaults.body)
    }

    private var unresolvedPlaceholders: [String] {
        NotificationCopyRenderer.unresolvedPlaceholders(in: title + " " + messageBody)
    }

    private var renderedCopy: NightWatchNotificationCopy {
        Self.previewCopy(templateID: templateID, title: title, body: messageBody)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                livePreview
                titleSection
                messageSection
                placeholdersSection
                renderedPreview

                if !unresolvedPlaceholders.isEmpty {
                    validationNotice
                }

                actions
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle(templateID.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Live preview")
                .font(AppTypography.headline)
            PixelCard {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(AppColors.grass)
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(renderedCopy.title)
                            .font(AppTypography.body.weight(.bold))
                        Text(renderedCopy.body)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var titleSection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Title")
                        .font(AppTypography.headline)
                    Spacer()
                    Text(String(title.count) + "/" + String(NotificationCopyOverride.maximumTitleLength))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                titleField
            }
        }
    }

    private var messageSection: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Message")
                        .font(AppTypography.headline)
                    Spacer()
                    Text(String(messageBody.count) + "/" + String(NotificationCopyOverride.maximumBodyLength))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                messageEditor
            }
        }
    }

    private var placeholdersSection: some View {
        PixelCard {
            DisclosureGroup(isExpanded: $placeholdersExpanded) {
                Text("These are optional helpers. Use {activity} for the chosen offline activity, {purpose} for the quiet-time reason, {time} for the cue time, and {minutes} for a lead-in length.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.sm)
            } label: {
                Text("Optional placeholders")
                    .font(AppTypography.headline)
            }
            .tint(AppColors.ink)
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            TextField("Notification title", text: $title)
                .textFieldStyle(.roundedBorder)
                .onChange(of: title) { _, value in
                    title = String(value.prefix(NotificationCopyOverride.maximumTitleLength))
                }
            Text(titleCountLabel)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notification title")
        .accessibilityValue(titleCountLabel)
    }

    private var messageEditor: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            TextEditor(text: $messageBody)
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                .onChange(of: messageBody) { _, value in
                    messageBody = String(value.prefix(NotificationCopyOverride.maximumBodyLength))
                }
            Text(messageCountLabel)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notification message")
        .accessibilityValue(messageCountLabel)
    }

    private var titleCountLabel: String {
        String(format: "%d of %d characters", title.count, NotificationCopyOverride.maximumTitleLength)
    }

    private var messageCountLabel: String {
        String(format: "%d of %d characters", messageBody.count, NotificationCopyOverride.maximumBodyLength)
    }

    private var renderedPreview: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Rendered sample")
                    .font(AppTypography.headline)
                Text(renderedCopy.body)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var validationNotice: some View {
        PixelCard {
            Label {
                Text("Remove " + unresolvedPlaceholders.joined(separator: ", ") + " before saving.")
                    .font(AppTypography.caption)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "text.badge.xmark")
                    .foregroundStyle(AppColors.warning)
            }
            .foregroundStyle(AppColors.ink)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            Button("Save message") {
                viewModel.updateNotificationCopy(for: templateID, title: title, body: messageBody)
                dismiss()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(PixelPrimaryButtonStyle())
            .disabled(!unresolvedPlaceholders.isEmpty || !templateID.isEditable)

            Button("Restore Ollie’s wording") {
                viewModel.resetNotificationCopy(for: templateID)
                dismiss()
            }
            .frame(minHeight: 44)
            .font(AppTypography.body)
            .foregroundStyle(AppColors.muted)
            .disabled(!templateID.isEditable)
        }
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
        let context = NotificationCopyContext(
            activityTitle: "Read",
            purpose: "quiet time",
            tip: "Make a little room for quiet.",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            minutes: templateID.minutes
        )
        let override = title == nil && body == nil
            ? nil
            : NotificationCopyOverride(id: templateID, title: title, body: body)
        return NotificationCopyResolver.resolve(
            id: templateID,
            moment: moment,
            context: context,
            overrides: override.map { [$0] } ?? []
        )
    }
}

#Preview("Message editor · custom") {
    NavigationStack {
        NotificationMessageEditorView(
            templateID: .windDownStart,
            override: NotificationCopyOverride(
                id: .windDownStart,
                title: "A softer start",
                body: "The phone can rest now. Make room for a quiet page."
            )
        )
        .environmentObject(FocusRunViewModel())
    }
}
