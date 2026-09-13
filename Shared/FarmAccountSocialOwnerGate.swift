import Foundation

/// Account-scoped social work may run only after the Farm committed the same
/// immutable UUID as the authenticated identity. Standalone legacy social
/// contexts have no Farm owner to compare and retain their existing behavior.
enum FarmAccountSocialOwnerGate {
    static func permits(sharedFarmAttached: Bool, activeFarmOwner: UUID?, expectedIdentity: UUID?) -> Bool {
        guard sharedFarmAttached else { return true }
        return activeFarmOwner != nil && activeFarmOwner == expectedIdentity
    }
}
