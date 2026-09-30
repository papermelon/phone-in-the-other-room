import SwiftUI

struct FocusRunSetupView: View {
    private enum PlanRoutineSection { case schedule, routine }
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var purposeCategory: OfflinePurposeCategory = .rest
    @State private var customPurpose = ""
    @State private var includePurposeInNotifications = false
    @State private var expandedSection: PlanRoutineSection? = .schedule
    @State private var showStartError = false
    @State private var habitDraft = WindDownHabitPlan()
    @State private var hasLoadedDraft = false
    @State private var habitSaveFailed = false
    @State private var eveningDraft: [WindDownRoutineStep] = []
    @State private var morningDraft: [WindDownRoutineStep] = []
    private let initialHabitFocus: WindDownHabitEditFocus?

    init(initialHabitFocus: WindDownHabitEditFocus? = nil) {
        self.initialHabitFocus = initialHabitFocus
        _expandedSection = State(initialValue: initialHabitFocus == nil ? .schedule : .routine)
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                hero
                if viewModel.isRunning || viewModel.activeScreenFreeMorning != nil {
                    PixelCard {
                        Label(
                            "Your current session keeps its routine. Changes begin with your next Wind Down.",
                            systemImage: "calendar.badge.clock"
                        )
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    }
                }
                if initialHabitFocus == nil {
                    NavigationLink("What I’m working toward") { RitualPersonalisationView() }
                        .font(AppTypography.body).frame(minHeight: 44)
                    tonightPlanAccordion
                    AutomaticWindDownCard()
                }
                if initialHabitFocus != nil {
                    privateRoutineCard.id("habit-routine")
                } else {
                    privateRoutineAccordion
                        .id("habit-routine")
                }
                if initialHabitFocus == nil {
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
                                    Text("Manage app limits and NFC tags.")
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
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
        }
        .onAppear {
            guard initialHabitFocus != nil, initialHabitFocus != .activity else { return }
            Task { @MainActor in
                await Task.yield()
                proxy.scrollTo(initialHabitFocus == .activity ? "habit-routine" : "habit-\(initialHabitFocus?.rawValue ?? "routine")", anchor: .top)
            }
        }
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle(initialHabitFocus == nil ? "Wind Down" : "Edit routine")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(initialHabitFocus != nil)
        .toolbar {
            if initialHabitFocus != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .settingsHelp(.planRoutine)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            setupActionBar
        }
        .onAppear(perform: loadPurpose)
        .onChange(of: viewModel.habitEditingIdentity) { _, _ in dismiss() }
        .onChange(of: viewModel.isRunning) { _, isRunning in
            if isRunning { dismiss() }
        }
        .alert("Wind Down could not start", isPresented: $showStartError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.nightWatchStartStatus.isEmpty
                ? "Please try again."
                : viewModel.nightWatchStartStatus)
        }
    }

    private var hero: some View {
        VStack(spacing: AppSpacing.sm) {
            if initialHabitFocus == nil {
                OllieRitualView(state: .ready, presentation: .cardCompanion)
            }
            Text(initialHabitFocus == nil ? "Put your phone to bed" : "Your Wind Down routine")
                .font(initialHabitFocus == nil ? AppTypography.display(32) : AppTypography.title)
            Text(initialHabitFocus == nil
                ? "Protect the quiet before sleep, then wake up before your phone does."
                : "Choose your evening and morning activities, then tap Save routine.")
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
                    detail: "Choose a few things to do while your selected apps are limited.",
                    systemImage: "book.closed.fill"
                )
                WindDownRoutineEditor(
                    eveningSteps: routineBinding(for: .evening),
                    morningSteps: routineBinding(for: .morning),
                    phonePlacement: habitDraft.phonePlacement
                )
                Divider()
                WindDownHabitSupportEditor(plan: $habitDraft, initialFocus: initialHabitFocus)
                    .id(viewModel.habitEditingIdentity)
                Text("Custom routine words stay inside Counting Sheep. A separate offline purpose appears in reminders only with your permission.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                Toggle("Allow offline-purpose words in reminders", isOn: $includePurposeInNotifications)
                    .font(AppTypography.caption)
                    .onChange(of: includePurposeInNotifications) { _, _ in savePurpose() }
                Text("Reminder text may be visible on your Lock Screen and in notification previews while the iPhone is locked.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
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
        let evening = eveningDraft.count
        let morning = morningDraft.count
        return "\(evening) evening · \(morning) morning ideas"
    }

    private func routineBinding(for phase: WindDownRoutinePhase) -> Binding<[WindDownRoutineStep]> {
        Binding(
            get: {
                phase == .evening ? eveningDraft : morningDraft
            },
            set: { steps in
                if phase == .evening {
                    eveningDraft = steps
                } else {
                    morningDraft = steps
                }
            }
        )
    }

    private var setupActionBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if habitSaveFailed {
                Text(viewModel.habitSaveMessage ?? "Your routine support couldn’t be saved. Please try again.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.warning)
            }
            Text(viewModel.isRunning || initialHabitFocus != nil
                ? "Next Wind Down · \(viewModel.nightWatchScheduleLabel)"
                : "Bedtime to phone wake · \(viewModel.nightWatchScheduleLabel)")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: saveOrStart) {
                Label(primaryActionTitle, systemImage: initialHabitFocus == nil ? "door.left.hand.open" : "checkmark")
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
        if initialHabitFocus != nil { return "Save routine" }
        if viewModel.isRunning { return "Save plan" }
        return viewModel.canBeginNightWatchNow ? "Put phone away" : "Save plan"
    }

    private var primaryActionHint: String {
        if initialHabitFocus != nil { return "Saves your routine for the next Wind Down" }
        return viewModel.canBeginNightWatchNow && !viewModel.isRunning
            ? "Starts tonight’s timer and requests selected-app limits through Screen-Free Morning, including overnight"
            : "Saves your plan. Reminders follow your notification settings."
    }

    private func saveOrStart() {
        guard viewModel.saveWindDownHabitPlan(habitDraft) else {
            habitSaveFailed = true
            return
        }
        habitSaveFailed = false
        viewModel.nightWatchPreferences.eveningRoutine = WindDownRoutineStep.normalized(eveningDraft, for: .evening)
        viewModel.nightWatchPreferences.morningRoutine = WindDownRoutineStep.normalized(morningDraft, for: .morning)
        viewModel.nightWatchPreferences.syncLegacyFieldsFromRoutine()
        if initialHabitFocus == nil && viewModel.canBeginNightWatchNow && !viewModel.isRunning {
            showStartError = !viewModel.requestStartNightWatch()
        } else {
            viewModel.saveNightWatchPlanForTonight()
            dismiss()
        }
    }

    private func loadPurpose() {
        guard !hasLoadedDraft else { return }
        hasLoadedDraft = true
        habitDraft = viewModel.windDownHabitPlan
        eveningDraft = viewModel.nightWatchPreferences.eveningRoutine
        morningDraft = viewModel.nightWatchPreferences.morningRoutine
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

#if DEBUG
#Preview("Edit routine · active Wind Down") {
    if let model = try? ScreenbookPersonalShieldProbe.fixture() {
        NavigationStack { FocusRunSetupView(initialHabitFocus: .activity) }
            .environmentObject(model).preferredColorScheme(.dark)
    }
}

#Preview("Edit routine · large text") {
    NavigationStack { FocusRunSetupView(initialHabitFocus: .activity) }
        .environmentObject(FocusRunViewModel(startsExternalServices: false))
        .environment(\.dynamicTypeSize, .accessibility3)
}
#endif

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
