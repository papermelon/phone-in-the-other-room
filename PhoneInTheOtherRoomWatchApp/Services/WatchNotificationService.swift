import Foundation
import UserNotifications

final class WatchNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WatchNotificationService()

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func scheduleRunStartedNotification(role: WindDownOccurrenceRole = .primarySleepBookend) {
        Task {
            guard await requestAuthorizationIfNeeded() else { return }

            let content = UNMutableNotificationContent()
            content.title = role == .additionalQuiet ? "Ollie is keeping quiet" : "Ollie is on Wind Down"
            content.body = role == .additionalQuiet
                ? "Your quiet time is running."
                : "Your phone is tucked in for the night."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: "watch-run-started", content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
        }
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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
