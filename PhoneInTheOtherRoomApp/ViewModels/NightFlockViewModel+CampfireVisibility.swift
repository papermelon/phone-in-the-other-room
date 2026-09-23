import Foundation

extension NightFlockViewModel {
    var campfireVisibility: CampfireVisibility {
        guard accountState == .linked, permitsFarmOwnerScopedSocialEffects, !campfireStorageFailed else { return .off }
        let saved = campfireDocumentOwner == pastureOwner ? campfireDocument.selection?.visibility : nil
        return CampfireVisibilityRules.initialVisibility(saved: saved, hasPrivateAgreement: hasCampfireSharing)
    }

    var selectedCampfirePartyIDs: [UUID] {
        if campfireDocumentOwner == pastureOwner, let selection = campfireDocument.selection {
            return selection.partyIDs.filter { id in slumberParties.contains { $0.partyID == id } }
        }
        return slumberParties.compactMap { campfireAgreement(partyID: $0.partyID) != nil ? $0.partyID : nil }
    }

    var campfireStartIsReady: Bool {
        if campfireVisibility == .off { return true }
        if campfireVisibility == .global && (campfireDocumentOwner != pastureOwner || campfireDocument.publicAgreement?.version != 2 || campfireDocument.publicAgreement?.enabled != true
            || campfireDocument.selection?.publicAgreementID != campfireDocument.publicAgreement?.id
            || campfireDocument.commands.contains(where: { $0.command == "agreement" })) { return false }
        if campfireVisibility == .party && selectedCampfirePartyIDs.isEmpty { return false }
        return selectedCampfirePartyIDs.allSatisfy { campfireAgreement(partyID: $0) != nil }
    }

    @discardableResult
    func restoreCampfireVisibility() -> Bool {
        guard let owner = pastureOwner, permitsFarmOwnerScopedSocialEffects, accountState == .linked else {
            clearCampfireVisibilityContext(); return false
        }
        if campfireDocumentOwner == owner { return !campfireStorageFailed }
        clearCampfireVisibilityContext()
        do {
            campfireDocument = try campfireVisibilityStore.load(owner: owner)
            campfireDocumentOwner = owner
            return true
        } catch {
            campfireDocumentOwner = owner; campfireStorageFailed = true
            campfireVisibilityMessage = "Your saved visibility couldn’t be read. Campfire sharing is paused."
            return false
        }
    }

    func clearCampfireVisibilityContext() {
        campfireDocumentOwner = nil; campfireDocument = .init(); campfireStorageFailed = false
        globalCampfireState = nil; globalCampfireFailure = nil; globalCampfireRequestID = nil
        globalCampfireLoading = false; globalCampfireAttempted = []; globalCampfireSendID = nil; campfireVisibilityMessage = nil
        globalCampfireGathering = "all"
        globalCampfireChannel = 0; globalCampfireChannelChanging = false; globalCampfireChannelMessage = nil
        resolvedCampfireProfile = nil
    }

    @discardableResult
    func saveCampfireDocument(_ value: CampfireVisibilityDocument) -> Bool {
        guard let owner = pastureOwner, owner == campfireDocumentOwner, permitsFarmOwnerScopedSocialEffects else { return false }
        do {
            try campfireVisibilityStore.save(value, owner: owner)
            campfireDocument = value
            return true
        } catch {
            campfireVisibilityMessage = "That visibility change couldn’t be saved. Please try again."
            return false
        }
    }

    /// Called only by the explicit audience confirmation, never by changing
    /// the gathering being browsed. The immutable run owner must still match.
    @discardableResult
    func chooseCampfireVisibility(_ visibility: CampfireVisibility, partyIDs: [UUID], run: FocusRun?,
                                  publicName: String, appearance: PublicCampfireAppearance) -> Bool {
        guard restoreCampfireVisibility(), permitsNightFlockNetwork else {
            campfireVisibilityMessage = "Sign in to choose who can see your Campfire session."; return false
        }
        if let run, run.nightWatchPlan?.campfireOwnerID != pastureOwner {
            campfireVisibilityMessage = "This session belongs to another account or was started before sign-in. Choose visibility for your next session."; return false
        }
        let eligible = partyIDs.filter { id in
            slumberParties.contains { $0.partyID == id } && v4ObservedPartyDetail(for: id)?.pasture?.campfire?.isSupported == true
        }
        guard visibility != .party || !eligible.isEmpty else {
            campfireVisibilityMessage = "Choose a Slumber Party to share with."; return false
        }
        guard visibility != .global || (globalCampfireState?.supportsProfiles == true && publicName == v4Profile?.displayName) else {
            campfireVisibilityMessage = "Global Campfire isn’t available right now. Your private party is still here."; return false
        }
        resolvedCampfireProfile = nil
        var document = campfireDocument
        var selection = CampfireAudienceSelection(visibility: visibility, partyIDs: visibility == .off ? [] : eligible, effectiveAt: Date())
        var agreementsToAccept: [SharedPastureCommand] = []
        selection.partyAgreementIDs = [:]; selection.partyStartedAt = [:]; selection.pendingPartyAgreements = [:]
        if visibility != .off {
            for id in eligible {
                if let agreement = campfireAgreement(partyID: id) {
                    selection.partyAgreementIDs?[id] = agreement.id
                    if let run {
                        let prior = document.runSelections[run.id]
                        let existing = v4ObservedPartyDetail(for: id)?.pasture?.campfire?.sessions.first { $0.id == run.id }
                        let priorStart = prior?.partyAgreementIDs?[id] == agreement.id ? prior?.partyStartedAt?[id] : nil
                        let originallyShared = run.nightWatchPlan?.campfireVisibility != .off
                            && run.nightWatchPlan?.campfirePartyIDs?.contains(id) == true
                            && (run.nightWatchPlan?.role != .primarySleepBookend || maySharePrimaryRun(run))
                        selection.partyStartedAt?[id] = existing?.startedAt ?? priorStart
                            ?? (originallyShared && run.startedAt >= agreement.acceptedAt
                                ? run.startedAt : CampfireVisibilityRules.sharingStart(requested: selection.effectiveAt, acceptedAt: agreement.acceptedAt))
                    }
                } else if let command = campfireSharingCommand(true, partyID: id) {
                    agreementsToAccept.append(command)
                    selection.pendingPartyAgreements?[id] = .init(commandID: command.id, memberEpochID: command.memberEpochID,
                        revision: (command.expectedRevision ?? 0) + 1)
                }
            }
        }
        // This is an explicit share-from-now override, not backfill of a plan
        // that began before a sharing agreement or under another account.
        document.runSelections = document.runSelections.filter { $0.value.effectiveAt > Date().addingTimeInterval(-8 * 86400) }
        if visibility == .global {
            document.publicName = publicName; document.appearance = appearance
            if document.publicAgreement?.version != 2 || document.publicAgreement?.enabled != true || globalCampfireState?.publicName != publicName || globalCampfireState?.appearance != appearance {
                var command = GlobalCampfireCommand(command: "agreement")
                command.consentVersion = 2
                command.enabled = true; command.expectedRevision = document.publicAgreement?.revision ?? 0
                command.publicName = publicName; command.appearance = appearance
                selection.publicAgreementCommandID = command.id
                guard document.enqueue(command) else { campfireVisibilityMessage = "Retry your pending Campfire changes before sharing globally."; return false }
            } else if let agreement = document.publicAgreement {
                selection.publicAgreementID = agreement.id
                if let run {
                    let prior = document.runSelections[run.id]
                    let wasShared = prior?.publicAgreementID == agreement.id || run.nightWatchPlan?.publicCampfireAgreementID == agreement.id
                    selection.publicStartedAt = wasShared ? prior?.publicStartedAt ?? CampfireVisibilityRules.sharingStart(requested: run.startedAt, acceptedAt: agreement.acceptedAt)
                        : CampfireVisibilityRules.sharingStart(requested: selection.effectiveAt, acceptedAt: agreement.acceptedAt)
                }
            }
        } else if document.publicAgreement?.enabled == true || document.commands.contains(where: { $0.command == "agreement" && $0.enabled == true }) {
            document.commands.removeAll { $0.command == "agreement" && $0.enabled == true }
            var command = GlobalCampfireCommand(command: "agreement")
            // Withdrawal has the same meaning on both deployed contracts.
            command.consentVersion = 1
            command.enabled = false; command.expectedRevision = document.publicAgreement?.revision ?? 0
            guard document.enqueue(command) else { campfireVisibilityMessage = "Your visibility change couldn’t be saved. Please retry."; return false }
        }
        document.selection = selection
        if let run { document.runSelections[run.id] = selection }
        guard saveCampfireDocument(document) else { return false }
        for command in agreementsToAccept { enqueuePasture(command) }
        reconcileCampfirePrivateVisibility()
        campfireVisibilityMessage = "Saving visibility… Your timer keeps running."
        drainGlobalCampfireCommands(retry: true)
        if let run { publishCampfireSession(run) }
        onCampfireAuthorityAvailable?()
        return true
    }

    func reconcileCampfirePrivateVisibility() {
        guard campfireDocumentOwner == pastureOwner, let selection = campfireDocument.selection,
              let owner = pastureOwner, let pending = try? pastureOutbox.commands(owner: owner) else { return }
        var document = campfireDocument
        for party in slumberParties {
            guard let state = v4ObservedPartyDetail(for: party.partyID)?.pasture, let agreement = state.campfire?.agreement else { continue }
            document.bindPrivateAgreement(partyID: party.partyID, memberEpochID: state.memberEpochID, agreement: agreement)
        }
        if document != campfireDocument { _ = saveCampfireDocument(document) }
        for party in slumberParties {
            guard let campfire = v4ObservedPartyDetail(for: party.partyID)?.pasture?.campfire, campfire.isSupported,
                  !pending.contains(where: { $0.partyID == party.partyID && $0.command == "setCampfireSharing" }) else { continue }
            let selected = selection.visibility != .off && selection.partyIDs.contains(party.partyID)
            // A remembered preference never accepts a new agreement or undoes
            // a withdrawal from another device. Only the confirm action enables.
            if !selected && campfire.agreement?.enabled == true { setCampfireSharing(false, partyID: party.partyID) }
        }
        if pending.isEmpty && campfireDocument.commands.isEmpty { campfireVisibilityMessage = nil }
    }

    func recordCampfireAgreementResponse(_ command: SharedPastureCommand, conflicted: Bool) -> Bool {
        guard command.command == "setCampfireSharing" else { return true }
        var document = campfireDocument
        document.acknowledgePrivateAgreement(commandID: command.id, partyID: command.partyID, conflicted: conflicted)
        return document == campfireDocument || saveCampfireDocument(document)
    }

    func campfireSelection(for run: FocusRun) -> CampfireAudienceSelection {
        if campfireDocument.selection?.visibility == .off { return .init(visibility: .off, partyIDs: [], effectiveAt: Date()) }
        if let explicit = campfireDocument.runSelections[run.id] { return explicit }
        return .init(visibility: run.nightWatchPlan?.campfireVisibility ?? .party,
                     partyIDs: run.nightWatchPlan?.campfirePartyIDs ?? selectedCampfirePartyIDs, effectiveAt: run.startedAt)
    }

    func campfireVisibilityStatus(for run: FocusRun?) -> String {
        guard accountState == .linked else { return "Sign in to share a session. Browsing never turns sharing on." }
        if let message = campfireVisibilityMessage { return message }
        guard let run, let end = CampfireRules.end(for: run), end > Date(), run.state != .endedEarly, run.state != .completed else {
            return "For your next session · \(campfireVisibility.title)"
        }
        guard run.nightWatchPlan?.campfireOwnerID == pastureOwner else { return "This session isn’t shared by this account." }
        let selection = campfireSelection(for: run)
        if selection.visibility == .off { return "Your visibility is Off. Any pending removal finishes when it syncs." }
        let confirmed = selection.partyIDs.filter { id in
            guard let party = v4ObservedPartyDetail(for: id) else { return false }
            return CampfireRules.currentSessions(party.pasture?.campfire, members: Set(party.memberships.map(\.memberID)),
                isFresh: v4ObservedPartyObservationState(for: id).permitsLivePresence, at: Date())
                .contains { $0.memberID == party.myMemberID && $0.id == run.id }
        }
        if selection.visibility == .global {
            let privateStatus = selection.partyIDs.isEmpty ? "" : " Private sharing confirmed for \(confirmed.count) of \(selection.partyIDs.count) selected parties."
            if globalCampfireFailure == nil, let state = globalCampfireState, state.isSupported,
               CampfireVisibilityRules.isFresh(observedAt: state.observedAt, now: Date()), state.ownSourceID == run.id {
                return "Your session is visible globally." + privateStatus
            }
            return "Global visibility hasn’t been confirmed. Your timer keeps running." + privateStatus
        }
        return !confirmed.isEmpty && confirmed.count == selection.partyIDs.count
            ? "Your session is visible to your selected Slumber Party audience."
            : "Party visibility hasn’t been confirmed. Your timer keeps running."
    }
}
