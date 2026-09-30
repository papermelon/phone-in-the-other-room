import Foundation

@MainActor
extension NightFlockViewModel {
    var supportsSocialInbox: Bool { v4ListState?.socialInboxVersion == 1 }

    var pendingSocialRoute: SocialNotificationRoute? {
        guard accountState == .linked, let data = UserDefaults.standard.data(forKey: SocialNotificationRoute.defaultsKey),
              let route = try? JSONDecoder().decode(SocialNotificationRoute.self, from: data), route.ownerID == pastureOwner else { return nil }
        return route
    }

    func resolveSocialRoute() async -> SocialInboxEvent? {
        guard let route = pendingSocialRoute, permitsNightFlockNetwork, let service else { return nil }
        let generation = localSocialGeneration, epoch = transportRecoveryEpoch
        do {
            let result = try await service.socialInbox(.init(action: "event", eventIDs: [route.eventID], ownerID: route.ownerID))
            guard isCurrentTransportTask(generation: generation, epoch: epoch), route.ownerID == pastureOwner else { return nil }
            UserDefaults.standard.removeObject(forKey: SocialNotificationRoute.defaultsKey)
            await markSocialEventRead(route.eventID)
            return result.events?.first
        } catch {
            guard isCurrentTransportTask(generation: generation, epoch: epoch) else { return nil }
            if case SocialInboxError.unavailable = error { UserDefaults.standard.removeObject(forKey: SocialNotificationRoute.defaultsKey) }
            socialInboxError = (error as? SocialInboxError)?.errorDescription ?? SocialInboxError.connection.errorDescription
            return nil
        }
    }

    func clearSocialInbox() {
        partySearchBusy = false; partySearchError = nil
        socialInboxTask?.cancel(); socialInboxTask = nil
        supportReplayTask?.cancel(); supportReplayTask = nil
        socialInboxEvents = []; socialUnreadCount = 0; socialPendingInvitations = 0
        socialInboxCursor = nil; socialInboxError = nil; socialInboxLoading = false
        socialPreferences = .init(); supportDetails = [:]; supportErrors = [:]; supportSending = []
    }

    func refreshSocialInbox(summary: Bool = false, nextPage: Bool = false) async {
        if let task = socialInboxTask {
            await task.value
            if summary { return }
        }
        guard supportsSocialInbox, permitsNightFlockNetwork, accountState == .linked,
              let owner = pastureOwner, let service else { return }
        let generation = localSocialGeneration, epoch = transportRecoveryEpoch
        let cursor = nextPage ? socialInboxCursor : nil
        guard !nextPage || cursor != nil else { return }
        socialInboxLoading = true; socialInboxError = nil
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                if isCurrentTransportTask(generation: generation, epoch: epoch) {
                    socialInboxLoading = false; socialInboxTask = nil
                }
            }
            do {
                let response = try await service.socialInbox(.init(action: summary ? "summary" : "inbox", cursor: cursor, ownerID: owner))
                guard !Task.isCancelled, isCurrentTransportTask(generation: generation, epoch: epoch), pastureOwner == owner else { return }
                if let rows = response.events {
                    socialInboxEvents = nextPage ? socialInboxEvents + rows.filter { row in !socialInboxEvents.contains { $0.id == row.id } } : rows
                    socialInboxCursor = response.nextCursor
                }
                socialUnreadCount = response.unreadCount ?? 0
                socialPendingInvitations = response.pendingInvitations ?? 0
                socialPreferences = response.preferences ?? .init()
            } catch {
                guard !Task.isCancelled, isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                socialInboxError = (error as? SocialInboxError)?.errorDescription ?? SocialInboxError.connection.errorDescription
            }
        }
        socialInboxTask = task
        await task.value
    }

    func loadSupportSource(_ source: SocialSource, eventID: String? = nil) async {
        guard supportsSocialInbox, permitsNightFlockNetwork, accountState == .linked,
              let owner = pastureOwner, let service else { return }
        let generation = localSocialGeneration, epoch = transportRecoveryEpoch
        do {
            let result = try await service.socialInbox(.init(action: eventID == nil ? "source" : "event", source: source,
                eventIDs: eventID.map { [$0] }, ownerID: owner))
            guard isCurrentTransportTask(generation: generation, epoch: epoch), owner == pastureOwner else { return }
            supportDetails[source] = result.detail; supportErrors[source] = nil
        } catch {
            guard isCurrentTransportTask(generation: generation, epoch: epoch), owner == pastureOwner else { return }
            supportDetails[source] = nil
            supportErrors[source] = (error as? SocialInboxError)?.errorDescription ?? SocialInboxError.connection.errorDescription
        }
    }

    func sendSupport(_ message: String, source: SocialSource, remove: Bool = false) {
        guard supportsSocialInbox, !supportSending.contains(source), restoreCampfireVisibility() else { return }
        var document = campfireDocument
        var pending = document.supportCommands ?? []
        if !pending.contains(where: { $0.source == source }) {
            pending.append(.init(source: source, messageID: message, action: remove ? "remove" : "send"))
        }
        document.supportCommands = pending
        guard saveCampfireDocument(document) else {
            supportErrors[source] = "Your cheer couldn’t be saved to send. Please try again."; return
        }
        replaySupportMessages()
    }

    func pendingSupport(_ source: SocialSource) -> PendingSupportMessage? {
        guard campfireDocumentOwner == pastureOwner else { return nil }
        return campfireDocument.supportCommands?.first { $0.source == source }
    }

    func replaySupportMessages() {
        guard supportReplayTask == nil, supportsSocialInbox, permitsNightFlockNetwork,
              accountState == .linked, restoreCampfireVisibility(), let owner = pastureOwner, let service,
              !(campfireDocument.supportCommands ?? []).isEmpty else { return }
        let generation = localSocialGeneration, epoch = transportRecoveryEpoch
        supportReplayTask = Task { [weak self] in
            guard let self else { return }
            defer { if isCurrentTransportTask(generation: generation, epoch: epoch) { supportReplayTask = nil } }
            // The journal can grow while a send is suspended; revisit it after each acknowledgement.
            var attempted = Set<UUID>()
            while let pending = campfireDocument.supportCommands?.first(where: { !attempted.contains($0.id) }) {
                guard !Task.isCancelled, owner == pastureOwner, isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                attempted.insert(pending.id); supportSending.insert(pending.source); supportErrors[pending.source] = nil
                do {
                    let result = try await service.socialInbox(pending.request(owner: owner))
                    guard owner == pastureOwner, isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                    supportDetails[pending.source] = result.detail
                    var document = campfireDocument
                    document.supportCommands?.removeAll { $0.id == pending.id }
                    if !saveCampfireDocument(document) { supportErrors[pending.source] = "Sent. Your saved send status will be checked again." }
                } catch {
                    guard owner == pastureOwner, isCurrentTransportTask(generation: generation, epoch: epoch) else { return }
                    if case SocialInboxError.unavailable = error {
                        var document = campfireDocument
                        document.supportCommands?.removeAll { $0.id == pending.id }
                        _ = saveCampfireDocument(document)
                        supportDetails[pending.source] = nil
                        supportErrors[pending.source] = SocialInboxError.unavailable.errorDescription
                    } else { supportErrors[pending.source] = "Couldn’t confirm your cheer. Retry when you’re ready." }
                }
                supportSending.remove(pending.source)
            }
        }
    }

    func markSocialEventRead(_ id: String) async {
        await markSocialEventsRead([id])
    }

    func markSocialEventsRead(_ ids: [String]) async {
        guard let owner = pastureOwner, accountState == .linked, permitsNightFlockNetwork, let service else { return }
        let generation = localSocialGeneration, epoch = transportRecoveryEpoch
        do {
            let result = try await service.socialInbox(.init(action: "read", eventIDs: Array(ids.prefix(50)), ownerID: owner))
            guard isCurrentTransportTask(generation: generation, epoch: epoch), owner == pastureOwner else { return }
            for index in socialInboxEvents.indices where ids.prefix(50).contains(socialInboxEvents[index].id) { socialInboxEvents[index].isRead = true }
            socialUnreadCount = result.unreadCount ?? socialUnreadCount
        } catch { /* A failed read remains new and can safely be retried on the next open. */ }
    }

    func setSocialPreferences(_ preferences: SocialNotificationPreferences) async {
        guard let owner = pastureOwner, accountState == .linked, permitsNightFlockNetwork, let service else { return }
        let generation = localSocialGeneration, epoch = transportRecoveryEpoch
        do {
            let response = try await service.socialInbox(.init(action: "preferences", preferences: preferences, ownerID: owner))
            guard isCurrentTransportTask(generation: generation, epoch: epoch), owner == pastureOwner else { return }
            socialPreferences = response.preferences ?? preferences
            if preferences.invitations || preferences.cheers {
                let allowed = await CampfireNotificationService.requestPermission()
                guard isCurrentTransportTask(generation: generation, epoch: epoch), owner == pastureOwner else { return }
                if !allowed { campfirePushStatus = "Notifications are off on this phone. Your inbox still works." }
                syncCampfirePush()
            }
        } catch {
            guard isCurrentTransportTask(generation: generation, epoch: epoch), owner == pastureOwner else { return }
            socialInboxError = "Your notification choices weren’t saved. Please try again."
        }
    }
}
