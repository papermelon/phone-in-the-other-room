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
                scheduleCard
                quietTimeCard
                activityCard
                automaticStartCard
                purposeCard
                guardCard
                Button {
                    if viewModel.canBeginNightWatchNow {
                        viewModel.requestStartNightWatch()
                    } else {
                        viewModel.saveNightWatchPlanForTonight()
                        dismiss()
                    }
                } label: {
                    HStack {
                        Image(systemName: "door.left.hand.open")
                        Text(viewModel.canBeginNightWatchNow ? "Start Wind Down" : "Save Wind Down")
                        Spacer()
                        Text(viewModel.nightWatchScheduleLabel)
                            .font(AppTypography.caption)
                    }
                    .font(AppTypography.headline)
                }
                .buttonStyle(PixelPrimaryButtonStyle())
                .accessibilityHint(
                    viewModel.canBeginNightWatchNow
                        ? "Starts tonight's phone-away ritual through the phone-free morning"
                        : "Saves the plan and asks Ollie to remind you at wind-down time"
                )
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Wind Down")
        .navigationBarTitleDisplayMode(.inline)
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
            OllieRitualView(state: .ready, size: 112)
            Text("Put your phone to bed")
                .font(AppTypography.display(32))
            Text("Protect the quiet before sleep, then wake up before your phone does.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private var scheduleCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Your sleep schedule")
                    .font(AppTypography.headline)
                DatePicker(
                    "Bedtime",
                    selection: Binding(
                        get: { viewModel.nightWatchBedtimeDate },
                        set: viewModel.updateNightWatchBedtime
                    ),
                    displayedComponents: .hourAndMinute
                )
                DatePicker(
                    "Wake time",
                    selection: Binding(
                        get: { viewModel.nightWatchWakeDate },
                        set: viewModel.updateNightWatchWakeTime
                    ),
                    displayedComponents: .hourAndMinute
                )
                Text("Tonight can still start late. Ollie will simply protect the time that remains.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private var quietTimeCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
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

    private func durationChoices(title: String, selection: Binding<Int>) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.headline)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(QuietTimeDurationOptions.including(selection.wrappedValue), id: \.self) { minutes in
                    Text(QuietTimeDurationOptions.label(for: minutes)).tag(minutes)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColors.grass)
        }
    }

    private var activityCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("What will fill the quiet?")
                    .font(AppTypography.headline)
                activityPicker(
                    title: "Tonight",
                    selection: $viewModel.nightWatchPreferences.eveningActivity,
                    choices: PhoneFreeActivity.eveningChoices
                )
                activityPicker(
                    title: "Tomorrow morning",
                    selection: $viewModel.nightWatchPreferences.morningActivity,
                    choices: PhoneFreeActivity.morningChoices
                )
                Text("These are gentle cues, never tasks to prove or complete.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func activityPicker(
        title: String,
        selection: Binding<PhoneFreeActivity>,
        choices: [PhoneFreeActivity]
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: selection.wrappedValue.systemImage)
                .frame(width: 24)
                .foregroundStyle(AppColors.grass)
            Text(title)
                .font(AppTypography.body)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(choices) { activity in
                    Text(activity.title).tag(activity)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
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
                    TextField("A book, project, person, or quiet moment", text: $customPurpose)
                        .textFieldStyle(.roundedBorder)
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

    private var automaticStartCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Toggle(
                    "Start Wind Down automatically",
                    isOn: Binding(
                        get: { viewModel.nightWatchPreferences.automaticStartEnabled },
                        set: viewModel.setAutomaticStartEnabled
                    )
                )
                .font(AppTypography.headline)
                Text("Ollie will let you know 60, 30, and 10 minutes before the phone rests. At the scheduled time, selected apps can rest automatically when shielding is enabled.")
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
            }
        }
    }

    private var guardCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("How will you start?")
                    .font(AppTypography.headline)
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
                    } else {
                        Label("Wind Down tag is ready", systemImage: "checkmark.circle.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.grass)
                        HStack {
                            Button("Replace tag") {
                                showTagReplacementConfirmation = true
                            }
                            Button("Forget tag", role: .destructive, action: viewModel.resetNFCTag)
                        }
                        .font(AppTypography.caption)
                    }
                    if !viewModel.nfcStatus.isEmpty {
                        Text(viewModel.nfcStatus)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }

                Divider()
                Text("Selected apps stay limited through Wind Down and sleep. Counting Sheep remains available for an emergency exit.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
                if viewModel.screenTimeAuthorization != .approved {
                    Button("Allow Screen Time access", action: viewModel.connectScreenTime)
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else if viewModel.bedtimeActivitySelection.phoneOtherIsEmpty {
                    Button("Choose apps to rest", action: { showBedtimeAppPicker = true })
                        .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else {
                    Text(viewModel.bedtimeActivitySelection.phoneOtherSelectionSummary)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                    Button("Change shielded apps", action: { showBedtimeAppPicker = true })
                        .font(AppTypography.caption)
                        .buttonStyle(.plain)
                }
#endif
            }
        }
    }

    private func loadPurpose() {
        purposeCategory = viewModel.offlinePurpose.category
        customPurpose = viewModel.offlinePurpose.customText ?? ""
        includePurposeInNotifications = viewModel.offlinePurpose.allowsCustomTextInNotifications
    }

    private func savePurpose() {
        if purposeCategory != .custom {
            includePurposeInNotifications = false
        }
        viewModel.updateOfflinePurpose(
            category: purposeCategory,
            customText: purposeCategory == .custom ? customPurpose : nil,
            allowsCustomTextInNotifications: purposeCategory == .custom && includePurposeInNotifications
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
