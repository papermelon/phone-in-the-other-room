import Foundation

extension FocusRunViewModel {
    /// Update a future automatic admission only when its captured audience has
    /// changed. Repeated presence reads must not reinstall the shield schedule.
    func reconcileScheduledCampfireAudience() {
        guard !isRunning, let schedule = persistence.automaticWindDownSchedule else { return }
        let social = nightFlockViewModel
        _ = social.restoreCampfireVisibility()
        let visibility = social.campfireVisibility
        let parties = visibility == .off ? [] : social.selectedCampfirePartyIDs.filter { social.campfireAgreement(partyID: $0) != nil }
        let receipt = visibility == .global && social.campfireStartIsReady ? social.campfireDocument.publicAgreement?.id : nil
        let intentions = parties.compactMap { id -> CampfireSharedIntention? in
            guard let agreement = social.campfireAgreement(partyID: id), agreement.version == 2 else { return nil }
            return .init(partyID: id, agreementID: agreement.id, text: "", announceStart: true, asksForBuddy: false)
        }
        guard schedule.plan.campfireVisibility != visibility
            || schedule.plan.campfireOwnerID != social.campfireOwnerForNewRun
            || schedule.plan.publicCampfireAgreementID != receipt
            || Set(schedule.plan.campfirePartyIDs ?? []) != Set(parties)
            || schedule.plan.campfireIntentions != intentions else { return }
        scheduleAutomaticWindDownIfNeeded()
    }
}

extension FocusRunViewModel {
    func campfireProfileSnapshot(for run: FocusRun) -> CampfireProfileSnapshot? {
        let owner = nightFlockViewModel.campfireOwnerForNewRun
        guard CampfireRules.permitsOwner(captured: run.nightWatchPlan?.campfireOwnerID, current: owner) else { return nil }
        let personal = (try? persistence.personalShieldSessions())?.first { $0.id == run.id }
        let tasks = personal?.steps.map(\.title) ?? run.nightWatchPlan?.eveningRoutine.map(\.title) ?? []
        let history = nightWatchRecords.filter { $0.isPractice != true && $0.plan.campfireOwnerID == owner }.sorted { $0.startedAt > $1.startedAt }.map {
            let kind = $0.role == .primarySleepBookend ? "Wind Down" : "Phone Away"
            return "\(kind) · \(OllieFormat.dateAndTime($0.startedAt)) – \(OllieFormat.dateAndTime(($0.endedAt ?? $0.plan.protectedUntil))) · \($0.outcome == .endedEarly ? "Ended early" : $0.outcome == .completed ? "Completed" : "Active")"
        }
        let routines = windDownRoutines.map {
            "\($0.userFacingTitle) · \(String(format: "%02d:%02d", $0.start.hour, $0.start.minute))–\(String(format: "%02d:%02d", $0.end.hour, $0.end.minute)) · \($0.weekdays.map { Calendar.current.shortWeekdaySymbols[min(7, max(1, $0)) - 1] }.joined(separator: ", "))\($0.enabled ? "" : " · Off")"
        }
        var appearance = PublicCampfireAppearance(persistence.userProfile.presentation)
        appearance.skinToneID = farmState.shepherd.skinTone.rawValue
        appearance.hairStyleID = farmState.shepherd.hairStyle.rawValue
        appearance.shepherdOutfitID = farmState.shepherd.sharedOutfitID
        appearance.shepherdAccessoryID = farmState.shepherd.accessoryItemID ?? "none"
        appearance.headShapeID = farmState.shepherd.headShape.rawValue
        appearance.shepherdShirtID = CountingSheepPublicPresentationAllowlist.shepherdShirtIDs.contains(farmState.shepherd.shirtItemID ?? "") ? farmState.shepherd.shirtItemID : "none"
        appearance.shepherdOuterwearID = farmState.shepherd.outfitItemID == "shepherd_open_moss_coat" ? "shepherd_open_moss_coat" : "none"
        appearance.ollieCoatID = farmState.equipment.ollieCoat.rawValue
        appearance = appearance.forServer(supportsWardrobe: nightFlockViewModel.globalCampfireState?.appearanceVersion == 1)
        let steps = nightWatchPreferences.eveningRoutine.map { "Evening · \($0.title)" }
            + nightWatchPreferences.morningRoutine.map { "Morning · \($0.title)" }
        var session = ["\(run.nightWatchPlan?.role == .primarySleepBookend ? "Wind Down" : "Phone Away") · \(run.state == .completed ? "Completed" : run.state == .endedEarly ? "Ended early" : "Active")",
            "Started \(OllieFormat.dateAndTime(run.startedAt))",
            "Planned end \(OllieFormat.dateAndTime((CampfireRules.end(for: run) ?? run.startedAt)))"]
        if let plan = run.nightWatchPlan, plan.role == .primarySleepBookend {
            session.append("Bedtime \(OllieFormat.dateAndTime(plan.intendedBedtime))")
            session.append("Wake time \(OllieFormat.dateAndTime(plan.wakeTime))")
        }
        session.append("Times in \(TimeZone.current.identifier)")
        return .init(session: session, tasks: tasks, routines: routines + steps,
            intention: run.nightWatchPlan?.campfireIntentions?.first(where: { !$0.text.isEmpty })?.text ?? personal?.goal ?? personalisation.goal?.wording ?? "",
            history: history, partyNames: nightFlockViewModel.slumberParties.map(\.name),
            inventory: farmState.ownedShopItemIDs,
            sheep: farmState.sheep.map { .init(id: $0.id, definitionID: $0.definitionID, name: $0.displayName,
                status: $0.status.rawValue, cosmetics: $0.equippedCosmeticIDs) },
            appearance: appearance,
            decorations: Dictionary(uniqueKeysWithValues: farmState.equipment.decorationPlacements.map { ($0.key.rawValue, $0.value) }),
            collectibles: Dictionary(uniqueKeysWithValues: farmState.equipment.collectiblePlacements.map { ($0.key.rawValue, $0.value) }),
            ollieAccessory: farmState.equipment.ollieAccessoryItemID ?? "none", barnCapacityLevel: farmState.barnCapacityLevel)
    }
}
