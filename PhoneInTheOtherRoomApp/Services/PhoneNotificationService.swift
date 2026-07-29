import Foundation
import UserNotifications

final class PhoneNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PhoneNotificationService()

    private let runNotificationIdentifiers = [
        "night-watch-sleep-time",
        "night-watch-phone-free-morning",
        "focus-run-complete"
    ]

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func scheduleOpenWatchReminder() {
        Task {
            guard await requestAuthorizationIfNeeded() else { return }

            let content = UNMutableNotificationContent()
            content.title = "Ollie is ready on your Watch"
            content.body = "Open the Watch app to see tonight's quiet time."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            let request = UNNotificationRequest(identifier: "open-watch-reminder", content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func scheduleRunCompletion(at endDate: Date?) {
        guard let endDate, endDate > Date() else { return }
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            let copy = NightWatchGuidance.notificationCopy(for: .complete)
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "focus-run-complete",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: endDate.timeIntervalSinceNow, repeats: false)
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func scheduleNightWatchTransitions(
        for run: FocusRun,
        purpose: OfflinePurposeProfile = .defaultProfile
    ) {
        guard let plan = run.nightWatchPlan else {
            scheduleRunCompletion(at: run.plannedEndAt)
            return
        }

        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: runNotificationIdentifiers)

            await addRunNotification(
                identifier: "night-watch-sleep-time",
                at: plan.intendedBedtime,
                copy: NightWatchGuidance.notificationCopy(for: .sleepTime),
                sound: nil,
                center: center
            )
            await addRunNotification(
                identifier: "night-watch-phone-free-morning",
                at: plan.wakeTime,
                copy: NightWatchGuidance.notificationCopy(
                    for: .phoneFreeMorning,
                    activityTitle: plan.morningActivity.shortTitle,
                    tip: purpose.reminderPhrase
                ),
                sound: nil,
                center: center
            )
            await addRunNotification(
                identifier: "focus-run-complete",
                at: plan.protectedUntil,
                copy: NightWatchGuidance.notificationCopy(for: .complete),
                sound: .default,
                center: center
            )
        }
    }

    func scheduleNightWatchReminder(
        at startDate: Date,
        purpose: OfflinePurposeProfile = .defaultProfile
    ) {
        guard startDate > Date() else { return }
        Task {
            guard await requestAuthorizationIfNeeded() else { return }
            let copy = NightWatchGuidance.notificationCopy(
                for: .windDownReminder,
                tip: purpose.reminderPhrase
            )
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "night-watch-reminder",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: startDate.timeIntervalSinceNow, repeats: false)
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelRunCompletion() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: runNotificationIdentifiers
        )
    }

    func cancelNightWatchReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["night-watch-reminder"])
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

    private func addRunNotification(
        identifier: String,
        at date: Date,
        copy: NightWatchNotificationCopy,
        sound: UNNotificationSound?,
        center: UNUserNotificationCenter
    ) async {
        guard date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = sound
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, date.timeIntervalSinceNow),
                repeats: false
            )
        )
        try? await center.add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
