import SwiftUI

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

struct OnboardingWelcomeStep: View {
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            OllieRitualView(state: .ready, size: 150)
            if let starterSheep = SheepCatalog.all.first {
                SheepPosterCard(
                    sheep: starterSheep,
                    status: .missing,
                    outcome: nil,
                    showExactOdds: false
                )
                .frame(maxWidth: 320)
            }
            VStack(spacing: AppSpacing.sm) {
                Text("Help Ollie bring a sheep home.")
                    .font(AppTypography.display(34))
                    .multilineTextAlignment(.center)
                Text("Some sheep have wandered from the pasture. Put your phone to bed, let the evening get quieter, and Ollie will follow the trail while you rest.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)
                    .multilineTextAlignment(.center)
            }
            OnboardingTimeline(draft: OnboardingDraft())
            Text("Counting Sheep is more than an app shield. It gives Ollie a reason to head into the fields and gives you a reason to keep the phone away.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
}

struct OnboardingQuietStep: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "THE QUIET",
                title: "What will the quiet make room for?",
                detail: "Choose a gentle cue for each edge of the night. Nothing needs to be checked off."
            )

            cueEditor(
                title: "Tonight, I’d like to make room for…",
                text: Binding(
                    get: { draft.eveningCueText ?? "" },
                    set: { draft.eveningCueText = PhoneFreeCue.normalized($0) }
                ),
                suggestions: PhoneFreeActivity.eveningChoices,
                selectedActivity: $draft.eveningActivity
            )
            cueEditor(
                title: "Tomorrow morning, I’d like to…",
                text: Binding(
                    get: { draft.morningCueText ?? "" },
                    set: { draft.morningCueText = PhoneFreeCue.normalized($0) }
                ),
                suggestions: PhoneFreeActivity.morningChoices,
                selectedActivity: $draft.morningActivity
            )
            PixelCard {
                Toggle("Let my words appear in reminders", isOn: $draft.allowsCustomTextInNotifications)
                    .font(AppTypography.caption)
                Text("Your words stay inside Counting Sheep unless you choose this. Lock Screen notifications can be visible to anyone near your phone.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func cueEditor(
        title: String,
        text: Binding<String>,
        suggestions: [PhoneFreeActivity],
        selectedActivity: Binding<PhoneFreeActivity>
    ) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.headline)
                TextField("It can be simple, specific, or left blank", text: text)
                    .textFieldStyle(.roundedBorder)
                Text("A few ideas, if they help")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(suggestions) { activity in
                            Button(activity.title) {
                                selectedActivity.wrappedValue = activity
                                text.wrappedValue = activity.title
                            }
                            .font(AppTypography.caption)
                            .buttonStyle(PixelChipButtonStyle(isSelected: text.wrappedValue == activity.title))
                        }
                    }
                }
            }
        }
    }
}

struct OnboardingScheduleStep: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "YOUR NIGHT",
                title: "When should Ollie search?",
                detail: "Wind Down gives Ollie a quiet trail before bed and a sunrise path after waking."
            )
            OnboardingTimeline(draft: draft)
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    DatePicker("Bedtime", selection: bedtimeBinding, displayedComponents: .hourAndMinute)
                    DatePicker("Wake time", selection: wakeBinding, displayedComponents: .hourAndMinute)
                }
            }
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    durationPicker("Quiet before bed", selection: $draft.windDownMinutes)
                    Divider().padding(.vertical, AppSpacing.xs)
                    durationPicker("Quiet after waking", selection: $draft.morningQuietMinutes)
                    Text("Thirty minutes is a friendly place to begin. You can change either window later.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .padding(.top, AppSpacing.xs)
                }
            }
        }
    }

    private var bedtimeBinding: Binding<Date> {
        timeBinding(hour: draft.bedtimeHour, minute: draft.bedtimeMinute) { hour, minute in
            draft.bedtimeHour = hour
            draft.bedtimeMinute = minute
        }
    }

    private var wakeBinding: Binding<Date> {
        timeBinding(hour: draft.wakeHour, minute: draft.wakeMinute) { hour, minute in
            draft.wakeHour = hour
            draft.wakeMinute = minute
        }
    }

    private func timeBinding(
        hour: Int,
        minute: Int,
        onChange: @escaping (Int, Int) -> Void
    ) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                onChange(components.hour ?? hour, components.minute ?? minute)
            }
        )
    }

    private func durationPicker(_ title: String, selection: Binding<Int>) -> some View {
        HStack {
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
}

struct OnboardingProtectionStep: View {
    @Binding var draft: OnboardingDraft
    @ObservedObject var viewModel: FocusRunViewModel
    let onChooseApps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "PROTECT THE QUIET",
                title: "Give the trail room to stay quiet.",
                detail: "Selected apps stay limited through Wind Down and sleep. Counting Sheep stays available while Ollie keeps watch."
            )

            OnboardingChoiceCard(
                title: OnboardingProtectionChoice.appShielding.title,
                detail: OnboardingProtectionChoice.appShielding.detail,
                icon: "iphone.slash",
                isSelected: draft.protectionChoice == .appShielding
            ) {
                draft.protectionChoice = .appShielding
                draft.shieldingEnabled = true
            }
            OnboardingChoiceCard(
                title: OnboardingProtectionChoice.nfcAndAppShielding.title,
                detail: OnboardingProtectionChoice.nfcAndAppShielding.detail,
                icon: "dot.radiowaves.left.and.right",
                isSelected: draft.protectionChoice == .nfcAndAppShielding
            ) {
                draft.protectionChoice = .nfcAndAppShielding
                draft.shieldingEnabled = true
            }

            if draft.protectionChoice == .nfcAndAppShielding {
                nfcCard
            }
            shieldingCard
        }
    }

    private var nfcCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("Wind Down tag", systemImage: "dot.radiowaves.left.and.right")
                    .font(AppTypography.headline)
                if viewModel.hasRegisteredNFCTag {
                    Label("Tag ready", systemImage: "checkmark.circle.fill")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                } else {
                    Text("Pair one writable tag to use as your Wind Down barrier.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Button("Pair Wind Down tag") {
                        viewModel.provisionNFCTag()
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
                if !viewModel.nfcStatus.isEmpty {
                    Text(viewModel.nfcStatus)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    private var shieldingCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("App shielding", systemImage: "shield.lefthalf.filled")
                    .font(AppTypography.headline)
                if viewModel.screenTimeAuthorization == .approved {
                    if viewModel.hasSelectedShieldingApps {
                        Text("Selected apps: \(viewModel.bedtimeActivitySelection.phoneOtherSelectionSummary)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.grass)
                    }
                    Button(
                        viewModel.hasSelectedShieldingApps ? "Change apps that rest" : "Choose apps that rest",
                        action: onChooseApps
                    )
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                } else if case .denied = viewModel.screenTimeAuthorization {
                    Text("Screen Time access is off. You can continue with a phone-away Wind Down and enable shielding later in More.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else if viewModel.screenTimeAuthorization == .unavailable {
                    Text("App shielding is unavailable on this device. The phone-away ritual still works without it.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else {
                    Button("Allow Screen Time access") {
                        viewModel.connectScreenTime()
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    Text("You choose which apps can rest. Counting Sheep never shields itself.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                if viewModel.shieldingReadiness != .ready {
                    Button("Continue without app shielding") {
                        draft.shieldingEnabled = false
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.grass)
                    Text(viewModel.shieldingReadiness.detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }
}

struct OnboardingAutomaticStartStep: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: "A GENTLE REMINDER",
                title: "Would you like Ollie to leave on schedule?",
                detail: "If you say yes, selected apps can rest automatically at Wind Down time. Ollie will send only the lead-ins you asked for."
            )
            PixelCard {
                Toggle("Start Wind Down automatically", isOn: $draft.automaticStartEnabled)
                    .font(AppTypography.headline)
                Text("You can still open Counting Sheep to see the active night. The app cannot open itself from a notification.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            PixelCard {
                Toggle(
                    "Send Wind Down reminders",
                    isOn: $draft.remindersEnabled
                )
                .font(AppTypography.headline)
                .disabled(!draft.automaticStartEnabled)
                Text("Choose a rhythm below. Overnight stays quiet unless you opt into a usage-aware cue.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }

            if draft.remindersEnabled && draft.automaticStartEnabled {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Choose your notification rhythm")
                        .font(AppTypography.headline)
                    ForEach(NotificationCadence.allCases) { cadence in
                        OnboardingChoiceCard(
                            title: cadence.title + " · " + String(cadence.scheduledTouchpointCount) + " cues",
                            detail: cadence.detail,
                            icon: cadence == .quiet ? "bell.slash" : "bell",
                            isSelected: draft.notificationCadence == cadence
                        ) {
                            draft.notificationCadence = cadence
                        }
                    }
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Toggle("Allow sounds at Wind Down start and completion", isOn: $draft.notificationSoundsEnabled)
                        Toggle("Offer one gentle sleep tip", isOn: $draft.educationalTipsEnabled)
                        Toggle("Remind me about a morning reflection", isOn: $draft.morningReflectionReminderEnabled)
                        Toggle("Remind me if selected apps are used", isOn: $draft.usageAwareRemindersEnabled)
                        Text("Usage-aware reminders need Screen Time access and selected apps. You can finish setup and enable this later in More.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                    .font(AppTypography.caption)
                }
            }
        }
    }
}

struct OnboardingReadyStep: View {
    let draft: OnboardingDraft

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            OllieRitualView(state: .ready, size: 112)
            onboardingTitle(
                eyebrow: "OLLIE HAS THE PLAN",
                title: "Ollie has the first night ready.",
                detail: "Each completed sleep-bookend Wind Down settles one equal sheep. You can change the plan later in More."
            )
            OnboardingTimeline(draft: draft)
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    summaryRow("Wind Down", value: timeLabel(hour: draft.bedtimeHour, minute: draft.bedtimeMinute))
                    summaryRow("Phone wakes", value: timeLabel(hour: draft.wakeHour, minute: draft.wakeMinute))
                    summaryRow("Evening", value: draft.eveningCueText ?? draft.eveningActivity.shortTitle)
                    summaryRow("Morning", value: draft.morningCueText ?? draft.morningActivity.shortTitle)
                    summaryRow("Protection", value: draft.protectionChoice.title)
                }
            }
            PixelCard {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "doc.text.image")
                        .foregroundStyle(AppColors.grass)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("ONE NIGHT, ONE SHEEP")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text("A protected night is the only progression unit. Ollie keeps the flock equal and the receipt factual.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
            }
        }
    }

    private func summaryRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(AppTypography.caption).foregroundStyle(AppColors.muted)
            Spacer()
            Text(value).font(AppTypography.body)
        }
    }

    private func timeLabel(hour: Int, minute: Int) -> String {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        )?.formatted(date: .omitted, time: .shortened) ?? "—"
    }
}

private func onboardingTitle(eyebrow: String, title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: AppSpacing.xs) {
        Text(eyebrow)
            .font(pixelFont(.caption))
            .foregroundStyle(AppColors.grass)
        Text(title)
            .font(AppTypography.display(30))
        Text(detail)
            .font(AppTypography.body)
            .foregroundStyle(AppColors.muted)
    }
}
