import Foundation
import UIKit
import UserNotifications

/// App delegate receives ordinary APNs tokens; the existing notification delegate
/// remains responsible for delivery presentation and routing.
final class CampfireAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        UserDefaults.standard.set(deviceToken.map { String(format: "%02x", $0) }.joined(), forKey: CampfireNotificationService.tokenKey)
        NotificationCenter.default.post(name: .campfirePushTokenChanged, object: nil)
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationCenter.default.post(name: .campfirePushRegistrationFailed, object: nil)
    }
}

@MainActor
enum CampfireNotificationService {
    static let tokenKey = "ollie.campfire.pushToken"
    static let pendingPartyKey = "ollie.campfire.pendingParty"
    static let installationKey = "ollie.campfire.pushInstallation"
    static var installationID: UUID {
        if let raw = UserDefaults.standard.string(forKey: installationKey), let id = UUID(uuidString: raw) { return id }
        let id = UUID(); UserDefaults.standard.set(id.uuidString, forKey: installationKey); return id
    }
    static func nextRevision() -> Int {
        let key = "ollie.campfire.pushRevision"
        let value = max(UserDefaults.standard.integer(forKey: key) + 1, Int(Date().timeIntervalSince1970 * 1000))
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
    static func requestPermission() async -> Bool {
        let granted = await PhoneNotificationService.shared.requestAuthorization()
        if granted { UIApplication.shared.registerForRemoteNotifications() }
        return granted
    }
    static func refreshTokenIfAuthorized() async {
        guard UserDefaults.standard.string(forKey: tokenKey) != nil else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    static func registration(owner: UUID, quietUntil: Date) async -> CampfireDeviceRegistration? {
        guard let token = UserDefaults.standard.string(forKey: tokenKey) else { return nil }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let enabled = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        let prefix = "ollie.campfire.\(owner.uuidString)."
        let start = UserDefaults.standard.object(forKey: prefix + "quietStart") as? Int ?? 23
        let end = UserDefaults.standard.object(forKey: prefix + "quietEnd") as? Int ?? 7
#if DEBUG
        let environment = "sandbox"
#else
        let environment = "production"
#endif
        return .init(ownerID: owner, installationID: installationID, token: token, environment: environment, enabled: enabled,
                     quietUntil: min(max(Date(), quietUntil), Date().addingTimeInterval(30 * 3600)),
                     timeZone: TimeZone.current.identifier, quietStart: start, quietEnd: end, revision: nextRevision())
    }
}

struct CampfireDeviceRegistration: Encodable {
    var ownerID: UUID
    var installationID: UUID
    var token: String
    var environment: String
    var enabled: Bool
    var quietUntil: Date
    var timeZone: String
    var quietStart: Int
    var quietEnd: Int
    var revision: Int
}

extension Notification.Name {
    static let campfirePushTokenChanged = Notification.Name("countingSheep.campfireTokenChanged")
    static let campfirePushRegistrationFailed = Notification.Name("countingSheep.campfireRegistrationFailed")
}
