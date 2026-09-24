import Foundation

extension NightFlockViewModel {
    func changeGlobalCampfireChannel(_ channelID: Int) {
        guard !globalCampfireChannelChanging, let state = globalCampfireState,
              state.channels?.contains(where: { $0.id == channelID }) == true else { return }
        globalCampfireChannelMessage = nil
        guard let source = state.ownSourceID, let agreement = state.agreement else {
            refreshGlobalCampfire(channelID: channelID)
            return
        }
        guard let owner = pastureOwner, permitsNightFlockNetwork, let service else { return }
        globalCampfireChannelChanging = true
        let generation = localSocialGeneration, epoch = transportRecoveryEpoch
        var command = GlobalCampfireCommand(command: "channel")
        command.channelID = channelID; command.sourceID = source; command.agreementID = agreement.id
        Task {
            defer { if pastureOwner == owner, isCurrentTransportTask(generation: generation, epoch: epoch) { globalCampfireChannelChanging = false } }
            do {
                let response = try await service.sendGlobalCampfire(command, ownerID: owner)
                guard pastureOwner == owner, permitsNightFlockNetwork,
                      isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                if response.accepted {
                    refreshGlobalCampfire(channelID: response.channelID ?? channelID)
                } else {
                    globalCampfireChannelMessage = response.channelFull == true
                        ? "That channel just filled up. Choose another spot."
                        : "Your shared session changed. Refresh and choose a channel again."
                    refreshGlobalCampfire()
                }
            } catch {
                guard pastureOwner == owner, isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                globalCampfireChannelMessage = "The channel change couldn’t be confirmed. Refresh to see your current spot."
                refreshGlobalCampfire(channelID: 0)
            }
        }
    }

    func refreshGlobalCampfire(gathering: String? = nil, cursor: UUID? = nil, channelID: Int? = nil) {
        guard restoreCampfireVisibility(), permitsNightFlockNetwork, let service, let owner = pastureOwner else { return }
        // Repeated appearance/foreground callbacks must not supersede the same
        // request indefinitely. A different filter can still replace it.
        guard !globalCampfireLoading || cursor != nil
            || (gathering != nil && gathering != globalCampfireGathering)
            || (channelID != nil && channelID != globalCampfireChannel) else { return }
        if let gathering, gathering != globalCampfireGathering {
            globalCampfireGathering = gathering; globalCampfireState = nil
        }
        if let channelID, channelID != globalCampfireChannel {
            globalCampfireChannel = channelID; globalCampfireState = nil
        }
        let requestedGathering = globalCampfireGathering
        let requestedChannel = globalCampfireChannel
        let attempt = UUID(), generation = localSocialGeneration, epoch = transportRecoveryEpoch
        globalCampfireRequestID = attempt; globalCampfireLoading = true
        Task {
            defer { if globalCampfireRequestID == attempt { globalCampfireLoading = false } }
            do {
                let response = try await service.globalCampfireState(gathering: requestedGathering, cursor: cursor, channelID: requestedChannel)
                guard globalCampfireRequestID == attempt, pastureOwner == owner, permitsNightFlockNetwork,
                      isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                guard let state = response.state, state.version == 1 else {
                    globalCampfireState = nil; globalCampfireFailure = .unsupported
                    return
                }
                var filtered = state
                let blocked = Set(campfireDocument.commands.filter { $0.command == "block" }.compactMap(\.targetID))
                filtered.participants.removeAll { blocked.contains($0.profileID) }
                globalCampfireState = filtered; globalCampfireFailure = state.available ? nil : .unavailable
                if let channelID = state.channelID { globalCampfireChannel = channelID }
                var document = campfireDocument
                document.publicAgreement = state.agreement
                if let name = state.publicName { document.publicName = name }
                if let appearance = state.appearance { document.appearance = appearance }
                let repaired = document.repairWithdrawals(for: state)
                if saveCampfireDocument(document) {
                    globalCampfireAttempted.subtract(repaired)
                    drainGlobalCampfireCommands()
                    onCampfireAuthorityAvailable?()
                }
            } catch {
                guard globalCampfireRequestID == attempt, pastureOwner == owner,
                      isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                globalCampfireFailure = error is DecodingError ? .unsupported : GlobalCampfireIssue.forHTTPStatus((error as? NightFlockRemoteError)?.statusCode ?? 0)
                // An old snapshot is no longer evidence of current presence.
                globalCampfireState = nil
            }
        }
    }

    func enqueueGlobalCampfire(_ command: GlobalCampfireCommand) {
        guard restoreCampfireVisibility(), permitsNightFlockNetwork else { return }
        var document = campfireDocument
        guard document.enqueue(command) else {
            campfireVisibilityMessage = "Your changes are waiting to sync. Retry before sending more."; return
        }
        guard saveCampfireDocument(document) else { return }
        drainGlobalCampfireCommands()
    }

    func drainGlobalCampfireCommands(retry: Bool = false) {
        guard restoreCampfireVisibility(), globalCampfireSendID == nil, permitsNightFlockNetwork,
              let owner = pastureOwner, let service else { return }
        if retry { globalCampfireAttempted = [] }
        let commands = campfireDocument.commands.filter { !globalCampfireAttempted.contains($0.id) }
        guard !commands.isEmpty else { return }
        let generation = localSocialGeneration, epoch = transportRecoveryEpoch
        let sendID = UUID()
        globalCampfireSendID = sendID
        Task {
            defer {
                if globalCampfireSendID == sendID {
                    globalCampfireSendID = nil
                    if pastureOwner == owner && isCurrentTransportTask(generation: generation, epoch: epoch) { drainGlobalCampfireCommands() }
                }
            }
            for command in commands {
                guard pastureOwner == owner, permitsNightFlockNetwork,
                      isCurrentTransportTask(generation: generation, epoch: epoch),
                      campfireDocumentOwner == owner else { return }
                guard campfireDocument.commands.contains(where: { $0.id == command.id }) else { continue }
                globalCampfireAttempted.insert(command.id)
                do {
                    let response = try await service.sendGlobalCampfire(command, ownerID: owner)
                    guard pastureOwner == owner, permitsNightFlockNetwork,
                          isCurrentTransportTask(generation: generation, epoch: epoch), campfireDocumentOwner == owner else { return }
                    if !response.accepted, response.retryable == false, command.command != "agreement" {
                        var document = campfireDocument
                        document.commands.removeAll { $0.id == command.id }
                        guard saveCampfireDocument(document) else { return }
                        if command.command == "profile" { resolvedCampfireProfile = command }
                        campfireVisibilityMessage = command.command == "profile"
                            ? "Your profile couldn’t be shared. Check for unusually long tasks or routines, then save visibility again."
                            : "That session or action is no longer available. Refresh the campfire to see what’s current."
                        refreshGlobalCampfire()
                        continue
                    }
                    guard response.accepted else { throw NightFlockServiceError.unsupportedResponse }
                    var document = campfireDocument
                    document.commands.removeAll { $0.id == command.id }
                    if command.command == "profile" { resolvedCampfireProfile = command }
                    if let agreement = response.agreement { document.publicAgreement = agreement }
                    if let agreement = response.agreement, response.conflict != true, command.enabled == true {
                        document.bindPublicAgreement(commandID: command.id, agreement: agreement)
                    }
                    guard saveCampfireDocument(document) else { return }
                    campfireVisibilityMessage = response.conflict == true
                        ? "Sharing changed on another device. Review visibility before sharing again." : nil
                    if response.conflict == true { globalCampfireState = nil }
                    refreshGlobalCampfire(channelID: response.channelID)
                } catch {
                    guard pastureOwner == owner, isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                    campfireVisibilityMessage = command.command == "agreement" && command.enabled == false
                        ? "Removal is waiting to sync. The last shared session may remain until it expires."
                        : "Your Campfire change is waiting to sync. Your timer keeps running."
                    return
                }
            }
        }
    }

    func publishGlobalCampfireSession(_ run: FocusRun, ended: Bool) {
        guard restoreCampfireVisibility(), permitsNightFlockNetwork,
              CampfireRules.permitsOwner(captured: run.nightWatchPlan?.campfireOwnerID, current: pastureOwner),
              let plan = run.nightWatchPlan, let expires = CampfireRules.end(for: run),
              let agreement = campfireDocument.publicAgreement else { return }
        let selection = campfireSelection(for: run)
        let explicitlyChanged = campfireDocument.runSelections[run.id] != nil
        let receipt = explicitlyChanged ? selection.publicAgreementID : plan.publicCampfireAgreementID
        guard CampfireVisibilityRules.permitsPublicPublication(visibility: selection.visibility, capturedAgreement: receipt, current: agreement),
              !campfireDocument.commands.contains(where: { $0.command == "agreement" }) else { return }
        let start = explicitlyChanged ? selection.publicStartedAt ?? expires : CampfireVisibilityRules.sharingStart(requested: run.startedAt, acceptedAt: agreement.acceptedAt)
        guard start >= agreement.acceptedAt, start < expires, expires > Date() || ended else { return }
        if !ended, agreement.version == 2, let profile = makeCampfireProfile?(run),
           (profile != resolvedCampfireProfile?.profile || resolvedCampfireProfile?.sourceID != run.id || resolvedCampfireProfile?.agreementID != agreement.id),
           !campfireDocument.commands.contains(where: { $0.command == "profile" && $0.profile == profile && $0.agreementID == agreement.id && $0.sourceID == run.id }) {
            var update = GlobalCampfireCommand(command: "profile")
            update.agreementID = agreement.id; update.sourceID = run.id; update.profile = profile; update.capturedAt = CampfireVisibilityRules.sharingStart(requested: Date(), acceptedAt: agreement.acceptedAt)
            enqueueGlobalCampfire(update)
        }
        if !ended, globalCampfireState?.ownSourceID == run.id { return }
        var command = GlobalCampfireCommand(command: "publish")
        command.id = NightFlockV4Idempotency.command("global-campfire-\(agreement.id)-\(ended)-channel-\(globalCampfireChannel)", seed: run.id)
        command.agreementID = agreement.id; command.sourceID = run.id
        command.kind = plan.role == .primarySleepBookend ? .windDown : .phoneAway
        command.activity = plan.role == .additionalQuiet ? plan.campfireActivity ?? .phoneAway : nil
        command.startedAt = start; command.expiresAt = expires; command.ended = ended
        command.channelID = globalCampfireChannel
        enqueueGlobalCampfire(command)
    }

    func globalCampfireAction(_ action: String, participant: GlobalCampfireParticipant, reason: String? = nil) {
        guard globalCampfireState?.isSupported == true, !participant.isMe else { return }
        var command = GlobalCampfireCommand(command: action)
        command.targetID = action == "encourage" ? participant.id : participant.profileID
        command.reason = reason
        enqueueGlobalCampfire(command)
        if action == "block" {
            globalCampfireState?.participants.removeAll { $0.profileID == participant.profileID }
        }
    }
}
