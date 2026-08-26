import Foundation

#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
import FamilyControls
#endif

@MainActor
final class ScreenTimeAuthorizationService {
    enum AuthorizationState: Equatable {
        case unavailable
        case notDetermined
        case approved
        case denied(String)

        var label: String {
            switch self {
            case .unavailable: return "Unavailable"
            case .notDetermined: return "Not connected"
            case .approved: return "Connected"
            case .denied: return "Needs permission"
            }
        }
    }

    func currentState() -> AuthorizationState {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        switch AuthorizationCenter.shared.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .approved:
            return .approved
        case .approvedWithDataAccess:
            return .approved
        case .denied:
            return .denied("Screen Time access was denied.")
        @unknown default:
            return .notDetermined
        }
#else
        return .unavailable
#endif
    }

    func requestAuthorization() async -> AuthorizationState {
#if SCREEN_TIME_REPORTS && canImport(FamilyControls)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return currentState()
        } catch {
            return .denied(error.localizedDescription)
        }
#else
        return .unavailable
#endif
    }
}
