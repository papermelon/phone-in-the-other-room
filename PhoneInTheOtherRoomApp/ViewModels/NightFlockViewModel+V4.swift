import Foundation

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
        v4ListState = response
        synchronizeV4RealtimeSubscriptions(with: response.parties)
        adoptServerV4ProfileIfSafe(response.profile)
        v4GrantInbox = response.grantInbox
        phase = .ready
        applyPendingV4GrantsIfPossible()
        synchronizeV4ProfileIfNeeded(serverProfile: response.profile)
    }

    func selectSlumberParty(_ partyID: UUID, cursor: NightFlockV4PaginationCursor? = nil) {
        guard accountState == .linked, permitsNightFlockNetwork, let service else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        phase = .loading
        Task {
            do {
                let response = try await service.stateV4Party(partyID: partyID, cursor: cursor)
                guard permitsNightFlockNetwork,
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                applyV4PartyDetail(response.party)
                phase = .ready
                applyPendingV4GrantsIfPossible()
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                presentNightFlockError(error, lane: .snapshot(schema: NightFlockV4Rules.schemaVersion))
            }
        }
    }

    func refreshSelectedSlumberParty() {
        guard let partyID = selectedV4Party?.summary.partyID else { return }
        selectSlumberParty(partyID, cursor: selectedV4Party?.cursor)
    }

    /// Clears only the detail presentation. Party subscriptions remain active
    /// while the user belongs to them so an active Wind Down can still receive
    /// a silent, directed cheer from any of up to five parties.
    func clearSelectedSlumberParty() {
        selectedV4Party = nil
    }

    func createSlumberParty(named name: String, timeZoneIdentifier: String = TimeZone.current.identifier) {
        performV4(.createParty(
            name: name,
            timeZoneIdentifier: timeZoneIdentifier,
            idempotencyKey: NightFlockV4Idempotency.command("create-party")
        ))
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
        performV4(.redeemInvite(
            inviteCode: normalized,
            idempotencyKey: NightFlockV4Idempotency.command("redeem-invite")
        ))
    }

    func leaveSlumberParty(_ partyID: UUID) {
        performV4(.leaveParty(
            partyID: partyID,
            idempotencyKey: NightFlockV4Idempotency.command("leave-party")
        ))
    }

    func deleteSlumberParty(_ partyID: UUID) {
        performV4(.deleteParty(
            partyID: partyID,
            idempotencyKey: NightFlockV4Idempotency.command("delete-party")
        ))
    }

    func blockSlumberPartyMember(partyID: UUID, memberID: UUID) {
        performV4(.blockMember(partyID: partyID, memberID: memberID,
                               idempotencyKey: NightFlockV4Idempotency.command("block-member")))
    }

    func reportSlumberPartyMember(partyID: UUID, memberID: UUID, reason: NightFlockReportReason) {
        performV4(.reportMember(partyID: partyID, memberID: memberID, reason: reason,
                                idempotencyKey: NightFlockV4Idempotency.command("report-member")))
    }

    func cheerSlumberPartyMember(partyID: UUID, memberID: UUID, cheer: NightFlockV4Cheer) {
        performV4(.cheerMember(partyID: partyID, memberID: memberID, cheer: cheer,
                               idempotencyKey: NightFlockV4Idempotency.command("cheer-member-\(cheer.rawValue)")), showLoading: false)
    }

    /// Sends only the intentionally small social profile. Farm inventory and
    /// progression never cross this boundary.
    func syncPublicProfile(
        _ profile: CountingSheepUserProfile,
        selectionKind: CountingSheepDisplayNameSelectionKind? = nil
    ) {
        guard profile.presentation.isAllowlisted(),
              accountState == .linked,
              permitsNightFlockNetwork,
              service != nil
        else { return }
        let effectiveSelectionKind = selectionKind
            ?? (profile.hasEstablishedDisplayName ? .change : .initial)
        pendingV4ProfileMutation = profile
        performV4(.updatePublicProfile(
            expectedRevision: profile.revision,
            nameSelectionKind: effectiveSelectionKind,
            displayName: profile.displayName,
            presentation: profile.presentation,
            idempotencyKey: NightFlockV4Idempotency.command("public-profile")
        ))
    }

    func sendSlumberPartyCheer(
        partyID: UUID,
        activityID: UUID,
        cheer: NightFlockV4Cheer
    ) {
        performV4(.react(
            partyID: partyID,
            activityID: activityID,
            cheer: cheer,
            idempotencyKey: NightFlockV4Idempotency.command("cheer-\(cheer.rawValue)", seed: activityID)
        ), showLoading: false)
    }

    func enqueueV4Activity(
        source: NightFlockV4SourceActivityRecord,
        origin: NightFlockV4OutboxOrigin = .live
    ) {
        guard permitsLocalSocialMutation, let outbox else { return }
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
        observedAt: Date = Date()
    ) {
        guard permitsLocalSocialMutation, let outbox else { return }
        let record = NightFlockV4StatusOutboxRecord(
            sourceEventID: sourceEventID,
            status: status,
            revision: revision,
            observedAt: observedAt,
            idempotencyKey: NightFlockV4Idempotency.command("status-\(status.rawValue)-\(revision)", seed: sourceEventID)
        )
        let generation = localSocialGeneration
        Task {
            guard isCurrentLocalSocialGeneration(generation) else { return }
            await outbox.enqueueV4Status(record, epoch: generation)
            guard isCurrentLocalSocialGeneration(generation) else { return }
            await flushOutbox()
        }
    }

    func publishV4WindDownStarting(runID: UUID, at date: Date) {
        enqueueV4Status(
            sourceEventID: runID,
            status: .windDownStarting,
            revision: 1,
            observedAt: date
        )
    }

    func publishV4PhoneAwayActive(for run: FocusRun) {
        guard !run.isPractice,
              let role = run.nightWatchPlan?.role,
              role == .primarySleepBookend || role == .additionalQuiet
        else { return }
        enqueueV4Status(
            sourceEventID: run.id,
            status: .phoneAwayActive,
            revision: 2,
            observedAt: run.phoneAwayValidatedAt ?? Date()
        )
    }

    /// Factual social activity is independent from legacy shared-goal setup
    /// and from local reward-settlement eligibility. It records only a primary
    /// Wind Down or an additional Phone Away—not practice or morning quiet.
    func publishV4TerminalActivity(for run: FocusRun) {
        guard !run.isPractice,
              let role = run.nightWatchPlan?.role,
              role == .primarySleepBookend || role == .additionalQuiet
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
                observedAt: endedAt
            )
        }
    }

    /// A late join replays the member's factual sources through the same
    /// account ledger; no client-side party fan-out is ever constructed.
    func enqueueV4LateJoinBackfill(_ sources: [NightFlockV4SourceActivityRecord]) {
        sources.forEach { enqueueV4Activity(source: $0, origin: .backfill) }
    }

    func completeV4Backfill(partyID: UUID, roundID: UUID, cursor: String) {
        performV4(.completeBackfill(
            partyID: partyID,
            roundID: roundID,
            cursor: cursor,
            idempotencyKey: NightFlockV4Idempotency.command("backfill-\(cursor)", seed: roundID)
        ), showLoading: false)
    }

    func acknowledgeV4Grants(_ grantIDs: [UUID]) {
        for grantID in grantIDs {
            performV4(.acknowledgeGrant(
                grantID: grantID,
                idempotencyKey: NightFlockV4Idempotency.command("ack-grant", seed: grantID)
            ), showLoading: false)
        }
    }

    func performV4(_ command: NightFlockV4Command, showLoading: Bool = true) {
        guard accountState == .linked, permitsNightFlockNetwork, let service else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        let existingPartyIDs = Set(slumberParties.map(\.partyID))
        if showLoading { phase = .loading }
        Task {
            do {
                let response = try await service.sendV4(command)
                guard permitsNightFlockNetwork,
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch),
                      response.accepted
                else { return }
                v4RequestID = response.requestID
                if let profile = response.profile { adoptServerV4ProfileIfSafe(profile) }
                if let code = response.inviteCode,
                   let partyID = v4PartyID(for: command, response: response),
                   let inviteID = response.invitation?.inviteID ?? response.party?.invitation?.inviteID ?? response.inviteID {
                    v4InviteCodes[partyID] = V4InviteCode(inviteID: inviteID, code: code)
                }
                if let preview = response.invitePreview { v4InvitePreview = preview }
                if let party = response.party { applyV4PartyDetail(party) }
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
                if case .redeemInvite = command,
                   let joined = slumberParties.first(where: { !existingPartyIDs.contains($0.partyID) }) {
                    let detail = try await service.stateV4Party(partyID: joined.partyID)
                    guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                    applyV4PartyDetail(detail.party)
                    if let round = detail.party?.summary.currentRound {
                        await enqueueV4LateJoinBackfill(for: joined.partyID, round: round)
                    }
                }
                if let partyID = selectedV4Party?.summary.partyID {
                    let detail = try await service.stateV4Party(partyID: partyID)
                    guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                    applyV4PartyDetail(detail.party)
                }
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                if case .updatePublicProfile = command {
                    // The local profile remains authoritative until a later
                    // canonical refresh; a failed request must not suppress it
                    // forever by leaving the pending mutation latched.
                    pendingV4ProfileMutation = nil
                }
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
              let outbox,
              let service
        else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        for record in await outbox.v4Records() {
            do {
                let response = try await service.sendV4(.publishActivity(record))
                guard response.accepted,
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                await outbox.removeV4(record.source.sourceEventID, kind: record.source.kind, epoch: generation)
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                await outbox.markV4Attempt(record.source.sourceEventID, kind: record.source.kind, epoch: generation)
                handleOutboxFailure(error, lane: .outbox(schema: NightFlockV4Rules.schemaVersion))
                return
            }
        }
        for record in await outbox.v4StatusRecords() {
            do {
                let response = try await service.sendV4(.publishStatus(
                    sourceEventID: record.sourceEventID,
                    status: record.status,
                    revision: record.revision,
                    observedAt: record.observedAt,
                    idempotencyKey: record.idempotencyKey
                ))
                guard response.accepted,
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                await outbox.removeV4Status(record.sourceEventID, epoch: generation)
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                await outbox.markV4StatusAttempt(record.sourceEventID, epoch: generation)
                handleOutboxFailure(error, lane: .outbox(schema: NightFlockV4Rules.schemaVersion))
                return
            }
        }
    }

    private func enqueueV4LateJoinBackfill(for partyID: UUID, round: NightFlockV4Round) async {
        guard let outbox, permitsLocalSocialMutation else { return }
        let practiceRunID = PersistenceService.shared.orientationState.practiceRunID
        let sources = PersistenceService.shared.nightWatchHistory.records.compactMap { record -> NightFlockV4SourceActivityRecord? in
            guard record.id != practiceRunID,
                  record.role == .primarySleepBookend || record.role == .additionalQuiet,
                  let endedAt = record.endedAt,
                  NightFlockV4RoundRules.isCurrent(round, at: endedAt)
            else { return nil }
            let kind: NightFlockV4ActivityKind = record.role == .primarySleepBookend ? .windDown : .phoneAway
            return NightFlockV4SourceActivityRecord(
                sourceEventID: record.id,
                kind: kind,
                outcome: record.outcome == .completed ? .completed : .partlyCompleted,
                startedAt: record.startedAt,
                endedAt: endedAt,
                windDownMinutes: kind == .windDown ? record.creditedWindDownMinutes : 0,
                phoneAwayMinutes: kind == .phoneAway ? record.creditedWindDownMinutes + record.creditedMorningQuietMinutes : 0,
                statusRevision: 3
            )
        }
        let generation = localSocialGeneration
        for source in sources {
            await outbox.enqueueV4(
                NightFlockV4OutboxSourceRecord(
                    source: source,
                    origin: .backfill,
                    idempotencyKey: NightFlockV4Idempotency.command(
                        "backfill-\(partyID.uuidString.lowercased())-\(round.roundID.uuidString.lowercased())-\(source.kind.rawValue)",
                        seed: source.sourceEventID
                    )
                ),
                epoch: generation
            )
        }
        await flushV4Outbox()
        guard isCurrentLocalSocialGeneration(generation) else { return }
        let cursor = "history-\(round.roundID.uuidString.lowercased())"
        performV4(.completeBackfill(
            partyID: partyID,
            roundID: round.roundID,
            cursor: cursor,
            idempotencyKey: NightFlockV4Idempotency.command("complete-backfill", seed: round.roundID)
        ), showLoading: false)
    }

    func synchronizeV4ProfileIfNeeded(serverProfile: CountingSheepUserProfile?) {
        guard pendingV4ProfileMutation == nil else { return }
        let local = PersistenceService.shared.userProfile
        guard CountingSheepDisplayName.validate(local.displayName).isSuccess,
              local.presentation.isAllowlisted()
        else { return }
        guard let plan = NightFlockV4ProfileSyncRules.routinePlan(local: local, server: serverProfile) else { return }
        syncPublicProfile(plan.profile, selectionKind: plan.nameSelectionKind)
    }

    /// Realtime tells us only that a relevant row may have changed. The state
    /// RPC below remains the sole source of the party projection.
    private func applyV4PartyDetail(
        _ detail: NightFlockV4PartyDetail?,
        select: Bool = true
    ) {
        guard let detail else {
            if select { selectedV4Party = nil }
            return
        }
        let partyID = detail.summary.partyID
        let previous = v4ObservedPartyDetails[partyID]
        v4ObservedPartyDetails[partyID] = detail
        if v4InviteCodes[partyID]?.inviteID != detail.invitation?.inviteID {
            v4InviteCodes.removeValue(forKey: partyID)
        }
        if select || selectedV4Party?.summary.partyID == partyID {
            selectedV4Party = detail
        }
        v4GrantInbox = detail.grantInbox

        // Do not replay a party's existing cheers when it is first selected.
        // A subsequent canonical refresh may surface only genuinely new totals.
        guard let previous,
              previous.summary.partyID == detail.summary.partyID
        else { return }
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

    private func v4PartyID(
        for command: NightFlockV4Command,
        response: NightFlockV4CommandResponse
    ) -> UUID? {
        if let partyID = response.party?.summary.partyID ?? response.invitation?.partyID {
            return partyID
        }
        switch command {
        case let .renameParty(partyID, _, _), let .startRound(partyID, _, _),
             let .createInvite(partyID, _), let .replaceInvite(partyID, _, _),
             let .revokeInvite(partyID, _, _), let .retrieveInvite(partyID, _),
             let .leaveParty(partyID, _), let .deleteParty(partyID, _),
             let .blockMember(partyID, _, _), let .reportMember(partyID, _, _, _),
             let .cheerMember(partyID, _, _, _),
             let .completeBackfill(partyID, _, _, _), let .react(partyID, _, _, _):
            return partyID
        case .createParty, .previewInvite, .redeemInvite, .updatePublicProfile,
             .publishActivity, .publishStatus, .acknowledgeGrant, .deleteAccount:
            return nil
        }
    }

    func synchronizeV4RealtimeSubscriptions(with parties: [NightFlockV4PartySummary]) {
        let desired = Set(parties.map(\.partyID))
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
            v4ObservedPartyDetails.removeValue(forKey: partyID)
            v4InviteCodes.removeValue(forKey: partyID)
            Task { [service] in await service?.stopV4Realtime(partyID: partyID) }
        }
        v4RealtimePartyIDs = desired
        for partyID in desired where v4RealtimeSetupTasks[partyID] == nil {
            v4RealtimeSetupTasks[partyID] = Task { [weak self] in
                guard let self, let service = self.service else { return }
                do {
                    try await service.startV4Realtime(partyID: partyID) { [weak self] in
                        await self?.scheduleV4RealtimeRefresh(for: partyID)
                    }
                    guard !Task.isCancelled, self.v4RealtimePartyIDs.contains(partyID) else { return }
                    self.refreshV4PartyObservation(partyID)
                } catch {
                    // Realtime remains a best-effort hint. Canonical refresh
                    // and the local run never wait on this websocket.
                }
            }
        }
    }

    private func scheduleV4RealtimeRefresh(for partyID: UUID) {
        guard v4RealtimePartyIDs.contains(partyID) else { return }
        v4RealtimeRefreshTasks.removeValue(forKey: partyID)?.cancel()
        v4RealtimeRefreshTasks[partyID] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled,
                  let self,
                  self.v4RealtimePartyIDs.contains(partyID)
            else { return }
            self.refreshV4PartyObservation(partyID)
        }
    }

    private func refreshV4PartyObservation(_ partyID: UUID) {
        guard accountState == .linked, permitsNightFlockNetwork, let service else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        let cursor = selectedV4Party?.summary.partyID == partyID ? selectedV4Party?.cursor : nil
        Task { [weak self] in
            guard let self else { return }
            do {
                let response = try await service.stateV4Party(partyID: partyID, cursor: cursor)
                guard self.permitsNightFlockNetwork,
                      self.v4RealtimePartyIDs.contains(partyID),
                      self.isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                self.applyV4PartyDetail(response.party, select: false)
                self.applyPendingV4GrantsIfPossible()
                // Sanitized party signals also cover join/leave, renames and
                // invitation/profile changes, so refresh the list projection
                // rather than leaving Home/Farm with an old summary.
                let list = try await service.stateV4List()
                guard self.permitsNightFlockNetwork,
                      self.isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                self.v4ListState = list
                self.synchronizeV4RealtimeSubscriptions(with: list.parties)
                self.adoptServerV4ProfileIfSafe(list.profile)
                self.v4GrantInbox = list.grantInbox
                self.applyPendingV4GrantsIfPossible()
            } catch {
                // A Realtime prompt cannot replace the main request/recovery
                // presentation; the next foreground or action refresh heals it.
            }
        }
    }

    func stopV4RealtimePresentation() {
        v4RealtimeRefreshTasks.values.forEach { $0.cancel() }
        v4RealtimeRefreshTasks = [:]
        v4RealtimeSetupTasks.values.forEach { $0.cancel() }
        v4RealtimeSetupTasks = [:]
        v4RealtimePartyIDs = []
        v4ObservedPartyDetails = [:]
        Task { [service] in
            await service?.stopV4Realtime()
        }
    }

    func adoptServerV4ProfileIfSafe(_ serverProfile: CountingSheepUserProfile?) {
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
