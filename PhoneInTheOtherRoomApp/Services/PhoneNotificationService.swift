import Foundation
import UserNotifications

final class PhoneNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PhoneNotificationService()

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
            content.title = "Open Counting Sheep on Watch"
            content.body = "Your Focus Run is starting. Open the Watch app so Ollie can stay with you."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            let request = UNNotificationRequest(identifier: "open-watch-reminder", content: content, trigger: trigger)
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
