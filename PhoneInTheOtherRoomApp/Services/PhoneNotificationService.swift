import Foundation
import UIKit
import UserNotifications

final class PhoneNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PhoneNotificationService()
    static let remindersEnabledKey = "ollie.notifications.remindersEnabled"
    static let preferencesKey = "ollie.notifications.preferences"
    static let pendingDestinationKey = "ollie.notifications.pendingDestination"

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
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: notificationIdentifiers)
            if !preferences.hasChosenCadence {
                await addLegacyTransitions(
                    for: plan,
                    purpose: purpose,
                    soundsEnabled: preferences.soundsEnabled,
                    preferences: preferences,
                    center: center
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
                await add(notification, to: center)
            }
            if preferences.morningReflectionReminderEnabled,
               let reflection = NightWatchNotificationPlanBuilder.reflectionNotification(
                   at: plan.protectedUntil.addingTimeInterval(60 * 60),
                   copyOverrides: preferences.copyOverrides
               ) {
                await add(reflection, to: center)
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
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: notificationIdentifiers)
            if !preferences.hasChosenCadence {
                await addLegacyAutomaticReminders(
                    at: startDate,
                    purpose: purpose,
                    preferences: preferences,
                    center: center
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
                await add(notification, to: center)
            }
            if preferences.morningReflectionReminderEnabled,
               let reflection = NightWatchNotificationPlanBuilder.reflectionNotification(
                   at: plan.protectedUntil.addingTimeInterval(60 * 60),
                   copyOverrides: preferences.copyOverrides
               ) {
                await add(reflection, to: center)
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
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: notificationIdentifiers
        )
    }

    func cancelRunCompletion() {
        cancelAllNightWatchNotifications()
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

    private func add(_ notification: PlannedNotification, to center: UNUserNotificationCenter) async {
        guard notification.date > Date() else { return }
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
        center: UNUserNotificationCenter
    ) async {
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
            to: center
        )
        let morning = NotificationCopyResolver.resolve(
            id: .phoneFreeMorning,
            moment: .phoneFreeMorning,
            context: NotificationCopyContext(
                activityTitle: plan.morningNotificationActivityTitle(
                    allowsPersonalText: purpose.allowsCustomTextInNotifications
                ),
                purpose: purpose.reminderPhrase,
                tip: purpose.reminderPhrase,
                date: plan.wakeTime
            ),
            overrides: preferences.copyOverrides
        )
        await add(
            PlannedNotification(
                id: "night-watch-phone-free-morning",
                date: plan.wakeTime,
                title: morning.title,
                body: morning.body,
                phase: .morningQuiet,
                importance: .passive,
                playsSound: false,
                destination: .activeRun
            ),
            to: center
        )
        let complete = NotificationCopyResolver.resolve(
            id: .complete,
            moment: .complete,
            context: NotificationCopyContext(date: plan.protectedUntil),
            overrides: preferences.copyOverrides
        )
        await add(
            PlannedNotification(
                id: "focus-run-complete",
                date: plan.protectedUntil,
                title: complete.title,
                body: complete.body,
                phase: .complete,
                importance: .active,
                playsSound: soundsEnabled,
                destination: .nights
            ),
            to: center
        )
    }

    private func addLegacyAutomaticReminders(
        at startDate: Date,
        purpose: OfflinePurposeProfile,
        preferences: NotificationPreferences,
        center: UNUserNotificationCenter
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
                to: center
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
            to: center
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
