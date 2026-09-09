import Foundation

enum NightFlockRemoteErrorCode: String, Codable, Equatable, Sendable {
    case unauthorized
    case linkedAccountRequired = "linked_account_required"
    case methodNotAllowed = "method_not_allowed"
    case invalidRequest = "invalid_request"
    case unsupportedSchema = "unsupported_schema"
    case activeMembershipExists = "active_membership_exists"
    case aliasConflict = "alias_conflict"
    case inviteMemberConstraint = "invite_member_constraint"
    case activeInviteExists = "active_invite_exists"
    case currentMembershipRequired = "current_membership_required"
    case inviteUnavailable = "invite_unavailable"
    case lobbyStarted = "lobby_started"
    case flockFull = "flock_full"
    case blockedMembership = "blocked_membership"
    case hostPermissionRequired = "host_permission_required"
    case accountUnavailable = "account_unavailable"
    case staleRevision = "stale_revision"
    case snapshotConstructionFailed = "snapshot_construction_failed"
    case sharedHistoryDeleted = "shared_history_deleted"
    case publicationBeforeAgreement = "publication_before_agreement"
    case agreementTimezoneMismatch = "agreement_timezone_mismatch"
    case publicationOutsidePlanWindow = "publication_outside_plan_window"
    case publicationOutsideReceiptWindow = "publication_outside_receipt_window"
    case invalidSharedNightPayload = "invalid_shared_night_payload"
    case invalidPlanChronology = "invalid_plan_chronology"
    case invalidReceiptChronology = "invalid_receipt_chronology"
    case invalidPlanBinding = "invalid_plan_binding"
    case invalidReceiptSource = "invalid_receipt_source"
    case receiptPlanMismatch = "receipt_plan_mismatch"
    case sharedNightPlanFrozen = "shared_night_plan_frozen"
    case sharedNightPlanCancelled = "shared_night_plan_cancelled"
    case receiptActualStartRequired = "receipt_actual_start_required"
    case serviceUnavailable = "service_unavailable"
    case internalError = "internal_error"
}

enum NightFlockRemoteRecovery: String, Codable, Equatable, Sendable {
    case reconcileMembership
    case reconcile
    case retry
    case fallbackSchema
    case linkAccount
    case authenticate
}

/// The operation that encountered an authentication boundary. This deliberately
/// describes transport only; no snapshot, run, or account data is carried here.
enum NightFlockRecoveryLane: Equatable, Sendable {
    case snapshot(schema: Int)
    case directCommand(schema: Int)
    case outbox(schema: Int)
}

enum NightFlockRecoverySession: Equatable, Sendable {
    case missing
    case anonymous
    case linked
    case unknown
}

/// The persisted identity binding is security-sensitive. In particular, an
/// unreadable UUID string is not the same thing as no binding: treating it as
/// absent could authorize creating or linking a different account.
enum NightFlockExpectedIdentity: Equatable, Sendable {
    case absent
    case valid(UUID)
    case invalid

    var permitsInitialBinding: Bool {
        self == .absent
    }

    var validUserID: UUID? {
        guard case let .valid(id) = self else { return nil }
        return id
    }
}

enum NightFlockExpectedIdentityBinding {
    static func classify(_ persistedValue: String?) -> NightFlockExpectedIdentity {
        guard let persistedValue else { return .absent }
        guard let id = UUID(uuidString: persistedValue) else { return .invalid }
        return .valid(id)
    }
}

/// The local auth session is interpreted together with the expected UUID
/// binding. A bound Slumber Party must never quietly become a fresh anonymous
/// account just because Supabase still has one locally.
enum NightFlockObservedAccountSession: Equatable, Sendable {
    case missing
    case anonymous
    case appleLinked(UUID)
    case unsupported
}

/// Supabase can omit the expanded `identities` collection from a session
/// payload even though its server-controlled app metadata already records the
/// linked provider. Treat either representation as evidence, but never allow
/// stale provider metadata to turn an anonymous session into a linked one.
enum NightFlockAppleIdentityEvidence {
    static func isLinked(
        isAnonymous: Bool,
        identityProviders: [String],
        primaryProvider: String?,
        providers: [String]
    ) -> Bool {
        guard !isAnonymous else { return false }
        return identityProviders.contains("apple")
            || primaryProvider == "apple"
            || providers.contains("apple")
    }

    static func preservesOriginalAccount(
        originalUserID: UUID,
        recoveredUserID: UUID,
        hasAppleIdentity: Bool
    ) -> Bool {
        originalUserID == recoveredUserID && hasAppleIdentity
    }

    /// An unbound installation may discover that Apple already owns a
    /// Counting Sheep account. Apple authentication is sufficient to reopen
    /// that account, but the caller must quarantine account-scoped local
    /// transport before using the returned session.
    static func permitsExistingAccountSignIn(hasAppleIdentity: Bool) -> Bool {
        hasAppleIdentity
    }
}

enum NightFlockAccountSessionTransition: Equatable, Sendable {
    case returnAnonymous
    case createAnonymous
    case returnLinked(adopting: UUID?)
    case reauthenticateApple(signOutLocalSession: Bool)
    case failClosed(signOutLocalSession: Bool)
}

enum NightFlockAccountSessionPolicy {
    static func decide(
        observed: NightFlockObservedAccountSession,
        expectedIdentity: NightFlockExpectedIdentity,
        createAnonymousIfMissing: Bool
    ) -> NightFlockAccountSessionTransition {
        switch observed {
        case .missing:
            switch expectedIdentity {
            case .absent:
                return createAnonymousIfMissing ? .createAnonymous : .returnAnonymous
            case .valid:
                return .reauthenticateApple(signOutLocalSession: false)
            case .invalid:
                return .failClosed(signOutLocalSession: false)
            }
        case .anonymous:
            switch expectedIdentity {
            case .absent:
                return .returnAnonymous
            case .valid:
                return .reauthenticateApple(signOutLocalSession: true)
            case .invalid:
                return .failClosed(signOutLocalSession: true)
            }
        case let .appleLinked(id):
            switch expectedIdentity {
            case .absent:
                return .returnLinked(adopting: id)
            case let .valid(expected) where expected == id:
                return .returnLinked(adopting: nil)
            case .valid, .invalid:
                return .failClosed(signOutLocalSession: true)
            }
        case .unsupported:
            return .failClosed(signOutLocalSession: true)
        }
    }

    static func mayLinkAppleIdentity(
        observed: NightFlockObservedAccountSession,
        expectedIdentity: NightFlockExpectedIdentity
    ) -> Bool {
        observed == .anonymous && expectedIdentity == .absent
    }
}

enum NightFlockAuthenticationAction: Equatable, Sendable {
    case none
    case reauthenticateApple
    case linkCurrentAnonymousApple
    case failClosed
}

struct NightFlockAuthenticationRecoveryDecision: Equatable, Sendable {
    let action: NightFlockAuthenticationAction
    /// Authentication recovery never mutates local social or ritual state.
    let preservesSnapshot: Bool
    let preservesRunContexts: Bool
    let preservesAllOutboxes: Bool
    /// Direct mutations are reconciled after identity validation, never replayed.
    let refreshAfterValidation: Bool
    /// Queued, idempotent records may resume after validation.
    let mayFlushOutboxAfterValidation: Bool
}

enum NightFlockAuthenticationRecoveryPolicy {
    static func decide(
        remoteCode: NightFlockRemoteErrorCode,
        lane: NightFlockRecoveryLane,
        session: NightFlockRecoverySession,
        expectedIdentity: NightFlockExpectedIdentity
    ) -> NightFlockAuthenticationRecoveryDecision {
        let preserves = NightFlockAuthenticationRecoveryDecision(
            action: .none,
            preservesSnapshot: true,
            preservesRunContexts: true,
            preservesAllOutboxes: true,
            refreshAfterValidation: false,
            mayFlushOutboxAfterValidation: false
        )
        switch remoteCode {
        case .unauthorized:
            guard case .valid = expectedIdentity else {
                return NightFlockAuthenticationRecoveryDecision(
                    action: .failClosed, preservesSnapshot: true, preservesRunContexts: true,
                    preservesAllOutboxes: true, refreshAfterValidation: false,
                    mayFlushOutboxAfterValidation: false
                )
            }
            return NightFlockAuthenticationRecoveryDecision(
                action: .reauthenticateApple, preservesSnapshot: true, preservesRunContexts: true,
                preservesAllOutboxes: true, refreshAfterValidation: true,
                mayFlushOutboxAfterValidation: true
            )
        case .linkedAccountRequired:
            guard session == .anonymous, expectedIdentity.permitsInitialBinding else {
                return NightFlockAuthenticationRecoveryDecision(
                    action: .failClosed, preservesSnapshot: true, preservesRunContexts: true,
                    preservesAllOutboxes: true, refreshAfterValidation: false,
                    mayFlushOutboxAfterValidation: false
                )
            }
            return NightFlockAuthenticationRecoveryDecision(
                action: .linkCurrentAnonymousApple, preservesSnapshot: true, preservesRunContexts: true,
                preservesAllOutboxes: true, refreshAfterValidation: true,
                mayFlushOutboxAfterValidation: true
            )
        default:
            return preserves
        }
    }
}

/// Recovery signals can arrive out of order from requests that were already in
/// flight. Fail-closed is absorbing for the view-model recovery lifecycle and
/// is not cleared by same-identity recovery once a later fail-closed result has
/// arrived; reset/reconstruction is outside this reducer.
enum NightFlockAuthenticationRecoveryStatePolicy {
    static func merge(
        current: NightFlockAuthenticationAction,
        incoming: NightFlockAuthenticationAction
    ) -> NightFlockAuthenticationAction {
        if current == .failClosed || incoming == .failClosed {
            return .failClosed
        }
        if current == .none {
            return incoming
        }
        return current
    }
}

struct NightFlockAuthenticationRecoveryPresentation: Equatable, Sendable {
    let action: NightFlockAuthenticationAction
    let shouldUpdatePresentation: Bool
}

/// Authentication signals can arrive out of order from session inspection,
/// state loads, commands, and outbox delivery. A signal may establish a
/// recovery from `.none` or escalate to fail-closed, but cannot replace a
/// presentation already owned by a newer request.
enum NightFlockAuthenticationRecoveryPresentationPolicy {
    static func decide(
        current: NightFlockAuthenticationAction,
        incoming: NightFlockAuthenticationAction
    ) -> NightFlockAuthenticationRecoveryPresentation {
        let merged = NightFlockAuthenticationRecoveryStatePolicy.merge(
            current: current,
            incoming: incoming
        )
        if current == .failClosed {
            return NightFlockAuthenticationRecoveryPresentation(
                action: merged,
                shouldUpdatePresentation: false
            )
        }
        if incoming == .failClosed {
            return NightFlockAuthenticationRecoveryPresentation(
                action: merged,
                shouldUpdatePresentation: true
            )
        }
        if current != .none {
            return NightFlockAuthenticationRecoveryPresentation(
                action: merged,
                shouldUpdatePresentation: false
            )
        }
        return NightFlockAuthenticationRecoveryPresentation(
            action: merged,
            shouldUpdatePresentation: true
        )
    }
}

/// An Apple callback owns only the recovery action it started with. Any result
/// from an older Sign in with Apple request must not mutate a newer
/// reconnect/link action, and must never mutate a later fail-closed result.
enum NightFlockAuthenticationRecoveryCompletionPolicy {
    static func ownsCallback(
        captured: NightFlockAuthenticationAction,
        current: NightFlockAuthenticationAction
    ) -> Bool {
        captured != .failClosed && captured == current
    }
}

/// All Night Flock transports consult this single pure gate. A recovery action
/// deliberately pauses every state load, command, reconciliation, and outbox
/// lane until a same-account Apple recovery succeeds. This prevents a still
/// `.linked` UI state from continuing to use a rejected credential.
enum NightFlockTransportRecoveryPolicy {
    static func permitsNetwork(recovery: NightFlockAuthenticationAction) -> Bool {
        recovery == .none
    }

    /// Session inspection can cause Supabase work or anonymous creation, so it
    /// shares the exact recovery gate used by ordinary Night Flock transport.
    static func permitsAccountSessionInspection(recovery: NightFlockAuthenticationAction) -> Bool {
        permitsNetwork(recovery: recovery)
    }

    static func shouldStopOutboxFlush(
        remoteCode: NightFlockRemoteErrorCode,
        recovery: NightFlockAuthenticationAction
    ) -> Bool {
        !permitsNetwork(recovery: recovery)
            || remoteCode == .unauthorized
            || remoteCode == .linkedAccountRequired
    }
}

enum NightFlockAppleRecoveryFailure: Equatable, Sendable {
    case cancellationOrNetwork
    case identityAlreadyExists
    case identityValidationFailed
    case other
}

/// Apple recovery keeps a retryable recovery only for cancellation, offline,
/// and ordinary provider failures. A provider account collision or any failed
/// identity proof makes the presentation explicitly fail closed.
enum NightFlockAppleRecoveryFailurePolicy {
    static func nextAction(
        recovery: NightFlockAuthenticationAction,
        failure: NightFlockAppleRecoveryFailure
    ) -> NightFlockAuthenticationAction {
        guard recovery != .none else { return .none }
        guard recovery != .failClosed else { return .failClosed }
        switch failure {
        case .identityAlreadyExists, .identityValidationFailed:
            return .failClosed
        case .cancellationOrNetwork, .other:
            return recovery
        }
    }
}

enum NightFlockDestructiveLocalEffect: Codable, Equatable, Sendable {
    case none
    case clearOutboxesAndRunContexts
}

enum NightFlockPendingDestructiveIntent: Codable, Equatable, Sendable {
    case leave
    case block(memberID: UUID)
    case deleteNightFlockData
    case sharingOff

    static func from(command: NightFlockCommand) -> NightFlockPendingDestructiveIntent? {
        switch command {
        case .leave: return .leave
        case let .block(memberID, _): return .block(memberID: memberID)
        case .deleteNightFlockData: return .deleteNightFlockData
        case .setSharing(false, _): return .sharingOff
        default: return nil
        }
    }
}

enum NightFlockPendingIntentPolicy {
    enum Resolution: Equatable, Sendable { case applied, notApplied, unknown }
    enum FailureDisposition: Equatable, Sendable {
        case presentAuthenticationRecovery
        case definitiveRejection
        case retainAmbiguousJournal
    }
    enum LocalDisposition: Equatable, Sendable {
        case commitDestructiveClear
        case preserveAndReleaseIntent
        case preserveAndBlockFlush
    }

    static func localEffect(
        for _: NightFlockPendingDestructiveIntent
    ) -> NightFlockDestructiveLocalEffect {
        .clearOutboxesAndRunContexts
    }

    /// A state response is authoritative for the membership contract. A nil
    /// snapshot means that this account no longer has Night Flock data, so it
    /// proves leave/delete and a targeted block were applied. If that API
    /// contract changes, callers must return `.unknown` instead of guessing.
    static func resolve(
        intent: NightFlockPendingDestructiveIntent,
        snapshot: NightFlockSnapshot?
    ) -> Resolution {
        switch intent {
        case .leave, .deleteNightFlockData:
            return snapshot == nil ? .applied : .notApplied
        case .sharingOff:
            guard let snapshot else { return .applied }
            return snapshot.sharingEnabled ? .notApplied : .applied
        case let .block(memberID):
            guard let snapshot else { return .applied }
            return snapshot.members.contains(where: { $0.id == memberID }) ? .notApplied : .applied
        }
    }

    static func permitsFlush(intentPresent: Bool) -> Bool { !intentPresent }

    static func permitsLocalMutation(
        intentPresent: Bool,
        stagedEffect: NightFlockDestructiveLocalEffect,
        authenticationTransportPermitted: Bool
    ) -> Bool {
        !intentPresent && stagedEffect == .none && authenticationTransportPermitted
    }

    static func disposition(for resolution: Resolution) -> LocalDisposition {
        switch resolution {
        case .applied: return .commitDestructiveClear
        case .notApplied: return .preserveAndReleaseIntent
        case .unknown: return .preserveAndBlockFlush
        }
    }
    static func failureDisposition(
        remoteCode: NightFlockRemoteErrorCode?
    ) -> FailureDisposition {
        switch remoteCode {
        case .some(.unauthorized), .some(.linkedAccountRequired):
            return .presentAuthenticationRecovery
        case .some(.invalidRequest), .some(.methodNotAllowed):
            return .definitiveRejection
        default:
            return .retainAmbiguousJournal
        }
    }

    static func definitiveRejection(_ error: NightFlockRemoteError?) -> Bool {
        failureDisposition(remoteCode: error?.code) == .definitiveRejection
    }
}

/// The actor applies this transition in write order. The first state models a
/// termination after the accepted marker is durable but before the preflight
/// intent is removed; restart reconciliation can safely repeat that state.
enum NightFlockPendingIntentTransitionPolicy {
    struct State: Equatable, Sendable {
        var stagedEffect: NightFlockDestructiveLocalEffect
        var pendingIntentPresent: Bool
    }

    enum RelaunchResolution: Equatable, Sendable {
        case commitAcceptedMarkerThenRemoveIntent
        case resolvePendingIntent
        case none
    }

    /// A durable accepted marker outranks a still-present preflight intent.
    /// The latter can remain only because termination happened between the two
    /// writes; it must not use eventually-consistent state to cancel proof of
    /// an already accepted command.
    static func relaunchResolution(
        stagedEffect: NightFlockDestructiveLocalEffect,
        pendingIntentPresent: Bool
    ) -> RelaunchResolution {
        guard pendingIntentPresent else { return .none }
        return stagedEffect == .none
            ? .resolvePendingIntent
            : .commitAcceptedMarkerThenRemoveIntent
    }

    static func afterAcceptedMarkerWrite(
        effect: NightFlockDestructiveLocalEffect
    ) -> State {
        State(stagedEffect: effect, pendingIntentPresent: true)
    }

    static func afterAcceptedTransition(
        effect: NightFlockDestructiveLocalEffect
    ) -> State {
        State(stagedEffect: effect, pendingIntentPresent: false)
    }

    static func afterDefinitiveRejection() -> State {
        State(stagedEffect: .none, pendingIntentPresent: false)
    }
}

enum NightFlockTransportEpochPolicy {
    static func isCurrent(captured: UInt64, current: UInt64) -> Bool { captured == current }
    static func advancing(_ current: UInt64) -> UInt64 { current &+ 1 }
}

enum NightFlockDestructiveCommitStage: Equatable, Sendable {
    case awaitingValidatedSnapshot
    case validatedResponseSnapshot
    case validatedStateReconciliation
}

/// V1 command responses can omit a snapshot. Destructive local effects stay
/// staged until either a response snapshot or a follow-up state load has
/// completed successfully; this preserves local state when that reconciliation
/// reaches an authentication boundary.
enum NightFlockDirectCommandCommitPolicy {
    static func localEffect(for command: NightFlockCommand) -> NightFlockDestructiveLocalEffect {
        switch command {
        case .leave, .block, .deleteNightFlockData:
            return .clearOutboxesAndRunContexts
        case .setSharing(let enabled, _) where !enabled:
            return .clearOutboxesAndRunContexts
        default:
            return .none
        }
    }

    static func shouldCommit(
        _ effect: NightFlockDestructiveLocalEffect,
        at stage: NightFlockDestructiveCommitStage
    ) -> Bool {
        effect != .none && stage != .awaitingValidatedSnapshot
    }
}

/// A server-accepted destructive v1 command is never replayed. If its response
/// omits state, its local effect remains staged until an authoritative state
/// snapshot later arrives (including after identity recovery).
enum NightFlockStagedDestructiveCommitPolicy {
    static func stage(
        existing: NightFlockDestructiveLocalEffect,
        incoming: NightFlockDestructiveLocalEffect
    ) -> NightFlockDestructiveLocalEffect {
        existing == .none ? incoming : existing
    }

    static func preserveAfterUnvalidatedReconciliation(
        staged: NightFlockDestructiveLocalEffect
    ) -> NightFlockDestructiveLocalEffect {
        staged
    }

    static func consumeAfterAuthoritativeState(
        staged: NightFlockDestructiveLocalEffect
    ) -> (effectToCommit: NightFlockDestructiveLocalEffect, remaining: NightFlockDestructiveLocalEffect) {
        (staged, .none)
    }
}

/// The outbox actor owns its admission epoch. A clear advances beyond both the
/// caller's pre-clear epoch and any earlier clear, so stale queued mutations
/// cannot repopulate deleted records after the actor processes the clear.
enum NightFlockOutboxEpochPolicy {
    static func admits(callerEpoch: UInt64, acceptedEpoch: UInt64) -> Bool {
        callerEpoch == acceptedEpoch
    }

    static func advancingClear(acceptedEpoch: UInt64, requestedEpoch: UInt64) -> UInt64 {
        max(acceptedEpoch, requestedEpoch) &+ 1
    }

    static func admitsClear(requestedEpoch: UInt64, acceptedEpoch: UInt64) -> Bool {
        requestedEpoch > acceptedEpoch
    }

    static func mayAdoptClearCompletion(currentEpoch: UInt64, returnedEpoch: UInt64) -> Bool {
        returnedEpoch >= currentEpoch
    }
}

struct NightFlockOutboxClearResult: Equatable, Sendable {
    let epoch: UInt64
    let didClear: Bool
}

enum NightFlockRelaunchReconciliationPolicy {
    static func requiresAuthoritativeReconciliation(
        staged: NightFlockDestructiveLocalEffect
    ) -> Bool { staged != .none }

    static func permitsOutboxFlush(staged: NightFlockDestructiveLocalEffect) -> Bool {
        staged == .none
    }
}

/// Full account deletion has a durable preflight state separate from the
/// accepted tombstone. A pending result is deliberately fail-closed: it may
/// be a server-side deletion whose response was lost, so no transport or
/// account inspection can safely occur and the command is never replayed.
enum NightFlockAccountDeletionIntentPolicy {
    enum Phase: Equatable, Sendable {
        case complete
        case pendingPreflight
        case acceptedTombstone
    }

    enum RecoveryAction: Equatable, Sendable {
        case none
        case failClosedNoNetworkNoReplay
        case finalizeLocally
    }

    static func phase(pendingIntentPresent: Bool, tombstonePresent: Bool) -> Phase {
        tombstonePresent ? .acceptedTombstone : (pendingIntentPresent ? .pendingPreflight : .complete)
    }

    static func recoveryAction(phase: Phase) -> RecoveryAction {
        switch phase {
        case .complete: return .none
        case .pendingPreflight: return .failClosedNoNetworkNoReplay
        case .acceptedTombstone: return .finalizeLocally
        }
    }

    static func permitsAdmission(phase: Phase) -> Bool { phase == .complete }

    /// The deletion preflight is an exclusive actor-owned transition, not an
    /// idempotent read. Once one caller has persisted `.pendingPreflight`, a
    /// second tap must not acquire the right to send another deletion request.
    static func permitsExclusivePreflightAcquisition(
        phase: Phase,
        ordinaryIntentPresent: Bool,
        stagedOrdinaryEffect: NightFlockDestructiveLocalEffect,
        callerEpoch: UInt64,
        acceptedEpoch: UInt64
    ) -> Bool {
        phase == .complete
            && !ordinaryIntentPresent
            && stagedOrdinaryEffect == .none
            && callerEpoch == acceptedEpoch
    }

    /// Ordinary destructive journal changes are allowed only while account
    /// deletion has no pending or accepted ownership. This keeps a corrupt or
    /// raced both-journal restore fail-closed rather than removing either key.
    static func permitsOrdinaryIntentTransition(
        phase: Phase,
        callerEpoch: UInt64,
        acceptedEpoch: UInt64
    ) -> Bool {
        phase == .complete && callerEpoch == acceptedEpoch
    }

    static func permitsActorMutation(
        phase: Phase,
        callerEpoch: UInt64,
        acceptedEpoch: UInt64
    ) -> Bool {
        permitsAdmission(phase: phase) && NightFlockOutboxEpochPolicy.admits(
            callerEpoch: callerEpoch,
            acceptedEpoch: acceptedEpoch
        )
    }

    static func permitsOrdinaryClear(
        phase: Phase,
        callerEpoch: UInt64,
        acceptedEpoch: UInt64
    ) -> Bool {
        permitsAdmission(phase: phase) && NightFlockOutboxEpochPolicy.admitsClear(
            requestedEpoch: callerEpoch,
            acceptedEpoch: acceptedEpoch
        )
    }

    /// A rejection leaves the actor at its existing epoch; only accepted
    /// deletion finalization owns a fresh closed epoch.
    static func epochAfterResponse(currentEpoch: UInt64, accepted: Bool) -> UInt64 {
        accepted ? currentEpoch &+ 1 : currentEpoch
    }

    static func mayRemoveTombstone(verifiedLocalSignOut: Bool) -> Bool {
        verifiedLocalSignOut
    }
}

enum NightFlockAcceptedDeletionPolicy {
    static func beginsFinalization(accepted: Bool) -> Bool { accepted }
    static func permitsLocalMutation(tombstonePresent: Bool) -> Bool { !tombstonePresent }
    enum FinalizationStep: Equatable, Sendable {
        case clearLanes
        case clearInviteCredential
        case clearIdentityAndSignOut
        case removeTombstone
        case resetPresentation
    }

    static func finalizationSteps(tombstonePresent: Bool) -> [FinalizationStep] {
        tombstonePresent ? [.clearLanes, .clearInviteCredential, .clearIdentityAndSignOut, .removeTombstone, .resetPresentation] : []
    }

    static func closedEpoch(acceptedEpoch: UInt64, requestedEpoch: UInt64) -> UInt64 {
        max(acceptedEpoch, requestedEpoch) &+ 1
    }

    enum RecoveryAction: Equatable, Sendable {
        case none
        case finalizeLocally
    }

    static func recoveryAction(tombstonePresent: Bool) -> RecoveryAction {
        tombstonePresent ? .finalizeLocally : .none
    }

    static func mayCompleteFinalization(
        inviteCredentialCleared: Bool,
        verifiedLocalSignOut: Bool
    ) -> Bool {
        inviteCredentialCleared && verifiedLocalSignOut
    }

    static func permitsActorMutation(
        tombstonePresent: Bool,
        callerEpoch: UInt64,
        acceptedEpoch: UInt64
    ) -> Bool {
        !tombstonePresent && NightFlockOutboxEpochPolicy.admits(
            callerEpoch: callerEpoch,
            acceptedEpoch: acceptedEpoch
        )
    }

    static func permitsOrdinaryClear(
        tombstonePresent: Bool,
        callerEpoch: UInt64,
        acceptedEpoch: UInt64
    ) -> Bool {
        !tombstonePresent && NightFlockOutboxEpochPolicy.admitsClear(
            requestedEpoch: callerEpoch,
            acceptedEpoch: acceptedEpoch
        )
    }
}

struct NightFlockRemoteError: Error, LocalizedError, Equatable, Sendable {
    let statusCode: Int
    let code: NightFlockRemoteErrorCode
    let requestID: String
    let retryable: Bool
    let recovery: NightFlockRemoteRecovery?

    var errorDescription: String? {
        switch code {
        case .unauthorized: return "Please link your Apple account to continue."
        case .linkedAccountRequired: return "Link your Apple account to join Slumber Party."
        case .methodNotAllowed, .invalidRequest: return "Slumber Party could not understand that request."
        case .unsupportedSchema: return "Slumber Party needs a newer connection."
        case .activeMembershipExists: return "You already have a Slumber Party."
        case .aliasConflict: return "Ollie couldn’t choose a unique alias for this lobby."
        case .inviteMemberConstraint: return "That invitation could not be added. Please try again."
        case .activeInviteExists: return "This lobby already has an invitation. Refresh it before making a new code."
        case .currentMembershipRequired: return "Your Slumber Party membership needs to be refreshed."
        case .inviteUnavailable: return "That invitation is no longer available."
        case .lobbyStarted: return "That lobby has already started."
        case .flockFull: return "That Slumber Party is full."
        case .blockedMembership: return "This Slumber Party is unavailable for this account."
        case .hostPermissionRequired: return "Only the host can do that."
        case .accountUnavailable: return "Slumber Party is unavailable for this account."
        case .staleRevision: return "That shared update is already up to date."
        case .snapshotConstructionFailed: return "Slumber Party could not load your lobby. Please try again."
        case .sharedHistoryDeleted: return "That shared record was removed and will not be sent again."
        case .publicationBeforeAgreement: return "That shared record began before this group agreement and will not be sent."
        case .agreementTimezoneMismatch: return "That sleep summary uses a different saved group time zone and will refresh."
        case .publicationOutsidePlanWindow: return "That shared plan is outside this group’s next-seven-night window."
        case .publicationOutsideReceiptWindow: return "That nightly result is outside this group’s current window."
        case .invalidSharedNightPayload: return "That shared-night update could not be used."
        case .invalidPlanChronology: return "That shared plan’s timing did not fit its night."
        case .invalidReceiptChronology: return "That nightly result’s timing did not fit its night."
        case .invalidPlanBinding, .receiptPlanMismatch: return "That nightly result no longer matches its saved plan."
        case .invalidReceiptSource: return "That nightly result needs its saved night identity."
        case .sharedNightPlanFrozen: return "That shared plan has already begun and will stay as it was."
        case .sharedNightPlanCancelled: return "That shared night is no longer available and will not be sent."
        case .receiptActualStartRequired: return "That factual nightly result needs its recorded start time."
        case .serviceUnavailable: return "Slumber Party is resting offline. Please try again."
        case .internalError: return "Slumber Party could not complete that request."
        }
    }

    var allowsSchemaFallback: Bool { code == .unsupportedSchema }
    var shouldReconcileMembership: Bool {
        recovery == .reconcileMembership || code == .activeMembershipExists || code == .currentMembershipRequired
    }

    var diagnosticFields: [String: String] {
        [
            "requestID": requestID,
            "code": code.rawValue,
            "status": String(statusCode),
        ]
    }

    init(statusCode: Int, code: NightFlockRemoteErrorCode, requestID: String, recovery: NightFlockRemoteRecovery? = nil) {
        self.statusCode = statusCode
        self.code = code
        self.requestID = Self.canonicalRequestID(requestID) ?? UUID().uuidString.lowercased()
        self.retryable = Self.policy(for: code).retryable
        self.recovery = recovery ?? Self.policy(for: code).recovery
    }

    static func decode(statusCode: Int, data: Data?, headerRequestID: String? = nil) -> NightFlockRemoteError {
        var body: [String: Any] = [:]
        if let data, let object = try? JSONSerialization.jsonObject(with: data), let object = object as? [String: Any] {
            body = object
        }
        let code = NightFlockRemoteErrorCode(rawValue: body["code"] as? String ?? "")
            ?? legacyCode(statusCode: statusCode, detail: body["error"] as? String)
        let bodyRequestID = body["requestID"] as? String
        let requestID = canonicalRequestID(bodyRequestID) ?? canonicalRequestID(headerRequestID) ?? UUID().uuidString.lowercased()
        return NightFlockRemoteError(statusCode: statusCode, code: code, requestID: requestID)
    }

    static func network(requestID: String = UUID().uuidString) -> NightFlockRemoteError {
        NightFlockRemoteError(statusCode: 0, code: .serviceUnavailable, requestID: requestID)
    }

    private static func legacyCode(statusCode: Int, detail: String?) -> NightFlockRemoteErrorCode {
        let normalized = (detail ?? "").lowercased()
        if normalized.contains("linked account required") || normalized.contains("apple-linked account") { return .linkedAccountRequired }
        if normalized.contains("unauthorized") || normalized.contains("invalid jwt") { return .unauthorized }
        if normalized.contains("one active slumber party") { return .activeMembershipExists }
        if normalized.contains("a reusable invitation already exists") || normalized.contains("active_invite_exists") { return .activeInviteExists }
        if normalized.contains("night_flock_members_active_alias") || (normalized.contains("23505") && normalized.contains("alias")) { return .aliasConflict }
        if normalized.contains("23505") && (normalized.contains("invite") || normalized.contains("member")) { return .inviteMemberConstraint }
        if normalized.contains("snapshot") || normalized.contains("projection") || (normalized.contains("construct") && normalized.contains("state")) { return .snapshotConstructionFailed }
        if normalized.contains("current membership required") { return .currentMembershipRequired }
        if normalized.contains("account already joined this lobby") { return .activeMembershipExists }
        if normalized.contains("invite") && (normalized.contains("expired") || normalized.contains("revoked") || normalized.contains("used") || normalized.contains("unavailable")) { return .inviteUnavailable }
        if normalized.contains("challenge unavailable") || normalized.contains("lobby unavailable") || normalized.contains("invitations close") || normalized.contains("already started") { return .lobbyStarted }
        if normalized.contains("full") || normalized.contains("capacity") { return .flockFull }
        if statusCode == 401 { return .unauthorized }
        if statusCode == 403 { return .accountUnavailable }
        if statusCode == 405 { return .methodNotAllowed }
        if statusCode == 409 { return .lobbyStarted }
        if statusCode == 410 { return .inviteUnavailable }
        if statusCode >= 500 || statusCode == 0 { return .serviceUnavailable }
        return .invalidRequest
    }

    private static func policy(for code: NightFlockRemoteErrorCode) -> (retryable: Bool, recovery: NightFlockRemoteRecovery?) {
        switch code {
        case .unauthorized: return (false, .authenticate)
        case .linkedAccountRequired: return (false, .linkAccount)
        case .activeMembershipExists, .currentMembershipRequired: return (false, .reconcileMembership)
        case .inviteMemberConstraint, .activeInviteExists, .staleRevision: return (false, .reconcile)
        case .unsupportedSchema: return (false, .fallbackSchema)
        case .lobbyStarted, .hostPermissionRequired: return (false, .reconcile)
        case .serviceUnavailable, .internalError, .snapshotConstructionFailed: return (true, .retry)
        case .sharedHistoryDeleted, .publicationBeforeAgreement, .agreementTimezoneMismatch: return (false, .reconcile)
        default: return (false, nil)
        }
    }

    private static func canonicalRequestID(_ value: String?) -> String? {
        guard let value, value.range(of: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89a-fA-F][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"#, options: .regularExpression) != nil else { return nil }
        return value.lowercased()
    }
}

/// A read failure belongs to its section, not the last command or another party.
struct NightFlockRefreshFailure: Equatable {
    let detail: String
    let requestReference: String?
    let canRetry: Bool

    static func actionTitle(for command: NightFlockV4Command, accepted: Bool) -> String {
        // A failed follow-up read must not invite repetition of a saved action.
        if accepted { return "Your change was saved. The latest view couldn’t be loaded." }
        switch command {
        case .updatePublicProfile: return "Your Slumber Party profile couldn’t be updated"
        case .createParty: return "Your Slumber Party couldn’t be created"
        case .renameParty: return "The party name couldn’t be changed"
        case .startRound: return "The next round couldn’t be started"
        case .createInvite, .replaceInvite, .revokeInvite, .retrieveInvite:
            return "The invitation couldn’t be updated"
        case .previewInvite: return "The invitation couldn’t be checked"
        case .redeemInvite: return "You couldn’t join this party yet"
        case .leaveParty: return "Your request to leave couldn’t be completed"
        case .deleteParty: return "The party couldn’t be deleted"
        case .blockMember: return "The member couldn’t be blocked"
        case .reportMember: return "Your report couldn’t be sent"
        case .deleteAccount: return "Your account couldn’t be deleted"
        case .cheerMember, .cheerMembershipMember, .react, .reactMembership:
            return "Your cheer couldn’t be sent"
        case .publishActivity, .completeBackfill: return "Your shared moment couldn’t be sent"
        case .publishStatus, .publishMembershipStatus: return "Your session update couldn’t be shared"
        case .acknowledgeGrant: return "Your party reward couldn’t be confirmed"
        }
    }

    init(remote: NightFlockRemoteError?) {
        requestReference = NightFlockSupportReference.format(requestID: remote?.requestID)
        canRetry = remote?.retryable ?? true
        switch remote?.code {
        case .invalidRequest, .methodNotAllowed, .unsupportedSchema:
            detail = "The app and Slumber Party couldn’t complete this request. Trying again may not help."
        case .none:
            detail = "The latest update couldn’t be reached. Check your connection and try again."
        default:
            detail = remote?.errorDescription ?? "The latest update couldn’t be loaded."
        }
    }
}

enum NightFlockSupportReference {
    static func canonicalRequestID(_ value: String?) -> String? {
        guard let value, value.range(of: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89a-fA-F][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"#, options: .regularExpression) != nil else { return nil }
        return value.lowercased()
    }

    static func format(requestID: String?) -> String? {
        guard let requestID = canonicalRequestID(requestID) else { return nil }
        return "Request ID: \(requestID)"
    }
}

struct NightFlockDiagnosticRecord: Equatable, Sendable {
    let requestID: String
    let code: String
    let operation: String
    let status: Int

    var fields: [String: String] {
        [
            "requestID": requestID,
            "code": code,
            "operation": operation,
            "status": String(status),
        ]
    }
}
