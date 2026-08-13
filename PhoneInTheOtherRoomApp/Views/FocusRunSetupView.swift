import SwiftUI

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct FocusRunSetupView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var purposeCategory: OfflinePurposeCategory = .rest
    @State private var customPurpose = ""
    @State private var includePurposeInNotifications = false
    @State private var showTagReplacementConfirmation = false
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
    @State private var showBedtimeAppPicker = false
#endif

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
                tonightPlanCard
                privateRoutineCard
                protectionCard
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Wind Down")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            setupActionBar
        }
        .onAppear(perform: loadPurpose)
        .onChange(of: viewModel.isRunning) { _, isRunning in
            if isRunning { dismiss() }
        }
        .alert(
            "Replace Wind Down tag?",
            isPresented: $showTagReplacementConfirmation
        ) {
            Button("Keep current tag", role: .cancel) {}
            Button("Replace tag") {
                viewModel.provisionNFCTag()
            }
        } message: {
            Text("We’ll write a new tag now. The current tag will stop working after the new one is saved.")
        }
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        .familyActivityPicker(
            headerText: "Choose the apps or categories that can rest during Wind Down.",
            footerText: "Counting Sheep uses this selection only for your two quiet windows. Websites are ignored.",
            isPresented: $showBedtimeAppPicker,
            selection: $viewModel.bedtimeActivitySelection
        )
        .onChange(of: viewModel.bedtimeActivitySelection) { _, _ in
            viewModel.saveScreenTimeSelection(.bedtime)
        }
#endif
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
            .frame(minHeight: 44)
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
                Text("Custom words stay inside Counting Sheep unless you separately allow them in reminders.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                Toggle("Let custom words appear in reminders", isOn: $includePurposeInNotifications)
                    .font(AppTypography.caption)
                    .onChange(of: includePurposeInNotifications) { _, _ in savePurpose() }
            }
        }
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
        viewModel.updateOfflinePurpose(
            category: preferences.eveningCueText == nil ? viewModel.offlinePurpose.category : .custom,
            customText: preferences.eveningCueText,
            allowsCustomTextInNotifications: includePurposeInNotifications
        )
        viewModel.saveNightWatchPreferences()
    }

    private var purposeCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("What is this quiet for?")
                    .font(AppTypography.headline)
                Text("Optional. Counting Sheep can bring your reason back into the app when it helps.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)

                Picker("Purpose", selection: $purposeCategory) {
                    ForEach(OfflinePurposeCategory.allCases) { category in
                        Text(category.title).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: purposeCategory) { _, _ in savePurpose() }

                if purposeCategory == .custom {
                    TextField(
                        "Purpose",
                        text: $customPurpose,
                        prompt: Text("A book, project, person, or quiet moment")
                            .foregroundStyle(AppColors.muted)
                    )
                        .windDownTextFieldSurface()
                        .onChange(of: customPurpose) { _, _ in savePurpose() }
                    Toggle("Use my words in reminders", isOn: $includePurposeInNotifications)
                        .font(AppTypography.body)
                        .onChange(of: includePurposeInNotifications) { _, _ in savePurpose() }
                    Text(
                        includePurposeInNotifications
                            ? "Your words may appear on the Lock Screen."
                            : "Your words stay inside Counting Sheep."
                    )
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    private var protectionCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                setupSectionHeader(
                    title: "Automatic start and protection",
                    detail: "Choose when Ollie starts and how the quiet is guarded.",
                    systemImage: "lock.shield.fill"
                )
                Toggle(
                    "Start Wind Down automatically",
                    isOn: Binding(
                        get: { viewModel.nightWatchPreferences.automaticStartEnabled },
                        set: viewModel.setAutomaticStartEnabled
                    )
                )
                .font(AppTypography.headline)
                Text("Ollie will let you know 60, 30, and 10 minutes before Wind Down. At the scheduled time, selected apps can be limited automatically when app limits are enabled.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                Text(
                    viewModel.selectedGuardKind == .nfcTag
                        ? "The app cannot open itself from a notification, so open Counting Sheep whenever you want to see the active Wind Down. Your Wind Down tag is still required to end normally."
                        : "The app cannot open itself from a notification, so open Counting Sheep whenever you want to see the active Wind Down."
                )
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                if viewModel.selectedGuardKind == .nfcTag && !viewModel.hasRegisteredNFCTag {
                    Text("Pair a Wind Down NFC tag to use automatic NFC Wind Down.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                }

                Divider()
                Text("How will you start?")
                    .font(AppTypography.body.weight(.semibold))
                ForEach(WindDownProtectionChoice.allCases) { choice in
                    Button {
                        viewModel.selectProtectionChoice(choice)
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: choice.systemImage)
                                .foregroundStyle(AppColors.grass)
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(choice.title)
                                    .font(AppTypography.body.weight(.semibold))
                                Text(choice.detail)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.muted)
                            }
                            Spacer()
                            if viewModel.selectedGuardKind == choice.guardKind {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppColors.grass)
                            }
                        }
                        .padding(AppSpacing.sm)
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .background(
                            viewModel.selectedGuardKind == choice.guardKind
                                ? AppColors.grass.opacity(0.16)
                                : AppColors.surfaceMuted,
                            in: RoundedRectangle(cornerRadius: AppRadius.md)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.md)
                                .stroke(
                                    viewModel.selectedGuardKind == choice.guardKind
                                        ? AppColors.grass
                                        : AppColors.stroke.opacity(0.45),
                                    lineWidth: 2
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.selectedGuardKind == .nfcTag {
                    Divider()
                    if viewModel.phoneBedTagRegistration == nil {
                        Text("Prepare one writable NFC tag to use as your Wind Down barrier.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                        Button("Set up Wind Down tag") {
                            viewModel.provisionNFCTag()
                        }
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        .frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        Label("Wind Down tag is ready", systemImage: "checkmark.circle.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.grass)
                        HStack(spacing: AppSpacing.sm) {
                            Button("Replace tag") {
                                showTagReplacementConfirmation = true
                            }
                            .frame(minHeight: 44)
                            Button("Forget tag", role: .destructive, action: viewModel.resetNFCTag)
                                .frame(minHeight: 44)
                        }
                        .font(AppTypography.caption)
                        .frame(minHeight: 44)
                    }
                    if !viewModel.nfcStatus.isEmpty {
                        Text(viewModel.nfcStatus)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }

                Divider()
                Text("Selected apps stay limited from Wind Down start through morning quiet. Counting Sheep stays available, and the emergency exit lifts the limits immediately.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
                if viewModel.screenTimeAuthorization != .approved {
                    Button("Allow Screen Time access", action: viewModel.connectScreenTime)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else if viewModel.bedtimeActivitySelection.phoneOtherIsEmpty {
                    Button("Choose apps to limit", action: { showBedtimeAppPicker = true })
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text(viewModel.bedtimeActivitySelection.phoneOtherSelectionSummary)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                    Button("Change shielded apps", action: { showBedtimeAppPicker = true })
                        .font(AppTypography.caption)
                        .buttonStyle(.plain)
                        .frame(minHeight: 44, alignment: .leading)
                }
#endif
            }
        }
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
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(PixelPrimaryButtonStyle())
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
        customPurpose = viewModel.nightWatchPreferences.eveningCueText
            ?? viewModel.offlinePurpose.customText
            ?? ""
        includePurposeInNotifications = viewModel.offlinePurpose.allowsCustomTextInNotifications
    }

    private func savePurpose() {
        let normalized = PhoneFreeCue.normalized(
            viewModel.nightWatchPreferences.eveningCueText ?? customPurpose
        )
        viewModel.updateOfflinePurpose(
            category: normalized == nil ? purposeCategory : .custom,
            customText: normalized,
            allowsCustomTextInNotifications: normalized != nil && includePurposeInNotifications
        )
    }

}

private struct WindDownTextFieldSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(AppTypography.body)
            .foregroundStyle(AppColors.ink)
            .tint(AppColors.grass)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .frame(minHeight: 48, alignment: .leading)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(AppColors.stroke.opacity(0.62), lineWidth: 1.5)
            }
    }
}

private extension View {
    func windDownTextFieldSurface() -> some View {
        modifier(WindDownTextFieldSurface())
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
    .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
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
