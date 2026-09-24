import Foundation
import ManagedSettings

final class QuietTimeShieldAction: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(for: action))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(action == .primaryButtonPressed ? response(for: action) : .none)
    }

    private func response(for action: ShieldAction) -> ShieldActionResponse {
        let destination: PersonalShieldAction
        switch action {
        case .primaryButtonPressed: destination = .checklist
        case .secondaryButtonPressed: destination = .briefAccess
        default: return .none
        }
        if let defaults = UserDefaults(suiteName: QuietTimeShieldPresentationStorage.appGroupIdentifier) {
            _ = PersonalShieldStorage.request(destination, in: defaults, at: Date())
        }
        if #available(iOS 26.5, *) { return .openParentalControlsApp }
        // Older systems cannot open the parent from a shield. Its subtitle names
        // the manual step, and the same short-lived request is consumed on open.
        return .defer
    }
}
