import SwiftUI

/// The phone owns the clock. Watch and UWB are deliberately only a gentle
/// placement assist at the beginning of a run, never an ongoing requirement.
struct ActiveRunView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let fixedNow: Date?
    @State private var emergencyExitExpanded = false
    @State private var showEarlyEndConfirmation = false
    @State private var showEmergencyExitSheet = false
    @State private var emergencyExitReason = ""
    @State private var emergencyExitConfirmation = ""
    @State private var showNFCTagReplacementConfirmation = false
    @State private var showEarlyWakeSheet = false

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

    private var fallbackExit: ActiveRunExitPresentation {
        run?.nightWatchPlan?.role == .additionalQuiet
            ? ActiveRunExitPresentation(
                actionTitle: "End Phone Away early",
                confirmationTitle: "End Phone Away early?",
                confirmationBody: "This ends the timer and removes any app limits.",
                cancelTitle: "Keep Phone Away running",
                confirmTitle: "End Phone Away"
            )
            : ActiveRunExitPresentation(
                actionTitle: "End Wind Down early",
                confirmationTitle: "End Wind Down early?",
                confirmationBody: "This immediately lifts app limits and ends this Wind Down early.",
                cancelTitle: "Keep Wind Down running",
                confirmTitle: "Use emergency exit"
            )
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
                : "Phone-away time"
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(
            run?.isNightWatch == true ? AppColors.activeWindDownBackground : AppColors.paper,
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)
        .alert(
            (presentation?.exit ?? fallbackExit).confirmationTitle,
            isPresented: $showEarlyEndConfirmation
        ) {
            Button((presentation?.exit ?? fallbackExit).cancelTitle, role: .cancel) {}
            Button((presentation?.exit ?? fallbackExit).confirmTitle, role: .destructive) {
                viewModel.endWindDownEarly()
            }
        } message: {
            Text((presentation?.exit ?? fallbackExit).confirmationBody)
        }
        .sheet(isPresented: $showEmergencyExitSheet, onDismiss: cancelEmergencyExit) {
            emergencyExitSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEarlyWakeSheet) {
            EarlyWakeSheet()
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
                    fixedDate: fixedNow
                )
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(
                        presentation.phase == .windDown && !presentation.isAdditionalQuiet
                            ? AppCopy.ActiveWindDown.cueEyebrow.value
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
                purposeCuePicker
                if run.placementStatus == .awaitingConfirmation {
                    ritualStatus
                } else if let message = viewModel.coordinator.backgroundReturnMessage {
                    returnBanner(message)
                }
                if let banner = presentation.shieldingBanner {
                    shieldingBanner(banner)
                }
                actions
                if !presentation.isAdditionalQuiet,
                   let phase,
                   let plan = run.nightWatchPlan,
                   let guidance = WindDownGuidanceLibrary.activeGuidance(for: phase, plan: plan) {
                    WindDownGuideCard(item: guidance, compact: true)
                }
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
                        Text(presentation?.eyebrow ?? "OLLIE IS ON WATCH")
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
                    presentation?.phaseStatusText ?? "Your phone-away time is still running.",
                    systemImage: presentation?.statusSystemImage ?? "moon.stars.fill"
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
                    Text("WATCH CHECK RESTING")
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
            return "START QUIET"
        }
        switch guardKind {
        case .qrCode: return "START SCAN"
        case .nfcTag: return "START TAG"
        default: return "WATCH CHECK"
        }
    }

    private var placementInstructions: String {
        if presentation?.isAdditionalQuiet == true {
            switch guardKind {
            case .qrCode: return "Scan the code to start the phone-away session."
            case .nfcTag: return "Tap your saved tag to start the phone-away session."
            default: return "Ollie only needs one short check before the phone-away session continues."
            }
        }
        switch guardKind {
        case .qrCode: return "Scan the code to begin Wind Down."
        case .nfcTag: return "Tap your Wind Down tag to begin."
        default: return "Ollie only needs one short Watch check before the Wind Down continues."
        }
    }

    private var placementButtonTitle: String {
        switch guardKind {
        case .qrCode: return "Scan to start"
        case .nfcTag: return "Tap to start"
        default: return "Check Watch placement"
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
                    eyebrow: AppCopy.ActiveWindDown.cueEyebrow.value,
                    activity: plan.eveningActivity,
                    title: plan.eveningActivityTitle,
                    detail: guidanceTip
                )
            case .morningQuiet:
                activityCue(
                    eyebrow: "PHONE-FREE MORNING",
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
                .accessibilityHint("Choose how to handle Screen-Free Morning tonight")
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
                        Text("Pair a replacement if you can. Emergency exit ends without the tag.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                        Button("Pair a replacement tag") {
                            showNFCTagReplacementConfirmation = true
                        }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                        .accessibilityHint("Opens tag settings so you can pair a replacement without ending this session")
                        Button(
                            presentation?.emergencyExit.actionTitle
                                ?? "End Wind Down without the tag"
                        ) {
                            guard viewModel.beginEmergencyExitChallenge() else { return }
                            emergencyExitReason = ""
                            emergencyExitConfirmation = ""
                            showEmergencyExitSheet = true
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
            } else if presentation?.isAdditionalQuiet == true {
                Button(presentation?.exit.actionTitle ?? "End Wind Down early") {
                    showEarlyEndConfirmation = true
                }
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.secondaryText)
            } else {
                Button(run?.isNightWatch == true
                    ? (presentation?.exit ?? fallbackExit).actionTitle
                    : "End early"
                ) {
                    viewModel.endWindDownEarly()
                }
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private var purposeCuePicker: some View {
        PixelCard {
            Menu {
                ForEach(QuietPurposeCue.allCases, id: \.self) { cue in
                    Button(cue.shieldText) { viewModel.setCurrentPurposeCue(cue) }
                }
            } label: {
                HStack {
                    Label("Purpose", systemImage: "leaf.fill")
                    Spacer()
                    Text(viewModel.currentPurposeCue?.shieldText ?? "Choose")
                }
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.ink)
            }
            .accessibilityLabel("Current purpose: \(viewModel.currentPurposeCue?.shieldText ?? "not chosen")")
            .accessibilityHint("Sets a short local purpose cue for this protected occurrence")
        }
    }

    private var emergencyExitSheet: some View {
        let emergency = presentation?.emergencyExit ?? fallbackExit
        let challenge = viewModel.emergencyExitChallenge
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppColors.grass)
                        .accessibilityHidden(true)
                    Text("Emergency exit")
                        .font(AppTypography.display(30))
                    if challenge?.stage == .readyToConfirm,
                       let reason = challenge?.reason {
                        Text("Keep your reason in mind.")
                            .font(AppTypography.body)
                        Text("You said:")
                            .font(AppTypography.caption.weight(.semibold))
                            .foregroundStyle(AppColors.muted)
                        Text(reason)
                            .font(AppTypography.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.sm)
                            .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
                        Text("Type your reason again to end this session without your tag.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.muted)
                        TextField("Type your reason again", text: $emergencyExitConfirmation)
                            .textInputAutocapitalization(.sentences)
                            .font(AppTypography.headline)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Type your reason again")
                            .onChange(of: emergencyExitConfirmation) { _, newValue in
                                _ = viewModel.submitEmergencyExitConfirmation(newValue)
                            }
                    } else {
                        Text("What do you need your phone for?")
                            .font(AppTypography.title)
                        Text("Take a moment to name what you’re reaching for.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.muted)
                        TextField("e.g. Reply to a message", text: $emergencyExitReason)
                            .textInputAutocapitalization(.sentences)
                            .font(AppTypography.headline)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("What do you need your phone for?")
                    }
                    Button(challenge?.stage == .readyToConfirm ? emergency.confirmTitle : "Continue") {
                        if challenge?.stage == .readyToConfirm {
                            guard viewModel.confirmEmergencyExit() else { return }
                            emergencyExitReason = ""
                            emergencyExitConfirmation = ""
                            showEmergencyExitSheet = false
                        } else {
                            _ = viewModel.submitEmergencyExitReason(emergencyExitReason)
                        }
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .disabled(challenge?.stage == .readyToConfirm
                        ? challenge?.canConfirm != true
                        : EmergencyExitChallenge.normalizedReason(emergencyExitReason).isEmpty)
                    .accessibilityHint("Continues to a second confirmation before ending without your tag")
                    Button(emergency.cancelTitle) {
                        showEmergencyExitSheet = false
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .navigationTitle("Emergency exit")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func cancelEmergencyExit() {
        emergencyExitReason = ""
        emergencyExitConfirmation = ""
        viewModel.cancelEmergencyExitChallenge()
        showEmergencyExitSheet = false
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
            Label(banner.message, systemImage: "iphone.slash")
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
                Text("SHORT BREAKS")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text(summary.subtitle)
                    .font(AppTypography.body)
                Text("Ollie is keeping count for this session.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var headline: String {
        presentation?.headline ?? "Phone resting. You can too."
    }

    private var subheadline: String {
        if let subheadline = presentation?.subheadline, !subheadline.isEmpty {
            return subheadline
        }
        switch guardKind {
        case .honorTimer: return "No Watch check needed. Take your phone to its bed."
        case .watchPlacement: return "The Watch helps with one short Wind Down check, then it can rest too."
        case .qrCode: return "A Wind Down code confirms the app-access barrier."
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
        presentation?.transitionCaption ?? "Ollie will check in when the phone-away time is done."
    }

    private var guidanceTip: String? {
        presentation?.guidanceTip()
    }

    private var timerAccessibilityLabel: String {
        presentation?.timerAccessibilityLabel(remainingSeconds: transitionRemainingSeconds)
            ?? "Less than a minute remaining"
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
