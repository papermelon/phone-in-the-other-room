import Foundation

enum NightFlockV4CheerTarget: Hashable {
    case activity(UUID)
    case membershipActivity(UUID)
    /// v4 has no server-side session identity for live cheers. This timestamp
    /// scopes local feedback to the exact status the person was seeing; a
    /// later status observation intentionally offers a fresh reaction.
    case member(UUID, observedAt: Date)
    case membershipStatus(UUID)
}

struct NightFlockV4CheerCommandKey: Hashable {
    var partyID: UUID
    var target: NightFlockV4CheerTarget
    var cheer: NightFlockV4Cheer
}

enum NightFlockV4CheerSendState: Equatable {
    case pending
    case sent
    case failed
}

enum NightFlockV4PartyObservationState: Equatable {
    case notRequested
    case refreshing(lastReceivedAt: Date?)
    case current(lastReceivedAt: Date)
    case stale(lastReceivedAt: Date?)
}

@MainActor
extension NightFlockViewModel {
    /// v4 is list-first: an empty list is a valid ready state, not an error or
    /// a prompt to create an older single-party lobby.
    var slumberParties: [NightFlockV4PartySummary] {
        v4ListState?.parties ?? []
    }

    var usesSlumberPartyV4: Bool { v4ListState != nil }

    var canCreateOrJoinAnotherParty: Bool {
        slumberParties.count < NightFlockV4Rules.maximumConcurrentParties
    }

    func refreshV4List(showLoading: Bool = false) async throws {
        guard accountState == .linked, permitsNightFlockNetwork, let service else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        if showLoading { phase = .loading }
        let response = try await service.stateV4List()
        guard permitsNightFlockNetwork,
              isCurrentTransportTask(generation: generation, epoch: transportEpoch)
        else { return }
        canonicalV4PartyIDs = Set(response.parties.map(\.partyID))
        hasCanonicalV4PartySnapshot = true
        var visibleResponse = response
        visibleResponse.parties.removeAll { isSharedHabitsPartySuppressed($0.partyID) }
        reconcileSharedHabitsLeaveFences(with: response.parties)
        v4ListState = visibleResponse
        let visiblePartyIDs = Set(visibleResponse.parties.map(\.partyID))
        await outbox?.retainUpdateCheers(in: visiblePartyIDs, epoch: generation)
        guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
        refreshSharedHabitsReceiptsForCurrentParties()
        synchronizeV4RealtimeSubscriptions(with: visibleResponse.parties)
        reconcileV4ObservedPartyDetails(with: visibleResponse.parties)
        adoptServerV4ProfileIfSafe(
            response.profile,
            supportsSocialAvatar: response.supportsProfileAvatar
        )
        v4GrantInbox = response.grantInbox
        phase = .ready
        applyPendingV4GrantsIfPossible()
        synchronizeV4ProfileIfNeeded(
            serverProfile: response.profile,
            supportsSocialAvatar: response.supportsProfileAvatar
        )
    }

    func selectSlumberParty(_ partyID: UUID, cursor: NightFlockV4PaginationCursor? = nil) {
        guard accountState == .linked,
              permitsNightFlockNetwork,
              !isSharedHabitsPartySuppressed(partyID),
              let service
        else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        let fenceGeneration = sharedHabitsFenceGeneration
        let attemptID = UUID()
        v4SelectedPartyRefreshAttemptIDs[partyID] = attemptID
        v4RefreshingPartyIDs.insert(partyID)
        v4ObservedPartyObservationStates[partyID] = .refreshing(
            lastReceivedAt: v4ObservedPartyRefreshDates[partyID]
        )
        phase = .loading
        let requestSequence = beginV4PartyDetailRequest()
        Task {
            defer {
                if v4SelectedPartyRefreshAttemptIDs[partyID] == attemptID {
                    v4SelectedPartyRefreshAttemptIDs.removeValue(forKey: partyID)
                    v4RefreshingPartyIDs.remove(partyID)
                }
            }
            do {
                let response = try await service.stateV4Party(partyID: partyID, cursor: cursor)
                guard permitsNightFlockNetwork,
                      sharedHabitsFenceGeneration == fenceGeneration,
                      !isSharedHabitsPartySuppressed(partyID),
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      v4SelectedPartyRefreshAttemptIDs[partyID] == attemptID,
                      slumberParties.contains(where: { $0.partyID == partyID })
                else { return }
                applyV4PartyDetail(response.party, requestSequence: requestSequence)
                // A concurrent canonical observation can be newer than this
                // selected request. Prefer that membership-filtered cache
                // instead of restoring an older selected response.
                if let current = v4ObservedPartyDetail(for: partyID) {
                    selectedV4Party = current
                }
                phase = .ready
                applyPendingV4GrantsIfPossible()
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      sharedHabitsFenceGeneration == fenceGeneration,
                      !isSharedHabitsPartySuppressed(partyID),
                      v4SelectedPartyRefreshAttemptIDs[partyID] == attemptID
                else { return }
                v4ObservedPartyObservationStates[partyID] = .stale(
                    lastReceivedAt: v4ObservedPartyRefreshDates[partyID]
                )
                presentNightFlockError(error, lane: .snapshot(schema: NightFlockV4Rules.schemaVersion))
            }
        }
    }

    func refreshSelectedSlumberParty() {
        guard let partyID = selectedV4Party?.summary.partyID else { return }
        selectSlumberParty(partyID, cursor: selectedV4Party?.cursor)
    }

    func v4ObservedPartyDetail(for partyID: UUID) -> NightFlockV4PartyDetail? {
        guard slumberParties.contains(where: { $0.partyID == partyID }) else { return nil }
        return v4ObservedPartyDetails[partyID]
    }

    func v4ObservedPartyRefreshDate(for partyID: UUID) -> Date? {
        v4ObservedPartyRefreshDates[partyID]
    }

    func v4ObservedPartyObservationState(for partyID: UUID) -> NightFlockV4PartyObservationState {
        v4ObservedPartyObservationStates[partyID] ?? .notRequested
    }

    func isRefreshingV4Party(_ partyID: UUID) -> Bool {
        v4RefreshingPartyIDs.contains(partyID)
    }

    /// Clears only the detail presentation. Party subscriptions remain active
    /// while the user belongs to them so an active Wind Down can still receive
    /// a silent, directed cheer from any of up to five parties.
    func clearSelectedSlumberParty() {
        selectedV4Party = nil
    }

    func createSlumberParty(named name: String, timeZoneIdentifier: String = TimeZone.current.identifier) {
        let commandID = UUID()
        stageSharedHabitsJoinAgreement(commandID: commandID, timeZoneIdentifier: timeZoneIdentifier) { [weak self] in
            self?.performV4(.createParty(
                name: name,
                timeZoneIdentifier: timeZoneIdentifier,
                idempotencyKey: NightFlockV4Idempotency.command("create-party", seed: commandID)
            ), resolvedPartyIntentCommandID: commandID, onResolvedNewParty: { partyID in
                self?.acceptStagedSharedHabitsAgreementAfterJoining(partyID: partyID, commandID: commandID)
            })
        }
    }

    func renameSlumberParty(_ partyID: UUID, name: String) {
        performV4(.renameParty(
            partyID: partyID,
            name: name,
            idempotencyKey: NightFlockV4Idempotency.command("rename-party")
        ))
    }

    func startAnotherSevenNights(_ partyID: UUID, timeZoneIdentifier: String = TimeZone.current.identifier) {
        performV4(.startRound(
            partyID: partyID,
            timeZoneIdentifier: timeZoneIdentifier,
            idempotencyKey: NightFlockV4Idempotency.command("start-round")
        ))
    }

    func createSlumberPartyInvite(_ partyID: UUID) {
        performV4(.createInvite(
            partyID: partyID,
            idempotencyKey: NightFlockV4Idempotency.command("create-invite")
        ))
    }

    func replaceSlumberPartyInvite(_ partyID: UUID, expectedInviteID: UUID) {
        performV4(.replaceInvite(
            partyID: partyID,
            expectedInviteID: expectedInviteID,
            idempotencyKey: NightFlockV4Idempotency.command("replace-invite")
        ))
    }

    func revokeSlumberPartyInvite(_ partyID: UUID, inviteID: UUID) {
        performV4(.revokeInvite(
            partyID: partyID,
            inviteID: inviteID,
            idempotencyKey: NightFlockV4Idempotency.command("revoke-invite")
        ))
    }

    func retrieveSlumberPartyInvite(_ partyID: UUID) {
        performV4(.retrieveInvite(
            partyID: partyID,
            idempotencyKey: NightFlockV4Idempotency.command("retrieve-invite")
        ))
    }

    func previewSlumberPartyInvite(code: String) {
        let normalized = NightFlockInviteCode.normalize(code)
        guard !normalized.isEmpty else { return }
        performV4(.previewInvite(
            inviteCode: normalized,
            idempotencyKey: NightFlockV4Idempotency.command("preview-invite")
        ))
    }

    func redeemSlumberPartyInvite(code: String) {
        let normalized = NightFlockInviteCode.normalize(code)
        guard !normalized.isEmpty else { return }
        let commandID = UUID()
        stageSharedHabitsJoinAgreement(commandID: commandID) { [weak self] in
            self?.performV4(.redeemInvite(
                inviteCode: normalized,
                idempotencyKey: NightFlockV4Idempotency.command("redeem-invite", seed: commandID)
            ), resolvedPartyIntentCommandID: commandID, onResolvedNewParty: { partyID in
                self?.acceptStagedSharedHabitsAgreementAfterJoining(partyID: partyID, commandID: commandID)
            })
        }
    }

    func leaveSlumberParty(_ partyID: UUID) {
        switch NightFlockSharedHabitsFencePolicy.partyExitDisposition(
            supportsSharedHabits: supportsSharedHabits
        ) {
        case .sendLegacyCommand:
            performV4(.leaveParty(
                partyID: partyID,
                idempotencyKey: NightFlockV4Idempotency.command("leave-party")
            ))
            return
        case .stageSharedHabitsFence:
            break
        }
        beginSharedHabitsPrivacyFence(partyID: partyID, action: .leave) { [weak self] fence in
            guard let self else { return }
            self.performV4(.leaveParty(
                partyID: partyID,
                idempotencyKey: self.fenceIdempotencyKey(fence, action: "leave-party")
            ))
        }
    }

    func deleteSlumberParty(_ partyID: UUID) {
        switch NightFlockSharedHabitsFencePolicy.partyExitDisposition(
            supportsSharedHabits: supportsSharedHabits
        ) {
        case .sendLegacyCommand:
            performV4(.deleteParty(
                partyID: partyID,
                idempotencyKey: NightFlockV4Idempotency.command("delete-party")
            ))
            return
        case .stageSharedHabitsFence:
            break
        }
        beginSharedHabitsPrivacyFence(partyID: partyID, action: .dissolveAndLeave) { [weak self] fence in
            guard let self else { return }
            self.performV4(.deleteParty(
                partyID: partyID,
                idempotencyKey: self.fenceIdempotencyKey(fence, action: "dissolve-party")
            ))
        }
    }

    func blockSlumberPartyMember(partyID: UUID, memberID: UUID) {
        performV4(.blockMember(partyID: partyID, memberID: memberID,
                               idempotencyKey: NightFlockV4Idempotency.command("block-member")))
    }

    func reportSlumberPartyMember(partyID: UUID, memberID: UUID, reason: NightFlockReportReason) {
        performV4(.reportMember(partyID: partyID, memberID: memberID, reason: reason,
                                idempotencyKey: NightFlockV4Idempotency.command("report-member")))
    }

    func cheerSlumberPartyMember(
        partyID: UUID,
        memberID: UUID,
        observedStatusAt: Date,
        cheer: NightFlockV4Cheer
    ) {
        let key = NightFlockV4CheerCommandKey(
            partyID: partyID,
            target: .member(memberID, observedAt: observedStatusAt),
            cheer: cheer
        )
        submitV4Cheer(
            key: key,
            command: .cheerMember(
                partyID: partyID,
                memberID: memberID,
                cheer: cheer,
                idempotencyKey: NightFlockV4Idempotency.command("cheer-member-\(cheer.rawValue)")
            )
        )
    }

    func cheerMembershipSlumberPartyMember(
        partyID: UUID,
        memberID: UUID,
        statusID: UUID,
        cheer: NightFlockV4Cheer
    ) {
        let key = NightFlockV4CheerCommandKey(partyID: partyID, target: .membershipStatus(statusID), cheer: cheer)
        submitV4Cheer(key: key, command: .cheerMembershipMember(
            partyID: partyID, memberID: memberID, statusID: statusID, cheer: cheer,
            idempotencyKey: NightFlockV4Idempotency.command("cheer-member-status-\(cheer.rawValue)", seed: statusID)
        ))
    }

    /// Sends only the intentionally small social profile. Farm inventory and
    /// progression never cross this boundary.
    func syncPublicProfile(
        _ profile: CountingSheepUserProfile,
        selectionKind: CountingSheepDisplayNameSelectionKind? = nil,
        avatarID: String? = nil,
        onAvatarSyncSettled: ((Result<Bool, Error>) -> Void)? = nil
    ) {
        guard profile.presentation.isAllowlisted(),
              accountState == .linked,
              permitsNightFlockNetwork,
              service != nil
        else { return }
        let effectiveSelectionKind = selectionKind
            ?? (profile.hasEstablishedDisplayName ? .change : .initial)
        var wirePresentation = profile.presentation
        if v4ListState?.profileHeadShapeVersion != 1 { wirePresentation.headShapeID = nil }
        pendingV4ProfileMutation = profile
        performV4(.updatePublicProfile(
            expectedRevision: profile.revision,
            nameSelectionKind: effectiveSelectionKind,
            displayName: profile.displayName,
            presentation: wirePresentation,
            avatarID: avatarID,
            idempotencyKey: NightFlockV4Idempotency.command("public-profile")
        ), onSettled: { result in
            if case let .failure(error) = result {
                onAvatarSyncSettled?(.failure(error))
            }
        }, onAcceptedResponse: { response in
            guard let avatarID else { return }
            onAvatarSyncSettled?(.success(
                response.profile?.presentation.avatarID == avatarID
            ))
        })
    }

    func sendSlumberPartyCheer(
        partyID: UUID,
        activityID: UUID,
        cheer: NightFlockV4Cheer
    ) {
        let key = NightFlockV4CheerCommandKey(
            partyID: partyID,
            target: .activity(activityID),
            cheer: cheer
        )
        submitV4Cheer(
            key: key,
            command: .react(
                partyID: partyID,
                activityID: activityID,
                cheer: cheer,
                idempotencyKey: NightFlockV4Idempotency.command("cheer-\(cheer.rawValue)", seed: activityID)
            )
        )
    }

    func sendMembershipSlumberPartyCheer(
        partyID: UUID,
        activityID: UUID,
        cheer: NightFlockV4Cheer
    ) {
        let key = NightFlockV4CheerCommandKey(partyID: partyID, target: .membershipActivity(activityID), cheer: cheer)
        submitV4Cheer(key: key, command: .reactMembership(
            partyID: partyID, activityID: activityID, cheer: cheer,
            idempotencyKey: NightFlockV4Idempotency.command("membership-cheer-\(cheer.rawValue)", seed: activityID)
        ))
    }

    func v4CheerSendState(for key: NightFlockV4CheerCommandKey) -> NightFlockV4CheerSendState? {
        v4CheerSendStates[key]
    }

    func enqueueV4Activity(
        source: NightFlockV4SourceActivityRecord,
        origin: NightFlockV4OutboxOrigin = .live
    ) {
        guard permitsLocalSocialMutation,
              mayPublishWhileSharedHabitsFenceIsOpen(),
              let outbox
        else { return }
        let idempotencyKey: String
        switch origin {
        case .live:
            idempotencyKey = NightFlockV4Idempotency.command(
                "activity-\(source.kind.rawValue)",
                seed: source.sourceEventID
            )
        case .backfill:
            // The durable outbox retains this key for retry, while a later
            // backfill must not replay the original live command journal.
            idempotencyKey = NightFlockV4Idempotency.command("backfill-activity-\(source.kind.rawValue)")
        }
        let record = NightFlockV4OutboxSourceRecord(
            source: source,
            origin: origin,
            idempotencyKey: idempotencyKey
        )
        let generation = localSocialGeneration
        Task {
            guard isCurrentLocalSocialGeneration(generation) else { return }
            await outbox.enqueueV4(record, epoch: generation)
            guard isCurrentLocalSocialGeneration(generation) else { return }
            await flushOutbox()
        }
    }

    func enqueueV4Status(
        sourceEventID: UUID,
        status: NightFlockV4LiveStatusKind,
        revision: Int,
        observedAt: Date = Date(),
        requiresPrimaryRunDecision: Bool? = nil,
        originStartedAt: Date? = nil
    ) {
        guard permitsLocalSocialMutation,
              mayPublishWhileSharedHabitsFenceIsOpen(),
              let outbox
        else { return }
        let record = NightFlockV4StatusOutboxRecord(
            sourceEventID: sourceEventID,
            status: status,
            revision: revision,
            observedAt: observedAt,
            idempotencyKey: NightFlockV4Idempotency.command("status-\(status.rawValue)-\(revision)", seed: sourceEventID),
            requiresPrimaryRunDecision: requiresPrimaryRunDecision,
            originStartedAt: originStartedAt
        )
        let generation = localSocialGeneration
        Task {
            guard isCurrentLocalSocialGeneration(generation) else { return }
            await outbox.enqueueV4Status(record, epoch: generation)
            guard isCurrentLocalSocialGeneration(generation) else { return }
            await flushOutbox()
        }
    }

    func publishV4WindDownStarting(runID: UUID, at date: Date, isPractice: Bool) {
        guard NightFlockV4PublicationPolicy.allows(
            .starting,
            role: .primarySleepBookend,
            isPractice: isPractice
        ), maySharePrimaryRun(runID: runID, startedAt: date) else { return }
        enqueueV4Status(
            sourceEventID: runID,
            status: .windDownStarting,
            revision: 1,
            observedAt: date,
            requiresPrimaryRunDecision: true,
            originStartedAt: date
        )
    }

    func publishV4PhoneAwayActive(for run: FocusRun) {
        guard NightFlockV4PublicationPolicy.allows(
            .active,
            role: run.nightWatchPlan?.role,
            isPractice: run.isPractice
        ), run.nightWatchPlan?.role != .primarySleepBookend || maySharePrimaryRun(run) else { return }
        enqueueV4Status(
            sourceEventID: run.id,
            status: .phoneAwayActive,
            revision: 2,
            observedAt: run.phoneAwayValidatedAt ?? Date(),
            requiresPrimaryRunDecision: run.nightWatchPlan?.role == .primarySleepBookend,
            originStartedAt: run.startedAt
        )
    }

    /// Factual social activity is independent from legacy shared-goal setup
    /// and from local reward-settlement eligibility. It records only a primary
    /// Wind Down or an additional Phone Away—not practice or morning quiet.
    func publishV4TerminalActivity(for run: FocusRun) {
        guard NightFlockV4PublicationPolicy.allows(
            .terminal,
            role: run.nightWatchPlan?.role,
            isPractice: run.isPractice
        ), let role = run.nightWatchPlan?.role,
              role != .primarySleepBookend || maySharePrimaryRun(run)
        else { return }
        let kind: NightFlockV4ActivityKind = role == .primarySleepBookend ? .windDown : .phoneAway
        let status: NightFlockV4ActivityStatus = run.completedSuccessfully ? .completed : .partlyCompleted
        let endedAt = run.endedAt ?? Date()
        let source = NightFlockV4SourceActivityRecord(
            sourceEventID: run.id,
            kind: kind,
            outcome: status,
            startedAt: run.startedAt,
            endedAt: endedAt,
            windDownMinutes: kind == .windDown ? run.creditedWindDownMinutes : 0,
            phoneAwayMinutes: kind == .phoneAway ? run.creditedQuietMinutes : 0,
            statusRevision: 3
        )
        enqueueV4Activity(source: source)
        if run.completedSuccessfully {
            enqueueV4Status(
                sourceEventID: run.id,
                status: kind == .windDown ? .windDownCompleted : .phoneAwayCompleted,
                revision: 3,
                observedAt: endedAt,
                requiresPrimaryRunDecision: role == .primarySleepBookend,
                originStartedAt: run.startedAt
            )
        }
    }

    func acknowledgeV4Grants(_ grantIDs: [UUID]) {
        for grantID in grantIDs {
            performV4(.acknowledgeGrant(
                grantID: grantID,
                idempotencyKey: NightFlockV4Idempotency.command("ack-grant", seed: grantID)
            ), showLoading: false)
        }
    }

    private func submitV4Cheer(
        key: NightFlockV4CheerCommandKey,
        command: NightFlockV4Command
    ) {
        guard v4CheerSendStates[key] != .pending, v4CheerSendStates[key] != .sent else { return }
        if stageUpdateCheerIfApplicable(key: key) { return }
        guard accountState == .linked, permitsNightFlockNetwork, service != nil else {
            v4CheerSendStates[key] = .failed
            return
        }
        v4CheerSendStates[key] = .pending
        performV4(command, showLoading: false) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.v4CheerSendStates[key] = .sent
            case .failure:
                self.v4CheerSendStates[key] = .failed
            }
        }
    }

    func performV4(
        _ command: NightFlockV4Command,
        showLoading: Bool = true,
        onSettled: ((Result<Void, Error>) -> Void)? = nil,
        onAcceptedResponse: ((NightFlockV4CommandResponse) -> Void)? = nil,
        resolvedPartyIntentCommandID: UUID? = nil,
        onResolvedNewParty: ((UUID) -> Void)? = nil
    ) {
        guard accountState == .linked, permitsNightFlockNetwork, let service else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        let directCommandPartyID = v4PartyID(for: command)
        let directCommandRequestSequence = directCommandPartyID.map { _ in
            beginV4PartyDetailRequest()
        }
        if showLoading { phase = .loading }
        Task {
            var commandAccepted = false
            do {
                let response = try await service.sendV4(command)
                guard permitsNightFlockNetwork,
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                guard response.accepted else {
                    onSettled?(.failure(NightFlockServiceError.unsupportedResponse))
                    return
                }
                commandAccepted = true
                onSettled?(.success(()))
                onAcceptedResponse?(response)
                let resolvedPartyID = response.resolvedPartyID
                if let resolvedPartyID, let resolvedPartyIntentCommandID {
                    // Persist the exact command-to-party binding before any
                    // list/detail follow-up can observe concurrent joins.
                    await persistResolvedSharedHabitsJoinAgreementIntent(
                        partyID: resolvedPartyID,
                        commandID: resolvedPartyIntentCommandID,
                        epoch: generation
                    )
                }
                v4RequestID = response.requestID
                if let profile = response.profile {
                    adoptServerV4ProfileIfSafe(
                        profile,
                        supportsSocialAvatar: v4ListState?.supportsProfileAvatar
                    )
                }
                if let code = response.inviteCode,
                   let partyID = v4PartyID(for: command, response: response),
                   let inviteID = response.invitation?.inviteID ?? response.party?.invitation?.inviteID ?? response.inviteID {
                    v4InviteCodes[partyID] = V4InviteCode(inviteID: inviteID, code: code)
                }
                if let preview = response.invitePreview { v4InvitePreview = preview }
                if let party = response.party {
                    let requestSequence: UInt64
                    if let directCommandPartyID,
                       party.summary.partyID == directCommandPartyID,
                       let directCommandRequestSequence {
                        requestSequence = directCommandRequestSequence
                    } else {
                        requestSequence = beginV4PartyDetailRequest()
                    }
                    applyV4PartyDetail(party, requestSequence: requestSequence)
                }
                switch command {
                case let .leaveParty(partyID, _), let .deleteParty(partyID, _):
                    v4InviteCodes.removeValue(forKey: partyID)
                    if selectedV4Party?.summary.partyID == partyID { clearSelectedSlumberParty() }
                case let .revokeInvite(partyID, _, _):
                    v4InviteCodes.removeValue(forKey: partyID)
                default:
                    break
                }
                try await refreshV4List(showLoading: false)
                if let resolvedPartyID,
                   slumberParties.contains(where: { $0.partyID == resolvedPartyID }) {
                    let requestSequence = beginV4PartyDetailRequest()
                    let detail = try await service.stateV4Party(partyID: resolvedPartyID)
                    guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                    applyV4PartyDetail(detail.party, requestSequence: requestSequence)
                    onResolvedNewParty?(resolvedPartyID)
                }
                if let partyID = selectedV4Party?.summary.partyID {
                    let requestSequence = beginV4PartyDetailRequest()
                    let detail = try await service.stateV4Party(partyID: partyID)
                    guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                    applyV4PartyDetail(detail.party, requestSequence: requestSequence)
                }
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                if case .updatePublicProfile = command {
                    // The local profile remains authoritative until a later
                    // canonical refresh; a failed request must not suppress it
                    // forever by leaving the pending mutation latched.
                    pendingV4ProfileMutation = nil
                }
                if !commandAccepted { onSettled?(.failure(error)) }
                presentNightFlockError(error, lane: .directCommand(schema: NightFlockV4Rules.schemaVersion))
            }
        }
    }

    /// The Farm integration installs this closure. Returning applied IDs keeps
    /// acknowledgement safely downstream of the existing durable reward ledger.
    func applyPendingV4GrantsIfPossible() {
        guard let apply = onApplyV4RewardGrants else { return }
        let pending = v4GrantInbox.filter { $0.acknowledgedAt == nil }
        let applied = apply(pending)
        guard !applied.isEmpty else { return }
        acknowledgeV4Grants(applied)
    }

    func flushV4Outbox() async {
        guard usesSlumberPartyV4,
              accountState == .linked,
              permitsNightFlockNetwork,
              mayPublishWhileSharedHabitsFenceIsOpen(),
              let outbox,
              let service
        else { return }
        guard await outbox.permitsSharedHabitsPublication() else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        for record in await outbox.v4Records() {
            guard await outbox.permitsSharedHabitsPublication() else { return }
            if record.source.kind == .windDown,
               !maySharePrimaryRun(runID: record.source.sourceEventID, startedAt: record.source.startedAt) {
                await outbox.removeV4(record.source.sourceEventID, kind: record.source.kind, epoch: generation)
                continue
            }
            do {
                let publication = record.publishing(toMembershipStream: v4ListState?.parties.contains(where: \.supportsMembershipSharing) == true)
                let response = try await service.sendV4(.publishActivity(publication))
                guard response.accepted,
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                await outbox.removeV4(record.source.sourceEventID, kind: record.source.kind, epoch: generation)
                // Publication acknowledgement is enough to request a fresh
                // canonical projection; do not wait for a Realtime hint.
                reconcileV4ObservedPartyDetails(with: slumberParties)
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                await outbox.markV4Attempt(record.source.sourceEventID, kind: record.source.kind, epoch: generation)
                handleOutboxFailure(error, lane: .outbox(schema: NightFlockV4Rules.schemaVersion))
                return
            }
        }
        for record in await outbox.v4StatusRecords() {
            guard await outbox.permitsSharedHabitsPublication() else { return }
            if !mayShareV4Status(record) {
                await outbox.removeV4Status(record, epoch: generation)
                continue
            }
            do {
                let membershipCapable = v4ListState?.parties.contains(where: \.supportsMembershipSharing) == true
                let command: NightFlockV4Command = membershipCapable
                    ? .publishMembershipStatus(sourceEventID: record.sourceEventID, status: record.status, revision: record.revision, observedAt: record.observedAt, idempotencyKey: NightFlockV4Idempotency.command("membership-status-\(record.status.rawValue)-\(record.revision)", seed: record.sourceEventID))
                    : .publishStatus(sourceEventID: record.sourceEventID, status: record.status, revision: record.revision, observedAt: record.observedAt, idempotencyKey: record.idempotencyKey)
                let response = try await service.sendV4(command)
                guard response.accepted,
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                await outbox.removeV4Status(record, epoch: generation)
                reconcileV4ObservedPartyDetails(with: slumberParties)
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                await outbox.markV4StatusAttempt(record, epoch: generation)
                handleOutboxFailure(error, lane: .outbox(schema: NightFlockV4Rules.schemaVersion))
                return
            }
        }
    }

    func synchronizeV4ProfileIfNeeded(
        serverProfile: CountingSheepUserProfile?,
        supportsSocialAvatar: Bool? = nil,
        onAvatarSyncSettled: ((Result<Bool, Error>) -> Void)? = nil
    ) {
        guard pendingV4ProfileMutation == nil else { return }
        let local = PersistenceService.shared.userProfile
        guard CountingSheepDisplayName.validate(local.displayName).isSuccess,
              local.presentation.isAllowlisted()
        else { return }
        let supportsSocialAvatar = supportsSocialAvatar
            ?? v4ListState?.supportsProfileAvatar
            ?? false
        guard let plan = NightFlockV4ProfileSyncRules.routinePlan(
            local: local,
            server: serverProfile,
            supportsSocialAvatar: supportsSocialAvatar,
            supportsHeadShape: v4ListState?.profileHeadShapeVersion == 1
        ) else { return }
        syncPublicProfile(
            plan.profile,
            selectionKind: plan.nameSelectionKind,
            avatarID: plan.avatarID,
            onAvatarSyncSettled: onAvatarSyncSettled
        )
    }

    /// Realtime tells us only that a relevant row may have changed. The state
    /// RPC below remains the sole source of the party projection.
    private func applyV4PartyDetail(
        _ detail: NightFlockV4PartyDetail?,
        select: Bool = true,
        requestSequence: UInt64? = nil
    ) {
        guard let detail else {
            if select { selectedV4Party = nil }
            return
        }
        let partyID = detail.summary.partyID
        guard !isSharedHabitsPartySuppressed(partyID) else { return }
        let requestSequence = requestSequence ?? beginV4PartyDetailRequest()
        guard NightFlockV4PartyDetailReconciliation.accepts(
            requestSequence: requestSequence,
            after: v4AcceptedPartyDetailRequestSequences[partyID]
        ) else {
            return
        }
        v4AcceptedPartyDetailRequestSequences[partyID] = requestSequence
        let previous = v4ObservedPartyDetails[partyID]
        v4ObservedPartyDetails[partyID] = detail
        let refreshedAt = Date()
        v4ObservedPartyRefreshDates[partyID] = refreshedAt
        v4ObservedPartyObservationStates[partyID] = .current(lastReceivedAt: refreshedAt)
        if v4InviteCodes[partyID]?.inviteID != detail.invitation?.inviteID {
            v4InviteCodes.removeValue(forKey: partyID)
        }
        if select || selectedV4Party?.summary.partyID == partyID {
            selectedV4Party = detail
        }
        resumeResolvedSharedHabitsJoinAgreementIfPossible(partyID: partyID)
        v4GrantInbox = detail.grantInbox
        recoverUpdateCheers(in: detail)

        // Do not replay a party's existing cheers when it is first selected.
        // A subsequent canonical refresh may surface only genuinely new totals.
        guard let previous,
              previous.summary.partyID == detail.summary.partyID
        else { return }
        if !detail.summary.supportsMembershipSharing {
        let priorCounts = Dictionary(uniqueKeysWithValues: previous.cheers.map {
            ("\($0.activityID.uuidString.lowercased()):\($0.cheer.rawValue)", $0.count)
        })
        let activityMemberIDs = Dictionary(uniqueKeysWithValues: detail.activities.map {
            ($0.activityID, $0.memberID)
        })
        for summary in detail.cheers {
            let key = "\(summary.activityID.uuidString.lowercased()):\(summary.cheer.rawValue)"
            guard summary.count > (priorCounts[key] ?? 0),
                  activityMemberIDs[summary.activityID] == detail.myMemberID
            else { continue }
            onV4CheerFeedback?(
                SlumberPartyCheerFeedback(
                    partyID: detail.summary.partyID,
                    cheer: summary.cheer,
                    count: summary.count,
                    observedAt: Date()
                )
            )
        }
        let priorLiveCounts = Dictionary(uniqueKeysWithValues: previous.liveCheers.map {
            ("\($0.memberID.uuidString.lowercased()):\($0.cheer.rawValue)", $0.count)
        })
        for summary in detail.liveCheers {
            let key = "\(summary.memberID.uuidString.lowercased()):\(summary.cheer.rawValue)"
            guard summary.memberID == detail.myMemberID,
                  summary.count > (priorLiveCounts[key] ?? 0)
            else { continue }
            onV4CheerFeedback?(
                SlumberPartyCheerFeedback(
                    partyID: detail.summary.partyID,
                    cheer: summary.cheer,
                    count: summary.count,
                    observedAt: Date()
                )
            )
        }
        }
        for delta in NightFlockV4MembershipCheerFeedbackRules.deltas(
            previous: previous,
            current: detail,
            at: refreshedAt
        ) {
            onV4CheerFeedback?(
                SlumberPartyCheerFeedback(
                    partyID: detail.summary.partyID,
                    cheer: delta.cheer,
                    count: delta.count,
                    observedAt: refreshedAt,
                    sourceEventID: delta.sourceEventID
                )
            )
        }
    }

    private func beginV4PartyDetailRequest() -> UInt64 {
        v4NextPartyDetailRequestSequence += 1
        return v4NextPartyDetailRequestSequence
    }

    private func v4PartyID(
        for command: NightFlockV4Command,
        response: NightFlockV4CommandResponse
    ) -> UUID? {
        if let partyID = response.party?.summary.partyID ?? response.invitation?.partyID {
            return partyID
        }
        return v4PartyID(for: command)
    }

    private func v4PartyID(for command: NightFlockV4Command) -> UUID? {
        switch command {
        case let .renameParty(partyID, _, _), let .startRound(partyID, _, _),
             let .createInvite(partyID, _), let .replaceInvite(partyID, _, _),
             let .revokeInvite(partyID, _, _), let .retrieveInvite(partyID, _),
             let .leaveParty(partyID, _), let .deleteParty(partyID, _),
             let .blockMember(partyID, _, _), let .reportMember(partyID, _, _, _),
             let .cheerMember(partyID, _, _, _), let .cheerMembershipMember(partyID, _, _, _, _),
             let .completeBackfill(partyID, _, _, _), let .react(partyID, _, _, _), let .reactMembership(partyID, _, _, _), let .acknowledgeUpdateCheer(partyID, _, _):
            return partyID
        case .createParty, .previewInvite, .redeemInvite, .updatePublicProfile,
             .publishActivity, .publishStatus, .publishMembershipStatus, .acknowledgeGrant, .deleteAccount:
            return nil
        }
    }

    func synchronizeV4RealtimeSubscriptions(with parties: [NightFlockV4PartySummary]) {
        let desired = NightFlockV4ObservedPartyRefreshPolicy.eligiblePartyIDs(from: parties)
        // A membership can disappear because another party's host blocks us
        // or deletes the party. Prune every presentation/cache surface from
        // the canonical list before any command flow attempts a detail reload.
        var stalePartyIDs = v4RealtimePartyIDs.subtracting(desired)
        stalePartyIDs.formUnion(Set(v4ObservedPartyDetails.keys).subtracting(desired))
        if let selectedPartyID = selectedV4Party?.summary.partyID,
           !desired.contains(selectedPartyID) {
            stalePartyIDs.insert(selectedPartyID)
            selectedV4Party = nil
        }
        stalePartyIDs.formUnion(Set(v4InviteCodes.keys).subtracting(desired))
        for partyID in stalePartyIDs {
            v4RealtimeRefreshTasks.removeValue(forKey: partyID)?.cancel()
            v4RealtimeSetupTasks.removeValue(forKey: partyID)?.cancel()
            v4PartyObservationTasks.removeValue(forKey: partyID)?.cancel()
            v4PartyObservationNeedsRefresh.remove(partyID)
            v4RealtimeRefreshAttemptIDs.removeValue(forKey: partyID)
            v4RealtimeSetupAttemptIDs.removeValue(forKey: partyID)
            v4PartyObservationAttemptIDs.removeValue(forKey: partyID)
            v4SelectedPartyRefreshAttemptIDs.removeValue(forKey: partyID)
            v4ObservedPartyDetails.removeValue(forKey: partyID)
            v4ObservedPartyRefreshDates.removeValue(forKey: partyID)
            v4ObservedPartyObservationStates.removeValue(forKey: partyID)
            v4AcceptedPartyDetailRequestSequences.removeValue(forKey: partyID)
            v4RefreshingPartyIDs.remove(partyID)
            v4RealtimeConnectedPartyIDs.remove(partyID)
            v4CheerSendStates = v4CheerSendStates.filter { $0.key.partyID != partyID }
            v4InviteCodes.removeValue(forKey: partyID)
            Task { [service] in await service?.stopV4Realtime(partyID: partyID) }
        }
        v4RealtimePartyIDs = desired
        for partyID in desired
        where !v4RealtimeConnectedPartyIDs.contains(partyID) && v4RealtimeSetupTasks[partyID] == nil {
            let attemptID = UUID()
            v4RealtimeSetupAttemptIDs[partyID] = attemptID
            v4RealtimeSetupTasks[partyID] = Task { [weak self] in
                await Task.yield()
                guard let self else { return }
                defer {
                    if self.v4RealtimeSetupAttemptIDs[partyID] == attemptID {
                        self.v4RealtimeSetupAttemptIDs.removeValue(forKey: partyID)
                        self.v4RealtimeSetupTasks.removeValue(forKey: partyID)
                    }
                }
                guard let service = self.service else { return }
                do {
                    try await service.startV4Realtime(partyID: partyID) { [weak self] in
                        await self?.scheduleV4RealtimeRefresh(for: partyID)
                    }
                    guard !Task.isCancelled, self.v4RealtimePartyIDs.contains(partyID) else { return }
                    self.v4RealtimeConnectedPartyIDs.insert(partyID)
                    self.refreshV4PartyObservation(partyID)
                } catch {
                    // Realtime remains a best-effort hint. Canonical refresh
                    // and the local run never wait on this websocket. The
                    // attempt is released by defer so a later foreground or
                    // canonical refresh can retry without duplicate setup.
                }
            }
        }
    }

    /// Foreground and accepted publication reconcile existing member parties
    /// directly. This never schedules a repeating request loop: each ID has
    /// at most one in-flight canonical detail request.
    func reconcileV4ObservedPartyDetails(with parties: [NightFlockV4PartySummary]) {
        let eligible = NightFlockV4ObservedPartyRefreshPolicy.eligiblePartyIDs(from: parties)
        for partyID in eligible {
            refreshV4PartyObservation(partyID, refreshListAfterward: false)
        }
    }

    private func scheduleV4RealtimeRefresh(for partyID: UUID) {
        guard v4RealtimePartyIDs.contains(partyID) else { return }
        v4RealtimeRefreshTasks.removeValue(forKey: partyID)?.cancel()
        let attemptID = UUID()
        v4RealtimeRefreshAttemptIDs[partyID] = attemptID
        v4RealtimeRefreshTasks[partyID] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            defer {
                if self?.v4RealtimeRefreshAttemptIDs[partyID] == attemptID {
                    self?.v4RealtimeRefreshAttemptIDs.removeValue(forKey: partyID)
                    self?.v4RealtimeRefreshTasks.removeValue(forKey: partyID)
                }
            }
            guard !Task.isCancelled,
                  let self,
                  self.v4RealtimePartyIDs.contains(partyID)
            else { return }
            self.refreshV4PartyObservation(partyID)
        }
    }

    private func refreshV4PartyObservation(
        _ partyID: UUID,
        refreshListAfterward: Bool = true
    ) {
        guard accountState == .linked,
              permitsNightFlockNetwork,
              !isSharedHabitsPartySuppressed(partyID),
              let service
        else { return }
        guard v4RealtimePartyIDs.contains(partyID) else { return }
        guard v4PartyObservationTasks[partyID] == nil else {
            v4PartyObservationNeedsRefresh.insert(partyID)
            return
        }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        let fenceGeneration = sharedHabitsFenceGeneration
        let cursor = selectedV4Party?.summary.partyID == partyID ? selectedV4Party?.cursor : nil
        let attemptID = UUID()
        let requestSequence = beginV4PartyDetailRequest()
        v4PartyObservationAttemptIDs[partyID] = attemptID
        v4ObservedPartyObservationStates[partyID] = .refreshing(
            lastReceivedAt: v4ObservedPartyRefreshDates[partyID]
        )
        let task = Task { [weak self] in
            await Task.yield()
            guard let self else { return }
            defer {
                if self.v4PartyObservationAttemptIDs[partyID] == attemptID {
                    self.v4PartyObservationAttemptIDs.removeValue(forKey: partyID)
                    self.v4PartyObservationTasks.removeValue(forKey: partyID)
                    if self.v4PartyObservationNeedsRefresh.remove(partyID) != nil {
                        self.refreshV4PartyObservation(partyID, refreshListAfterward: false)
                    }
                }
            }
            do {
                let response = try await service.stateV4Party(partyID: partyID, cursor: cursor)
                guard self.permitsNightFlockNetwork,
                      self.v4RealtimePartyIDs.contains(partyID),
                      self.sharedHabitsFenceGeneration == fenceGeneration,
                      !self.isSharedHabitsPartySuppressed(partyID),
                      self.isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                self.applyV4PartyDetail(response.party, select: false, requestSequence: requestSequence)
                self.applyPendingV4GrantsIfPossible()
                // Realtime invalidation can change the immutable archive as
                // well as the current status. Refresh the separate scope.
                self.refreshSharedHabits(partyID: partyID)
                guard refreshListAfterward else { return }
                // Sanitized party signals also cover join/leave, renames and
                // invitation/profile changes, so refresh the list projection
                // rather than leaving Home/Farm with an old summary.
                let list = try await service.stateV4List()
                guard self.permitsNightFlockNetwork,
                      self.isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                self.canonicalV4PartyIDs = Set(list.parties.map(\.partyID))
                self.hasCanonicalV4PartySnapshot = true
                var visibleList = list
                visibleList.parties.removeAll { self.isSharedHabitsPartySuppressed($0.partyID) }
                self.reconcileSharedHabitsLeaveFences(with: list.parties)
                self.v4ListState = visibleList
                self.refreshSharedHabitsReceiptsForCurrentParties()
                self.synchronizeV4RealtimeSubscriptions(with: visibleList.parties)
                self.adoptServerV4ProfileIfSafe(list.profile)
                self.v4GrantInbox = list.grantInbox
                self.applyPendingV4GrantsIfPossible()
            } catch {
                // A Realtime prompt cannot replace the main request/recovery
                // presentation; the next foreground or action refresh heals it.
                guard self.v4PartyObservationAttemptIDs[partyID] == attemptID,
                      self.v4RealtimePartyIDs.contains(partyID),
                      self.isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                self.v4ObservedPartyObservationStates[partyID] = .stale(
                    lastReceivedAt: self.v4ObservedPartyRefreshDates[partyID]
                )
            }
        }
        v4PartyObservationTasks[partyID] = task
    }

#if DEBUG
    /// Screenbook-only fixture seam. It follows the production cache shape but
    /// performs no account, network, or subscription work.
    func installV4ObservedPartyPreview(_ detail: NightFlockV4PartyDetail) {
        let partyID = detail.summary.partyID
        v4ListState = NightFlockV4ListStateResponse(parties: [detail.summary])
        v4ObservedPartyDetails = [partyID: detail]
        let now = Date()
        v4ObservedPartyRefreshDates = [partyID: now]
        v4ObservedPartyObservationStates = [partyID: .current(lastReceivedAt: now)]
        selectedV4Party = detail
    }
#endif

    func stopV4RealtimePresentation() {
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
        v4NextPartyDetailRequestSequence = 0
        v4AcceptedPartyDetailRequestSequences = [:]
        Task { [service] in
            await service?.stopV4Realtime()
        }
    }

    func adoptServerV4ProfileIfSafe(
        _ serverProfile: CountingSheepUserProfile?,
        supportsSocialAvatar: Bool? = nil
    ) {
        guard let serverProfile else { return }
        // A local appearance/name edit stays local until its own command has
        // resolved. Refreshes must not erase it merely because the server has
        // an older revision.
        if let pending = pendingV4ProfileMutation {
            guard serverProfile.revision > pending.revision else { return }
            pendingV4ProfileMutation = nil
        }
        let local = PersistenceService.shared.userProfile
        guard serverProfile.revision >= local.revision else { return }
        // The social projection intentionally omits local rename timestamps.
        // Preserve them so local UI remains aligned with the server's rolling
        // limit rather than briefly offering a third rename.
        var merged = serverProfile
        merged.successfulDisplayNameChangeDates = local.successfulDisplayNameChangeDates
        let supportsSocialAvatar = supportsSocialAvatar
            ?? v4ListState?.supportsProfileAvatar
            ?? false
        // A deliberate local choice, including an explicit Shepherd, survives
        // old-server refreshes. A pristine profile may adopt a supported
        // account's existing social identity during recovery.
        merged.presentation.avatarID = SocialAvatarAdoptionRules.resolvedAvatarID(
            localAvatarID: local.presentation.avatarID,
            hasExplicitLocalSelection: PersistenceService.shared.hasExplicitSocialAvatarSelection,
            serverAvatarID: serverProfile.presentation.avatarID,
            serverSupportsAvatars: supportsSocialAvatar
        )
        PersistenceService.shared.userProfile = merged
        v4Profile = merged
    }
}

private extension Result where Success == String, Failure == CountingSheepDisplayName.ValidationError {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
