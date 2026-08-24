import Foundation

enum EmergencyExitReasonStorage {
    static let keyPrefix = "ollie.emergencyExit.reason."

    static func key(for runID: UUID) -> String {
        keyPrefix + runID.uuidString
    }
}

/// An ephemeral, two-step confirmation for ending an NFC-protected run
/// without its tag. The reason is kept only while this sheet is open.
struct EmergencyExitChallenge: Equatable, Identifiable {
    enum Stage: Equatable {
        // These names remain source-compatible with the original challenge;
        // they now represent the reason and reason-again steps.
        case enterWord
        case readyToConfirm
    }

    static let maximumReasonLength = 240

    let id: UUID
    let activeRunID: UUID
    private(set) var stage: Stage
    private(set) var reason: String?
    private(set) var confirmationMatches = false

    init(
        id: UUID = UUID(),
        activeRunID: UUID,
        stage: Stage = .enterWord,
        reason: String? = nil,
        confirmationMatches: Bool = false
    ) {
        self.id = id
        self.activeRunID = activeRunID
        self.stage = stage
        self.reason = reason
        self.confirmationMatches = confirmationMatches
    }

    static func limitedReason(_ value: String) -> String {
        String(value.prefix(maximumReasonLength))
    }

    static func normalizedReason(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'")
            .lowercased()
    }

    mutating func submitReason(_ value: String) -> Bool {
        let limited = Self.limitedReason(value)
        guard !Self.normalizedReason(limited).isEmpty else { return false }
        reason = limited
        stage = .readyToConfirm
        confirmationMatches = false
        return true
    }

    mutating func submitConfirmation(_ value: String) -> Bool {
        guard stage == .readyToConfirm, let reason else {
            confirmationMatches = false
            return false
        }
        confirmationMatches = !Self.normalizedReason(value).isEmpty
            && Self.normalizedReason(value) == Self.normalizedReason(reason)
        return confirmationMatches
    }

    // Compatibility shim for callers that used the old API. It now accepts a
    // user-owned reason and never recognizes a canned phrase.
    mutating func submit(_ value: String) -> Bool {
        if stage == .enterWord { return submitReason(value) }
        return submitConfirmation(value)
    }

    var canConfirm: Bool { stage == .readyToConfirm && confirmationMatches }
}

/// Keeps the one-use challenge separate from persisted session state. Recreating
/// this machine after launch deliberately produces no authorization.
struct EmergencyExitChallengeMachine: Equatable {
    private(set) var challenge: EmergencyExitChallenge?

    mutating func begin(for runID: UUID) -> EmergencyExitChallenge {
        let challenge = EmergencyExitChallenge(activeRunID: runID)
        self.challenge = challenge
        return challenge
    }

    @discardableResult
    mutating func submitReason(_ value: String, for runID: UUID) -> Bool {
        guard var challenge, challenge.activeRunID == runID else {
            self.challenge = nil
            return false
        }
        let accepted = challenge.submitReason(value)
        self.challenge = challenge
        return accepted
    }

    @discardableResult
    mutating func submitConfirmation(_ value: String, for runID: UUID) -> Bool {
        guard var challenge, challenge.activeRunID == runID else {
            self.challenge = nil
            return false
        }
        let accepted = challenge.submitConfirmation(value)
        self.challenge = challenge
        return accepted
    }

    @discardableResult
    mutating func submit(_ value: String, for runID: UUID) -> Bool {
        guard let challenge else { return false }
        return challenge.stage == .enterWord
            ? submitReason(value, for: runID)
            : submitConfirmation(value, for: runID)
    }

    /// Consumes a ready challenge before terminal work begins, so a replay
    /// cannot race a repeated button tap or later run replacement.
    mutating func consumeConfirmation(for runID: UUID) -> Bool {
        guard let challenge,
              challenge.activeRunID == runID,
              challenge.canConfirm else {
            if challenge?.activeRunID != runID { self.challenge = nil }
            return false
        }
        self.challenge = nil
        return true
    }

    mutating func cancel() { challenge = nil }
}
