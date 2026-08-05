import SwiftUI

/// The phone owns the clock. Watch and UWB are deliberately only a gentle
/// placement assist at the beginning of a run, never an ongoing requirement.
struct ActiveRunView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var emergencyExitExpanded = false
    @State private var showEmergencyExitConfirmation = false
    @State private var showNFCTagReplacementConfirmation = false

    private var run: FocusRun? { viewModel.activeRun }
    private var guardKind: SessionGuardKind { run?.guardKind ?? .honorTimer }

    var body: some View {
        Group {
            if let run, run.isNightWatch {
                nightWatchBody(run: run)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        hero
                        ritualStatus
                        phoneFreeCue
                        if let message = viewModel.coordinator.backgroundReturnMessage {
                            returnBanner(message)
                        }
                        if let message = viewModel.coordinator.shieldingMessage {
                            returnBanner(message)
                        }
                        actions
                    }
                    .padding(16)
                }
            }
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle(run?.isNightWatch == true ? "Wind Down" : "Phone-away time")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "End Wind Down early?",
            isPresented: $showEmergencyExitConfirmation
        ) {
            Button("Keep Wind Down running", role: .cancel) {}
            Button("Use emergency exit", role: .destructive) {
                viewModel.emergencyEndWindDown()
            }
        } message: {
            Text("This immediately lifts any app shields and ends this Wind Down early.")
        }
        .alert(
            "Pair a new Wind Down tag?",
            isPresented: $showNFCTagReplacementConfirmation
        ) {
            Button("Keep current tag", role: .cancel) {}
            Button("Pair new tag") {
                viewModel.provisionNFCTag(forActiveRun: true)
            }
        } message: {
            Text("We’ll write a new tag now. Your current Wind Down will stay in place, and the old tag will stop working after the new one is saved.")
        }
    }

    private func nightWatchBody(run: FocusRun) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                NightJourneyView(run: run, reduceMotion: reduceMotion)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(phase?.title.uppercased() ?? "OLLIE IS ON WATCH")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(headline)
                        .font(AppTypography.headline)
                    Text(timerInterval: countdownInterval, countsDown: true, showsHours: true)
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .monospacedDigit()
                        .accessibilityLabel(timerAccessibilityLabel)
                    Text(transitionCaption)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if run.placementStatus == .awaitingConfirmation {
                    ritualStatus
                } else if let message = viewModel.coordinator.backgroundReturnMessage {
                    returnBanner(message)
                }
                if let message = viewModel.coordinator.shieldingMessage {
                    shieldingBanner(message)
                }
                actions
            }
            .padding(AppSpacing.md)
        }
        .scrollIndicators(.hidden)
        .saturation(viewModel.quietAppearanceEnabled ? 0.15 : 1)
    }

    private var hero: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    OllieRitualView(state: ollieState, size: 76)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(phase?.title.uppercased() ?? "OLLIE IS ON WATCH")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.secondaryText)
                        Text(headline)
                            .font(pixelFont(.title2))
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
                Label(phaseStatusText, systemImage: phase == .morningQuiet ? "sun.max.fill" : "moon.stars.fill")
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
                    Button(viewModel.hasRegisteredNFCTag ? "Pair a new tag instead" : "Pair this tag") {
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
        switch guardKind {
        case .qrCode: return "START SCAN"
        case .nfcTag: return "START TAG"
        default: return "WATCH CHECK"
        }
    }

    private var placementInstructions: String {
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
        if let plan = run?.nightWatchPlan, let phase {
            switch phase {
            case .windDown:
                activityCue(
                    eyebrow: "PHONE-FREE WIND-DOWN",
                    activity: plan.eveningActivity,
                    detail: guidanceTip ?? "Let the evening get a little quieter."
                )
            case .morningQuiet:
                activityCue(
                    eyebrow: "PHONE-FREE MORNING",
                    activity: plan.morningActivity,
                    detail: guidanceTip ?? "Let the phone wake after you do."
                )
            case .overnight, .complete:
                EmptyView()
            }
        }
    }

    private func activityCue(eyebrow: String, activity: PhoneFreeActivity, detail: String) -> some View {
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
                    Text(activity.title)
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
            if guardKind == .watchPlacement {
                Button {
                    viewModel.coordinator.pingPhone()
                } label: {
                    Label("Help me find my phone", systemImage: "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
            }

            if guardKind == .nfcTag,
               run?.isNightWatch == true,
               run?.placementStatus != .awaitingConfirmation {
                DisclosureGroup(
                    "Need your phone early?",
                    isExpanded: $emergencyExitExpanded
                ) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Your Wind Down tag is active. Ollie keeps watch until the scheduled finish.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                        Button("Pair a replacement tag") {
                            showNFCTagReplacementConfirmation = true
                        }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                        Button("End Wind Down early") {
                            showEmergencyExitConfirmation = true
                        }
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    }
                    .padding(.top, AppSpacing.xs)
                }
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
            } else {
                Button(run?.isNightWatch == true ? "End Wind Down early" : "End early") {
                    viewModel.endWindDownEarly()
                }
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private func returnBanner(_ message: String) -> some View {
        Label(message, systemImage: "arrow.uturn.backward.circle.fill")
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.secondaryText)
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private func shieldingBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Label(message, systemImage: "iphone.slash")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
            if viewModel.shieldingReadiness == .ready {
                Button("Try app shielding again") {
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

    private var headline: String {
        if run?.placementStatus == .awaitingConfirmation {
            return "A calm start"
        }
        switch phase {
        case .windDown: return "The evening can get quieter now."
        case .overnight: return "Phone resting. You can too."
        case .morningQuiet: return "Wake up before your phone does."
        case .complete: return "A protected night."
        case nil: return "Phone resting. You can too."
        }
    }

    private var subheadline: String {
        let isAdditional = run?.nightWatchPlan?.role == .additionalQuiet
        if run?.placementStatus != .awaitingConfirmation {
            switch phase {
            case .windDown: return isAdditional ? "A bounded quiet period. Ollie is keeping the edges simple." : "Phone-free time until bedtime."
            case .overnight: return "Sleep time. Your phone stays tucked away."
            case .morningQuiet: return "Phone-free time after waking."
            case .complete: return isAdditional ? "Your bounded quiet period is recorded." : "Your phone-free night is ready."
            case nil: break
            }
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
        run?.nightWatchPhase()
    }

    private var transitionRemainingSeconds: TimeInterval {
        guard let transition = viewModel.coordinator.nextNightWatchTransition else {
            return viewModel.coordinator.remainingSeconds
        }
        return max(0, transition.timeIntervalSince(Date()))
    }

    private var countdownInterval: ClosedRange<Date> {
        let now = Date()
        let transition = viewModel.coordinator.nextNightWatchTransition
            ?? run?.plannedEndAt
            ?? now
        return now...max(now, transition)
    }

    private var transitionCaption: String {
        guard let transition = viewModel.coordinator.nextNightWatchTransition, let phase else {
            return "Ollie will check in when the phone-away time is done."
        }
        let time = transition.formatted(date: .omitted, time: .shortened)
        if run?.nightWatchPlan?.role == .additionalQuiet {
            return phase == .complete ? "Quiet period complete" : "Quiet period ends at \(time)"
        }
        switch phase {
        case .windDown: return "Bedtime at \(time)"
        case .overnight: return "Phone-free morning begins at \(time)"
        case .morningQuiet: return "Your phone wakes at \(time)"
        case .complete: return "Wind Down is complete"
        }
    }

    private var phaseStatusText: String {
        if run?.nightWatchPlan?.role == .additionalQuiet, phase == .complete {
            return "This bounded quiet period is recorded."
        }
        switch phase {
        case .windDown: return "Your phone is tucked away. Ollie is following the first trail."
        case .overnight: return "Sleep time is keeping. There is nothing else to do here."
        case .morningQuiet: return "This phone-free morning is yours. Ollie is taking the trail home."
        case .complete: return "Both phone-free windows are protected."
        case nil: return "Your phone-away time is yours now. Ollie will check in when it is done."
        }
    }

    private var guidanceTip: String? {
        guard let run, let phase else { return nil }
        let phaseTip = WindDownGuidanceLibrary.featured(for: phase, seed: run.id)?.body
        guard phase == .windDown || phase == .morningQuiet else { return phaseTip }
        return [viewModel.offlinePurpose.inAppDisplayPhrase + ".", phaseTip]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private var timerAccessibilityLabel: String {
        let remaining = OllieFormat.minutes(transitionRemainingSeconds)
        return remaining > 0 ? "\(remaining) minutes until the next Wind Down step" : "Less than a minute remaining"
    }
}
