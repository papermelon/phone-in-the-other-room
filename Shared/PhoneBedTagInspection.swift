import Foundation

enum PhoneBedTagInspection: Equatable {
    case unreadable
    case empty
    case credential(digest: String)
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
        error: PhoneBedTagReadError
    ) -> PhoneBedTagInspection {
        switch error {
        case .unreadable:
            return .unreadable
        case .zeroLengthWritableTag:
            return .empty
        case .none:
            return credentialDigest.map { .credential(digest: $0) } ?? .empty
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
    case mayProceed

}

enum PhoneBedTagProvisionIntent: Equatable {
    case normalPairing
    case settingsRetiredTagResync
}

enum PhoneBedTagProvisionPolicy {
    static func resolve(
        intent: PhoneBedTagProvisionIntent,
        inspection: PhoneBedTagInspection,
        activeCredentialDigests: Set<String>,
        retiredCredentialDigests: Set<String>
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
                // Pair only blank tags. Existing non-Counting Sheep data is
                // never an invitation to overwrite somebody else's tag.
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
        }
    }
}
