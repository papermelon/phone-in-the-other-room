import SwiftUI

/// The phone owns the clock. Legacy guards may still decode, but the current
/// presentation reports timer and selected-app-limit state only.
struct ActiveRunView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let fixedNow: Date?
    @State private var emergencyExitExpanded = false
    @State private var showNFCTagReplacementConfirmation = false
    @State private var showEarlyWakeSheet = false
    @State private var earlyWakeChoice: MorningQuietIntent?

    init(now: Date? = nil) {
        fixedNow = now
    }

    private var run: FocusRun? { viewModel.activeRun }
    private var guardKind: SessionGuardKind { run?.guardKind ?? .honorTimer }
    private var currentDate: Date { fixedNow ?? Date() }
    private var presentation: ActiveRunPresentation? {
        guard let run else { return nil }
        return ActiveRunPresentation(
            run: run,
            at: currentDate,
            offlinePurpose: viewModel.offlinePurpose.inAppDisplayPhrase,
            shieldingState: viewModel.coordinator.shieldingState
        )
    }

    private var fallbackReturnBarTitle: String {
        run?.nightWatchPlan?.role == .additionalQuiet ? "Phone Away" : "Wind Down"
    }

    private var tagReplacementTitle: String {
        presentation?.isAdditionalQuiet == true ? "Pair a new Phone Away tag?" : "Pair a new Wind Down tag?"
    }

    private var tagReplacementMessage: String {
        presentation?.isAdditionalQuiet == true
            ? "We’ll write a new tag now. Your Phone Away period will keep running, and the old tag will stop working after the new one is saved."
            : "We’ll write a new tag now. Your current Wind Down will stay in place, and the old tag will stop working after the new one is saved."
    }

    var body: some View {
        Group {
            if let run, run.isNightWatch, let presentation {
                nightWatchBody(run: run, presentation: presentation)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        hero
                        ritualStatus
                        phoneFreeCue
                        if let run {
                            let tracker = viewModel.briefAccessTrackerSummary(for: run)
                            if tracker.pauseCount > 0 {
                                briefAccessNotice(summary: tracker)
                            }
                        }
                        if let message = viewModel.coordinator.backgroundReturnMessage {
                            returnBanner(message)
                        }
                        if let banner = presentation?.shieldingBanner {
                            shieldingBanner(banner)
                        }
                        PersonalShieldActions()
                        actions
                    }
                    .padding(16)
                }
            }
        }
        .background(
            (run?.isNightWatch == true
                ? AppColors.activeWindDownBackground
                : AppColors.paper
            ).ignoresSafeArea()
        )
        .navigationTitle(
            run?.isNightWatch == true
                ? (presentation?.returnBarTitle ?? fallbackReturnBarTitle)
                : "Timer"
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            run?.isNightWatch == true ? AppColors.activeWindDownBackground : AppColors.paper,
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showEarlyWakeSheet, onDismiss: {
            guard let intent = earlyWakeChoice else { return }
            earlyWakeChoice = nil
            viewModel.chooseEarlyWake(intent)
        }) {
            EarlyWakeSheet(onChoice: { intent in
                earlyWakeChoice = intent
                showEarlyWakeSheet = false
            })
                .environmentObject(viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            tagReplacementTitle,
            isPresented: $showNFCTagReplacementConfirmation
        ) {
            Button("Keep current tag", role: .cancel) {}
            Button("Pair new tag") {
                let current = viewModel.primaryPhoneBedTag
                viewModel.provisionNFCTag(
                    forActiveRun: true,
                    role: .primary,
                    name: current?.name ?? NamedPhoneBedTagRegistration.defaultName,
                    purposes: current?.purposes ?? NamedPhoneBedTagRegistration.allPurposes
                )
            }
        } message: {
            Text(tagReplacementMessage)
        }
    }

    private func nightWatchBody(run: FocusRun, presentation: ActiveRunPresentation) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                NightJourneyView(
                    run: run,
                    reduceMotion: reduceMotion,
                    fixedDate: fixedNow,
                    accessoryItemID: viewModel.farmState.equipment.ollieAccessoryItemID
                )
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(
                        presentation.phase == .windDown && !presentation.isAdditionalQuiet
                            ? "EVENING PHASE"
                            : presentation.eyebrow
                    )
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(headline)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.ink)
                    if fixedNow != nil {
                        Text(OllieFormat.timer(transitionRemainingSeconds))
                            .font(.system(size: 34, weight: .black, design: .monospaced))
                            .foregroundStyle(AppColors.ink)
                            .monospacedDigit()
                            .accessibilityLabel(timerAccessibilityLabel)
                    } else {
                        Text(timerInterval: countdownInterval, countsDown: true, showsHours: true)
                            .font(.system(size: 34, weight: .black, design: .monospaced))
                            .foregroundStyle(AppColors.ink)
                            .monospacedDigit()
                            .accessibilityLabel(timerAccessibilityLabel)
                    }
                    Text(transitionCaption)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                let tracker = viewModel.briefAccessTrackerSummary(for: run)
                if tracker.pauseCount > 0 {
                    briefAccessNotice(summary: tracker)
                }
                if let plan = run.nightWatchPlan, plan.role == .primarySleepBookend,
                   presentation.phase == .windDown {
                    Text(plan.phonePlacement.actionCue)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                    if plan.usesSmallerRoutine {
                        Text("Your smaller version · same timing and protection")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }
                PersonalShieldActions()
                if run.placementStatus == .awaitingConfirmation {
                    ritualStatus
                } else if let message = viewModel.coordinator.backgroundReturnMessage {
                    returnBanner(message)
                }
                if let banner = presentation.shieldingBanner {
                    shieldingBanner(banner)
                }
                actions
            }
            .padding(AppSpacing.md)
        }
        .scrollIndicators(.hidden)
        .background(AppColors.activeWindDownBackground.ignoresSafeArea())
    }

    private var hero: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    OllieRitualView(state: ollieState, presentation: .inline)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(presentation?.eyebrow ?? "TIMER")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.secondaryText)
                        Text(headline)
                            .font(pixelFont(.title2))
                            .foregroundStyle(AppColors.ink)
                        Text(subheadline)
                            .font(pixelFont(.body))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }

                Text(
                    timerInterval: countdownInterval,
                    countsDown: true,
                    showsHours: true
                )
                    .font(.system(size: 58, weight: .black, design: .monospaced))
                    .foregroundStyle(AppColors.ink)
                    .monospacedDigit()
                    .contentTransition(reduceMotion ? .identity : .numericText())
                    .accessibilityLabel(timerAccessibilityLabel)
                    .accessibilityAddTraits(.updatesFrequently)

                WindDownPhaseProgressView(interval: progressInterval)
                Text(transitionCaption)
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private var ollieState: OllieRitualState {
        if run?.placementStatus == .awaitingConfirmation {
            return .tuckingIn
        }
        switch phase {
        case .windDown: return .guarding
        case .overnight: return .overnight
        case .morningQuiet: return .morningQuiet
        case .complete: return .completed
        case nil: return .guarding
        }
    }

    @ViewBuilder
    private var ritualStatus: some View {
        switch run?.placementStatus ?? .notRequired {
        case .notRequired, .confirmed:
            PixelCard {
                Label(
                    presentation?.phaseStatusText ?? "The timer is still running.",
                    systemImage: presentation?.statusSystemImage ?? "timer"
                )
                    .font(pixelFont(.body))
                    .foregroundStyle(AppColors.secondaryText)
            }
        case .awaitingConfirmation:
            PixelCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(placementEyebrow)
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(placementInstructions)
                        .font(pixelFont(.body))
                    Button(placementButtonTitle) {
                        if guardKind == .qrCode {
                            viewModel.showQRCodeScanner = true
                        } else if guardKind == .nfcTag {
                            viewModel.scanNFCTag()
                        } else {
                            viewModel.coordinator.requestDistanceCheck()
                        }
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())
                    if !viewModel.nfcStatus.isEmpty {
                        Text(viewModel.nfcStatus)
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    Button(hasCompatibleRegisteredTag ? "Pair a new tag instead" : "Pair this tag") {
                        showNFCTagReplacementConfirmation = true
                    }
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                    Button("Continue without a tag check") {
                        viewModel.coordinator.continueWithoutWatch()
                    }
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.secondaryText)
                }
            }
        case .unavailable:
            PixelCard {
                VStack(alignment: .leading, spacing: 9) {
                    Text("OLDER CHECK UNAVAILABLE")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.secondaryText)
                    Text("Your timer keeps going. No action needed.")
                        .font(pixelFont(.body))
                }
            }
        }
    }

    private var placementEyebrow: String {
        if presentation?.isAdditionalQuiet == true {
            return "START TIMER"
        }
        switch guardKind {
        case .qrCode: return "START SCAN"
        case .nfcTag: return "START TAG"
        default: return "OLDER SETUP"
        }
    }

    private var placementInstructions: String {
        if presentation?.isAdditionalQuiet == true {
            switch guardKind {
            case .qrCode: return "Scan the code to start the phone-away session."
            case .nfcTag: return "Tap your saved tag to start the phone-away session."
            default: return "This older setup continues with the iPhone timer."
            }
        }
        switch guardKind {
        case .qrCode: return "Scan the code to begin Wind Down."
        case .nfcTag: return "Tap your Wind Down tag to begin."
        default: return "This older setup continues with the iPhone timer."
        }
    }

    private var placementButtonTitle: String {
        switch guardKind {
        case .qrCode: return "Scan to start"
        case .nfcTag: return "Tap to start"
        default: return "Continue on iPhone"
        }
    }

    @ViewBuilder
    private var phoneFreeCue: some View {
        if let plan = run?.nightWatchPlan,
           presentation?.isAdditionalQuiet == false,
           let phase,
           let guidanceTip {
            switch phase {
            case .windDown:
                activityCue(
                    eyebrow: "EVENING IDEA",
                    activity: plan.eveningActivity,
                    title: plan.eveningActivityTitle,
                    detail: guidanceTip
                )
            case .morningQuiet:
                activityCue(
                    eyebrow: "MORNING IDEA",
                    activity: plan.morningActivity,
                    title: plan.morningActivityTitle,
                    detail: guidanceTip
                )
            case .overnight, .complete:
                EmptyView()
            }
        }
    }


    private func activityCue(
        eyebrow: String,
        activity: PhoneFreeActivity,
        title: String,
        detail: String
    ) -> some View {
        PixelCard {
            HStack(spacing: 12) {
                Image(systemName: activity.systemImage)
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 5) {
                    Text(eyebrow)
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(title)
                        .font(pixelFont(.headline))
                    Text(detail)
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.secondaryText)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if presentation?.phase == .overnight,
               presentation?.isAdditionalQuiet == false,
               viewModel.isEarlyWakeAvailable {
                Button("I'm awake early") {
                    showEarlyWakeSheet = true
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                .accessibilityHint("Choose how to handle the planned Screen-Free Morning")
            }

            if guardKind == .watchPlacement {
                Button {
                    viewModel.coordinator.pingPhone()
                } label: {
                    Label("Help me find my phone", systemImage: "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
            }

            if guardKind == .nfcTag, run != nil {
                Button(presentation?.nfcExitActionTitle ?? "Tap tag to end Wind Down") {
                    viewModel.requestEndWindDown()
                }
                .buttonStyle(PixelPrimaryButtonStyle())

                if !viewModel.nfcStatus.isEmpty {
                    Text(viewModel.nfcStatus)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                DisclosureGroup(isExpanded: $emergencyExitExpanded) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Pair a replacement, or confirm the session phrase to end without your tag.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                        Button("Pair a replacement tag") {
                            showNFCTagReplacementConfirmation = true
                        }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                        .accessibilityHint("Opens tag settings so you can pair a replacement without ending this session")
                        Button("End \(viewModel.activeRunIsAdditionalQuiet ? "Phone Away" : "Wind Down")") {
                            viewModel.openPersonalShield(.endSession)
                        }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.amber)
                        .accessibilityHint("Opens a deliberate confirmation before ending without your registered tag")
                    }
                    .padding(.top, AppSpacing.xs)
                }
                label: {
                    Label("Can’t use your tag?", systemImage: "questionmark.circle")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.amber)
                }
                .accessibilityLabel("Can’t use your tag?")
                .accessibilityHint("Shows tag replacement and emergency exit options")
            } else {
                Button("End \(viewModel.activeRunIsAdditionalQuiet ? "Phone Away" : "Wind Down")") {
                    viewModel.openPersonalShield(.endSession)
                }
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
                .frame(minHeight: 44)
            }
        }
    }

    private var hasCompatibleRegisteredTag: Bool {
        viewModel.hasRegisteredNFCTag(
            for: presentation?.isAdditionalQuiet == true ? .phoneAway : .windDown
        )
    }

    private func returnBanner(_ message: String) -> some View {
        Label(message, systemImage: "arrow.uturn.backward.circle.fill")
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.secondaryText)
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private func shieldingBanner(_ banner: ActiveRunShieldingBanner) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Label(banner.message, systemImage: "shield")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
            if let retryTitle = banner.retryTitle {
                Button(retryTitle) {
                    viewModel.retryShielding()
                }
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.grass)
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private func briefAccessNotice(summary: QuietTimeBriefAccessTrackerSummary) -> some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("BRIEF ACCESS")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text(summary.subtitle)
                    .font(AppTypography.body)
                Text(shieldRole.briefAccessExplanation)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var headline: String {
        presentation?.headline ?? "The timer is running."
    }

    private var subheadline: String {
        if let subheadline = presentation?.subheadline, !subheadline.isEmpty {
            return subheadline
        }
        switch guardKind {
        case .honorTimer: return "The timer runs on this iPhone; no Watch check is needed."
        case .watchPlacement: return "This older setup continues as an iPhone timer."
        case .qrCode: return "This older setup continues as an iPhone timer."
        case .nfcTag: return "Your Wind Down tag is the normal way to finish early."
        }
    }

    private var progressInterval: ClosedRange<Date> {
        guard let run else {
            let now = Date()
            return now...now
        }
        guard let plan = run.nightWatchPlan, let phase else {
            return run.startedAt...max(run.startedAt, run.plannedEndAt)
        }
        switch phase {
        case .windDown:
            let plannedStart = plan.intendedBedtime.addingTimeInterval(TimeInterval(-plan.windDownMinutes * 60))
            let start = max(run.startedAt, plannedStart)
            return start...max(start, plan.intendedBedtime)
        case .overnight:
            let start = max(run.startedAt, plan.intendedBedtime)
            return start...max(start, plan.wakeTime)
        case .morningQuiet:
            let start = max(run.startedAt, plan.wakeTime)
            return start...max(start, plan.protectedUntil)
        case .complete:
            return plan.protectedUntil...plan.protectedUntil
        }
    }

    private var phase: NightWatchPhase? {
        presentation?.phase
    }

    private var transitionRemainingSeconds: TimeInterval {
        guard let transition = presentation?.nextTransitionDate else {
            return max(0, (run?.plannedEndAt ?? currentDate).timeIntervalSince(currentDate))
        }
        return max(0, transition.timeIntervalSince(currentDate))
    }

    private var countdownInterval: ClosedRange<Date> {
        let transition = presentation?.nextTransitionDate
            ?? run?.plannedEndAt
            ?? currentDate
        return currentDate...max(currentDate, transition)
    }

    private var transitionCaption: String {
        presentation?.transitionCaption ?? "The timer ends at the planned time."
    }

    private var guidanceTip: String? {
        presentation?.guidanceTip()
    }

    private var timerAccessibilityLabel: String {
        presentation?.timerAccessibilityLabel(remainingSeconds: transitionRemainingSeconds)
            ?? "Less than a minute remaining"
    }

    private var shieldRole: QuietTimeShieldRole {
        run?.nightWatchPlan?.role == .additionalQuiet ? .additionalQuiet : .primaryWindDown
    }
}

#Preview("Active run · Phone Away · 6 PM") {
    let calendar = Calendar.current
    let now = calendar.date(
        from: DateComponents(year: 2026, month: 8, day: 11, hour: 18, minute: 0)
    )!
    let end = now.addingTimeInterval(30 * 60)
    let viewModel = FocusRunViewModel()
    let plan = NightWatchPlan.additionalQuiet(start: now, end: end)
    viewModel.coordinator.run = FocusRun(
        plannedDurationSeconds: 30 * 60,
        startedAt: now,
        state: .running,
        guardKind: .honorTimer,
        nightWatchPlan: plan,
        appShieldingRequested: false
    )
    return NavigationStack {
        ActiveRunView(now: now)
            .environmentObject(viewModel)
    }
}

#Preview("Active run · primary overnight") {
    let calendar = Calendar.current
    let bedtime = calendar.date(
        from: DateComponents(year: 2026, month: 8, day: 11, hour: 23, minute: 0)
    )!
    let now = calendar.date(
        from: DateComponents(year: 2026, month: 8, day: 12, hour: 0, minute: 30)
    )!
    let wake = calendar.date(
        from: DateComponents(year: 2026, month: 8, day: 12, hour: 7, minute: 0)
    )!
    let protectedUntil = wake.addingTimeInterval(30 * 60)
    let viewModel = FocusRunViewModel()
    let plan = NightWatchPlan(
        intendedBedtime: bedtime,
        wakeTime: wake,
        protectedUntil: protectedUntil,
        windDownMinutes: 30,
        morningQuietMinutes: 30,
        eveningActivity: .read,
        morningActivity: .openCurtains
    )
    viewModel.coordinator.run = FocusRun(
        plannedDurationSeconds: protectedUntil.timeIntervalSince(bedtime.addingTimeInterval(-30 * 60)),
        startedAt: bedtime.addingTimeInterval(-30 * 60),
        state: .running,
        guardKind: .honorTimer,
        nightWatchPlan: plan,
        appShieldingRequested: false
    )
    return NavigationStack {
        ActiveRunView(now: now)
            .environmentObject(viewModel)
    }
}
