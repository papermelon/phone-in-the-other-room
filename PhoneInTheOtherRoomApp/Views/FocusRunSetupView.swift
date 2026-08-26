import SwiftUI

struct FocusRunSetupView: View {
    private enum PlanRoutineSection { case schedule, routine }
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var purposeCategory: OfflinePurposeCategory = .rest
    @State private var customPurpose = ""
    @State private var includePurposeInNotifications = false
    @State private var expandedSection: PlanRoutineSection? = .schedule

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                hero
                if viewModel.isRunning {
                    PixelCard {
                        Label(
                            "Your current Wind Down stays unchanged. These choices begin with the next one.",
                            systemImage: "calendar.badge.clock"
                        )
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    }
                }
                tonightPlanAccordion
                privateRoutineAccordion
                NavigationLink {
                    SettingsProtectionTagsView()
                        .environmentObject(viewModel)
                } label: {
                    PixelCard {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(AppColors.grass)
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text("Protection & tags")
                                    .font(AppTypography.headline)
                                Text("Manage app limits, NFC tags, and automatic start.")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppColors.muted)
                        }
                        .frame(minHeight: 44)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Wind Down")
        .navigationBarTitleDisplayMode(.inline)
        .settingsHelp(.planRoutine)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            setupActionBar
        }
        .onAppear(perform: loadPurpose)
        .onChange(of: viewModel.isRunning) { _, isRunning in
            if isRunning { dismiss() }
        }
    }

    private var hero: some View {
        VStack(spacing: AppSpacing.sm) {
            OllieRitualView(state: .ready, presentation: .cardCompanion)
            Text("Put your phone to bed")
                .font(AppTypography.display(32))
            Text("Protect the quiet before sleep, then wake up before your phone does.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private var tonightPlanCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                setupSectionHeader(
                    title: "Tonight's plan",
                    detail: "Bedtime, wake time, and two quiet windows.",
                    systemImage: "moon.stars.fill"
                )
                DatePicker(
                    "Bedtime",
                    selection: Binding(
                        get: { viewModel.nightWatchBedtimeDate },
                        set: viewModel.updateNightWatchBedtime
                    ),
                    displayedComponents: .hourAndMinute
                )
                .frame(minHeight: 44)
                DatePicker(
                    "Wake time",
                    selection: Binding(
                        get: { viewModel.nightWatchWakeDate },
                        set: viewModel.updateNightWatchWakeTime
                    ),
                    displayedComponents: .hourAndMinute
                )
                .frame(minHeight: 44)
                Text("Tonight can still start late. Ollie will simply protect the time that remains.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                Divider()
                Text("Quiet windows")
                    .font(AppTypography.body.weight(.semibold))
                durationChoices(
                    title: "Quiet before bed",
                    selection: $viewModel.nightWatchPreferences.windDownMinutes
                )
                durationChoices(
                    title: "Quiet after waking",
                    selection: $viewModel.nightWatchPreferences.morningQuietMinutes
                )
                Text("Choose each window separately, from 15 minutes to 3 hours.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private var tonightPlanAccordion: some View {
        DisclosureGroup(isExpanded: expansionBinding(for: .schedule)) {
            tonightPlanCard
                .padding(.top, AppSpacing.xs)
        } label: {
            setupSectionHeader(
                title: "Tonight’s plan",
                detail: viewModel.nightWatchScheduleLabel,
                systemImage: "moon.stars.fill"
            )
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
        .accessibilityHint("Shows bedtime, wake time, and quiet windows")
    }

    private func setupSectionHeader(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.grass)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.headline)
                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func durationChoices(title: String, selection: Binding<Int>) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.body.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            Picker(selection: selection) {
                ForEach(QuietTimeDurationOptions.including(selection.wrappedValue), id: \.self) { minutes in
                    Text(QuietTimeDurationOptions.label(for: minutes)).tag(minutes)
                }
            } label: {
                Text(QuietTimeDurationOptions.label(for: selection.wrappedValue))
                    .font(AppTypography.body.weight(.semibold))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .pickerStyle(.menu)
            .tint(AppColors.ink)
            .padding(.horizontal, AppSpacing.sm)
            .frame(minWidth: 148, minHeight: 54)
            .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(AppColors.stroke.opacity(0.48), lineWidth: 1.5)
            }
        }
        .frame(minHeight: 44)
    }

    private var privateRoutineCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                setupSectionHeader(
                    title: "Private routine",
                    detail: "A repeatable sequence of optional ideas around the phone-away ritual.",
                    systemImage: "book.closed.fill"
                )
                WindDownRoutineEditor(
                    eveningSteps: routineBinding(for: .evening),
                    morningSteps: routineBinding(for: .morning),
                    onChange: saveRoutineChanges
                )
                Text("Custom routine words stay inside Counting Sheep. A separate offline purpose appears in reminders only with your permission.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                Toggle("Allow offline-purpose words in reminders", isOn: $includePurposeInNotifications)
                    .font(AppTypography.caption)
                    .onChange(of: includePurposeInNotifications) { _, _ in savePurpose() }
            }
        }
    }

    private var privateRoutineAccordion: some View {
        DisclosureGroup(isExpanded: expansionBinding(for: .routine)) {
            privateRoutineCard
                .padding(.top, AppSpacing.xs)
        } label: {
            setupSectionHeader(
                title: "Private routine",
                detail: routineSummary,
                systemImage: "book.closed.fill"
            )
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
        .accessibilityHint("Shows optional evening and morning ideas")
    }

    private func expansionBinding(for section: PlanRoutineSection) -> Binding<Bool> {
        Binding(
            get: { expandedSection == section },
            set: { expandedSection = $0 ? section : nil }
        )
    }

    private var routineSummary: String {
        let evening = viewModel.nightWatchPreferences.eveningRoutine.count
        let morning = viewModel.nightWatchPreferences.morningRoutine.count
        return "\(evening) evening · \(morning) morning ideas"
    }

    private func routineBinding(for phase: WindDownRoutinePhase) -> Binding<[WindDownRoutineStep]> {
        Binding(
            get: {
                phase == .evening
                    ? viewModel.nightWatchPreferences.eveningRoutine
                    : viewModel.nightWatchPreferences.morningRoutine
            },
            set: { steps in
                if phase == .evening {
                    viewModel.nightWatchPreferences.eveningRoutine = steps
                } else {
                    viewModel.nightWatchPreferences.morningRoutine = steps
                }
            }
        )
    }

    private func saveRoutineChanges() {
        var preferences = viewModel.nightWatchPreferences
        preferences.syncLegacyFieldsFromRoutine()
        viewModel.nightWatchPreferences = preferences
        viewModel.saveNightWatchPreferences()
    }

    private var setupActionBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(viewModel.isRunning
                ? "Next Wind Down · \(viewModel.nightWatchScheduleLabel)"
                : "Bedtime to phone wake · \(viewModel.nightWatchScheduleLabel)")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: saveOrStart) {
                Label(primaryActionTitle, systemImage: "door.left.hand.open")
                    .font(AppTypography.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PixelChipButtonStyle(isSelected: true))
            .accessibilityHint(primaryActionHint)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
        .background(AppColors.paper)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.stroke.opacity(0.14))
                .frame(height: 1)
        }
    }

    private var primaryActionTitle: String {
        if viewModel.isRunning {
            return "Save for next Wind Down"
        }
        return viewModel.canBeginNightWatchNow ? "Start Wind Down" : "Save Wind Down"
    }

    private var primaryActionHint: String {
        viewModel.canBeginNightWatchNow && !viewModel.isRunning
            ? "Starts tonight's phone-away ritual through the phone-free morning"
            : "Saves the plan and asks Ollie to remind you at wind-down time"
    }

    private func saveOrStart() {
        if viewModel.canBeginNightWatchNow && !viewModel.isRunning {
            viewModel.requestStartNightWatch()
        } else {
            viewModel.saveNightWatchPlanForTonight()
            dismiss()
        }
    }

    private func loadPurpose() {
        purposeCategory = viewModel.offlinePurpose.category
        customPurpose = viewModel.offlinePurpose.customText ?? ""
        includePurposeInNotifications = viewModel.offlinePurpose.allowsCustomTextInNotifications
    }

    private func savePurpose() {
        let normalized = PhoneFreeCue.normalized(customPurpose)
        viewModel.updateOfflinePurpose(
            category: normalized == nil ? purposeCategory : .custom,
            customText: normalized,
            allowsCustomTextInNotifications: normalized != nil && includePurposeInNotifications
        )
    }

}

#Preview("Wind Down setup") {
    NavigationStack {
        FocusRunSetupView()
            .environmentObject(FocusRunViewModel())
    }
}

#Preview("Phone bed setup") {
    let viewModel = FocusRunViewModel()
    viewModel.selectedGuardKind = .nfcTag
    return NavigationStack {
        FocusRunSetupView()
            .environmentObject(viewModel)
    }
}

#Preview("Wind Down setup · dark") {
    NavigationStack {
        FocusRunSetupView()
            .environmentObject(FocusRunViewModel())
    }
    .preferredColorScheme(.dark)
}

#Preview("Wind Down setup · smallest iPhone") {
    NavigationStack {
        FocusRunSetupView()
            .environmentObject(FocusRunViewModel())
    }
}

#Preview("Wind Down setup · accessibility") {
    NavigationStack {
        FocusRunSetupView()
            .environmentObject(FocusRunViewModel())
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}

#Preview("Wind Down setup · long cues") {
    let viewModel = FocusRunViewModel()
    viewModel.nightWatchPreferences.eveningCueText = "Read a few quiet pages, leave the phone charging, and let the room settle before sleep."
    viewModel.nightWatchPreferences.morningCueText = "Open the curtains, make a warm breakfast, and start the morning without reaching for the phone first."
    return NavigationStack {
        FocusRunSetupView()
            .environmentObject(viewModel)
    }
}
