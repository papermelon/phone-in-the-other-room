import Foundation

enum PhoneAwaySearchSettlementReason: String, Codable, Equatable {
    case eligible
    case notPhoneAway
    case practice
    case endedEarly
    case tooShort
}

/// The durable audit record for one terminal Phone Away attempt. It is stored
/// with the search state before Farm is projected, so a later launch can finish
/// the projection without applying the meter or search twice.
struct PhoneAwaySearchSettlementRecord: Codable, Equatable, Identifiable {
    let runID: UUID
    let eligible: Bool
    let reason: PhoneAwaySearchSettlementReason
    let completedSuccessfully: Bool
    let isPractice: Bool
    let creditedMinutes: Int
    let appliedCreditDelta: Int
    let meterBefore: Int
    let meterAfter: Int
    let outcomeID: UUID?
    let protectedWindDownCount: Int
    let createdAt: Date

    var id: UUID { runID }

    init(
        runID: UUID,
        eligible: Bool,
        reason: PhoneAwaySearchSettlementReason,
        completedSuccessfully: Bool,
        isPractice: Bool,
        creditedMinutes: Int,
        appliedCreditDelta: Int,
        meterBefore: Int,
        meterAfter: Int,
        outcomeID: UUID?,
        protectedWindDownCount: Int,
        createdAt: Date
    ) {
        self.runID = runID
        self.eligible = eligible
        self.reason = reason
        self.completedSuccessfully = completedSuccessfully
        self.isPractice = isPractice
        self.creditedMinutes = max(0, creditedMinutes)
        self.appliedCreditDelta = max(0, appliedCreditDelta)
        self.meterBefore = max(0, meterBefore)
        self.meterAfter = max(0, meterAfter)
        self.outcomeID = outcomeID
        self.protectedWindDownCount = max(0, protectedWindDownCount)
        self.createdAt = createdAt
    }
}

struct PhoneAwaySearchSettlementInput: Equatable {
    let runID: UUID
    let role: WindDownOccurrenceRole
    let completedSuccessfully: Bool
    let isPractice: Bool
    let creditedMinutes: Int
    let protectedWindDownCount: Int
    let trackedSheepID: String?
    let settledAt: Date
    let seed: UInt64?

    init(
        runID: UUID,
        role: WindDownOccurrenceRole = .additionalQuiet,
        completedSuccessfully: Bool,
        isPractice: Bool = false,
        creditedMinutes: Int,
        protectedWindDownCount: Int,
        trackedSheepID: String? = nil,
        settledAt: Date = Date(),
        seed: UInt64? = nil
    ) {
        self.runID = runID
        self.role = role
        self.completedSuccessfully = completedSuccessfully
        self.isPractice = isPractice
        self.creditedMinutes = creditedMinutes
        self.protectedWindDownCount = protectedWindDownCount
        self.trackedSheepID = trackedSheepID
        self.settledAt = settledAt
        self.seed = seed
    }

    /// Rebuilds the settlement input from a terminal persisted run. Keeping
    /// this reconstruction in Shared gives launch recovery the same facts as
    /// the normal completion path without consulting the current meter.
    static func terminalRun(
        _ run: FocusRun,
        protectedWindDownCount: Int,
        trackedSheepID: String?
    ) -> Self? {
        guard run.nightWatchPlan?.role == .additionalQuiet else { return nil }
        return Self(
            runID: run.id,
            role: .additionalQuiet,
            completedSuccessfully: run.completedSuccessfully,
            isPractice: run.isPractice,
            creditedMinutes: run.creditedQuietMinutes,
            protectedWindDownCount: protectedWindDownCount,
            trackedSheepID: trackedSheepID,
            settledAt: run.endedAt ?? run.plannedEndAt
        )
    }
}

struct PhoneAwaySearchSettlementResult: Equatable {
    let state: SheepSearchState
    let record: PhoneAwaySearchSettlementRecord
    let outcome: SheepSearchOutcome?
}

enum PhoneAwayReceiptState: Equatable {
    case practice
    case endedEarly
    case belowMinimum
    case credited
    case meterFullWhileLocked
    case resolved
    case legacy
}

/// Copy and accessibility facts for a terminal Phone Away receipt. This stays
/// in Shared so the UI cannot accidentally reconstruct a receipt from the
/// current meter rather than the settlement that belongs to the run.
struct PhoneAwayReceiptPresentation: Equatable {
    let state: PhoneAwayReceiptState
    let eyebrow: String
    let title: String
    let message: String
    let accessibilityLabel: String
    let searchLinkTitle: String?
    let searchLinkHint: String?

    var showsSearchLink: Bool { searchLinkTitle != nil }

    static func make(
        record: PhoneAwaySearchSettlementRecord?,
        outcome: SheepSearchOutcome? = nil
    ) -> PhoneAwayReceiptPresentation {
        guard let record else {
            return PhoneAwayReceiptPresentation(
                state: .legacy,
                eyebrow: "PHONE AWAY RECEIPT",
                title: "Phone Away time saved.",
                message: "This older receipt has no saved Phone Away gift progress, so none is shown here.",
                accessibilityLabel: "Phone Away receipt. This older receipt has no saved Phone Away gift progress, so none is shown here.",
                searchLinkTitle: nil,
                searchLinkHint: nil
            )
        }

        if record.isPractice || record.reason == .practice {
            return PhoneAwayReceiptPresentation(
                state: .practice,
                eyebrow: "PHONE AWAY PRACTICE",
                title: "Practice complete.",
                message: "This was practice. \(record.creditedMinutes) completed minutes were saved in Nights. Phone Away gift progress was not added.",
                accessibilityLabel: "Phone Away practice complete. This was practice. \(record.creditedMinutes) completed minutes were saved in Nights. Phone Away gift progress was not added.",
                searchLinkTitle: nil,
                searchLinkHint: nil
            )
        }

        if record.reason == .endedEarly || !record.completedSuccessfully {
            return PhoneAwayReceiptPresentation(
                state: .endedEarly,
                eyebrow: "PHONE AWAY ENDED",
                title: "Phone Away ended early.",
                message: "\(record.creditedMinutes) completed minutes were saved in Nights. Phone Away gift progress begins at \(PhoneAwaySearchMeter.minimumEligibleMinutes) completed minutes after a completed session.",
                accessibilityLabel: "Phone Away ended early. \(record.creditedMinutes) completed minutes were saved in Nights. Phone Away gift progress begins at \(PhoneAwaySearchMeter.minimumEligibleMinutes) completed minutes after a completed session.",
                searchLinkTitle: nil,
                searchLinkHint: nil
            )
        }

        if record.reason == .tooShort || !record.eligible {
            return PhoneAwayReceiptPresentation(
                state: .belowMinimum,
                eyebrow: "PHONE AWAY RECEIPT",
                title: "Phone Away time saved.",
                message: "No Phone Away gift progress was added. Progress begins at \(PhoneAwaySearchMeter.minimumEligibleMinutes) completed minutes.",
                accessibilityLabel: "Phone Away time saved. No Phone Away gift progress was added. Progress begins at \(PhoneAwaySearchMeter.minimumEligibleMinutes) completed minutes.",
                searchLinkTitle: nil,
                searchLinkHint: nil
            )
        }

        if record.outcomeID != nil, outcome != nil {
            let remaining = max(0, record.meterAfter)
            let remainder = remaining == 0
                ? "The Phone Away meter is empty."
                : "The Phone Away meter has \(remaining) of \(SheepTrailMapState.maximumMappedMinutes) minutes remaining."
            let found = outcome?.result == .found
            return PhoneAwayReceiptPresentation(
                state: .resolved,
                eyebrow: found ? "OLLIE FOUND A MISSING SHEEP" : "OLLIE KEPT A CLUE",
                title: found ? "Ollie found a missing sheep." : "Ollie kept a clue.",
                message: found
                    ? "Ollie found a missing sheep. It's saved in Search Journal. \(remainder)"
                    : "Ollie kept a clue in Search Journal. \(remainder)",
                accessibilityLabel: found
                    ? "Ollie found a missing sheep. It's saved in Search Journal. \(remainder)"
                    : "Ollie kept a clue in Search Journal. \(remainder)",
                searchLinkTitle: SheepSearchPresentation.completionLinkTitle(for: .phoneBreak),
                searchLinkHint: SheepSearchPresentation.completionLinkHint(for: .phoneBreak)
            )
        }

        if record.appliedCreditDelta == 0,
           record.protectedWindDownCount < SheepSearchEngine.starterGuaranteeRuns,
           record.meterAfter >= SheepTrailMapState.maximumMappedMinutes {
            return PhoneAwayReceiptPresentation(
                state: .meterFullWhileLocked,
                eyebrow: "PHONE AWAY METER",
                title: "Your saved meter is waiting.",
                message: "Your Phone Away meter is full at \(record.meterAfter) of \(SheepTrailMapState.maximumMappedMinutes) minutes. No additional minutes were added this time; the saved meter is waiting until three Wind Downs are complete.",
                accessibilityLabel: "Your saved Phone Away meter is waiting. The meter is full at \(record.meterAfter) of \(SheepTrailMapState.maximumMappedMinutes) minutes. No additional minutes were added this time; it is waiting until three Wind Downs are complete.",
                searchLinkTitle: nil,
                searchLinkHint: nil
            )
        }

        let delta = record.appliedCreditDelta
        let bankingMessage = record.protectedWindDownCount < SheepSearchEngine.starterGuaranteeRuns
            ? "The saved meter is locked until three Wind Downs are complete, so these minutes are banking there."
            : "A full meter is when Ollie looks for a missing sheep."
        return PhoneAwayReceiptPresentation(
            state: .credited,
            eyebrow: "PHONE AWAY PROGRESS",
            title: "Phone Away progress saved.",
            message: "\(delta) minute\(delta == 1 ? "" : "s") added. The Phone Away meter now holds \(record.meterAfter) of \(SheepTrailMapState.maximumMappedMinutes) minutes. \(bankingMessage)",
            accessibilityLabel: "Phone Away progress saved. \(delta) minute\(delta == 1 ? "" : "s") added. The Phone Away meter now holds \(record.meterAfter) of \(SheepTrailMapState.maximumMappedMinutes) minutes. \(bankingMessage)",
            searchLinkTitle: nil,
            searchLinkHint: nil
        )
    }
}

enum PhoneAwaySearchSettlementEngine {
    static func eligibility(
        for input: PhoneAwaySearchSettlementInput
    ) -> (eligible: Bool, reason: PhoneAwaySearchSettlementReason) {
        guard input.role == .additionalQuiet else { return (false, .notPhoneAway) }
        guard !input.isPractice else { return (false, .practice) }
        guard input.completedSuccessfully else { return (false, .endedEarly) }
        guard input.creditedMinutes >= PhoneAwaySearchMeter.minimumEligibleMinutes else {
            return (false, .tooShort)
        }
        return (true, .eligible)
    }

    static func settle(
        input: PhoneAwaySearchSettlementInput,
        state: SheepSearchState
    ) -> PhoneAwaySearchSettlementResult {
        if let existing = state.phoneAwaySettlement(for: input.runID) {
            let outcome = existing.outcomeID.flatMap { outcomeID in
                state.outcomes.first { $0.id == outcomeID }
            }
            return PhoneAwaySearchSettlementResult(state: state, record: existing, outcome: outcome)
        }

        let meterBefore = state.trailMap.pendingMappedMinutes
        let resolvedEligibility = eligibility(for: input)
        guard resolvedEligibility.eligible else {
            let record = PhoneAwaySearchSettlementRecord(
                runID: input.runID,
                eligible: false,
                reason: resolvedEligibility.reason,
                completedSuccessfully: input.completedSuccessfully,
                isPractice: input.isPractice,
                creditedMinutes: input.creditedMinutes,
                appliedCreditDelta: 0,
                meterBefore: meterBefore,
                meterAfter: meterBefore,
                outcomeID: nil,
                protectedWindDownCount: input.protectedWindDownCount,
                createdAt: input.settledAt
            )
            var nextState = state
            nextState.appendPhoneAwaySettlement(record)
            return PhoneAwaySearchSettlementResult(state: nextState, record: record, outcome: nil)
        }

        // The meter is intentionally one full locked meter before the third
        // protected Wind Down, then one full meter plus one carried remainder.
        let isUnlocked = input.protectedWindDownCount >= SheepSearchEngine.starterGuaranteeRuns
        let pendingCap = isUnlocked
            ? SheepTrailMapState.maximumPendingMinutes
            : SheepTrailMapState.maximumMappedMinutes
        let cappedMinutes = min(
            PhoneAwaySearchMeter.perRunCreditCap,
            max(0, input.creditedMinutes)
        )

        var nextState = state
        let appliedCreditDelta = nextState.trailMap.credit(
            runID: input.runID,
            minutes: cappedMinutes,
            pendingCap: pendingCap
        )

        var outcome: SheepSearchOutcome?
        if isUnlocked,
           nextState.trailMap.isReadyForBonusSearch,
           nextState.phoneBreakOutcome(for: input.runID) == nil {
            nextState.trailMap.consumeBonusSearchMeter()
            let calculation = SheepSearchEngine.calculatePhoneBreak(
                runID: input.runID,
                protectedNightNumber: input.protectedWindDownCount,
                state: nextState,
                trackedSheepID: input.trackedSheepID,
                now: input.settledAt,
                seed: input.seed
            )
            nextState.append(calculation.outcome)
            outcome = calculation.outcome
        } else {
            outcome = nextState.phoneBreakOutcome(for: input.runID)
        }

        let record = PhoneAwaySearchSettlementRecord(
            runID: input.runID,
            eligible: true,
            reason: .eligible,
            completedSuccessfully: true,
            isPractice: false,
            creditedMinutes: input.creditedMinutes,
            appliedCreditDelta: appliedCreditDelta,
            meterBefore: meterBefore,
            meterAfter: nextState.trailMap.pendingMappedMinutes,
            outcomeID: outcome?.id,
            protectedWindDownCount: input.protectedWindDownCount,
            createdAt: input.settledAt
        )
        nextState.appendPhoneAwaySettlement(record)
        return PhoneAwaySearchSettlementResult(state: nextState, record: record, outcome: outcome)
    }
}
