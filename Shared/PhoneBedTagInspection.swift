import Foundation

enum PhoneBedTagInspection: Equatable {
    case unreadable
    case empty
    case credential(digest: String)
    case foreign
}

/// A Core NFC read can provide both a stale message object and an error. The
/// error is authoritative except for the documented zero-length writable-tag
/// condition, so callers never reinterpret an unreadable occupied tag as safe
/// to overwrite.
enum PhoneBedTagReadError: Equatable {
    case none
    case zeroLengthWritableTag
    case unreadable
}

enum PhoneBedTagReadResolutionPolicy {
    static func resolve(
        credentialDigest: String?,
        error: PhoneBedTagReadError,
        isCountingSheepCredential: Bool = true
    ) -> PhoneBedTagInspection {
        switch error {
        case .unreadable:
            return .unreadable
        case .zeroLengthWritableTag:
            return .empty
        case .none:
            guard let credentialDigest else { return .empty }
            return isCountingSheepCredential
                ? .credential(digest: credentialDigest)
                : .foreign
        }
    }
}

enum PhoneBedTagSlotCommitOutcome: Equatable {
    case physicalWriteSucceeded
    case cancelled
    case readFailed
    case queryFailed
    case writeFailed
}

enum PhoneBedTagSlotCommitPolicy {
    static func shouldCommit(_ outcome: PhoneBedTagSlotCommitOutcome) -> Bool {
        outcome == .physicalWriteSucceeded
    }
}

enum PhoneBedTagProvisionInspectionDecision: Equatable {
    case abort
    case alreadyPaired(digest: String)
    case previouslyPaired(digest: String)
    /// A valid Counting Sheep credential that is not active in this install.
    /// The caller must obtain explicit confirmation before starting a second
    /// NFC session that may overwrite it.
    case resetRequired(digest: String)
    case mayProceed

}

enum PhoneBedTagProvisionIntent: Equatable {
    case normalPairing
    case settingsRetiredTagResync
    case settingsResetAndPair
}

enum PhoneBedTagProvisionPolicy {
    static func resolve(
        intent: PhoneBedTagProvisionIntent,
        inspection: PhoneBedTagInspection,
        activeCredentialDigests: Set<String>,
        retiredCredentialDigests: Set<String>,
        expectedCredentialDigest: String? = nil
    ) -> PhoneBedTagProvisionInspectionDecision {
        switch intent {
        case .normalPairing:
            switch inspection {
            case .unreadable:
                return .abort
            case let .credential(digest) where activeCredentialDigests.contains(digest):
                return .alreadyPaired(digest: digest)
            case let .credential(digest) where retiredCredentialDigests.contains(digest):
                return .previouslyPaired(digest: digest)
            case .credential:
                // Normal pairing is intentionally blank-only. Recovery is a
                // separate Settings-only intent with explicit reset copy.
                return .abort
            case .foreign:
                // Existing non-Counting Sheep data is never an invitation to
                // overwrite somebody else's tag.
                return .abort
            case .empty:
                return .mayProceed
            }
        case .settingsRetiredTagResync:
            guard case let .credential(digest) = inspection,
                  retiredCredentialDigests.contains(digest) else {
                return .abort
            }
            // An active credential always wins, including malformed legacy state.
            return activeCredentialDigests.contains(digest)
                ? .alreadyPaired(digest: digest)
                : .mayProceed
        case .settingsResetAndPair:
            switch inspection {
            case .empty:
                // A blank tag follows the ordinary pairing path.
                return expectedCredentialDigest == nil ? .mayProceed : .abort
            case let .credential(digest):
                guard !activeCredentialDigests.contains(digest) else {
                    return .alreadyPaired(digest: digest)
                }
                if let expectedCredentialDigest {
                    return expectedCredentialDigest == digest ? .mayProceed : .abort
                }
                return .resetRequired(digest: digest)
            case .foreign, .unreadable:
                return .abort
            }
        }
    }
}
