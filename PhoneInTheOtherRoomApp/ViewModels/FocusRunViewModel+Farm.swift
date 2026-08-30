import Foundation

@MainActor
extension FocusRunViewModel {
    var userProfile: CountingSheepUserProfile {
        persistence.userProfile
    }

    var shepherdDisplayName: String {
        userProfile.displayName
    }

    var selectedSocialAvatarID: String {
        userProfile.presentation.avatarID
    }

    var availableSocialAvatarIDs: [String] {
        SocialAvatarRules.availableAvatarIDs(
            discoveries: coordinator.farmState.discoveries
        )
    }

    var socialAvatarSharingAvailable: Bool {
        nightFlockViewModel.v4ListState?.supportsProfileAvatar == true
    }

    /// Stores the explicit choice independently from the Farm's featured sheep.
    /// A discovered sheep stays eligible after it leaves the active flock.
    @discardableResult
    func selectSocialAvatar(_ avatarID: String) -> String? {
        guard SocialAvatarRules.canSelect(
            avatarID,
            discoveries: coordinator.farmState.discoveries
        ) else {
            return "Choose your Shepherd, Ollie, or a sheep Ollie has already found."
        }
        var profile = persistence.userProfile
        if profile.presentation.avatarID != avatarID {
            profile.presentation.avatarID = avatarID
            persistence.userProfile = profile
        }
        persistence.hasExplicitSocialAvatarSelection = true
        if socialAvatarSharingAvailable {
            if nightFlockViewModel.v4ListState?.profile?.presentation.avatarID == avatarID {
                socialAvatarSyncMessage = "Shared with Slumber Party."
            } else {
                socialAvatarSyncMessage = "Saved on this iPhone. Slumber Party will refresh this choice when it can."
                synchronizeSlumberPartyProfile { [weak self] result in
                    guard let self, self.selectedSocialAvatarID == avatarID else { return }
                    switch result {
                    case .success(true):
                        self.socialAvatarSyncMessage = "Shared with Slumber Party."
                    case .success(false):
                        self.socialAvatarSyncMessage = "Saved on this iPhone. Slumber Party has not confirmed it yet."
                    case .failure:
                        self.socialAvatarSyncMessage = "Saved on this iPhone. Slumber Party could not update it yet."
                    }
                }
            }
        } else {
            socialAvatarSyncMessage = "Saved on this iPhone. It will share when your Slumber Party service supports avatars."
        }
        objectWillChange.send()
        return nil
    }

    /// Returns inline feedback when the name was not changed, keeping the
    /// editor gentle without presenting a punitive alert.
    @discardableResult
    func saveShepherdDisplayName(_ proposedName: String, at date: Date? = nil) -> String? {
        let current = persistence.userProfile
        let decision = CountingSheepDisplayNameChangeRules.decision(
            current: current,
            proposedName: proposedName,
            now: date ?? nowProvider()
        )

        switch decision {
        case .accepted:
            persistence.userProfile = CountingSheepDisplayNameChangeRules.applying(
                decision,
                to: current
            )
            synchronizeSlumberPartyProfile()
            objectWillChange.send()
            return nil
        case let .noChange(normalizedName):
            return "Ollie already knows you as \(normalizedName)."
        case .invalid(.tooShort):
            return "Try a name with at least \(CountingSheepDisplayName.minimumLength) characters."
        case .invalid(.tooLong):
            return "Try a name with no more than \(CountingSheepDisplayName.maximumLength) characters."
        case .invalid(.unsupportedCharacter):
            return "Names can use letters, numbers, spaces, apostrophes, and dashes."
        case .changeLimitReached:
            return "You can choose a new name again after one of your recent changes has had time to rest."
        }
    }

    var pastureSceneSnapshot: PastureSceneSnapshot? {
        persistence.farmPastureSceneSnapshot
    }

    func persistPastureSceneSnapshot(_ snapshot: PastureSceneSnapshot) {
        persistence.farmPastureSceneSnapshot = snapshot
    }

    func shearFarmSheep(_ sheepID: UUID) {
        var didShear = false
        mutateFarm { state in
            let amount = try state.shear(
                sheepID: sheepID,
                protectedNightCount: coordinator.progress.totalCompletedRuns
            )
            didShear = true
            return "+\(amount) wool. The fleece will grow back over more Wind Downs."
        }
        if didShear {
            recordFirstRunFarmAction(.sheared)
        }
    }

    func tradeFarmSheep(_ sheepID: UUID) {
        mutateFarm { state in
            let amount = try state.tradeToAnotherFarm(
                sheepID: sheepID,
                protectedNightCount: coordinator.progress.totalCompletedRuns
            )
            return "+\(amount) wool. This sheep has moved to another farm. Its story stays in the Search Journal."
        }
    }

    func welcomePendingFarmSheep(_ sheepID: UUID) {
        mutateFarm { state in
            try state.welcomePending(sheepID: sheepID)
            return "The Barn door is open. Your new sheep is in the pasture."
        }
    }

    func toggleFarmSheepFavorite(_ sheepID: UUID) {
        mutateFarm { state in
            try state.toggleFavorite(sheepID: sheepID)
            return nil
        }
    }

    func purchaseFarmShopItem(_ itemID: String) {
        mutateFarm { state in
            try state.purchase(
                itemID: itemID,
                qualifyingWindDowns: coordinator.sheepSearchState.completedWindDownSearchCount
            )
            let title = FarmShopCatalog.item(for: itemID)?.title ?? "Farm Shop find"
            return "\(title) is yours and ready at the Farm."
        }
    }

    func equipFarmShopItem(_ itemID: String) {
        mutateFarm { state in
            try state.equip(itemID: itemID)
            let title = FarmShopCatalog.item(for: itemID)?.title ?? "Farm Shop find"
            return "\(title) is now part of the Farm."
        }
    }

    func wearOllieAccessory(_ itemID: String) {
        mutateFarm { state in
            try state.wearOllieAccessory(itemID: itemID)
            return FarmShopCatalog.item(for: itemID).map { "Ollie is wearing \($0.title)." }
        }
    }

    func takeOffOllieAccessory(_ itemID: String) {
        mutateFarm { state in
            try state.takeOffOllieAccessory(itemID: itemID)
            return "Ollie is ready for the next search."
        }
    }

    func wearShepherdOutfit(_ itemID: String) {
        mutateFarm { state in
            try state.wearShepherdOutfit(itemID: itemID)
            return FarmShopCatalog.item(for: itemID).map { "\($0.title) is ready for the next search." }
        }
    }

    func takeOffShepherdOutfit(_ itemID: String) {
        mutateFarm { state in
            try state.takeOffShepherdOutfit(itemID: itemID)
            return "Your Shepherd’s coat is back in the wardrobe."
        }
    }

    func wearShepherdAccessory(_ itemID: String) {
        mutateFarm { state in
            try state.wearShepherdAccessory(itemID: itemID)
            return FarmShopCatalog.item(for: itemID).map { "Your Shepherd is wearing \($0.title)." }
        }
    }

    func takeOffShepherdAccessory(_ itemID: String) {
        mutateFarm { state in
            try state.takeOffShepherdAccessory(itemID: itemID)
            return "Your Shepherd’s field gear is back in the wardrobe."
        }
    }

    func placeFarmDecoration(_ itemID: String) {
        mutateFarm { state in
            try state.placeFarmDecoration(itemID: itemID)
            return FarmShopCatalog.item(for: itemID).map { "\($0.title) has a place in the pasture." }
        }
    }

    func putAwayFarmDecoration(_ itemID: String) {
        mutateFarm { state in
            try state.putAwayFarmDecoration(itemID: itemID)
            return "The decoration is safe in the Farm store room."
        }
    }

    func displayFarmCollectible(_ itemID: String) {
        mutateFarm { state in
            try state.displayCollectible(itemID: itemID)
            return FarmShopCatalog.item(for: itemID).map { "\($0.title) is on display by the Barn." }
        }
    }

    func storeFarmCollectible(_ itemID: String) {
        mutateFarm { state in
            try state.storeCollectible(itemID: itemID)
            return "The keepsake is tucked safely away."
        }
    }

    func trackSheepDefinition(_ definitionID: String?) {
        var didTrack = false
        mutateFarm { state in
            state.setTrackedSheep(definitionID)
            didTrack = definitionID != nil
            guard let definitionID,
                  let sheep = SheepCatalog.definition(for: definitionID) else {
                return "Ollie will watch for any missing sheep."
            }
            return "Ollie will watch more closely for \(sheep.name)—without a guarantee."
        }
        if didTrack {
            recordFirstRunFarmAction(.choseTrackedSheep)
            recordFirstRunFarmAction(.visitedSearch)
        }
    }

    func setShepherdSkinTone(_ skinTone: ShepherdSkinTone) {
        mutateFarm { state in
            state.setShepherdSkinTone(skinTone)
            return nil
        }
    }

    func setShepherdHairStyle(_ hairStyle: ShepherdHairStyle) {
        mutateFarm { state in
            state.setShepherdHairStyle(hairStyle)
            return nil
        }
    }

    func applyWindDownStartingPoint(_ answers: WindDownProfileAnswer, at date: Date = Date()) {
        let recommendation = WindDownProfileMapper.recommendation(for: answers)
        let record = WindDownProfileRecord(
            answers: answers,
            recommendation: recommendation,
            createdAt: persistence.windDownProfileRecord?.createdAt ?? date,
            updatedAt: date
        )
        persistence.windDownProfileRecord = record
    }

    var claimedWelcomeGiftItemID: String? {
        persistence.welcomeRewardLedger.claimedWearableGrant?.itemID
    }

    var existingWelcomeGiftItemID: String? {
        persistence.welcomeRewardLedger.grant(of: .profileWearable)?.itemID
    }

    @discardableResult
    func claimWelcomeGift(_ itemID: String, wearNow: Bool, at date: Date = Date()) -> Bool {
        do {
            let result = try WelcomeRewardEngine.claimWelcomeGift(
                itemID: itemID,
                wearNow: wearNow,
                farm: coordinator.farmState,
                search: coordinator.sheepSearchState,
                ledger: persistence.welcomeRewardLedger,
                now: date
            )
            coordinator.farmState = result.farm
            persistence.farmState = result.farm
            persistence.welcomeRewardLedger = result.ledger
            synchronizeSlumberPartyProfile()
            return true
        } catch let error as FarmActionError {
            farmActionMessage = farmMessage(for: error)
        } catch {
            farmActionMessage = "The Farm could not save that change. Please try once more."
        }
        return false
    }

    func claimPendingWelcomeWearable() {
        do {
            let result = try WelcomeRewardEngine.claimWearable(
                farm: coordinator.farmState,
                search: coordinator.sheepSearchState,
                ledger: persistence.welcomeRewardLedger
            )
            coordinator.farmState = result.farm
            persistence.farmState = result.farm
            persistence.welcomeRewardLedger = result.ledger
            synchronizeSlumberPartyProfile()
            if let itemID = result.ledger.claimedWearableGrant?.itemID,
               let title = FarmShopCatalog.item(for: itemID)?.title {
                farmActionMessage = "\(title) is waiting. Ollie can help you put it on."
            } else {
                farmActionMessage = "The welcome gift is yours. Put it on the shepherd when you are ready."
            }
            recordFirstRunFarmAction(.claimedWearable)
        } catch let error as FarmActionError {
            farmActionMessage = farmMessage(for: error)
        } catch {
            farmActionMessage = "The Farm could not save that change. Please try once more."
        }
    }

    func equipPendingWelcomeWearable() {
        do {
            let result = try WelcomeRewardEngine.equipWearable(
                farm: coordinator.farmState,
                search: coordinator.sheepSearchState,
                ledger: persistence.welcomeRewardLedger
            )
            coordinator.farmState = result.farm
            persistence.farmState = result.farm
            synchronizeSlumberPartyProfile()
            if let itemID = result.ledger.claimedWearableGrant?.itemID,
               let title = FarmShopCatalog.item(for: itemID)?.title {
                farmActionMessage = "\(title) is on the shepherd."
            } else {
                farmActionMessage = "Your Shepherd is wearing the welcome gift."
            }
            recordFirstRunFarmAction(.equippedWearable)
        } catch let error as FarmActionError {
            farmActionMessage = farmMessage(for: error)
        } catch {
            farmActionMessage = "The Farm could not save that change. Please try once more."
        }
    }

    func clearFarmActionMessage() {
        farmActionMessage = nil
    }

    func applySlumberPartyGrants(_ grants: [NightFlockRewardGrant]) {
        guard !grants.isEmpty else { return }
        let result = NightFlockRewardEngine.apply(
            grants: grants,
            farm: coordinator.farmState,
            search: coordinator.sheepSearchState,
            ledger: persistence.nightFlockRewardLedger,
            protectedNightCount: max(1, coordinator.progress.totalCompletedRuns)
        )
        coordinator.farmState = result.farm
        coordinator.sheepSearchState = result.search
        if let outcome = result.outcome {
            coordinator.latestSheepSearchOutcome = outcome
        }
        persistence.farmState = result.farm
        persistence.sheepSearchState = result.search
        persistence.nightFlockRewardLedger = result.ledger
        synchronizeSlumberPartyProfile()
        if !result.applied.isEmpty {
            nightFlockViewModel.acknowledgeAppliedGrants(result.applied.map(\.id))
            if result.applied.contains(where: { $0.rewardKind == .sheepSearch }) {
                farmActionMessage = "A Slumber Party gift reached the Farm."
            } else if result.applied.contains(where: { $0.rewardKind == .itemOrWool }) {
                farmActionMessage = "A small Slumber Party keepsake arrived."
            } else if result.applied.contains(where: { $0.woolAmount > 0 }) {
                farmActionMessage = "A little wool arrived from Slumber Party."
            }
        }
    }

    /// Reuses the established local Farm reward ledger before returning IDs to
    /// schema four for acknowledgement. Party deletion cannot erase an inbox
    /// item before this local idempotency check has happened.
    func applyV4SlumberPartyGrants(_ inbox: [NightFlockV4GrantInboxItem]) -> [UUID] {
        let grants = inbox.compactMap(NightFlockV4GrantAdapter.legacyGrant)
        guard !grants.isEmpty else { return [] }
        let result = NightFlockRewardEngine.apply(
            grants: grants,
            farm: coordinator.farmState,
            search: coordinator.sheepSearchState,
            ledger: persistence.nightFlockRewardLedger,
            protectedNightCount: max(1, coordinator.progress.totalCompletedRuns)
        )
        coordinator.farmState = result.farm
        coordinator.sheepSearchState = result.search
        if let outcome = result.outcome { coordinator.latestSheepSearchOutcome = outcome }
        persistence.farmState = result.farm
        persistence.sheepSearchState = result.search
        persistence.nightFlockRewardLedger = result.ledger
        synchronizeSlumberPartyProfile()
        let appliedWool = result.applied
            .filter { $0.rewardKind == .wool }
            .reduce(0) { $0 + max(0, $1.woolAmount) }
        if appliedWool > 0 {
            farmActionMessage = appliedWool == 1
                ? "1 wool came home from Slumber Party."
                : "\(appliedWool) wool came home from Slumber Party."
        } else if !result.applied.isEmpty {
            farmActionMessage = "A Slumber Party update reached your Farm."
        }
        // An acknowledgement may have failed after this durable ledger write.
        // Return prior and newly applied inbox IDs so the v4 ack command can
        // converge without duplicating a Farm reward.
        return inbox.compactMap { item in
            result.ledger.hasApplied(item.grantID) ? item.grantID : nil
        }
    }

    func publishSlumberPartyOutcome(for run: FocusRun) {
        // v4 records the factual local ritual independently of legacy goal
        // sharing and of Farm settlement. It never delays either path.
        nightFlockViewModel.publishV4TerminalActivity(for: run)
        publishSharedHabitsOutcome(for: run)
        if run.nightWatchPlan?.role == .additionalQuiet, run.completedSuccessfully {
            let metrics = slumberPartyMetrics(for: run)
            nightFlockViewModel.sharePhoneAwayMetrics(metrics, for: run, at: nowProvider())
            return
        }
        // Independent Screen-Free Morning occurrences never enter the social
        // boundary. A primary Wind Down is eligible only after its authorized
        // terminal delivery has been journaled.
        guard run.isProgressionEligibleNightWatch,
              run.completedSuccessfully,
              persistence.windDownMorningSettlementJournal.benefit(for: run.id)?.isDelivered == true else {
            return
        }
        let metrics = slumberPartyMetrics(for: run)
        nightFlockViewModel.handleTerminalRun(run, metrics: metrics)
    }

    /// Decision restoration and agreement restoration race independently on a
    /// relaunch. Re-offer the bounded factual terminal records whenever either
    /// becomes available; the existing source IDs and revisioned outboxes make
    /// repeated callbacks converge instead of duplicating activity or receipts.
    func replayRestoredSharedPrimaryTerminalOutcomes() {
        let decisions = nightFlockViewModel.primaryRunSharingDecisions
        var runsByID = Dictionary(
            uniqueKeysWithValues: NightFlockPrimaryRunTerminalReplayRules
                .recordsEligibleForReplay(
                    from: persistence.nightWatchHistory.records,
                    decisions: decisions
                )
                .map { ($0.id, terminalReplayRun(from: $0)) }
        )
        if let activeRun,
           activeRun.nightWatchPlan?.role == .primarySleepBookend,
           (activeRun.state == .completed || activeRun.state == .endedEarly),
           decisions[activeRun.id]?.allowsSharing == true,
           activeRun.isPractice == false {
            runsByID[activeRun.id] = activeRun
        }
        for run in runsByID.values.sorted(by: { lhs, rhs in
            if lhs.startedAt != rhs.startedAt { return lhs.startedAt < rhs.startedAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }) {
            publishSlumberPartyOutcome(for: run)
        }
    }

    private func terminalReplayRun(from record: NightWatchRecord) -> FocusRun {
        let terminalAt = record.endedAt ?? record.updatedAt
        var run = FocusRun(
            id: record.id,
            plannedDurationSeconds: max(
                0,
                record.plan.protectedUntil.timeIntervalSince(record.startedAt)
            ),
            startedAt: record.startedAt,
            state: record.outcome == .completed ? .completed : .endedEarly,
            guardKind: record.startMethod,
            nightWatchPlan: record.plan
        )
        run.actualDurationSeconds = max(0, terminalAt.timeIntervalSince(record.startedAt))
        run.plannedEndAt = record.plan.protectedUntil
        run.endedAt = record.endedAt
        run.completedSuccessfully = record.outcome == .completed
        run.briefAccessUseCount = record.briefAccessUseCount
        run.isPractice = record.isPractice ?? false
        return run
    }

    private func slumberPartyMetrics(for run: FocusRun) -> NightFlockLocalNightMetrics {
        let isPhoneAway = run.nightWatchPlan?.role == .additionalQuiet
        let wake = run.nightWatchPlan?.wakeTime
        let sleepMinutes: Int? = {
            guard let wake else { return nil }
            return recentNightSleeps.first { summary in
                guard let date = summary.nightEndingDate ?? summary.endDate else { return false }
                return Calendar.current.isDate(date, inSameDayAs: wake)
            }.map { Int($0.durationSeconds / 60) }
        }()
        return NightFlockLocalNightMetrics(
            windDownMinutes: isPhoneAway ? 0 : run.creditedWindDownMinutes,
            phoneAwayMinutes: isPhoneAway ? run.creditedQuietMinutes : 0,
            shieldingEvidence: snapshotShieldingEvidence(),
            tuckedAway: run.phoneAwayValidatedAt != nil || run.completedSuccessfully,
            completedSuccessfully: run.completedSuccessfully && !isPhoneAway,
            sleepDurationMinutes: sleepMinutes,
            restfulness: morningCheckIn(for: wake ?? nowProvider()).restfulness
        )
    }

    func publishSlumberPartyMetricSupplement(at date: Date) {
        guard let snapshot = nightFlockViewModel.snapshot else { return }
        let sharing = snapshot.sharing
        guard sharing.shareSleepDuration || sharing.shareRestfulness else { return }
        let record = persistence.nightWatchHistory.records.first { candidate in
            Calendar.current.isDate(candidate.plan.wakeTime, inSameDayAs: date)
                && candidate.role == .primarySleepBookend
        }
        if let record,
           !nightFlockViewModel.maySharePrimaryRun(runID: record.id, startedAt: record.startedAt) {
            return
        }
        let sleepMinutes: Int? = sharing.shareSleepDuration
            ? recentNightSleeps.first { summary in
                guard let sleepDate = summary.nightEndingDate ?? summary.endDate else { return false }
                return Calendar.current.isDate(sleepDate, inSameDayAs: date)
            }.map { Int($0.durationSeconds / 60) }
            : nil
        let restfulness = sharing.shareRestfulness ? morningCheckIn(for: date).restfulness : nil
        guard sleepMinutes != nil || restfulness != nil else { return }
        let windDownMinutes = record?.creditedWindDownMinutes ?? 0
        nightFlockViewModel.shareSupplementalMetrics(
            NightFlockLocalNightMetrics(
                windDownMinutes: windDownMinutes,
                phoneAwayMinutes: 0,
                shieldingEvidence: snapshotShieldingEvidence(),
                tuckedAway: record != nil,
                completedSuccessfully: record?.outcome == .completed,
                sleepDurationMinutes: sleepMinutes,
                restfulness: restfulness
            ),
            runID: record?.id,
            at: record?.plan.wakeTime ?? date
        )
    }

    func snapshotShieldingEvidence() -> NightFlockShieldingEvidence {
        nightFlockViewModel.snapshot?.memberSetups
            .first(where: { $0.memberID == nightFlockViewModel.snapshot?.myMemberID })?
            .shieldingEvidence
            ?? nightFlockViewModel.commitmentDraft.shieldingEvidence
    }

    private func mutateFarm(_ mutation: (inout FarmState) throws -> String?) {
        var state = coordinator.farmState
        do {
            let message = try mutation(&state)
            coordinator.farmState = state
            persistence.farmState = state
            farmActionMessage = message
            synchronizeSlumberPartyProfile()
        } catch let error as FarmActionError {
            farmActionMessage = farmMessage(for: error)
        } catch {
            farmActionMessage = "The Farm could not save that change. Please try once more."
        }
    }

    /// Farm state is reduced locally into the small curated snapshot before it
    /// crosses the Slumber Party boundary. The network gate inside the view
    /// model makes this a no-op for offline or unlinked accounts.
    private func synchronizeSlumberPartyProfile(
        onAvatarSyncSettled: ((Result<Bool, Error>) -> Void)? = nil
    ) {
        nightFlockViewModel.synchronizeV4ProfileIfNeeded(
            serverProfile: nightFlockViewModel.v4Profile,
            onAvatarSyncSettled: onAvatarSyncSettled
        )
    }

    private func farmMessage(for error: FarmActionError) -> String {
        switch error {
        case .sheepNotFound:
            return "That sheep is no longer in this part of the Farm."
        case .sheepNotActive:
            return "That sheep has already moved on from the active flock."
        case .woolRegrowing:
            return "The wool is still growing. The Barn shows how many Wind Downs remain."
        case .barnFull:
            return "The Barn is full. Trade a sheep to another farm or open another pasture first."
        case .itemNotFound:
            return "That Farm Shop item is not available."
        case .itemAlreadyOwned:
            return "That item is already yours."
        case .itemNotOwned:
            return "Bring that item home from the Farm Shop before equipping it."
        case .itemNotEquippable:
            return "That Farm Shop item belongs in a different place."
        case .itemNotEquipped:
            return "That item is not wearing this slot right now."
        case .itemNotPlaced:
            return "That decoration is already in the Farm store room."
        case .itemNotDisplayed:
            return "That keepsake is already tucked away."
        case .displayFull:
            return "The keepsake shelf is full. Store one keepsake before displaying another."
        case .itemLocked:
            return "That Farm Shop find is not unlocked yet."
        case .insufficientFunds:
            return "The till needs a little more wool."
        case .upgradeOutOfSequence:
            return "Open the next pasture before expanding farther."
        case .maximumCapacityReached:
            return "All four expansions are open. The Farm can hold 60 sheep."
        case .welcomeGiftAlreadyClaimed:
            return "That welcome gift is already part of Your Shepherd."
        }
    }
}
