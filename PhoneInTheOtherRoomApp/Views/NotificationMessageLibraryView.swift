import SwiftUI

struct NotificationMessageLibraryView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var showingResetConfirmation = false

    private let categories = NotificationMessageCategory.allCases

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                intro
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        ForEach(categories) { category in
                            NavigationLink {
                                NotificationMessageCategoryView(category: category)
                                    .environmentObject(viewModel)
                            } label: {
                                categoryRow(category)
                            }
                            .buttonStyle(.plain)
                            if category.id != categories.last?.id {
                                Divider()
                                    .overlay(AppColors.stroke.opacity(0.16))
                            }
                        }
                    }
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Restore defaults")
                            .font(AppTypography.headline)
                        Text("Restore Ollie’s original messages across the library.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                        Button("Restore all messages") {
                            showingResetConfirmation = true
                        }
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        .disabled(viewModel.notificationPreferences.copyOverrides.isEmpty)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Notification messages")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Restore Ollie’s defaults?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restore all messages", role: .destructive) {
                viewModel.resetAllNotificationCopies()
            }
            Button("Keep custom messages", role: .cancel) {}
        } message: {
            Text("Your custom notification messages will be removed. Fixed protection notices stay unchanged.")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Notification messages")
                .font(AppTypography.title)
            Text("Keep the words brief and kind. Fixed protection notices stay read-only.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
        }
    }

    private func categoryRow(_ category: NotificationMessageCategory) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: category.systemImage)
                .foregroundStyle(AppColors.grass)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(category.title)
                    .font(AppTypography.body.weight(.bold))
                Text(String(category.templates.count) + " " + (category.templates.count == 1 ? "message" : "messages"))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            Spacer(minLength: AppSpacing.xs)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.muted)
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

private struct NotificationMessageCategoryView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let category: NotificationMessageCategory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text(category.detail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        ForEach(Array(category.templates.enumerated()), id: \.element) { index, templateID in
                            templateRow(templateID)
                            if index < category.templates.count - 1 {
                                Divider()
                                    .overlay(AppColors.stroke.opacity(0.16))
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func templateRow(_ templateID: NotificationTemplateID) -> some View {
        if templateID.isEditable {
            NavigationLink {
                NotificationMessageEditorView(
                    templateID: templateID,
                    override: viewModel.notificationPreferences.copyOverride(for: templateID)
                )
                .environmentObject(viewModel)
            } label: {
                rowContent(templateID)
            }
            .buttonStyle(.plain)
        } else {
            rowContent(templateID)
        }
    }

    private func rowContent(_ templateID: NotificationTemplateID) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: templateID.isEditable ? "pencil" : "lock.fill")
                .foregroundStyle(templateID.isEditable ? AppColors.grass : AppColors.muted)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Text(templateID.title)
                        .font(AppTypography.body.weight(.bold))
                    if let stateLabel = stateLabel(for: templateID) {
                        Text(stateLabel)
                            .font(AppTypography.caption)
                            .foregroundStyle(stateLabel == "Custom" ? AppColors.grass : AppColors.muted)
                    }
                }
                Text(templateID.detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: AppSpacing.xs)
            if templateID.isEditable {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.muted)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(templateID.isEditable ? "Opens the message editor" : "Fixed protection wording")
    }

    private func stateLabel(for templateID: NotificationTemplateID) -> String? {
        if !templateID.isEditable { return "Fixed" }
        return viewModel.notificationPreferences.copyOverride(for: templateID) == nil ? nil : "Custom"
    }
}

private struct NotificationMessageCategory: Identifiable, CaseIterable, Equatable {
    enum ID: String, CaseIterable {
        case beforeWindDown
        case eveningAndBedtime
        case morning
        case usageAwareSupport
        case otherNotices
    }

    let id: ID
    let title: String
    let detail: String
    let systemImage: String
    let templates: [NotificationTemplateID]

    static let allCases: [Self] = [
        Self(
            id: .beforeWindDown,
            title: "Before Wind Down",
            detail: "Lead-in cues that help the phone find its bed.",
            systemImage: "arrow.down.to.line",
            templates: [.windDownLeadIn60, .windDownLeadIn30, .windDownLeadIn10, .windDownStart]
        ),
        Self(
            id: .eveningAndBedtime,
            title: "Evening and bedtime",
            detail: "Cues for the before-bed window and the quiet that follows.",
            systemImage: "moon.fill",
            templates: [.windDownMidpoint, .sleepTime]
        ),
        Self(
            id: .morning,
            title: "Morning",
            detail: "The gentle handoff into morning quiet and the receipt afterward.",
            systemImage: "sunrise.fill",
            templates: [.phoneFreeMorning, .morningMidpoint, .complete, .morningReflection]
        ),
        Self(
            id: .usageAwareSupport,
            title: "Usage-aware support",
            detail: "Optional cues after selected-app activity in each phase.",
            systemImage: "hand.raised.fill",
            templates: [.usageWindDown, .usageOvernight, .usageMorningQuiet]
        ),
        Self(
            id: .otherNotices,
            title: "Other notices",
            detail: "Bounded quiet-time receipts and protection status.",
            systemImage: "ellipsis.bubble.fill",
            templates: [.quietPeriodComplete, .shieldingFailed]
        )
    ]
}

#Preview("Message library · customized") {
    NavigationStack {
        NotificationMessageLibraryView()
            .environmentObject(FocusRunViewModel())
    }
}
