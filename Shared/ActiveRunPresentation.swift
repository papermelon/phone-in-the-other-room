import Foundation

enum ActiveRunShieldingFailure: Equatable {
    case noSelection
    case unavailable
    case monitoring
    case other

    var isRetryable: Bool {
        self == .monitoring
    }
}

enum ActiveRunShieldingState: Equatable {
    case notRequested
    case scheduled
    case active
    case failed(ActiveRunShieldingFailure)

    static func from(_ outcome: QuietTimeShieldingOutcome) -> Self {
        switch outcome {
        case .disabled, .cleared:
            return .notRequested
        case .scheduled:
            return .scheduled
        case .applied:
            return .active
        case .noSelection:
            return .failed(.noSelection)
        case .failed(let reason):
            switch reason {
            case "monitoring": return .failed(.monitoring)
            case "unavailable": return .failed(.unavailable)
            default: return .failed(.other)
            }
        }
    }

    var isRetryable: Bool {
        guard case .failed(let failure) = self else { return false }
        return failure.isRetryable
    }
}

struct ActiveRunShieldingBanner: Equatable {
    let message: String
    let retryTitle: String?
}

struct ActiveRunExitPresentation: Equatable {
    let actionTitle: String
    let confirmationTitle: String
    let confirmationBody: String
    let cancelTitle: String
    let confirmTitle: String
}

/// Cross-target terminal copy is limited to facts carried by the run itself:
/// its role, terminal state, and elapsed timer interval. It deliberately says
/// nothing about physical placement, sleep, selected-app use, or a search that
/// may not have resolved yet.
struct RunTerminalPresentation: Equatable {
    let role: WindDownOccurrenceRole
    let completedSuccessfully: Bool
    let elapsedSeconds: TimeInterval

    init(run: FocusRun) {
        let datedElapsed = run.endedAt.map { max(0, $0.timeIntervalSince(run.startedAt)) } ?? 0
        self.init(
            role: run.nightWatchPlan?.role ?? .primarySleepBookend,
            completedSuccessfully: run.completedSuccessfully,
            elapsedSeconds: max(run.actualDurationSeconds, datedElapsed)
        )
    }

    init(
        role: WindDownOccurrenceRole,
        completedSuccessfully: Bool,
        elapsedSeconds: TimeInterval
    ) {
        self.role = role
        self.completedSuccessfully = completedSuccessfully
        self.elapsedSeconds = max(0, elapsedSeconds)
    }

    var modeName: String {
        role == .additionalQuiet ? "Phone Away" : "Wind Down"
    }

    var eyebrow: String {
        completedSuccessfully
            ? "\(modeName.uppercased()) TIMER ENDED"
            : "\(modeName.uppercased()) TIME SAVED"
    }

    var headline: String {
        completedSuccessfully
            ? "The \(modeName) timer ended."
            : "Your \(modeName) time adds up."
    }

    var timerSummary: String {
        "\(elapsedLabel) on the \(modeName) timer."
    }

    var accessibilityLabel: String {
        "\(headline) \(timerSummary)"
    }

    private var elapsedLabel: String {
        let minutes = Int(elapsedSeconds / 60)
        guard minutes > 0 else { return "Under 1 minute" }
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

/// User-facing copy and affordances for an active phone-away run. This keeps
/// additional quiet from borrowing the primary Wind Down story while leaving
/// the persisted NightWatch phases and coordinator untouched.
struct ActiveRunPresentation: Equatable {
    let role: WindDownOccurrenceRole
    let phase: NightWatchPhase?
    let planEndDate: Date
    let nextTransitionDate: Date?
    let placementStatus: PlacementStatus
    let runID: UUID?
    let offlinePurpose: String?
    let shieldingState: ActiveRunShieldingState
    let now: Date

    init(
        run: FocusRun,
        at now: Date = Date(),
        offlinePurpose: String? = nil,
        shieldingState: ActiveRunShieldingState = .notRequested
    ) {
        let plan = run.nightWatchPlan
        self.init(
            role: plan?.role ?? .primarySleepBookend,
            phase: plan?.phase(at: now),
            planEndDate: plan?.protectedUntil ?? run.plannedEndAt,
            nextTransitionDate: plan?.nextTransition(after: now) ?? run.plannedEndAt,
            placementStatus: run.placementStatus,
            runID: run.id,
            offlinePurpose: offlinePurpose,
            shieldingState: shieldingState,
            now: now
        )
    }

    init(
        role: WindDownOccurrenceRole,
        phase: NightWatchPhase?,
        planEndDate: Date,
        nextTransitionDate: Date? = nil,
        placementStatus: PlacementStatus = .confirmed,
        runID: UUID? = nil,
        offlinePurpose: String? = nil,
        shieldingState: ActiveRunShieldingState = .notRequested,
        now: Date
    ) {
        self.role = role
        self.phase = phase
        self.planEndDate = planEndDate
        self.nextTransitionDate = nextTransitionDate ?? planEndDate
        self.placementStatus = placementStatus
        self.runID = runID
        self.offlinePurpose = offlinePurpose
        self.shieldingState = shieldingState
        self.now = now
    }

    var isAdditionalQuiet: Bool {
        role == .additionalQuiet
    }

    var eyebrow: String {
        if isAdditionalQuiet { return "PHONE AWAY" }
        switch phase {
        case .windDown: return "WIND DOWN · EVENING"
        case .overnight: return "WIND DOWN · OVERNIGHT"
        case .morningQuiet: return "SCREEN-FREE MORNING"
        case .complete: return "WIND DOWN TIMER ENDED"
        case nil: return "WIND DOWN"
        }
    }

    var headline: String {
        if placementStatus == .awaitingConfirmation { return "Ready when you are." }
        if isAdditionalQuiet { return "Phone Away timer is running." }
        switch phase {
        case .windDown: return "Wind Down has begun."
        case .overnight: return "Settle in for the night."
        case .morningQuiet: return "Screen-Free Morning timer is running."
        case .complete: return "The Wind Down timer ended."
        case nil: return "Wind Down timer is running."
        }
    }

    var subheadline: String {
        if isAdditionalQuiet {
            if placementStatus == .awaitingConfirmation {
                return "Phone Away starts after the check."
            }
            return "The timer continues to its planned end."
        }
        if placementStatus != .awaitingConfirmation {
            switch phase {
            case .windDown: return "Leave your phone in its spot while you get ready for bed."
            case .overnight: return "Your countdown now runs until morning."
            case .morningQuiet: return "Begin your day before picking up your phone."
            case .complete: return "Your session summary is ready."
            case nil: break
            }
        }
        return ""
    }

    var transitionCaption: String {
        guard let transition = nextTransitionDate else {
            return isAdditionalQuiet ? "Ends at \(OllieFormat.time(planEndDate))" : "Wind Down timer ended"
        }
        let time = OllieFormat.time(transition)
        if isAdditionalQuiet { return "Ends at \(OllieFormat.time(planEndDate))" }
        switch phase {
        case .windDown: return "Bedtime at \(time)"
        case .overnight: return "Screen-Free Morning begins at \(time)"
        case .morningQuiet: return "Screen-Free Morning ends at \(time)"
        case .complete: return "Wind Down timer ended"
        case nil: return "The Wind Down timer continues to its planned end."
        }
    }

    var phaseStatusText: String {
        if isAdditionalQuiet {
            return phase == .complete ? "Phone Away timer ended." : "Phone Away timer is running."
        }
        switch phase {
        case .windDown: return "Wind Down is in its evening phase."
        case .overnight: return "Wind Down is in its overnight phase."
        case .morningQuiet: return "Screen-Free Morning timer is running."
        case .complete: return "Wind Down timer ended."
        case nil: return "Wind Down timer is running."
        }
    }

    var statusSystemImage: String {
        "timer"
    }

    var returnBarTitle: String {
        isAdditionalQuiet ? "Phone Away" : "Wind Down"
    }

    var returnBarEndDate: Date {
        isAdditionalQuiet ? planEndDate : (nextTransitionDate ?? planEndDate)
    }

    var returnBarAccessibilityHint: String {
        isAdditionalQuiet
            ? "Returns to the live Phone Away"
            : "Returns to the live Wind Down journey"
    }

    var exit: ActiveRunExitPresentation {
        if isAdditionalQuiet {
            return ActiveRunExitPresentation(
                actionTitle: "End Phone Away early",
                confirmationTitle: "End Phone Away early?",
                confirmationBody: "This ends the timer and lifts selected-app limits.",
                cancelTitle: "Keep Phone Away running",
                confirmTitle: "End Phone Away"
            )
        }
        return ActiveRunExitPresentation(
            actionTitle: "End Wind Down early",
            confirmationTitle: "End Wind Down early?",
            confirmationBody: "This immediately lifts selected-app limits and ends this Wind Down early.",
            cancelTitle: "Keep Wind Down running",
            confirmTitle: "End Wind Down"
        )
    }

    var nfcExitActionTitle: String {
        isAdditionalQuiet
            ? "Tap tag to end Phone Away"
            : "Tap tag to end Wind Down"
    }

    var emergencyExit: ActiveRunExitPresentation {
        let runName = isAdditionalQuiet ? "Phone Away" : "Wind Down"
        return ActiveRunExitPresentation(
            actionTitle: "End \(runName) without the tag",
            confirmationTitle: "End \(runName) without the tag?",
            confirmationBody: "This ends \(runName) without the registered tag and immediately lifts selected-app limits.",
            cancelTitle: "Keep \(runName) running",
            confirmTitle: "End without tag"
        )
    }

    var shieldingBanner: ActiveRunShieldingBanner? {
        let endTime = OllieFormat.time(planEndDate)
        let message: String
        switch shieldingState {
        case .notRequested:
            return nil
        case .scheduled:
            message = "Selected-app limits are scheduled to end at \(endTime)."
        case .active:
            message = "Selected-app limits are active now and scheduled to end at \(endTime)."
        case .failed(let failure):
            switch failure {
            case .noSelection:
                message = isAdditionalQuiet
                    ? "Selected-app limits did not start. The Phone Away timer continues; repair protection before another start."
                    : "Selected-app limits did not start. The Wind Down timer continues; repair protection before another start."
            case .monitoring, .unavailable, .other:
                message = isAdditionalQuiet
                    ? "Selected-app limits did not stay active. The Phone Away timer continues; repair protection before another start."
                    : "Selected-app limits did not stay active. The Wind Down timer continues; repair protection before another start."
            }
        }
        return ActiveRunShieldingBanner(
            message: message,
            retryTitle: shieldingState.isRetryable ? "Try app limits again" : nil
        )
    }

    func guidanceTip() -> String? {
        guard !isAdditionalQuiet,
              let phase,
              phase == .windDown || phase == .morningQuiet else { return nil }
        let phaseTip = runID.flatMap { WindDownGuidanceLibrary.featured(for: phase, seed: $0)?.body }
        let purposeText = offlinePurpose?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let purpose = purposeText.isEmpty
            ? nil
            : (purposeText.hasSuffix(".") ? purposeText : "\(purposeText).")
        let combined = [purpose, phaseTip].compactMap { $0 }.joined(separator: " ")
        return combined.isEmpty ? nil : combined
    }

    func timerAccessibilityLabel(remainingSeconds: TimeInterval) -> String {
        let remaining = OllieFormat.minutes(remainingSeconds)
        if remaining > 0 {
            return isAdditionalQuiet
                ? "\(remaining) minutes until Phone Away ends"
                : "\(remaining) minutes until the next Wind Down phase"
        }
        return "Less than a minute remaining"
    }
}
