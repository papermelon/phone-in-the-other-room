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
            "End Wind Down without the tag?",
            isPresented: $showEmergencyExitConfirmation
        ) {
            Button("Keep Wind Down running", role: .cancel) {}
            Button("Use emergency exit", role: .destructive) {
                viewModel.emergencyEndWindDown()
            }
        } message: {
            Text("This immediately lifts any app shields and records that the tag was bypassed.")
        }
        .alert(
            "Pair a new phone-bed tag?",
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
        VStack(spacing: AppSpacing.sm) {
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
            actions
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                    Button("Continue without a placement check") {
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
        case .qrCode: return "TUCK-IN SCAN"
        case .nfcTag: return "TUCK-IN TAP"
        default: return "WATCH TUCK-IN"
        }
    }

    private var placementInstructions: String {
        switch guardKind {
        case .qrCode: return "Scan the little code where your phone will sleep."
        case .nfcTag: return "Tap the little tag where your phone will sleep."
        default: return "Walk your phone away. Ollie only needs one quick tuck-in check."
        }
    }

    private var placementButtonTitle: String {
        switch guardKind {
        case .qrCode: return "Scan phone bed"
        case .nfcTag: return "Tap phone bed"
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

            if guardKind == .nfcTag, run?.isNightWatch == true {
                Button {
                    viewModel.requestEndWindDown()
                } label: {
                    Label("Tap tag to end Wind Down", systemImage: "dot.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PixelPrimaryButtonStyle())
                .accessibilityHint("Scans the registered phone-bed tag before ending Wind Down")

                if !viewModel.nfcStatus.isEmpty {
                    Text(viewModel.nfcStatus)
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                DisclosureGroup(
                    "Can't access your tag?",
                    isExpanded: $emergencyExitExpanded
                ) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("The emergency exit is always available if the tag is lost or unreachable.")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.secondaryText)
                        Button("Pair a replacement tag") {
                            showNFCTagReplacementConfirmation = true
                        }
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                        Button("End without tag") {
                            showEmergencyExitConfirmation = true
                        }
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.secondaryText)
                    }
                    .padding(.top, AppSpacing.xs)
                }
                .font(pixelFont(.caption))
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
        Text(message)
            .font(pixelFont(.caption))
            .foregroundStyle(AppColors.secondaryText)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.sky.opacity(0.18), in: RoundedRectangle(cornerRadius: AppRadius.md))
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
        if run?.placementStatus != .awaitingConfirmation {
            switch phase {
            case .windDown: return "Phone-free time until bedtime."
            case .overnight: return "Sleep time. Your phone stays tucked away."
            case .morningQuiet: return "Phone-free time after waking."
            case .complete: return "Your phone-free night is ready."
            case nil: break
            }
        }
        switch guardKind {
        case .honorTimer: return "No Watch check needed. Take your phone to its bed."
        case .watchPlacement: return "The Watch helps only with tuck-in, then it can rest too."
        case .qrCode: return "A small scan marks the place your phone is resting."
        case .nfcTag: return "A small tap marked the place your phone is resting."
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
        switch phase {
        case .windDown: return "Bedtime at \(time)"
        case .overnight: return "Phone-free morning begins at \(time)"
        case .morningQuiet: return "Your phone wakes at \(time)"
        case .complete: return "Wind Down is complete"
        }
    }

    private var phaseStatusText: String {
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
