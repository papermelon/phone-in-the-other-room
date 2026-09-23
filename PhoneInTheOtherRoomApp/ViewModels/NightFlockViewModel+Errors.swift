import Foundation
import Supabase

extension NightFlockViewModel {
    func presentListRefreshError(_ error: Error) {
        guard !(error is CancellationError) else { return }
        presentNightFlockError(error, lane: .snapshot(schema: 4))
        guard pendingAuthenticationRecovery == .none else { return }
        let failure = NightFlockRefreshFailure(listError: Self.remoteError(from: error), showingPrevious: v4ListState != nil)
        listRefreshFailure = failure
        phase = v4ListState == nil ? .error(failure.detail) : .ready
    }

    func refreshFailure(for error: Error) -> NightFlockRefreshFailure? {
        let remote = Self.remoteError(from: error)
        if let remote {
            let presentation = configureAuthenticationRecovery(remote, lane: .snapshot(schema: 4))
            guard presentation.shouldUpdatePresentation else { return nil }
            if pendingAuthenticationRecovery != .none {
                presentNightFlockError(error, lane: .snapshot(schema: 4))
                return nil
            }
        } else if pendingAuthenticationRecovery != .none {
            return nil
        }
        return NightFlockRefreshFailure(remote: remote)
    }

    static func recoveryKind(for remote: NightFlockRemoteError) -> NightFlockRemoteRecovery? {
        switch remote.recovery {
        case .reconcileMembership, .reconcile, .retry:
            return remote.recovery
        case .linkAccount, .authenticate, .fallbackSchema, .none:
            return remote.retryable ? .retry : nil
        }
    }

    func presentNightFlockError(
        _ error: Error,
        lane: NightFlockRecoveryLane = .snapshot(schema: 3),
        actionTitle: String? = nil
    ) {
        if let remote = Self.remoteError(from: error) {
            let presentation = configureAuthenticationRecovery(remote, lane: lane)
            guard presentation.shouldUpdatePresentation else { return }
            actionFailureTitle = actionTitle
            requestReference = NightFlockSupportReference.format(requestID: remote.requestID)
            pendingNightFlockRecovery = pendingAuthenticationRecovery == .none
                ? Self.recoveryKind(for: remote)
                : nil
            phase = Self.phase(for: remote)
            return
        }

        // A non-auth error from an older request cannot replace an owned
        // Apple-recovery presentation or its support reference.
        guard pendingAuthenticationRecovery == .none else { return }
        actionFailureTitle = actionTitle
        requestReference = nil
        if error is FunctionsError || error is URLError {
            requestReference = NightFlockSupportReference.format(requestID: UUID().uuidString)
        }
        phase = Self.phase(for: error)
    }

    @discardableResult
    func configureAuthenticationRecovery(
        _ remote: NightFlockRemoteError,
        lane: NightFlockRecoveryLane
    ) -> NightFlockAuthenticationRecoveryPresentation {
        let incoming = authenticationRecoveryAction(for: remote, lane: lane)
        let presentation = NightFlockAuthenticationRecoveryPresentationPolicy.decide(
            current: pendingAuthenticationRecovery,
            incoming: incoming
        )
        guard presentation.shouldUpdatePresentation else { return presentation }
        let previous = pendingAuthenticationRecovery
        pendingAuthenticationRecovery = presentation.action
        // Only a newly owned recovery (or fail-closed escalation) invalidates
        // in-flight transport. Repeating the same presentation must not make
        // its own current request stale.
        if previous != presentation.action {
            transportRecoveryEpoch = NightFlockTransportEpochPolicy.advancing(transportRecoveryEpoch)
            if presentation.action != .none {
                stopV4RealtimePresentation()
            }
        }
        if pendingAuthenticationRecovery == .failClosed {
            pendingNightFlockRecovery = nil
        }
        return presentation
    }

    private func authenticationRecoveryAction(
        for remote: NightFlockRemoteError,
        lane: NightFlockRecoveryLane
    ) -> NightFlockAuthenticationAction {
        let expected = NightFlockExpectedIdentityBinding.classify(
            defaults.string(forKey: NightFlockAccountService.expectedLinkedUserIDKey)
        )
        let session: NightFlockRecoverySession
        switch accountState {
        case .anonymous: session = .anonymous
        case .linked: session = .linked
        case .unavailable: session = .missing
        case .linking: session = .unknown
        }
        return NightFlockAuthenticationRecoveryPolicy.decide(
            remoteCode: remote.code,
            lane: lane,
            session: session,
            expectedIdentity: expected
        ).action
    }

    static func remoteError(from error: Error) -> NightFlockRemoteError? {
        if let remote = error as? NightFlockRemoteError { return remote }
        if let error = error as? URLError { return .network(reason: error.code) }
        if let functionsError = error as? FunctionsError,
           case let .httpError(status, data) = functionsError {
            return NightFlockRemoteError.decode(statusCode: status, data: data)
        }
        return nil
    }

    static func phase(for error: Error) -> Phase {
        if let remote = error as? NightFlockRemoteError {
            switch remote.code {
            case .inviteUnavailable: return .expiredInvite
            case .flockFull: return .fullFlock
            case .blockedMembership: return .blocked
            default: return .error(remote.errorDescription ?? "Something went wrong with Slumber Party. Please try again in a moment.")
            }
        }
        if let functionsError = error as? FunctionsError {
            switch functionsError {
            case .relayError:
                return .offline
            case .httpError(let code, let data):
                return phase(for: NightFlockRemoteError.decode(statusCode: code, data: data))
            }
        }
        if error is URLError { return .offline }
        return .error("Something went wrong with Slumber Party. Please try again in a moment.")
    }

    var canRetryNightFlockRequest: Bool {
        pendingNightFlockRecovery != nil || phase == .offline
    }

    func retryNightFlockRequest() {
        guard NightFlockTransportRecoveryPolicy.permitsNetwork(
            recovery: pendingAuthenticationRecovery
        ) else {
            // The Sign in with Apple control remains the only recovery path.
            return
        }
        switch pendingNightFlockRecovery {
        case .reconcileMembership:
            pendingNightFlockRecovery = nil
            Task { await reconcileMembershipRecovery() }
        case .retry, .reconcile:
            pendingNightFlockRecovery = nil
            Task { await refreshNightFlockStateForRecovery() }
        case .linkAccount, .authenticate, .fallbackSchema, .none:
            phase = .loading
            Task { await refreshNightFlockStateForRecovery() }
        }
    }
}
