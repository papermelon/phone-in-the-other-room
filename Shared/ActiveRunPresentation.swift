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
        case .windDown: return "PHONE-FREE WIND-DOWN"
        case .overnight: return "SLEEP TIME"
        case .morningQuiet: return "PHONE-FREE MORNING"
        case .complete: return "NIGHT COMPLETE"
        case nil: return "OLLIE IS ON WATCH"
        }
    }

    var headline: String {
        if isAdditionalQuiet { return "A little room away from the screen." }
        if placementStatus == .awaitingConfirmation { return "A calm start" }
        switch phase {
        case .windDown: return "The evening can get quieter now."
        case .overnight: return "Phone resting. You can too."
        case .morningQuiet: return "Wake up before your phone does."
        case .complete: return "A quiet night kept."
        case nil: return "Phone resting. You can too."
        }
    }

    var subheadline: String {
        if isAdditionalQuiet {
            if placementStatus == .awaitingConfirmation {
            return "Phone Away starts after the check."
            }
            return "A little room away from the screen."
        }
        if placementStatus != .awaitingConfirmation {
            switch phase {
            case .windDown: return "Phone-free time until bedtime."
            case .overnight: return "Sleep time. Your phone stays tucked away."
            case .morningQuiet: return "Phone-free time after waking."
            case .complete: return "Your phone-free night is ready."
            case nil: break
            }
        }
        return ""
    }

    var transitionCaption: String {
        guard let transition = nextTransitionDate else {
            return isAdditionalQuiet ? "Ends at \(OllieFormat.time(planEndDate))" : "Wind Down is complete"
        }
        let time = OllieFormat.time(transition)
        if isAdditionalQuiet { return "Ends at \(OllieFormat.time(planEndDate))" }
        switch phase {
        case .windDown: return "Bedtime at \(time)"
        case .overnight: return "Phone-free morning begins at \(time)"
        case .morningQuiet: return "Your phone wakes at \(time)"
        case .complete: return "Wind Down is complete"
        case nil: return "Ollie will check in when the phone-away time is done."
        }
    }

    var phaseStatusText: String {
        if isAdditionalQuiet {
            return phase == .complete ? "Phone Away is complete." : "Phone Away is running."
        }
        switch phase {
        case .windDown: return "Your phone is tucked away. Ollie is following the first trail."
        case .overnight: return "Sleep time is keeping. There is nothing else to do here."
        case .morningQuiet: return "This phone-free morning is yours. Ollie is taking the trail home."
        case .complete: return "Both quiet windows were kept."
        case nil: return "Your phone-away time is yours now. Ollie will check in when it is done."
        }
    }

    var statusSystemImage: String {
        if isAdditionalQuiet { return "moon.stars.fill" }
        return phase == .morningQuiet ? "sun.max.fill" : "moon.stars.fill"
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
                confirmationBody: "This ends the timer and removes any app limits.",
                cancelTitle: "Keep Phone Away running",
                confirmTitle: "End Phone Away"
            )
        }
        return ActiveRunExitPresentation(
            actionTitle: "End Wind Down early",
            confirmationTitle: "End Wind Down early?",
            confirmationBody: "This immediately lifts app limits and ends this Wind Down early.",
            cancelTitle: "Keep Wind Down running",
            confirmTitle: "Use emergency exit"
        )
    }

    var shieldingBanner: ActiveRunShieldingBanner? {
        let endTime = OllieFormat.time(planEndDate)
        let message: String
        switch shieldingState {
        case .notRequested:
            return nil
        case .scheduled:
            message = "Selected apps will be limited until \(endTime)."
        case .active:
            message = isAdditionalQuiet
                ? "Selected apps are limited until \(endTime)."
                : "Selected apps are limited until \(endTime)."
        case .failed(let failure):
            switch failure {
            case .noSelection:
                message = isAdditionalQuiet
                    ? "App limits didn’t start. Your Phone Away timer is still running."
                    : "No selected apps were set up, so Wind Down is continuing without app limits."
            case .monitoring, .unavailable, .other:
                message = isAdditionalQuiet
                    ? "App limits didn’t start. Your Phone Away timer is still running."
                    : "App limits didn’t start. Wind Down is still running, and you can try again next time."
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
                : "\(remaining) minutes until the next Wind Down step"
        }
        return "Less than a minute remaining"
    }
}
