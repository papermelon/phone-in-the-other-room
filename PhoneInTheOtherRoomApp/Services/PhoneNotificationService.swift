import Foundation
import UIKit
import UserNotifications

/// Serializes async notification planning without making the service itself a
/// global actor. A later edit/disable invalidates every earlier task before it
/// can add a stale request after authorization returns.
private enum NotificationOwnershipChannel: Hashable {
    case windDown
    case screenFreeMorning
    case automatic
}

private final class NotificationGenerationLedger {
    private let lock = NSLock()
    private var values: [NotificationOwnershipChannel: Int] = [:]

    func begin(_ channel: NotificationOwnershipChannel) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let next = (values[channel] ?? 0) + 1
        values[channel] = next
        return next
    }

    func accepts(_ generation: Int, for channel: NotificationOwnershipChannel) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return values[channel] == generation
    }

    func current(_ channel: NotificationOwnershipChannel) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return values[channel] ?? 0
    }

    /// Holds ownership through the synchronous replacement operation, closing
    /// the check-then-remove race with an active-run invalidation.
    func performIfCurrent(
        _ generation: Int,
        for channel: NotificationOwnershipChannel,
        _ operation: () -> Void
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard values[channel] == generation else { return false }
        operation()
        return true
    }
}

final class PhoneNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PhoneNotificationService()
    static let remindersEnabledKey = "ollie.notifications.remindersEnabled"
    static let preferencesKey = "ollie.notifications.preferences"
    static let pendingDestinationKey = "ollie.notifications.pendingDestination"
    static let screenFreeMorningIdentifierPrefix = "ollie.screenFreeMorning."

    private let notificationIdentifiers = [
        "night-watch-lead-in-60",
        "night-watch-lead-in-30",
        "night-watch-lead-in-10",
        "night-watch-wind-down-start",
        "night-watch-wind-down-midpoint",
        "night-watch-sleep-time",
        "night-watch-phone-free-morning",
        "night-watch-morning-midpoint",
        "focus-run-complete",
        "night-watch-quiet-period-complete",
        "night-watch-morning-reflection",
        "night-watch-reminder",
        "night-watch-usage-windDown",
        "night-watch-usage-overnight",
        "night-watch-usage-morningQuiet",
        "night-watch-shielding-failed"
    ]
    private let notificationGenerations = NotificationGenerationLedger()

    private override init() {
        super.init()
    }

    var preferences: NotificationPreferences {
        get {
            if let data = UserDefaults.standard.data(forKey: Self.preferencesKey),
               let stored = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
                return stored
            }
            let legacyEnabled = UserDefaults.standard.object(
                forKey: Self.remindersEnabledKey
            ) as? Bool ?? NotificationPreferences.defaults.remindersEnabled
            var migrated = NotificationPreferences.defaults
            migrated.remindersEnabled = legacyEnabled
            return migrated
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: Self.preferencesKey)
            UserDefaults.standard.set(newValue.remindersEnabled, forKey: Self.remindersEnabledKey)
        }
    }

    var remindersEnabled: Bool {
        get { preferences.remindersEnabled }
        set {
            var updated = preferences
            updated.remindersEnabled = newValue
            preferences = updated
            if !newValue { cancelAllNightWatchNotifications() }
        }
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async -> Bool {
        await requestAuthorizationIfNeeded()
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func scheduleNightWatchNotifications(
        for plan: NightWatchPlan,
        startedAt: Date,
        purpose: OfflinePurposeProfile,
        seed: UUID,
        preferences: NotificationPreferences = PhoneNotificationService.shared.preferences
    ) {
        guard preferences.remindersEnabled else {
            cancelAllNightWatchNotifications()
            return
        }
        // An active run owns the static identifiers now. Invalidate a pending
        // automatic-auth task before it can remove or recreate them.
        _ = notificationGenerations.begin(.automatic)
        let generation = notificationGenerations.begin(.windDown)
        Task {
            guard await requestAuthorizationIfNeeded(),
                  notificationGenerations.accepts(generation, for: .windDown),
                  preferences.remindersEnabled else { return }
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: notificationIdentifiers)
            if !preferences.hasChosenCadence {
                await addLegacyTransitions(
                    for: plan,
                    purpose: purpose,
                    soundsEnabled: preferences.soundsEnabled,
                    preferences: preferences,
                    center: center,
                    generation: generation
                )
                return
            }
            let planned = NightWatchNotificationPlanBuilder.scheduledNotifications(
                for: plan,
                startedAt: startedAt,
                cadence: preferences.cadence,
                purpose: purpose,
                seed: seed,
                educationalTipsEnabled: preferences.educationalTipsEnabled,
                soundsEnabled: preferences.soundsEnabled,
                copyOverrides: preferences.copyOverrides
            )
            for notification in planned {
                await add(notification, to: center, generation: generation, channel: .windDown)
            }
            if plan.role == .primarySleepBookend,
               preferences.morningReflectionReminderEnabled,
               let reflection = NightWatchNotificationPlanBuilder.reflectionNotification(
                   at: plan.protectedUntil.addingTimeInterval(60 * 60),
                   copyOverrides: preferences.copyOverrides
               ) {
                await add(reflection, to: center, generation: generation, channel: .windDown)
            }
        }
    }

    func scheduleAutomaticWindDownNotifications(
        at startDate: Date,
        plan: NightWatchPlan,
        purpose: OfflinePurposeProfile,
        seed: UUID,
        preferences: NotificationPreferences = PhoneNotificationService.shared.preferences
    ) {
        guard preferences.remindersEnabled, startDate > Date() else { return }
        let generation = notificationGenerations.begin(.automatic)
        Task {
            guard await requestAuthorizationIfNeeded(),
                  notificationGenerations.accepts(generation, for: .automatic),
                  preferences.remindersEnabled else { return }
            let center = UNUserNotificationCenter.current()
            guard notificationGenerations.performIfCurrent(generation, for: .automatic, {
                center.removePendingNotificationRequests(withIdentifiers: notificationIdentifiers)
            }) else { return }
            if !preferences.hasChosenCadence {
                await addLegacyAutomaticReminders(
                    at: startDate,
                    purpose: purpose,
                    preferences: preferences,
                    center: center,
                    generation: generation,
                    channel: .automatic
                )
                return
            }
            let planned = NightWatchNotificationPlanBuilder.scheduledNotifications(
                for: plan,
                startedAt: startDate,
                cadence: preferences.cadence,
                purpose: purpose,
                seed: seed,
                educationalTipsEnabled: preferences.educationalTipsEnabled,
                soundsEnabled: preferences.soundsEnabled,
                copyOverrides: preferences.copyOverrides
            )
            for notification in planned {
                await add(notification, to: center, generation: generation, channel: .automatic)
            }
            if plan.role == .primarySleepBookend,
               preferences.morningReflectionReminderEnabled,
               let reflection = NightWatchNotificationPlanBuilder.reflectionNotification(
                   at: plan.protectedUntil.addingTimeInterval(60 * 60),
                   copyOverrides: preferences.copyOverrides
               ) {
                await add(reflection, to: center, generation: generation, channel: .automatic)
            }
        }
    }

    /// Reconciles the finite upcoming list without disturbing an active run's
    /// phase notifications. The system permits at most 64 pending local
    /// notifications, so existing non-scheduler requests keep their slots.
    func reconcileUpcomingWindDownNotifications(
        for schedule: WindDownScheduleState,
        primaryExtensionMinutes: Int,
        purpose: OfflinePurposeProfile,
        preferences: NotificationPreferences = PhoneNotificationService.shared.preferences,
        now: Date = Date()
    ) {
        guard preferences.remindersEnabled else { return }
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let owned = pending.filter {
                $0.identifier.hasPrefix(UpcomingWindDownNotificationPlanBuilder.identifierPrefix)
            }
            let planned = UpcomingWindDownNotificationPlanBuilder.scheduledNotifications(
                for: schedule,
                after: now,
                primaryExtensionMinutes: primaryExtensionMinutes,
                purpose: purpose,
                copyOverrides: preferences.copyOverrides,
                limit: UpcomingWindDownNotificationPlanBuilder.maximumPendingCount
            )
            let availableSlots = max(
                0,
                UpcomingWindDownNotificationPlanBuilder.maximumPendingCount
                    - (pending.count - owned.count)
            )
            let retainedPlan = Array(planned.prefix(availableSlots))
            // Replace owned requests even when their stable identifier stays
            // the same so edited copy and purpose text take effect.
            center.removePendingNotificationRequests(
                withIdentifiers: owned.map(\.identifier)
            )
            for notification in retainedPlan {
                await add(notification, to: center)
            }
        }
    }

    func scheduleNextWindDownReminder(
        at date: Date,
        purpose: OfflinePurposeProfile,
        preferences: NotificationPreferences = PhoneNotificationService.shared.preferences
    ) {
        guard preferences.remindersEnabled, date > Date() else { return }
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            let copy = NotificationCopyResolver.resolve(
                id: .windDownStart,
                moment: .windDownReminder,
                context: NotificationCopyContext(
                    purpose: purpose.reminderPhrase,
                    tip: purpose.reminderPhrase,
                    date: date
                ),
                overrides: preferences.copyOverrides
            )
            let notification = PlannedNotification(
                id: "night-watch-reminder",
                date: date,
                title: copy.title,
                body: copy.body,
                phase: .windDown,
                importance: .active,
                playsSound: preferences.soundsEnabled,
                destination: .home
            )
            await add(notification, to: UNUserNotificationCenter.current())
        }
    }

    func scheduleLegacyCompletion(at endDate: Date?) {
        guard remindersEnabled, let endDate, endDate > Date() else { return }
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            let copy = NotificationCopyResolver.resolve(
                id: .complete,
                moment: .complete,
                context: NotificationCopyContext(date: endDate),
                overrides: preferences.copyOverrides
            )
            let notification = PlannedNotification(
                id: "focus-run-complete",
                date: endDate,
                title: copy.title,
                body: copy.body,
                phase: .complete,
                importance: .active,
                playsSound: preferences.soundsEnabled,
                destination: .nights
            )
            await add(notification, to: .current())
        }
    }

    /// Replaces only the independent Morning cues. Wind Down's active or next
    /// automatic notifications remain intact, and no message hints at a
    /// receipt, sheep, or reward.
    func reconcileScreenFreeMorningNotifications(
        occurrences: [MorningQuietOccurrence],
        now: Date = Date()
    ) {
        guard preferences.remindersEnabled else { return }
        let generation = notificationGenerations.begin(.screenFreeMorning)
        let current = occurrences.filter { $0.outcome == .scheduled || $0.outcome == .active }
        Task {
            guard await requestAuthorizationIfNeeded(),
                  notificationGenerations.accepts(generation, for: .screenFreeMorning),
                  preferences.remindersEnabled else { return }
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let owned = pending.map(\.identifier).filter {
                $0.hasPrefix(Self.screenFreeMorningIdentifierPrefix)
            }
            center.removePendingNotificationRequests(withIdentifiers: owned)
            // Once a journal-backed Morning exists, its start/end cues replace
            // the legacy FocusRun morning/midpoint/completion requests.
            if !current.isEmpty {
                center.removePendingNotificationRequests(
                    withIdentifiers: NightWatchNotificationPlanBuilder.supersededMorningIdentifiers
                )
            }
            for occurrence in current {
                let base = Self.screenFreeMorningIdentifierPrefix + occurrence.id.uuidString.lowercased()
                if occurrence.outcome == .scheduled, occurrence.scheduledStart > now {
                    await add(
                        PlannedNotification(
                            id: base + ".start",
                            date: occurrence.scheduledStart,
                            title: "Screen-Free Morning",
                            body: "Your planned phone-away morning time can begin now.",
                            phase: .morningQuiet,
                            importance: .active,
                            playsSound: preferences.soundsEnabled,
                            destination: .home
                        ),
                        to: center,
                        generation: generation,
                        channel: .screenFreeMorning
                    )
                }
                if occurrence.scheduledEnd > now {
                    await add(
                        PlannedNotification(
                            id: base + ".end",
                            date: occurrence.scheduledEnd,
                            title: "Screen-Free Morning",
                            body: "Your planned phone-away morning time has ended.",
                            phase: .morningQuiet,
                            importance: .active,
                            playsSound: preferences.soundsEnabled,
                            destination: .home
                        ),
                        to: center,
                        generation: generation,
                        channel: .screenFreeMorning
                    )
                }
            }
        }
    }

    func cancelScreenFreeMorningNotifications(for occurrenceID: UUID) {
        let base = Self.screenFreeMorningIdentifierPrefix + occurrenceID.uuidString.lowercased()
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [base + ".start", base + ".end"]
        )
    }

    func scheduleUsageNotification(for phase: NightWatchPhase, at date: Date = Date()) {
        guard preferences.remindersEnabled,
              preferences.usageAwareRemindersEnabled,
              let notification = NightWatchNotificationPlanBuilder.usageNotification(
                  for: phase,
                  date: date,
                  copyOverrides: preferences.copyOverrides
              ) else { return }
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            await add(notification, to: .current())
        }
    }

    func scheduleShieldingFailure(at date: Date = Date()) {
        guard preferences.remindersEnabled else { return }
        let copy = NightWatchGuidance.notificationCopy(for: .shieldingFailed)
        let notification = PlannedNotification(
            id: "night-watch-shielding-failed",
            date: date,
            title: copy.title,
            body: copy.body,
            phase: .windDown,
            importance: .active,
            playsSound: false,
            destination: .activeRun
        )
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            await add(notification, to: UNUserNotificationCenter.current())
        }
    }

    func cancelAllNightWatchNotifications() {
        _ = notificationGenerations.begin(.windDown)
        let morningGeneration = notificationGenerations.begin(.screenFreeMorning)
        _ = notificationGenerations.begin(.automatic)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: notificationIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: notificationIdentifiers)
        cancelScreenFreeMorningNotifications(on: center, generation: morningGeneration)
        cancelUpcomingWindDownNotifications(on: center)
    }

    /// Cancels Counting Sheep's pending and delivered notification requests and
    /// removes the local notification preferences/click destination. It never
    /// enumerates or removes requests belonging to another app.
    func resetLocalState() {
        cancelAllNightWatchNotifications()
        UserDefaults.standard.removeObject(forKey: Self.preferencesKey)
        UserDefaults.standard.removeObject(forKey: Self.remindersEnabledKey)
        UserDefaults.standard.removeObject(forKey: Self.pendingDestinationKey)
    }

    func cancelRunCompletion() {
        _ = notificationGenerations.begin(.windDown)
        let windDownTerminalIDs = notificationIdentifiers.filter {
            $0 != "night-watch-phone-free-morning" && $0 != "night-watch-morning-midpoint"
        }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: windDownTerminalIDs)
        center.removeDeliveredNotifications(withIdentifiers: windDownTerminalIDs)
    }

    func cancelNightWatchReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                "night-watch-reminder",
                "night-watch-lead-in-60",
                "night-watch-lead-in-30",
                "night-watch-lead-in-10"
            ]
        )
    }

    func cancelMorningReflectionReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["night-watch-morning-reflection"]
        )
    }

    private func cancelUpcomingWindDownNotifications(on center: UNUserNotificationCenter) {
        Task {
            let pending = await center.pendingNotificationRequests()
            let delivered = await center.deliveredNotifications()
            let ownedIdentifiers = Set(
                pending.map(\.identifier) + delivered.map(\.request.identifier)
            ).filter {
                $0.hasPrefix(UpcomingWindDownNotificationPlanBuilder.identifierPrefix)
            }
            guard !ownedIdentifiers.isEmpty else { return }
            let identifiers = Array(ownedIdentifiers)
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    private func cancelScreenFreeMorningNotifications(
        on center: UNUserNotificationCenter,
        generation: Int
    ) {
        Task {
            let pending = await center.pendingNotificationRequests()
            let delivered = await center.deliveredNotifications()
            let identifiers = Set(
                pending.map(\.identifier) + delivered.map(\.request.identifier)
            ).filter { $0.hasPrefix(Self.screenFreeMorningIdentifierPrefix) }
            guard notificationGenerations.accepts(generation, for: .screenFreeMorning),
                  !identifiers.isEmpty else { return }
            let owned = Array(identifiers)
            center.removePendingNotificationRequests(withIdentifiers: owned)
            center.removeDeliveredNotifications(withIdentifiers: owned)
        }
    }

    func consumePendingDestination() -> NotificationDestination? {
        guard let rawValue = UserDefaults.standard.string(forKey: Self.pendingDestinationKey),
              let destination = NotificationDestination(rawValue: rawValue) else {
            return nil
        }
        UserDefaults.standard.removeObject(forKey: Self.pendingDestinationKey)
        return destination
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    private func add(
        _ notification: PlannedNotification,
        to center: UNUserNotificationCenter,
        generation: Int? = nil,
        channel: NotificationOwnershipChannel = .windDown
    ) async {
        let acceptsGeneration = generation.map {
            NotificationSchedulingGenerationPolicy.accepts(
                requested: $0,
                current: notificationGenerations.current(channel),
                remindersEnabled: preferences.remindersEnabled
            )
        } ?? preferences.remindersEnabled
        guard notification.date > Date(), acceptsGeneration else { return }
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = notification.playsSound ? .default : nil
        content.interruptionLevel = notification.importance == .active ? .active : .passive
        content.userInfo = [
            "destination": notification.destination.rawValue
        ]
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, notification.date.timeIntervalSinceNow),
                repeats: false
            )
        )
        try? await center.add(request)
    }

    private func addLegacyTransitions(
        for plan: NightWatchPlan,
        purpose: OfflinePurposeProfile,
        soundsEnabled: Bool,
        preferences: NotificationPreferences,
        center: UNUserNotificationCenter,
        generation: Int
    ) async {
        if plan.role == .additionalQuiet {
            let quietCopy = NightWatchGuidance.notificationCopy(for: .quietPeriodComplete)
            await add(
                PlannedNotification(
                    id: "night-watch-quiet-period-complete",
                    date: plan.protectedUntil,
                    title: quietCopy.title,
                    body: quietCopy.body,
                    phase: .complete,
                    importance: .active,
                    playsSound: soundsEnabled,
                    destination: .nights
                ),
                to: center,
                generation: generation
            )
            return
        }
        let sleepCopy = NotificationCopyResolver.resolve(
            id: .sleepTime,
            moment: .sleepTime,
            context: NotificationCopyContext(date: plan.intendedBedtime),
            overrides: preferences.copyOverrides
        )
        await add(
            PlannedNotification(
                id: "night-watch-sleep-time",
                date: plan.intendedBedtime,
                title: sleepCopy.title,
                body: sleepCopy.body,
                phase: .overnight,
                importance: .passive,
                playsSound: false,
                destination: .activeRun
            ),
            to: center,
            generation: generation
        )
        // The journal-backed Screen-Free Morning owns its own start/end cues.
        // Do not reintroduce the former FocusRun morning/completion requests.
    }

    private func addLegacyAutomaticReminders(
        at startDate: Date,
        purpose: OfflinePurposeProfile,
        preferences: NotificationPreferences,
        center: UNUserNotificationCenter,
        generation: Int,
        channel: NotificationOwnershipChannel
    ) async {
        for minutes in [60, 30, 10] {
            let templateID: NotificationTemplateID
            switch minutes {
            case 60: templateID = .windDownLeadIn60
            case 30: templateID = .windDownLeadIn30
            default: templateID = .windDownLeadIn10
            }
            let copy = NotificationCopyResolver.resolve(
                id: templateID,
                moment: .windDownLeadIn(minutes: minutes),
                context: NotificationCopyContext(
                    date: startDate.addingTimeInterval(TimeInterval(-minutes * 60)),
                    minutes: minutes
                ),
                overrides: preferences.copyOverrides
            )
            await add(
                PlannedNotification(
                    id: "night-watch-lead-in-\(minutes)",
                    date: startDate.addingTimeInterval(TimeInterval(-minutes * 60)),
                    title: copy.title,
                    body: copy.body,
                    phase: .windDown,
                    importance: .passive,
                    playsSound: false,
                    destination: .home
                ),
                to: center,
                generation: generation,
                channel: channel
            )
        }
        let copy = NotificationCopyResolver.resolve(
            id: .windDownStart,
            moment: .windDownReminder,
            context: NotificationCopyContext(
                purpose: purpose.reminderPhrase,
                tip: purpose.reminderPhrase,
                date: startDate
            ),
            overrides: preferences.copyOverrides
        )
        await add(
            PlannedNotification(
                id: "night-watch-reminder",
                date: startDate,
                title: copy.title,
                body: copy.body,
                phase: .windDown,
                importance: .active,
                playsSound: false,
                destination: .home
            ),
            to: center,
            generation: generation,
            channel: channel
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if notification.request.content.interruptionLevel == .passive {
            return [.list]
        }
        return notification.request.content.sound == nil ? [.banner] : [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let rawValue = response.notification.request.content.userInfo["destination"] as? String,
           let destination = NotificationDestination(rawValue: rawValue) {
            UserDefaults.standard.set(destination.rawValue, forKey: Self.pendingDestinationKey)
            NotificationCenter.default.post(
                name: .countingSheepNotificationDestination,
                object: destination
            )
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let countingSheepNotificationDestination = Notification.Name(
        "countingSheep.notificationDestination"
    )
}
