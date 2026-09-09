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

    @Published var phase: Phase
    @Published private(set) var diagnostics: NightFlockDiagnostics
    @Published private(set) var accountState: NightFlockAccountState {
        didSet {
            diagnostics = diagnostics.updatingAccountState(accountState)
        }
    }
    @Published var snapshot: NightFlockSnapshot?
    @Published var latestInviteCode: String?
    @Published var latestInviteID: UUID?
    @Published var invitePreview: NightFlockInvitePreview?
    @Published var inviteRecoveryPresentation: NightFlockInviteRecoveryPresentation = .hidden
    @Published var warmNotice: String?
    @Published var requestReference: String?
    @Published var orientationState: NightFlockOrientationState
    @Published var commitmentDraft = NightFlockCommitmentDraft()
    @Published var shareNextPrimaryRun = true
    @Published var selectedIdentity: NightFlockIdentity = .moonlitMeadow
    @Published var joinCode = ""
    @Published var prefersJoinEntry = false
    /// Additive schema-four presentation. Legacy `snapshot` remains intact for
    /// clients and deployments that have not yet upgraded.
    @Published var v4ListState: NightFlockV4ListStateResponse?
    @Published var selectedV4Party: NightFlockV4PartyDetail?
    @Published var v4InvitePreview: NightFlockV4InvitePreview?
    struct V4InviteCode: Equatable {
        var inviteID: UUID
        var code: String
    }
    @Published var v4InviteCodes: [UUID: V4InviteCode] = [:]
    @Published var v4RequestID: String?
    @Published var v4Profile: CountingSheepUserProfile?
    @Published var v4GrantInbox: [NightFlockV4GrantInboxItem] = []
    @Published var sharedHabitsPrivacyFences: [NightFlockSharedHabitsPrivacyFence] = []
    @Published var sharedHabitsStates: [UUID: NightFlockSharedHabitsStateResponse] = [:]
    @Published var sharedHabitsLoadingPartyIDs: Set<UUID> = []
    @Published var sharedNightsLoadingPartyIDs: Set<UUID> = []
    @Published var sharedHabitsAgreementSavingPartyIDs: Set<UUID> = []
    @Published var sharedHabitsAgreementErrors: [UUID: String] = [:]
    var sharedHabitsAgreementAttemptIDs: [UUID: UUID] = [:]
    @Published var sharedHabitsFormerParties: [NightFlockSharedHabitsFormerParty] = []
    @Published var sharedHabitsStagedJoinPartyIDs: Set<UUID> = []
    var canonicalV4PartyIDs: Set<UUID> = []
    var hasCanonicalV4PartySnapshot = false
    var pendingV4ProfileMutation: CountingSheepUserProfile?
    /// The membership-filtered canonical detail cache feeds both the party
    /// screen and Home. It is deliberately one store, never list inference.
    // The v4 extension owns mutation. Cross-file Swift extensions cannot set a
    // `private(set)` property, so these remain module-internal while views use
    // the focused membership-filtered accessors in `+V4`.
    @Published var v4ObservedPartyDetails: [UUID: NightFlockV4PartyDetail] = [:]
    @Published var v4ObservedPartyRefreshDates: [UUID: Date] = [:]
    @Published var v4ObservedPartyObservationStates: [UUID: NightFlockV4PartyObservationState] = [:]
    @Published var v4RefreshingPartyIDs: Set<UUID> = []
    @Published var partyRefreshFailures: [UUID: NightFlockRefreshFailure] = [:]
    @Published var updateCheerAcknowledgements: [UUID: NightFlockV4CheerSendState] = [:]
    @Published var v4CheerSendStates: [NightFlockV4CheerCommandKey: NightFlockV4CheerSendState] = [:]
    var v4NextPartyDetailRequestSequence: UInt64 = 0
    var v4AcceptedPartyDetailRequestSequences: [UUID: UInt64] = [:]
    var v4RealtimeRefreshTasks: [UUID: Task<Void, Never>] = [:]
    var v4RealtimeSetupTasks: [UUID: Task<Void, Never>] = [:]
    var v4PartyObservationTasks: [UUID: Task<Void, Never>] = [:]
    var v4PartyObservationNeedsRefresh: Set<UUID> = []
    var v4RealtimeSetupAttemptIDs: [UUID: UUID] = [:]
    var v4RealtimeRefreshAttemptIDs: [UUID: UUID] = [:]
    var v4PartyObservationAttemptIDs: [UUID: UUID] = [:]
    var v4SelectedPartyRefreshAttemptIDs: [UUID: UUID] = [:]
    var v4RealtimePartyIDs: Set<UUID> = []
    var v4RealtimeConnectedPartyIDs: Set<UUID> = []
    var onApplyRewardGrants: (([NightFlockRewardGrant]) -> Void)?
    /// The v4 grant inbox uses party/round identifiers rather than legacy
    /// challenge milestones. The Farm layer owns the durable application and
    /// returns only grants it has actually recorded.
    var onApplyV4RewardGrants: (([NightFlockV4GrantInboxItem]) -> [UUID])?
    var onV4CheerFeedback: ((SlumberPartyCheerFeedback) -> Void)?
    var onSharedHabitsAgreementAvailable: (() -> Void)?
    /// The host restores local run history independently of this outbox. It
    /// uses this callback to reapply durable per-run privacy decisions once
    /// they have been decoded after a relaunch.
    var onPrimaryRunSharingDecisionsRestored: (() -> Void)?
    var onSharedHabitsAuthorityInvalidated: (() -> Void)?

    var v4InviteCode: String? {
        guard let party = selectedV4Party,
              let invitation = party.invitation,
              invitation.status == .active,
              v4InviteCodes[party.summary.partyID]?.inviteID == invitation.inviteID
        else { return nil }
        return v4InviteCodes[party.summary.partyID]?.code
    }

    let featureEnabled: Bool
    let accountService: NightFlockAccountService?
    let inviteCredentialService: NightFlockInviteCredentialService?
    let service: NightFlockService?
    let outbox: NightFlockOutboxService?
    let orientationStore: NightFlockOrientationStore
    let defaults: UserDefaults
    private struct AppleSignInAttempt {
        let nonce: String
        let recovery: NightFlockAuthenticationAction
        /// The recovery epoch that owned the request. A later recovery must
        /// never let this callback replace its presentation or session state.
        let transportEpoch: UInt64
    }
    private var pendingAppleSignInAttempt: AppleSignInAttempt?
    var pendingNightFlockRecovery: NightFlockRemoteRecovery?
    @Published var pendingAuthenticationRecovery: NightFlockAuthenticationAction = .none {
        didSet {
            quiesceInvitePlaintextPresentationIfNeeded(
                authenticationAction: pendingAuthenticationRecovery
            )
        }
    }
    var runContexts: [UUID: NightFlockRunShareContext] = [:]
    var primaryRunSharingDecisions: [UUID: NightFlockPrimaryRunSharingDecision] = [:]
    var primaryRunSharingRequiredAfter: Date?
    var localSocialGeneration: UInt64 = 0
    private var isDeletingOnlineAccount = false
    private var stagedDestructiveLocalEffect: NightFlockDestructiveLocalEffect = .none
    private var hasRestoredStagedDestructiveEffect = false
    private var accountEntryInFlight = false
    var inviteMutationInFlight = false
    var inviteCredential: NightFlockInviteCredential?
    var linkedAccountID: UUID?
    private var acceptedAccountDeletionTombstone = false
    private var pendingAccountDeletionIntent = false
    private var pendingDestructiveIntent: NightFlockPendingDestructiveIntent?
    // Split Night Flock extensions share this main-actor transport token; it
    // remains internal to the app module rather than becoming public API.
    var transportRecoveryEpoch: UInt64 = 0
    var sharedHabitsFenceGeneration: UInt64 = 0
    var sharedHabitsDestructiveCommandPartyIDs: Set<UUID> = []

    func quiesceInvitePlaintextPresentationIfNeeded(
        authenticationAction: NightFlockAuthenticationAction = .none,
        deletionSignal: NightFlockInviteDeletionSignal = .none
    ) {
        guard NightFlockInvitePlaintextVisibilityPolicy.shouldHide(
            authenticationAction: authenticationAction,
            deletionSignal: deletionSignal
        ) else { return }
        hideInvitePlaintextPresentation()
    }

    func hideInvitePlaintextPresentation() {
        inviteRecoveryPresentation = .hidden
        latestInviteCode = nil
    }

    struct SnapshotLoadFailure: Error {
        let underlying: Error
        let schema: Int
    }

    private struct NightFlockTransportPaused: Error {}

    var homeSummary: NightFlockHomeSummary? {
        NightFlockHomeDiscoveryPolicy.summary(
            featureEnabled: featureEnabled,
            v4Parties: v4ListState?.parties
        )
    }

    var canShowSocialUI: Bool { featureEnabled }

    private var accountDeletionIntentPhase: NightFlockAccountDeletionIntentPolicy.Phase {
        NightFlockAccountDeletionIntentPolicy.phase(
            pendingIntentPresent: pendingAccountDeletionIntent,
            tombstonePresent: acceptedAccountDeletionTombstone
        )
    }

    /// A recovery action quiesces all Night Flock transport, even before the
    /// UI's account state has changed away from `.linked`.
    var permitsNightFlockNetwork: Bool {
        hasRestoredStagedDestructiveEffect && pendingDestructiveIntent == nil
            && NightFlockAccountDeletionIntentPolicy.permitsAdmission(phase: accountDeletionIntentPhase)
            && !isDeletingOnlineAccount
            && permitsNightFlockAuthenticationTransport
    }

    var permitsNightFlockAccountSessionInspection: Bool {
        hasRestoredStagedDestructiveEffect
            && NightFlockAccountDeletionIntentPolicy.permitsAdmission(phase: accountDeletionIntentPhase)
            && !isDeletingOnlineAccount && NightFlockTransportRecoveryPolicy.permitsAccountSessionInspection(
            recovery: pendingAuthenticationRecovery
        )
    }

    /// A preflight destructive intent deliberately blocks ordinary transport,
    /// but its same-bound owner may load authoritative state to determine
    /// whether the server applied it. It never replays the command or flushes.
    private var permitsPendingDestructiveIntentReconciliation: Bool {
        hasRestoredStagedDestructiveEffect
            && pendingDestructiveIntent != nil
            && NightFlockAccountDeletionIntentPolicy.permitsAdmission(phase: accountDeletionIntentPhase)
            && !isDeletingOnlineAccount
            && permitsNightFlockAuthenticationTransport
    }

    private var permitsNightFlockAuthenticationTransport: Bool {
        NightFlockTransportRecoveryPolicy.permitsNetwork(
            recovery: pendingAuthenticationRecovery
        )
    }

    func isCurrentLocalSocialGeneration(_ generation: UInt64) -> Bool {
        generation == localSocialGeneration
    }

    func isCurrentTransportRecoveryEpoch(_ epoch: UInt64) -> Bool {
        NightFlockTransportEpochPolicy.isCurrent(captured: epoch, current: transportRecoveryEpoch)
    }

    func isCurrentTransportTask(generation: UInt64, epoch: UInt64) -> Bool {
        isCurrentLocalSocialGeneration(generation) && isCurrentTransportRecoveryEpoch(epoch)
    }

    var permitsLocalSocialMutation: Bool {
        NightFlockAccountDeletionIntentPolicy.permitsAdmission(phase: accountDeletionIntentPhase)
            && NightFlockAcceptedDeletionPolicy.permitsLocalMutation(tombstonePresent: isDeletingOnlineAccount)
            && NightFlockPendingIntentPolicy.permitsLocalMutation(
                intentPresent: pendingDestructiveIntent != nil,
                stagedEffect: stagedDestructiveLocalEffect,
                authenticationTransportPermitted: permitsNightFlockAuthenticationTransport
            )
    }

    /// A validated destructive command owns the cleanup. The first generation
    /// bump invalidates work already in flight; the final bump invalidates work
    /// that began while the outbox actor was clearing. Clearing memory after
    /// the actor hop removes any synchronous context write made in that gap.
    private func clearLocalSocialWork(requestedEpoch: UInt64? = nil) async -> Bool {
        let requestedEpoch = requestedEpoch ?? (localSocialGeneration &+ 1)
        localSocialGeneration = requestedEpoch
        onSharedHabitsAuthorityInvalidated?()
        let result = await outbox?.clear(epoch: requestedEpoch)
            ?? NightFlockOutboxClearResult(
                epoch: NightFlockOutboxEpochPolicy.advancingClear(
                    acceptedEpoch: requestedEpoch,
                    requestedEpoch: requestedEpoch
                ),
                didClear: true
            )
        guard result.didClear else {
            localSocialGeneration = max(localSocialGeneration, result.epoch)
            return false
        }
        guard NightFlockOutboxEpochPolicy.mayAdoptClearCompletion(
            currentEpoch: localSocialGeneration,
            returnedEpoch: result.epoch
        ) else { return false }
        localSocialGeneration = result.epoch
        runContexts = [:]
        primaryRunSharingDecisions = [:]
        v4RealtimeRefreshTasks.values.forEach { $0.cancel() }
        v4RealtimeRefreshTasks = [:]
        v4RealtimeSetupTasks.values.forEach { $0.cancel() }
        v4RealtimeSetupTasks = [:]
        v4PartyObservationTasks.values.forEach { $0.cancel() }
        v4PartyObservationTasks = [:]
        v4PartyObservationNeedsRefresh = []
        v4RealtimeRefreshAttemptIDs = [:]
        v4RealtimeSetupAttemptIDs = [:]
        v4PartyObservationAttemptIDs = [:]
        v4SelectedPartyRefreshAttemptIDs = [:]
        v4RealtimePartyIDs = []
        v4RealtimeConnectedPartyIDs = []
        v4RefreshingPartyIDs = []
        v4ObservedPartyDetails = [:]
        v4ObservedPartyRefreshDates = [:]
        v4ObservedPartyObservationStates = [:]
        v4CheerSendStates = [:]
        updateCheerAcknowledgements = [:]
        sharedHabitsPrivacyFences = []
        sharedHabitsStates = [:]
        sharedHabitsLoadingPartyIDs = []
        sharedNightsLoadingPartyIDs = []
        sharedHabitsAgreementSavingPartyIDs = []
        sharedHabitsAgreementErrors = [:]
        sharedHabitsAgreementAttemptIDs = [:]
        sharedHabitsFormerParties = []
        sharedHabitsStagedJoinPartyIDs = []
        canonicalV4PartyIDs = []
        hasCanonicalV4PartySnapshot = false
        sharedHabitsDestructiveCommandPartyIDs = []
        v4NextPartyDetailRequestSequence = 0
        v4AcceptedPartyDetailRequestSequences = [:]
        await service?.stopV4Realtime()
        selectedV4Party = nil
        return true
    }

    private func stageDestructiveLocalEffect(
        _ effect: NightFlockDestructiveLocalEffect,
        epoch: UInt64
    ) async {
        stagedDestructiveLocalEffect = NightFlockStagedDestructiveCommitPolicy.stage(
            existing: stagedDestructiveLocalEffect,
            incoming: effect
        )
        await outbox?.stageDestructiveEffect(stagedDestructiveLocalEffect, epoch: epoch)
    }

    /// State was accepted by the server already; this only commits its local
    /// consequence after an authoritative snapshot has been observed.
    private func commitStagedDestructiveLocalEffectIfNeeded() async -> Bool {
        let transition = NightFlockStagedDestructiveCommitPolicy.consumeAfterAuthoritativeState(
            staged: stagedDestructiveLocalEffect
        )
        guard transition.effectToCommit != .none else { return false }
        guard await clearLocalSocialWork() else { return false }
        stagedDestructiveLocalEffect = transition.remaining
        return true
    }

    private func reconcilePendingDestructiveIntentIfNeeded() async -> Bool {
        guard let intent = pendingDestructiveIntent,
              accountState == .linked,
              permitsPendingDestructiveIntentReconciliation,
              let service, let outbox
        else { return false }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        phase = .loading
        do {
            let authoritativeSnapshot = try await loadSnapshotWithSchemaFallback(
                service: service,
                generation: generation,
                transportEpoch: transportEpoch,
                allowsPendingDestructiveIntentReconciliation: true
            )
            guard permitsPendingDestructiveIntentReconciliation,
                  pendingDestructiveIntent == intent,
                  isCurrentTransportTask(generation: generation, epoch: transportEpoch)
            else { return false }
            if NightFlockPendingIntentTransitionPolicy.relaunchResolution(
                stagedEffect: stagedDestructiveLocalEffect,
                pendingIntentPresent: true
            ) == .commitAcceptedMarkerThenRemoveIntent {
                // The durable accepted marker was written before pending-intent
                // removal. Keep it through authoritative state, remove only
                // the stale preflight record, then let the marker clear lanes.
                guard await outbox.removePendingDestructiveIntent(epoch: generation) else { return false }
                pendingDestructiveIntent = nil
                snapshot = authoritativeSnapshot
                syncDraftFromSnapshot()
                _ = await commitStagedDestructiveLocalEffectIfNeeded()
                phase = .ready
                return true
            }
            let resolution = NightFlockPendingIntentPolicy.resolve(
                intent: intent,
                snapshot: authoritativeSnapshot
            )
            switch resolution {
            case .applied:
                let effect = NightFlockPendingIntentPolicy.localEffect(for: intent)
                guard await outbox.acceptPendingDestructiveIntent(intent, effect: effect, epoch: generation) else {
                    return false
                }
                stagedDestructiveLocalEffect = NightFlockStagedDestructiveCommitPolicy.stage(
                    existing: stagedDestructiveLocalEffect,
                    incoming: effect
                )
                pendingDestructiveIntent = nil
                snapshot = authoritativeSnapshot
                syncDraftFromSnapshot()
                _ = await commitStagedDestructiveLocalEffectIfNeeded()
                phase = .ready
                return true
            case .notApplied:
                guard await outbox.removePendingDestructiveIntent(epoch: generation) else { return false }
                pendingDestructiveIntent = nil
                snapshot = authoritativeSnapshot
                syncDraftFromSnapshot()
                phase = .ready
                await flushOutbox()
                return true
            case .unknown:
                warmNotice = "Ollie is keeping your shared updates safe until we can confirm what happened."
                phase = .offline
                return false
            }
        } catch is NightFlockTransportPaused {
            return false
        } catch let failure as SnapshotLoadFailure {
            guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return false }
            presentNightFlockError(failure.underlying, lane: .snapshot(schema: failure.schema))
            if pendingAuthenticationRecovery == .none {
                warmNotice = "Ollie is keeping your shared updates safe until we can confirm what happened."
                phase = .offline
            }
            return false
        } catch {
            guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return false }
            presentNightFlockError(error, lane: .snapshot(schema: 3))
            if pendingAuthenticationRecovery == .none {
                warmNotice = "Ollie is keeping your shared updates safe until we can confirm what happened."
                phase = .offline
            }
            return false
        }
    }

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
        inviteCredentialService: NightFlockInviteCredentialService? = nil,
        previewSnapshot: NightFlockSnapshot? = nil,
        previewPhase: Phase? = nil,
        previewAccountState: NightFlockAccountState = .anonymous,
        diagnostics: NightFlockDiagnostics? = nil,
        orientationStore: NightFlockOrientationStore = NightFlockOrientationStore(),
        previewOrientationState: NightFlockOrientationState? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.featureEnabled = featureEnabled
        self.accountService = accountService
        self.service = service
        self.outbox = outbox
        self.inviteCredentialService = inviteCredentialService ?? (featureEnabled ? NightFlockInviteCredentialService() : nil)
        self.orientationStore = orientationStore
        self.defaults = defaults
        orientationState = previewOrientationState ?? orientationStore.load()
        warmNotice = nil
        requestReference = nil
        snapshot = previewSnapshot
        v4ListState = nil
        selectedV4Party = nil
        v4InvitePreview = nil
        v4InviteCodes = [:]
        v4RequestID = nil
        v4Profile = nil
        self.diagnostics = diagnostics ?? NightFlockDiagnostics.initial(
            featureFlag: featureEnabled ? .enabled : .disabled,
            configuration: featureEnabled ? .valid : .notEvaluated,
            accountState: previewAccountState
        )
        accountState = previewAccountState
        phase = previewPhase ?? (featureEnabled ? .idle : .hidden)
        guard featureEnabled, let outbox else {
            hasRestoredStagedDestructiveEffect = true
            return
        }
        let generation = localSocialGeneration
        Task { [weak self] in
            let contexts = await outbox.runContexts()
            let primaryRunSharingDecisions = await outbox.primaryRunSharingDecisions()
            let primaryRunSharingRequiredAfter = await outbox.primaryRunSharingPolicyRequiredAfter()
            let stagedEffect = await outbox.stagedDestructiveEffect()
            let deletionTombstone = await outbox.hasAcceptedAccountDeletion()
            let pendingIntent = await outbox.pendingDestructiveIntent()
            let pendingAccountDeletion = await outbox.hasPendingAccountDeletionIntent()
            let sharedHabitsFences = await outbox.sharedHabitsPrivacyFences()
            await MainActor.run {
                guard let self else { return }
                guard self.isCurrentLocalSocialGeneration(generation) else { return }
                self.stagedDestructiveLocalEffect = stagedEffect
                self.acceptedAccountDeletionTombstone = deletionTombstone
                self.pendingAccountDeletionIntent = pendingAccountDeletion
                self.sharedHabitsPrivacyFences = sharedHabitsFences
                if !sharedHabitsFences.isEmpty {
                    self.sharedHabitsFenceGeneration &+= 1
                }
                self.pendingDestructiveIntent = pendingIntent
                self.hasRestoredStagedDestructiveEffect = true
                for context in contexts where self.runContexts[context.runID] == nil {
                    self.runContexts[context.runID] = context
                }
                self.primaryRunSharingRequiredAfter = primaryRunSharingRequiredAfter
                for decision in primaryRunSharingDecisions where self.primaryRunSharingDecisions[decision.runID] == nil {
                    self.primaryRunSharingDecisions[decision.runID] = decision
                }
                if !primaryRunSharingDecisions.isEmpty {
                    self.onPrimaryRunSharingDecisionsRestored?()
                }
                self.objectWillChange.send()
                switch NightFlockAccountDeletionIntentPolicy.recoveryAction(
                    phase: NightFlockAccountDeletionIntentPolicy.phase(
                        pendingIntentPresent: pendingAccountDeletion,
                        tombstonePresent: deletionTombstone
                    )
                ) {
                case .finalizeLocally:
                    Task { await self.finalizeAcceptedAccountDeletion() }
                case .failClosedNoNetworkNoReplay:
                    self.accountState = .unavailable
                    self.pendingAuthenticationRecovery = .failClosed
                    self.warmNotice = "Ollie is keeping your account closed here because we could not confirm whether its deletion finished."
                    self.phase = .error("Account deletion needs local confirmation before Slumber Party can reconnect.")
                case .none where self.phase == .idle:
                    self.bootstrap()
                case .none:
                    break
                }
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
            accountService: NightFlockAccountService(provider: provider, defaults: defaults),
            service: NightFlockService(provider: provider),
            outbox: NightFlockOutboxService(defaults: defaults),
            diagnostics: .initial(featureFlag: featureFlag, configuration: .valid)
        )
    }

    func entryAppeared() {
        guard featureEnabled, phase != .loading, permitsNightFlockAccountSessionInspection else { return }
        Task { await activateEntry() }
    }

    func bootstrap() {
        guard !accountEntryInFlight, featureEnabled, phase == .idle, permitsNightFlockAccountSessionInspection else { return }
        accountEntryInFlight = true
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        Task {
            defer { accountEntryInFlight = false }
            guard let accountService else { return }
            do {
                let currentAccountState = try await accountService.currentState(createAnonymousIfMissing: false)
                guard permitsNightFlockAccountSessionInspection,
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                accountState = currentAccountState
                guard accountState == .linked else { return }
                if pendingDestructiveIntent != nil {
                    _ = await reconcilePendingDestructiveIntentIfNeeded()
                    return
                }
                if stagedDestructiveLocalEffect != .none {
                    guard await refreshState(showLoading: false) else { return }
                    await flushOutbox()
                    return
                }
                await flushOutbox()
                guard permitsNightFlockNetwork,
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                await refreshState(showLoading: false)
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                guard !isDeletingOnlineAccount else { return }
                guard shouldPresentAccountInspectionFailure(error) else { return }
                presentAccountRecoveryRequirement(error)
            }
        }
    }

    func handleForeground() {
        guard featureEnabled, accountState == .linked, permitsNightFlockNetwork else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        Task {
            await flushOutbox()
            guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
            await refreshState(showLoading: false)
        }
    }

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        guard pendingAuthenticationRecovery != .failClosed else { return }
        do {
            let nonce = try NightFlockAccountService.makeAppleNonce()
            pendingAppleSignInAttempt = AppleSignInAttempt(
                nonce: nonce.rawValue,
                recovery: pendingAuthenticationRecovery,
                transportEpoch: transportRecoveryEpoch
            )
            request.nonce = nonce.requestValue
            request.requestedScopes = []
        } catch {
            if pendingAuthenticationRecovery != .failClosed {
                phase = .error(error.localizedDescription)
            }
        }
    }

    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard featureEnabled else { return }
        guard let attempt = pendingAppleSignInAttempt else { return }
        guard isCurrentTransportRecoveryEpoch(attempt.transportEpoch),
              Self.appleCallbackOwnsCurrentRecovery(
                captured: attempt.recovery,
                current: pendingAuthenticationRecovery
              )
        else {
            discardAppleSignInAttempt(attempt)
            neutralizeStaleAppleCallback(touchedSession: false, accountService: nil)
            return
        }
        switch result {
        case .failure(let error):
            pendingAppleSignInAttempt = nil
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                phase = .error("Apple sign-in was cancelled. Your local Wind Down and shared updates are still safe here.")
            } else {
                phase = .error("Apple sign-in did not finish. Please try again.")
            }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                pendingAppleSignInAttempt = nil
                if attempt.recovery != .none {
                    pendingAuthenticationRecovery = .failClosed
                    transportRecoveryEpoch = NightFlockTransportEpochPolicy.advancing(transportRecoveryEpoch)
                    accountState = .unavailable
                }
                phase = .error(NightFlockAccountError.identityTokenMissing.localizedDescription)
                return
            }
            pendingAppleSignInAttempt = nil
            guard let accountService else {
                accountState = .unavailable
                phase = .error("Account linking is unavailable in this build. Your current account was left unchanged.")
                return
            }
            let previousAccountState = accountState
            accountState = .linking
            phase = .loading
            let recovery = attempt.recovery
            Task {
                do {
                    if recovery == .linkCurrentAnonymousApple || recovery == .none {
                        // Quarantine account-scoped transport before Apple can
                        // replace the temporary anonymous server session. This
                        // order remains safe if the app terminates mid-sign-in.
                        guard await clearLocalSocialWork() else {
                            throw NightFlockAccountError.identityChanged
                        }
                        snapshot = nil
                        v4ListState = nil
                        selectedV4Party = nil
                        v4ObservedPartyDetails = [:]
                        v4InviteCodes = [:]
                        v4InvitePreview = nil
                        v4GrantInbox = []
                        linkedAccountID = nil
                    }
                    switch recovery {
                    case .reauthenticateApple:
                        try await accountService.reauthenticateAppleIdentity(identityToken: token, nonce: attempt.nonce)
                    case .linkCurrentAnonymousApple, .none:
                        try await accountService.linkAppleIdentity(
                            identityToken: token,
                            nonce: attempt.nonce
                        )
                    case .failClosed:
                        throw NightFlockAccountError.identityChanged
                    }
                    guard Self.appleCallbackOwnsCurrentRecovery(
                        captured: recovery,
                        current: pendingAuthenticationRecovery
                    ), isCurrentTransportRecoveryEpoch(attempt.transportEpoch) else {
                        neutralizeStaleAppleCallback(touchedSession: true, accountService: accountService)
                        return
                    }
                    accountState = .linked
                    pendingAuthenticationRecovery = .none
                    transportRecoveryEpoch = NightFlockTransportEpochPolicy.advancing(transportRecoveryEpoch)
                    pendingNightFlockRecovery = nil
                    if pendingDestructiveIntent != nil {
                        _ = await reconcilePendingDestructiveIntentIfNeeded()
                        return
                    }
                    guard await refreshState(showLoading: true) else { return }
                    guard permitsNightFlockNetwork else { return }
                    await flushOutbox()
                } catch {
                    guard Self.appleCallbackOwnsCurrentRecovery(
                        captured: recovery,
                        current: pendingAuthenticationRecovery
                    ), isCurrentTransportRecoveryEpoch(attempt.transportEpoch) else {
                        neutralizeStaleAppleCallback(touchedSession: true, accountService: accountService)
                        return
                    }
                    let nextRecovery = Self.appleRecoveryAction(after: error, recovery: recovery)
                    if recovery != .none, nextRecovery == .failClosed {
                        if recovery == .reauthenticateApple {
                            await accountService.signOutLocallyAfterFailedRecovery()
                        }
                        pendingAuthenticationRecovery = .failClosed
                        transportRecoveryEpoch = NightFlockTransportEpochPolicy.advancing(transportRecoveryEpoch)
                        accountState = .unavailable
                    } else {
                        accountState = previousAccountState
                    }
                    phase = .error(NightFlockAccountService.linkFailureMessage(for: error))
                }
            }
        }
    }

    private static func appleCallbackOwnsCurrentRecovery(
        captured: NightFlockAuthenticationAction,
        current: NightFlockAuthenticationAction
    ) -> Bool {
        NightFlockAuthenticationRecoveryCompletionPolicy.ownsCallback(
            captured: captured,
            current: current
        )
    }

    private func discardAppleSignInAttempt(_ attempt: AppleSignInAttempt) {
        guard pendingAppleSignInAttempt?.nonce == attempt.nonce else { return }
        pendingAppleSignInAttempt = nil
    }

    /// A stale Apple callback never replaces newer recovery UI. If its provider
    /// exchange may have changed the local Supabase session, fail-closed wins
    /// conservatively by signing that session out before returning.
    private func neutralizeStaleAppleCallback(
        touchedSession: Bool,
        accountService: NightFlockAccountService?
    ) {
        if pendingAuthenticationRecovery != .none || accountState == .linking {
            accountState = .unavailable
        }
        guard touchedSession, pendingAuthenticationRecovery == .failClosed,
              let accountService else { return }
        Task { await accountService.signOutLocallyAfterFailedRecovery() }
    }

    private static func appleRecoveryAction(
        after error: Error,
        recovery: NightFlockAuthenticationAction
    ) -> NightFlockAuthenticationAction {
        let failure: NightFlockAppleRecoveryFailure
        if let authError = error as? AuthError,
           authError.errorCode == .identityAlreadyExists {
            failure = .identityAlreadyExists
        } else if let accountError = error as? NightFlockAccountError {
            switch accountError {
            case .identityChanged, .expectedIdentityMissing, .accountIsNotAnonymous,
                    .existingIdentityBinding, .invalidExpectedIdentityBinding,
                    .unsupportedAuthenticatedSession:
                failure = .identityValidationFailed
            case .identityTokenMissing, .nonceUnavailable, .reauthenticationRequired:
                failure = .other
            }
        } else if error is URLError {
            failure = .cancellationOrNetwork
        } else {
            failure = .other
        }
        return NightFlockAppleRecoveryFailurePolicy.nextAction(
            recovery: recovery,
            failure: failure
        )
    }

    private func presentAccountRecoveryRequirement(_ error: Error) {
        let incoming = Self.accountInspectionRecoveryAction(for: error)
        let presentation = NightFlockAuthenticationRecoveryPresentationPolicy.decide(
            current: pendingAuthenticationRecovery,
            incoming: incoming
        )
        guard presentation.shouldUpdatePresentation else { return }
        let previous = pendingAuthenticationRecovery
        pendingAuthenticationRecovery = presentation.action
        if previous != presentation.action {
            transportRecoveryEpoch = NightFlockTransportEpochPolicy.advancing(transportRecoveryEpoch)
        }
        accountState = .unavailable
        switch incoming {
        case .reauthenticateApple:
            phase = .error(NightFlockAccountError.reauthenticationRequired.localizedDescription)
        case .failClosed:
            phase = .error(error.localizedDescription)
        case .none, .linkCurrentAnonymousApple:
            phase = .offline
        }
    }

    /// Re-evaluate an inspection failure after its suspension point. A newer
    /// recovery owns the presentation unless this error escalates it to the
    /// absorbing fail-closed state.
    private func shouldPresentAccountInspectionFailure(_ error: Error) -> Bool {
        NightFlockAuthenticationRecoveryPresentationPolicy.decide(
            current: pendingAuthenticationRecovery,
            incoming: Self.accountInspectionRecoveryAction(for: error)
        ).shouldUpdatePresentation
    }

    private static func accountInspectionRecoveryAction(
        for error: Error
    ) -> NightFlockAuthenticationAction {
        if error as? NightFlockAccountError == .reauthenticationRequired {
            return .reauthenticateApple
        }
        if let accountError = error as? NightFlockAccountError,
           requiresFailClosedAccountRecovery(accountError) {
            return .failClosed
        }
        return .none
    }

    private static func requiresFailClosedAccountRecovery(_ error: NightFlockAccountError) -> Bool {
        switch error {
        case .identityChanged, .expectedIdentityMissing, .accountIsNotAnonymous,
                .existingIdentityBinding, .invalidExpectedIdentityBinding,
                .unsupportedAuthenticatedSession:
            return true
        case .reauthenticationRequired, .identityTokenMissing, .nonceUnavailable:
            return false
        }
    }

    func retryAccountConnection() {
        guard featureEnabled, accountState != .linking, permitsNightFlockAccountSessionInspection else { return }
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
        guard accountState == .linked, permitsNightFlockNetwork,
              let service, let outbox
        else { return }
        let previousAccountState = accountState
        let generation = localSocialGeneration
        let initialTransportEpoch = transportRecoveryEpoch
        Task {
            var transportEpoch = initialTransportEpoch
            do {
                guard await outbox.stagePendingAccountDeletionIntent(epoch: generation) else {
                    phase = .offline
                    warmNotice = "Ollie could not safely prepare your account deletion on this phone."
                    return
                }
                pendingAccountDeletionIntent = true
                isDeletingOnlineAccount = true
                transportRecoveryEpoch = NightFlockTransportEpochPolicy.advancing(transportRecoveryEpoch)
                transportEpoch = transportRecoveryEpoch
                // This request owns the pending deletion journal. It is the
                // sole allowed transport while that journal is present.
                guard permitsNightFlockAuthenticationTransport,
                      isDeletingOnlineAccount,
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else {
                    return
                }
                let deletionKey = NightFlockV4Idempotency.command("delete-account")
                let accepted: Bool
                if usesSlumberPartyV4 {
                    let response = try await service.sendV4(.deleteAccount(idempotencyKey: deletionKey))
                    accepted = response.accepted && response.deleteAccount != false
                } else {
                    let response = try await service.send(.deleteAccount(
                        idempotencyKey: NightFlockIdempotency.command("delete-account")
                    ))
                    accepted = response.accepted
                }
                guard isDeletingOnlineAccount else { return }
                if !accepted {
                    guard await outbox.rejectPendingAccountDeletionIntent(epoch: generation) else { return }
                    pendingAccountDeletionIntent = false
                    isDeletingOnlineAccount = false
                    transportRecoveryEpoch = NightFlockTransportEpochPolicy.advancing(transportRecoveryEpoch)
                    transportEpoch = transportRecoveryEpoch
                    guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                    accountState = previousAccountState
                    phase = .error("Ollie could not confirm that account deletion request.")
                    return
                }
                quiesceInvitePlaintextPresentationIfNeeded(deletionSignal: .accepted)
                // Accepted server deletion is durable even when an older
                // transport response changed epochs during the await.
                let epoch = await outbox.acceptAccountDeletion(
                    epoch: NightFlockAccountDeletionIntentPolicy.epochAfterResponse(
                        currentEpoch: localSocialGeneration,
                        accepted: true
                    )
                )
                localSocialGeneration = epoch
                pendingAccountDeletionIntent = false
                acceptedAccountDeletionTombstone = true
                await finalizeAcceptedAccountDeletion()
            } catch {
                guard isDeletingOnlineAccount, pendingAccountDeletionIntent else { return }
                if NightFlockPendingIntentPolicy.definitiveRejection(Self.remoteError(from: error)) {
                    guard await outbox.rejectPendingAccountDeletionIntent(epoch: generation) else { return }
                    pendingAccountDeletionIntent = false
                    isDeletingOnlineAccount = false
                    transportRecoveryEpoch = NightFlockTransportEpochPolicy.advancing(transportRecoveryEpoch)
                    transportEpoch = transportRecoveryEpoch
                    guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                    accountState = previousAccountState
                    presentNightFlockError(error, lane: .directCommand(schema: 1))
                    return
                }
                quiesceInvitePlaintextPresentationIfNeeded(deletionSignal: .ambiguous)
                // Timeout, cancellation, authentication, or any unknown
                // error can follow a committed server deletion. Preserve the
                // preflight tombstone, stay transport-silent, and never offer
                // this code path as a resend retry.
                isDeletingOnlineAccount = false
                accountState = .unavailable
                if pendingAuthenticationRecovery != .failClosed {
                    pendingAuthenticationRecovery = .failClosed
                    transportRecoveryEpoch = NightFlockTransportEpochPolicy.advancing(transportRecoveryEpoch)
                }
                warmNotice = "Ollie is keeping your account closed here until its deletion can be confirmed safely."
                phase = .error("Account deletion is still being confirmed. Slumber Party will stay paused on this phone.")
            }
        }
    }

    private func finalizeAcceptedAccountDeletion() async {
        guard acceptedAccountDeletionTombstone else { return }
        let epoch = localSocialGeneration
        guard await outbox?.finalizeAcceptedAccountDeletion(epoch: epoch) != false else { return }
        runContexts = [:]
        primaryRunSharingDecisions = [:]
        do {
            guard let inviteCredentialService else {
                throw NightFlockInviteCredentialServiceError.encoding
            }
            try inviteCredentialService.clear()
            inviteCredential = nil
            inviteRecoveryPresentation = .hidden
            latestInviteCode = nil
            latestInviteID = nil
        } catch {
            inviteRecoveryPresentation = .hidden
            latestInviteCode = nil
            accountState = .unavailable
            phase = .error("Ollie is keeping this account closed while local invitation cleanup finishes. Please try again after reopening Counting Sheep.")
            return
        }
        guard await accountService?.signOutAfterAccountDeletion() ?? false else {
            phase = .error("Ollie is finishing your account cleanup here. Please try again when you’re ready.")
            return
        }
        runContexts = [:]
        primaryRunSharingDecisions = [:]
        guard NightFlockAcceptedDeletionPolicy.mayCompleteFinalization(
                inviteCredentialCleared: inviteCredential == nil,
                verifiedLocalSignOut: true
              ),
              NightFlockAccountDeletionIntentPolicy.mayRemoveTombstone(verifiedLocalSignOut: true),
              await outbox?.completeAcceptedAccountDeletion(epoch: epoch) != false
        else { return }
        acceptedAccountDeletionTombstone = false
        pendingAccountDeletionIntent = false
        isDeletingOnlineAccount = false
        snapshot = nil
        v4ListState = nil
        sharedHabitsPrivacyFences = []
        sharedHabitsStates = [:]
        sharedHabitsLoadingPartyIDs = []
        sharedNightsLoadingPartyIDs = []
        sharedHabitsAgreementSavingPartyIDs = []
        sharedHabitsAgreementErrors = [:]
        sharedHabitsAgreementAttemptIDs = [:]
        sharedHabitsFormerParties = []
        sharedHabitsStagedJoinPartyIDs = []
        sharedHabitsDestructiveCommandPartyIDs = []
        selectedV4Party = nil
        v4ObservedPartyDetails = [:]
        v4ObservedPartyRefreshDates = [:]
        v4ObservedPartyObservationStates = [:]
        v4CheerSendStates = [:]
        updateCheerAcknowledgements = [:]
        v4NextPartyDetailRequestSequence = 0
        v4AcceptedPartyDetailRequestSequences = [:]
        v4InviteCodes = [:]
        v4InvitePreview = nil
        v4Profile = nil
        v4GrantInbox = []
        pendingV4ProfileMutation = nil
        v4RealtimeRefreshTasks.values.forEach { $0.cancel() }
        v4RealtimeRefreshTasks = [:]
        v4RealtimeSetupTasks.values.forEach { $0.cancel() }
        v4RealtimeSetupTasks = [:]
        v4PartyObservationTasks.values.forEach { $0.cancel() }
        v4PartyObservationTasks = [:]
        v4PartyObservationNeedsRefresh = []
        v4RealtimeRefreshAttemptIDs = [:]
        v4RealtimeSetupAttemptIDs = [:]
        v4PartyObservationAttemptIDs = [:]
        v4SelectedPartyRefreshAttemptIDs = [:]
        v4RealtimePartyIDs = []
        v4RealtimeConnectedPartyIDs = []
        v4RefreshingPartyIDs = []
        await service?.stopV4Realtime()
        accountState = .anonymous
        stagedDestructiveLocalEffect = .none
        pendingAuthenticationRecovery = .none
        pendingNightFlockRecovery = nil
        pendingAppleSignInAttempt = nil
        requestReference = nil
        warmNotice = nil
        phase = .idle
    }

    /// Persists the primary run's one-shot decision before releasing a
    /// validation that timer/NFC admission may have delivered synchronously.
    func preparePrimaryRun(
        _ run: FocusRun,
        share: Bool,
        isPractice: Bool,
        publishValidatedStatusAfterAdmission: Bool
    ) {
        defer { shareNextPrimaryRun = true }
        let decision = NightFlockPrimaryRunSharingDecision(
            runID: run.id,
            allowsSharing: share,
            capturedAt: run.startedAt
        )
        primaryRunSharingDecisions[run.id] = decision
        let generation = localSocialGeneration
        let context: NightFlockRunShareContext?
        if permitsLocalSocialMutation,
           share,
           let snapshot,
           snapshot.sharingEnabled,
           let day = NightFlockChallengeDayRules.challengeDay(
                at: run.startedAt,
                challenge: snapshot.challenge
           ) {
            let prepared = NightFlockRunShareContext(
                runID: run.id,
                challengeID: snapshot.challenge.id,
                memberID: snapshot.myMemberID,
                challengeDay: day,
                createdAt: run.startedAt
            )
            runContexts[run.id] = prepared
            context = prepared
        } else {
            context = nil
        }
        Task {
            guard isCurrentLocalSocialGeneration(generation) else { return }
            guard share else {
                // The durable per-run decision is written before beginning
                // plan retraction, so relaunch replay fails closed even if
                // termination interrupts the network-facing cancellation.
                cancelSharedNightPlansForPrivatePrimaryRun(run)
                return
            }
            if let context {
                await outbox?.saveRunContext(context, epoch: generation)
            }
            guard isCurrentLocalSocialGeneration(generation) else { return }
            // Rehydrated automatic runs may already be terminal by the time
            // their durable decision/context reaches this path. Their factual
            // outcome can publish, but they must never emit a late "starting"
            // activity after the night has finished.
            guard run.state != .completed, run.state != .endedEarly else { return }
            publishV4WindDownStarting(runID: run.id, at: run.startedAt, isPractice: isPractice)
            guard NightFlockPrimaryRunValidationAdmissionRules
                .shouldPublishValidatedStatusAfterAdmission(
                    sharesRun: share,
                    wasValidatedDuringAdmission: publishValidatedStatusAfterAdmission
                ) else { return }
            publishV4PhoneAwayActive(for: run)
            publishPhoneTucked(for: run)
        }
    }

    /// Admission callers await this before coordinator start. When social
    /// authority is absent there is nothing remote to fence; when it is
    /// present, failure to persist is a failed-closed admission.
    func stagePrimaryRunSharingDecisionForAdmission(
        _ decision: NightFlockPrimaryRunSharingDecision
    ) async -> NightFlockPrimaryRunSharingDecision? {
        guard featureEnabled, accountState == .linked, outbox != nil else { return decision }
        let generation = localSocialGeneration
        guard let outbox,
              let durableDecision = await outbox.lookupOrCreatePrimaryRunSharingDecision(
                decision,
                epoch: generation
              ),
              isCurrentLocalSocialGeneration(generation)
        else { return nil }
        primaryRunSharingDecisions[durableDecision.runID] = durableDecision
        return durableDecision
    }

    func hasPrimaryRunSharingDecision(for runID: UUID) -> Bool {
        primaryRunSharingDecisions[runID] != nil
    }

    func maySharePrimaryRun(_ run: FocusRun) -> Bool {
        maySharePrimaryRun(runID: run.id, startedAt: run.startedAt)
    }

    func maySharePrimaryRun(runID: UUID, startedAt: Date) -> Bool {
        NightFlockPrimaryRunSharingPolicy.mayShare(
            runID: runID, startedAt: startedAt,
            decision: primaryRunSharingDecisions[runID],
            requiredAfter: primaryRunSharingRequiredAfter
        )
    }

    func mayShareV4Status(_ record: NightFlockV4StatusOutboxRecord) -> Bool {
        NightFlockPrimaryRunStatusPublicationRules.mayShare(
            requiresPrimaryRunDecision: record.requiresPrimaryRunDecision,
            runID: record.sourceEventID, originStartedAt: record.originStartedAt,
            observedAt: record.observedAt,
            decision: primaryRunSharingDecisions[record.sourceEventID],
            requiredAfter: primaryRunSharingRequiredAfter
        )
    }

    func publishPhoneTucked(for run: FocusRun) {
        guard permitsLocalSocialMutation else { return }
        guard run.isProgressionEligibleNightWatch,
              maySharePrimaryRun(run),
              run.phoneAwayValidatedAt != nil,
              var context = runContexts[run.id],
              !context.phoneTuckedQueued else { return }
        context.phoneTuckedQueued = true
        runContexts[run.id] = context
        enqueue(state: .phoneTucked, for: context)
    }

    func handleTerminalRun(_ run: FocusRun, metrics: NightFlockLocalNightMetrics? = nil) {
        guard permitsLocalSocialMutation else { return }
        guard run.nightWatchPlan?.role != .primarySleepBookend || maySharePrimaryRun(run) else { return }
        if runContexts[run.id] != nil {
            finishTerminalRun(run, metrics: metrics, persistedContexts: [])
            return
        }
        let generation = localSocialGeneration
        Task {
            let persistedContexts = await outbox?.runContexts() ?? []
            guard isCurrentLocalSocialGeneration(generation) else { return }
            finishTerminalRun(run, metrics: metrics, persistedContexts: persistedContexts)
        }
    }

    private func finishTerminalRun(
        _ run: FocusRun,
        metrics: NightFlockLocalNightMetrics?,
        persistedContexts: [NightFlockRunShareContext]
    ) {
        guard run.completedSuccessfully, run.isProgressionEligibleNightWatch else {
            runContexts.removeValue(forKey: run.id)
            let generation = localSocialGeneration
            Task {
                guard isCurrentLocalSocialGeneration(generation) else { return }
                await outbox?.removeRunContext(run.id, epoch: generation)
                guard isCurrentLocalSocialGeneration(generation) else { return }
            }
            return
        }
        guard var context = NightFlockRunShareContextResolver.resolve(
            runID: run.id,
            memory: runContexts,
            persisted: persistedContexts
        ) else { return }
        if context.morningQuietCompletedQueued, metrics == nil { return }
        context.phoneTuckedQueued = true
        context.morningQuietCompletedQueued = true
        runContexts[run.id] = context
        if let metrics {
            enqueueNightMetrics(for: context, metrics: metrics)
        } else {
            enqueue(state: .morningQuietCompleted, for: context)
        }
    }

    func sharePhoneAwayMetrics(_ metrics: NightFlockLocalNightMetrics, for run: FocusRun, at date: Date) {
        guard permitsLocalSocialMutation else { return }
        guard let snapshot, snapshot.sharing.sharePhoneAwayMinutes,
              let day = NightFlockChallengeDayRules.challengeDay(at: date, challenge: snapshot.challenge)
        else { return }
        let context = runContexts[run.id] ?? NightFlockRunShareContext(
            runID: run.id,
            challengeID: snapshot.challenge.id,
            memberID: snapshot.myMemberID,
            challengeDay: day,
            createdAt: date
        )
        runContexts[run.id] = context
        enqueueNightMetrics(for: context, metrics: metrics)
    }

    func hasSharedResult(for runID: UUID) -> Bool {
        runContexts[runID] != nil
    }

    private func activateEntry() async {
        guard !accountEntryInFlight, permitsNightFlockAccountSessionInspection, let accountService else { return }
        accountEntryInFlight = true
        defer { accountEntryInFlight = false }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        phase = .loading
        do {
            let currentAccountState = try await accountService.currentState(
                createAnonymousIfMissing: pendingDestructiveIntent == nil
            )
            guard permitsNightFlockAccountSessionInspection,
                  isCurrentTransportTask(generation: generation, epoch: transportEpoch)
            else { return }
            accountState = currentAccountState
            if accountState == .linked {
                if pendingDestructiveIntent != nil {
                    _ = await reconcilePendingDestructiveIntentIfNeeded()
                    return
                }
                if stagedDestructiveLocalEffect != .none {
                    guard await refreshState(showLoading: false) else { return }
                    await flushOutbox()
                    return
                }
                await flushOutbox()
                guard permitsNightFlockNetwork,
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                await refreshState(showLoading: false)
            } else {
                phase = .idle
            }
        } catch {
            guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
            guard !isDeletingOnlineAccount else { return }
            guard shouldPresentAccountInspectionFailure(error) else { return }
            presentAccountRecoveryRequirement(error)
        }
    }

    func refreshState(showLoading: Bool) async -> Bool {
        guard permitsNightFlockNetwork, let service else { return false }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        if showLoading { phase = .loading }
        do {
            let v4 = try await service.stateV4List()
            guard permitsNightFlockNetwork,
                  isCurrentTransportTask(generation: generation, epoch: transportEpoch)
            else { return false }
            canonicalV4PartyIDs = Set(v4.parties.map(\.partyID))
            hasCanonicalV4PartySnapshot = true
            var visibleV4 = v4
            visibleV4.parties.removeAll { isSharedHabitsPartySuppressed($0.partyID) }
            reconcileSharedHabitsLeaveFences(with: v4.parties)
            v4ListState = visibleV4
            refreshSharedHabitsReceiptsForCurrentParties()
            synchronizeV4RealtimeSubscriptions(with: visibleV4.parties)
            reconcileV4ObservedPartyDetails(with: visibleV4.parties)
            adoptServerV4ProfileIfSafe(v4.profile)
            v4GrantInbox = v4.grantInbox
            phase = .ready
            applyPendingV4GrantsIfPossible()
            synchronizeV4ProfileIfNeeded(serverProfile: v4.profile)
            return true
        } catch is NightFlockTransportPaused {
            return false
        } catch let error where Self.allowsSchemaFallback(error) {
            // v4 is additive. A deployment that has not received its schema
            // four RPCs continues down the established v3 → v1 path.
            v4ListState = nil
        } catch {
            guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return false }
            presentNightFlockError(error, lane: .snapshot(schema: NightFlockV4Rules.schemaVersion))
            return false
        }
        do {
            let loadedSnapshot = try await loadSnapshotWithSchemaFallback(
                service: service,
                generation: generation,
                transportEpoch: transportEpoch
            )
            guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return false }
            snapshot = loadedSnapshot
            syncDraftFromSnapshot()
            await reconcileInviteCredential(authoritativeSnapshot: loadedSnapshot)
            let committedDestructiveEffect = await commitStagedDestructiveLocalEffectIfNeeded()
            if !committedDestructiveEffect {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return false }
            }
            phase = .ready
            applyPendingGrantsIfPossible()
            return true
        } catch is NightFlockTransportPaused {
            return false
        } catch let failure as SnapshotLoadFailure {
            guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return false }
            presentNightFlockError(failure.underlying, lane: .snapshot(schema: failure.schema))
            return false
        } catch {
            guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return false }
            presentNightFlockError(error, lane: .snapshot(schema: 3))
            return false
        }
    }

    private func loadSnapshotWithSchemaFallback(
        service: NightFlockService,
        generation: UInt64,
        transportEpoch: UInt64,
        allowsPendingDestructiveIntentReconciliation: Bool = false
    ) async throws -> NightFlockSnapshot? {
        try requireNightFlockTransport(
            generation: generation,
            transportEpoch: transportEpoch,
            allowsPendingDestructiveIntentReconciliation: allowsPendingDestructiveIntentReconciliation
        )
        do {
            let snapshot = try await service.stateV3()
            try requireNightFlockTransport(
                generation: generation,
                transportEpoch: transportEpoch,
                allowsPendingDestructiveIntentReconciliation: allowsPendingDestructiveIntentReconciliation
            )
            return snapshot
        } catch is NightFlockTransportPaused {
            throw NightFlockTransportPaused()
        } catch let error where Self.allowsSchemaFallback(error) {
            try requireNightFlockTransport(
                generation: generation,
                transportEpoch: transportEpoch,
                allowsPendingDestructiveIntentReconciliation: allowsPendingDestructiveIntentReconciliation
            )
            do {
                let snapshot = try await service.stateV2()
                try requireNightFlockTransport(
                    generation: generation,
                    transportEpoch: transportEpoch,
                    allowsPendingDestructiveIntentReconciliation: allowsPendingDestructiveIntentReconciliation
                )
                return snapshot
            } catch is NightFlockTransportPaused {
                throw NightFlockTransportPaused()
            } catch let error where Self.allowsSchemaFallback(error) {
                try requireNightFlockTransport(
                    generation: generation,
                    transportEpoch: transportEpoch,
                    allowsPendingDestructiveIntentReconciliation: allowsPendingDestructiveIntentReconciliation
                )
                do {
                    let snapshot = try await service.state()
                    try requireNightFlockTransport(
                        generation: generation,
                        transportEpoch: transportEpoch,
                        allowsPendingDestructiveIntentReconciliation: allowsPendingDestructiveIntentReconciliation
                    )
                    return snapshot
                } catch is NightFlockTransportPaused {
                    throw NightFlockTransportPaused()
                } catch {
                    throw SnapshotLoadFailure(underlying: error, schema: 1)
                }
            } catch {
                throw SnapshotLoadFailure(underlying: error, schema: 2)
            }
        } catch {
            throw SnapshotLoadFailure(underlying: error, schema: 3)
        }
    }

    private static func allowsSchemaFallback(_ error: Error) -> Bool {
        if let remote = error as? NightFlockRemoteError { return remote.allowsSchemaFallback }
        if case NightFlockServiceError.unsupportedResponse = error { return true }
        return false
    }

    private func requireNightFlockTransport(
        generation: UInt64,
        transportEpoch: UInt64,
        allowsPendingDestructiveIntentReconciliation: Bool = false
    ) throws {
        let permitsTransport = permitsNightFlockNetwork
            || (allowsPendingDestructiveIntentReconciliation
                && permitsPendingDestructiveIntentReconciliation)
        guard permitsTransport, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else {
            throw NightFlockTransportPaused()
        }
    }

    func refreshNightFlockStateForRecovery() async {
        if pendingDestructiveIntent != nil {
            _ = await reconcilePendingDestructiveIntentIfNeeded()
            return
        }
        await refreshState(showLoading: true)
    }

    func reconcileMembershipRecovery() async {
        await reconcileMembershipRecovery(requestID: requestReference?.replacingOccurrences(of: "Request ID: ", with: ""))
    }

    func reconcileMembershipRecovery(requestID: String?) async {
        guard permitsNightFlockNetwork else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        if let requestID {
            requestReference = NightFlockSupportReference.format(requestID: requestID)
        }
        guard let service else {
            pendingNightFlockRecovery = .reconcileMembership
            phase = .error("Ollie could not check your Slumber Party yet.")
            return
        }
        phase = .loading
        do {
            let recovered = try await loadSnapshotWithSchemaFallback(
                service: service,
                generation: generation,
                transportEpoch: transportEpoch
            )
            guard permitsNightFlockNetwork,
                  isCurrentTransportTask(generation: generation, epoch: transportEpoch)
            else { return }
            guard recovered != nil else {
                pendingNightFlockRecovery = .reconcileMembership
                phase = .error("Ollie could not find your lobby yet. Try again when you’re ready.")
                return
            }
            snapshot = recovered
            syncDraftFromSnapshot()
            pendingNightFlockRecovery = nil
            warmNotice = "You already have a Slumber Party. Ollie brought your lobby back."
            phase = .ready
        } catch is NightFlockTransportPaused {
            return
        } catch let failure as SnapshotLoadFailure {
            guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
            presentNightFlockError(failure.underlying, lane: .snapshot(schema: failure.schema))
            guard pendingAuthenticationRecovery == .none else { return }
            pendingNightFlockRecovery = .reconcileMembership
        } catch {
            guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
            presentNightFlockError(error, lane: .snapshot(schema: 3))
            guard pendingAuthenticationRecovery == .none else { return }
            pendingNightFlockRecovery = .reconcileMembership
        }
    }

    private func perform(_ command: NightFlockCommand, showLoading: Bool = true) {
        guard accountState == .linked, permitsNightFlockNetwork, let service else { return }
        let generation = localSocialGeneration
        let initialTransportEpoch = transportRecoveryEpoch
        if showLoading { phase = .loading }
        Task {
            var transportEpoch = initialTransportEpoch
            let ownsDestructiveIntent = NightFlockPendingDestructiveIntent.from(command: command)
            do {
                if let intent = ownsDestructiveIntent {
                    guard let outbox,
                          await outbox.stagePendingDestructiveIntent(intent, epoch: generation)
                    else {
                        phase = .offline
                        warmNotice = "Ollie needs to keep this shared change safe before sending it."
                        return
                    }
                    pendingDestructiveIntent = intent
                    // A durable journal is a transport boundary. Preflight
                    // responses may not establish recovery or replace UI once
                    // this owner has adopted its new token.
                    transportRecoveryEpoch = NightFlockTransportEpochPolicy.advancing(transportRecoveryEpoch)
                    transportEpoch = transportRecoveryEpoch
                }
                guard (ownsDestructiveIntent != nil || permitsNightFlockNetwork),
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                let response = try await service.send(command)
                guard response.accepted else { throw NightFlockServiceError.unsupportedResponse }
                if let intent = ownsDestructiveIntent {
                    // The command was accepted. Promote its durable marker
                    // before removing the preflight intent, even if an auth
                    // recovery began while the request was suspended.
                    guard let outbox,
                          await outbox.acceptPendingDestructiveIntent(
                            intent,
                            effect: NightFlockPendingIntentPolicy.localEffect(for: intent),
                            epoch: generation
                          )
                    else { return }
                    stagedDestructiveLocalEffect = NightFlockStagedDestructiveCommitPolicy.stage(
                        existing: stagedDestructiveLocalEffect,
                        incoming: NightFlockPendingIntentPolicy.localEffect(for: intent)
                    )
                    pendingDestructiveIntent = nil
                } else {
                    guard permitsNightFlockNetwork,
                          isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                    else { return }
                    let localEffect = NightFlockDirectCommandCommitPolicy.localEffect(for: command)
                    await stageDestructiveLocalEffect(localEffect, epoch: generation)
                }
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                if let responseSnapshot = response.snapshot {
                    snapshot = responseSnapshot
                } else {
                    guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                    let reconciledSnapshot = try await service.state()
                    guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                    snapshot = reconciledSnapshot
                }
                latestInviteCode = response.inviteCode
                latestInviteID = response.inviteID
                switch command {
                case .revokeInvite, .leave, .deleteNightFlockData, .deleteAccount:
                    try? inviteCredentialService?.clear()
                    inviteCredential = nil
                    inviteRecoveryPresentation = .hidden
                default:
                    break
                }
                let committedDestructiveEffect = await commitStagedDestructiveLocalEffectIfNeeded()
                // This command owns the validated destructive clear above; it
                // may finish its own success presentation after that clear.
                guard permitsNightFlockNetwork,
                      committedDestructiveEffect || isCurrentLocalSocialGeneration(generation)
                else { return }
                phase = .ready
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                if ownsDestructiveIntent != nil {
                    switch NightFlockPendingIntentPolicy.failureDisposition(
                        remoteCode: Self.remoteError(from: error)?.code
                    ) {
                    case .presentAuthenticationRecovery:
                        // Keep the preflight intent or accepted marker intact.
                        // Apple recovery reconciles authoritative state; this
                        // direct destructive command is never replayed.
                        presentNightFlockError(error, lane: .directCommand(schema: 1))
                        return
                    case .definitiveRejection:
                        guard await outbox?.removePendingDestructiveIntent(epoch: generation) == true else { return }
                        pendingDestructiveIntent = nil
                        transportRecoveryEpoch = NightFlockTransportEpochPolicy.advancing(transportRecoveryEpoch)
                        transportEpoch = transportRecoveryEpoch
                    case .retainAmbiguousJournal:
                        // The server may have committed after transport failed,
                        // so retain the journal and wait for authoritative state.
                        warmNotice = "Ollie is keeping your shared updates safe until we can confirm what happened."
                        phase = .offline
                        return
                    }
                }
                presentNightFlockError(error, lane: .directCommand(schema: 1))
            }
        }
    }

    private func enqueue(state: NightFlockCheckInState, for context: NightFlockRunShareContext) {
        guard permitsLocalSocialMutation else { return }
        guard let outbox else { return }
        if snapshot?.challenge.sharedGoal != nil {
            enqueueCommitmentProgress(state: state, for: context)
            return
        }
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
        let generation = localSocialGeneration
        Task {
            guard isCurrentLocalSocialGeneration(generation) else { return }
            await outbox.enqueue(record, updating: context, epoch: generation)
            guard isCurrentLocalSocialGeneration(generation) else { return }
            await flushOutbox()
        }
    }

    func flushOutbox() async {
        guard accountState == .linked, permitsNightFlockNetwork,
              mayPublishWhileSharedHabitsFenceIsOpen(),
              NightFlockPendingIntentPolicy.permitsFlush(intentPresent: pendingDestructiveIntent != nil),
              NightFlockRelaunchReconciliationPolicy.permitsOutboxFlush(staged: stagedDestructiveLocalEffect),
              let outbox, let service else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        guard await outbox.permitsSharedHabitsPublication() else { return }
        await flushSharedHabitsOutbox()
        guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
        await flushV4Outbox()
        guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
        let v3Records = await outbox.v3Records()
        guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
        for record in v3Records {
            guard await outbox.permitsSharedHabitsPublication() else { return }
            do {
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                let response = try await service.sendV3(.publishNightMetrics(
                    challengeID: record.challengeID,
                    day: record.challengeDay,
                    status: record.status,
                    shieldingEvidence: record.shieldingEvidence,
                    windDownMinutes: record.windDownMinutes,
                    phoneAwayMinutes: record.phoneAwayMinutes,
                    sleepDurationMinutes: record.sleepDurationMinutes,
                    restfulness: record.restfulness,
                    idempotencyKey: record.idempotencyKey
                ))
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                guard response.accepted else { throw NightFlockServiceError.unsupportedResponse }
                await outbox.removeV3(record.id, epoch: generation)
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                if let updated = response.snapshot {
                    snapshot = updated
                    syncDraftFromSnapshot()
                }
                applyPendingGrantsIfPossible()
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                // Keep v3 queued until schema-three is live, but still drain v2/v1
                // so local Wind Down progress reaches a current hosted backend.
                handleOutboxFailure(error, lane: .outbox(schema: 3))
                await outbox.markV3Attempt(record.id, epoch: generation)
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                if let remote = error as? NightFlockRemoteError,
                   NightFlockTransportRecoveryPolicy.shouldStopOutboxFlush(
                    remoteCode: remote.code,
                    recovery: pendingAuthenticationRecovery
                   ) {
                    return
                }
                if !permitsNightFlockNetwork { return }
                break
            }
        }
        let v2Records = await outbox.v2Records()
        guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
        for record in v2Records {
            guard await outbox.permitsSharedHabitsPublication() else { return }
            let status: NightFlockMemberNightStatus = record.status
            do {
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                let response = try await service.sendV2(.publishProgress(
                    challengeID: record.challengeID,
                    day: record.challengeDay,
                    status: status,
                    shieldingEvidence: record.shieldingEvidence,
                    idempotencyKey: record.idempotencyKey
                ))
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                guard response.accepted else { throw NightFlockServiceError.unsupportedResponse }
                await outbox.removeV2(record.id, epoch: generation)
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                if let updated = response.snapshot { snapshot = updated }
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                handleOutboxFailure(error, lane: .outbox(schema: 2))
                await outbox.markV2Attempt(record.id, epoch: generation)
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                return
            }
        }
        let v1Records = await outbox.records()
        guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
        for record in v1Records {
            guard await outbox.permitsSharedHabitsPublication() else { return }
            do {
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                let response = try await service.send(.publishCheckIn(
                    challengeID: record.challengeID,
                    day: record.challengeDay,
                    state: record.state,
                    idempotencyKey: record.idempotencyKey
                ))
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                guard response.accepted else { throw NightFlockServiceError.unsupportedResponse }
                await outbox.remove(record.id, epoch: generation)
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                if let updated = response.snapshot { snapshot = updated }
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                handleOutboxFailure(error, lane: .outbox(schema: 1))
                await outbox.markAttempt(record.id, epoch: generation)
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                return
            }
        }
    }

    func handleOutboxFailure(_ error: Error, lane: NightFlockRecoveryLane) {
        if let remote = Self.remoteError(from: error) {
            presentNightFlockError(remote, lane: lane)
            guard pendingAuthenticationRecovery == .none else { return }
            guard snapshot != nil else { return }
        } else if snapshot == nil && v4ListState == nil {
            guard pendingAuthenticationRecovery == .none else { return }
            phase = .offline
            return
        }

        guard pendingAuthenticationRecovery == .none else { return }
        phase = .ready
        warmNotice = "Ollie is keeping your Slumber Party update safe until it can travel."
    }

}
