import AuthenticationServices
import Foundation
import Supabase

@MainActor
final class NightFlockViewModel: ObservableObject {
    enum Phase: Equatable {
        case hidden
        case idle
        case loading
        case ready
        case offline
        case expiredInvite
        case fullFlock
        case blocked
        case error(String)
    }

    @Published private(set) var phase: Phase
    @Published private(set) var diagnostics: NightFlockDiagnostics
    @Published private(set) var accountState: NightFlockAccountState {
        didSet {
            diagnostics = diagnostics.updatingAccountState(accountState)
        }
    }
    @Published private(set) var snapshot: NightFlockSnapshot?
    @Published private(set) var latestInviteCode: String?
    @Published private(set) var latestInviteID: UUID?
    @Published var shareNextPrimaryRun = true
    @Published var selectedIdentity: NightFlockIdentity = .moonlitMeadow
    @Published var joinCode = ""

    let featureEnabled: Bool
    private let accountService: NightFlockAccountService?
    private let service: NightFlockService?
    private let outbox: NightFlockOutboxService?
    private var pendingAppleNonce: String?
    private var runContexts: [UUID: NightFlockRunShareContext] = [:]

    var homeSummary: NightFlockHomeSummary? {
        guard featureEnabled else { return nil }
        return snapshot.map { NightFlockHomeSummary.make(from: $0) } ?? .invitation
    }

    var canShowSocialUI: Bool { featureEnabled }

    var canOfferSharingForNextPrimaryRun: Bool {
        featureEnabled && snapshot?.challenge.status == .active
    }

    var isChallengeSharingEnabled: Bool {
        snapshot?.sharingEnabled == true
    }

    init(
        featureEnabled: Bool,
        accountService: NightFlockAccountService? = nil,
        service: NightFlockService? = nil,
        outbox: NightFlockOutboxService? = nil,
        previewSnapshot: NightFlockSnapshot? = nil,
        previewPhase: Phase? = nil,
        previewAccountState: NightFlockAccountState = .anonymous,
        diagnostics: NightFlockDiagnostics? = nil
    ) {
        self.featureEnabled = featureEnabled
        self.accountService = accountService
        self.service = service
        self.outbox = outbox
        snapshot = previewSnapshot
        self.diagnostics = diagnostics ?? NightFlockDiagnostics.initial(
            featureFlag: featureEnabled ? .enabled : .disabled,
            configuration: featureEnabled ? .valid : .notEvaluated,
            accountState: previewAccountState
        )
        accountState = previewAccountState
        phase = previewPhase ?? (featureEnabled ? .idle : .hidden)
        guard featureEnabled, let outbox else { return }
        Task { [weak self] in
            let contexts = await outbox.runContexts()
            await MainActor.run {
                guard let self else { return }
                for context in contexts where self.runContexts[context.runID] == nil {
                    self.runContexts[context.runID] = context
                }
                self.objectWillChange.send()
            }
        }
    }

    static func configured(bundle: Bundle = .main, defaults: UserDefaults = .standard) -> NightFlockViewModel {
        let featureFlag = SupabaseConfiguration.nightFlockFeatureFlag(bundle: bundle)
        guard featureFlag == .enabled else {
            return NightFlockViewModel(
                featureEnabled: false,
                diagnostics: .initial(featureFlag: featureFlag, configuration: .notEvaluated)
            )
        }

        let configuration: SupabaseConfiguration
        do {
            configuration = try SupabaseConfiguration.load(bundle: bundle)
        } catch {
            return NightFlockViewModel(
                featureEnabled: false,
                diagnostics: .initial(
                    featureFlag: featureFlag,
                    configuration: .invalid(SupabaseConfiguration.nightFlockConfigurationIssue(for: error))
                )
            )
        }
        let provider = ConfiguredSupabaseClientProvider(configuration: configuration)
        return NightFlockViewModel(
            featureEnabled: true,
            accountService: NightFlockAccountService(provider: provider),
            service: NightFlockService(provider: provider),
            outbox: NightFlockOutboxService(defaults: defaults),
            diagnostics: .initial(featureFlag: featureFlag, configuration: .valid)
        )
    }

    func entryAppeared() {
        guard featureEnabled, phase != .loading else { return }
        Task { await activateEntry() }
    }

    func bootstrap() {
        guard featureEnabled, phase == .idle else { return }
        Task {
            guard let accountService else { return }
            do {
                accountState = try await accountService.currentState(createAnonymousIfMissing: false)
                guard accountState == .linked else { return }
                await flushOutbox()
                await refreshState(showLoading: false)
            } catch {
                accountState = .unavailable
            }
        }
    }

    func resetNextPrimaryRunSharing() {
        shareNextPrimaryRun = true
    }

    func handleForeground() {
        guard featureEnabled, accountState == .linked else { return }
        Task {
            await flushOutbox()
            await refreshState(showLoading: false)
        }
    }

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try NightFlockAccountService.makeAppleNonce()
            pendingAppleNonce = nonce.rawValue
            request.nonce = nonce.requestValue
            request.requestedScopes = []
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard featureEnabled else { return }
        switch result {
        case .failure(let error):
            pendingAppleNonce = nil
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                phase = .idle
            } else {
                phase = .error("Apple sign-in did not finish. Please try again.")
            }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  let nonce = pendingAppleNonce else {
                phase = .error(NightFlockAccountError.identityTokenMissing.localizedDescription)
                return
            }
            pendingAppleNonce = nil
            guard let accountService else {
                accountState = .unavailable
                phase = .error("Account linking is unavailable in this build. Your current account was left unchanged.")
                return
            }
            accountState = .linking
            phase = .loading
            Task {
                do {
                    try await accountService.linkAppleIdentity(identityToken: token, nonce: nonce)
                    accountState = .linked
                    await refreshState(showLoading: true)
                } catch {
                    accountState = .anonymous
                    phase = .error(NightFlockAccountService.linkFailureMessage(for: error))
                }
            }
        }
    }

    func retryAccountConnection() {
        guard featureEnabled, accountState != .linking else { return }
        phase = .idle
        Task { await activateEntry() }
    }

    func createFlock() {
        let timeZone = TimeZone.current.identifier
        perform(.createFlock(
            identity: selectedIdentity,
            timeZoneIdentifier: timeZone,
            idempotencyKey: NightFlockIdempotency.command("create-flock")
        ))
    }

    func joinFlock() {
        let normalized = joinCode.uppercased().filter { $0.isLetter || $0.isNumber }
        guard !normalized.isEmpty else { return }
        perform(.join(
            shortCode: normalized,
            idempotencyKey: NightFlockIdempotency.command("join")
        ))
    }

    func createInvite() {
        perform(.createInvite(idempotencyKey: NightFlockIdempotency.command("invite")))
    }

    func revokeLatestInvite() {
        guard let latestInviteID else { return }
        perform(.revokeInvite(
            inviteID: latestInviteID,
            idempotencyKey: NightFlockIdempotency.command("revoke-invite-\(latestInviteID.uuidString)")
        ))
    }

    func leave() {
        perform(.leave(idempotencyKey: NightFlockIdempotency.command("leave")))
    }

    func setSharingEnabled(_ enabled: Bool) {
        perform(.setSharing(
            enabled: enabled,
            idempotencyKey: NightFlockIdempotency.command("sharing-\(enabled)")
        ), showLoading: false)
    }

    func block(_ member: NightFlockMember) {
        perform(.block(
            memberID: member.id,
            idempotencyKey: NightFlockIdempotency.command("block-\(member.id.uuidString)")
        ))
    }

    func report(_ member: NightFlockMember, reason: NightFlockReportReason) {
        perform(.report(
            memberID: member.id,
            reason: reason,
            idempotencyKey: NightFlockIdempotency.command("report-\(member.id.uuidString)-\(reason.rawValue)")
        ))
    }

    func react(to entry: NightFlockPastureEntry, with reaction: NightFlockReactionKind) {
        perform(.react(
            checkInID: entry.id,
            reaction: reaction,
            idempotencyKey: NightFlockIdempotency.command("react-\(entry.id.uuidString)-\(reaction.rawValue)")
        ), showLoading: false)
    }

    func deleteNightFlockData() {
        perform(.deleteNightFlockData(
            idempotencyKey: NightFlockIdempotency.command("delete-night-flock")
        ))
    }

    func deleteOnlineAccount() {
        guard accountState == .linked else { return }
        Task {
            do {
                let response = try await service?.send(.deleteAccount(
                    idempotencyKey: NightFlockIdempotency.command("delete-account")
                ))
                guard response?.accepted == true else { throw NightFlockServiceError.unsupportedResponse }
                await accountService?.signOutAfterAccountDeletion()
                await outbox?.clear()
                runContexts = [:]
                snapshot = nil
                accountState = .anonymous
                phase = .idle
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    func preparePrimaryRun(runID: UUID, at date: Date, share: Bool) {
        defer { shareNextPrimaryRun = true }
        guard share, let snapshot, snapshot.sharingEnabled,
              let day = NightFlockChallengeDayRules.challengeDay(at: date, challenge: snapshot.challenge) else {
            return
        }
        let context = NightFlockRunShareContext(
            runID: runID,
            challengeID: snapshot.challenge.id,
            memberID: snapshot.myMemberID,
            challengeDay: day,
            createdAt: date
        )
        runContexts[runID] = context
        Task { await outbox?.saveRunContext(context) }
    }

    func publishPhoneTucked(for run: FocusRun) {
        guard run.isProgressionEligibleNightWatch,
              run.phoneAwayValidatedAt != nil,
              var context = runContexts[run.id],
              !context.phoneTuckedQueued else { return }
        context.phoneTuckedQueued = true
        runContexts[run.id] = context
        enqueue(state: .phoneTucked, for: context)
    }

    func handleTerminalRun(_ run: FocusRun) {
        guard var context = runContexts[run.id] else {
            Task {
                guard let restored = await outbox?.runContexts().first(where: { $0.runID == run.id }) else {
                    return
                }
                runContexts[run.id] = restored
                handleTerminalRun(run)
            }
            return
        }
        guard run.completedSuccessfully, run.isProgressionEligibleNightWatch else {
            runContexts.removeValue(forKey: run.id)
            Task { await outbox?.removeRunContext(run.id) }
            return
        }
        guard !context.morningQuietCompletedQueued else { return }
        context.phoneTuckedQueued = true
        context.morningQuietCompletedQueued = true
        runContexts[run.id] = context
        enqueue(state: .morningQuietCompleted, for: context)
    }

    func hasSharedResult(for runID: UUID) -> Bool {
        runContexts[runID] != nil
    }

    private func activateEntry() async {
        guard let accountService else { return }
        phase = .loading
        do {
            accountState = try await accountService.currentState(createAnonymousIfMissing: true)
            if accountState == .linked {
                await flushOutbox()
                await refreshState(showLoading: false)
            } else {
                phase = .idle
            }
        } catch {
            accountState = .unavailable
            phase = .offline
        }
    }

    private func refreshState(showLoading: Bool) async {
        guard let service else { return }
        if showLoading { phase = .loading }
        do {
            snapshot = try await service.state()
            phase = .ready
        } catch {
            phase = snapshot == nil ? .offline : .ready
        }
    }

    private func perform(_ command: NightFlockCommand, showLoading: Bool = true) {
        guard accountState == .linked, let service else { return }
        if showLoading { phase = .loading }
        Task {
            do {
                let response = try await service.send(command)
                guard response.accepted else { throw NightFlockServiceError.unsupportedResponse }
                switch command {
                case .leave, .block, .deleteNightFlockData:
                    await outbox?.clear()
                    runContexts = [:]
                case .setSharing(let enabled, _) where !enabled:
                    await outbox?.clear()
                    runContexts = [:]
                default:
                    break
                }
                latestInviteCode = response.inviteCode
                latestInviteID = response.inviteID
                if let responseSnapshot = response.snapshot { snapshot = responseSnapshot }
                else { snapshot = try await service.state() }
                phase = .ready
            } catch {
                phase = Self.phase(for: error)
            }
        }
    }

    private func enqueue(state: NightFlockCheckInState, for context: NightFlockRunShareContext) {
        guard let outbox else { return }
        let record = NightFlockOutboxRecord(
            challengeID: context.challengeID,
            memberID: context.memberID,
            challengeDay: context.challengeDay,
            runID: context.runID,
            state: state,
            idempotencyKey: NightFlockIdempotency.checkIn(
                challengeID: context.challengeID,
                memberID: context.memberID,
                day: context.challengeDay,
                runID: context.runID,
                state: state
            )
        )
        Task {
            await outbox.enqueue(record, updating: context)
            await flushOutbox()
        }
    }

    private func flushOutbox() async {
        guard accountState == .linked, let outbox, let service else { return }
        for record in await outbox.records() {
            do {
                let response = try await service.send(.publishCheckIn(
                    challengeID: record.challengeID,
                    day: record.challengeDay,
                    state: record.state,
                    idempotencyKey: record.idempotencyKey
                ))
                guard response.accepted else { throw NightFlockServiceError.unsupportedResponse }
                await outbox.remove(record.id)
                if let updated = response.snapshot { snapshot = updated }
            } catch {
                await outbox.markAttempt(record.id)
                phase = snapshot == nil ? .offline : phase
                return
            }
        }
    }

}
