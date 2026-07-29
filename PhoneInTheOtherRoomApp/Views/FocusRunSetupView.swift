import SwiftUI

struct FocusRunSetupView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var purposeCategory: OfflinePurposeCategory = .rest
    @State private var customPurpose = ""
    @State private var includePurposeInNotifications = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                hero
                scheduleCard
                quietTimeCard
                activityCard
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
                        Text(viewModel.canBeginNightWatchNow ? "Start Quiet Time" : "Save Quiet Time")
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
        .navigationTitle("Quiet Time")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadPurpose)
        .onChange(of: viewModel.isRunning) { _, isRunning in
            if isRunning { dismiss() }
        }
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

    private var guardCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Optional phone-bed check")
                    .font(AppTypography.headline)
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: icon(for: viewModel.selectedGuardKind))
                        .foregroundStyle(AppColors.grass)
                    Picker("Phone-bed check", selection: $viewModel.selectedGuardKind) {
                        ForEach(availableGuardKinds) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Text(viewModel.selectedGuardKind.detail)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
#if DEBUG
                Divider()
                Toggle(
                    "Shield selected apps during the two quiet windows",
                    isOn: Binding(
                        get: { viewModel.shieldingEnabled },
                        set: viewModel.setShieldingEnabled
                    )
                )
                .font(AppTypography.caption)
                Text("Development preview. Overnight stays unshielded, and ending Quiet Time always clears the shield.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
#endif
            }
        }
    }

    private var availableGuardKinds: [SessionGuardKind] {
#if DEBUG
        [.honorTimer, .watchPlacement, .qrCode, .nfcTag]
#else
        [.honorTimer, .watchPlacement, .qrCode]
#endif
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

    private func icon(for kind: SessionGuardKind) -> String {
        switch kind {
        case .honorTimer: return "moon.stars.fill"
        case .watchPlacement: return "applewatch"
        case .qrCode: return "qrcode.viewfinder"
        case .nfcTag: return "dot.radiowaves.left.and.right"
        }
    }
}

#Preview("Quiet Time setup") {
    NavigationStack {
        FocusRunSetupView()
            .environmentObject(FocusRunViewModel())
    }
}

#Preview("Phone bed setup") {
    let viewModel = FocusRunViewModel()
    viewModel.selectedGuardKind = .qrCode
    return NavigationStack {
        FocusRunSetupView()
            .environmentObject(viewModel)
    }
}
