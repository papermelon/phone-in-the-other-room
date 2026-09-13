// Host-harness substitutes for Apple/Supabase boundaries only. The tested
// view model, persistence adapter and file store are the production sources.
import Foundation

enum NightFlockAccountError: Error { case identityChanged, reauthenticationRequired }
struct NightFlockAppleNonce { var rawValue: String; var requestValue: String }
actor NightFlockAccountService {
    let owner: UUID
    var beforeIdentity: (@MainActor () -> Void)?
    init(owner: UUID) { self.owner = owner }
    func setBeforeIdentity(_ hook: @escaping @MainActor () -> Void) { beforeIdentity = hook }
    func currentLinkedAccountID() async throws -> UUID? {
        await beforeIdentity?()
        return owner
    }
    func signInForFarm(identityToken: String, nonce: String) async throws {}
    func signOutPreservingFarmBinding() async throws {}
    func signOutForAccountSwitch() async throws {}
    func signInWithPassword(identifier: String, password: String) async throws {}
    func registerPassword(email: String, password: String, username: String) async throws -> Bool { false }
    func verifyEmailCode(email: String, code: String, recovery: Bool = false, emailChange: Bool = false) async throws {}
    func resendVerification(email: String) async throws {}
    func sendPasswordRecovery(email: String) async throws {}
    func changePassword(_ password: String, nonce: String? = nil) async throws {}
    func sendPasswordChangeCode() async throws {}
    func changeRecoveryEmail(_ email: String) async throws {}
    func claimUsername(_ raw: String) async throws {}
    func connectApple(identityToken: String, nonce: String) async throws {}
    func credentialProfile() async throws -> AccountCredentialProfile {
        AccountCredentialProfile(id: owner, hasApple: true, hasEmail: false)
    }
    nonisolated static func makeAppleNonce() throws -> NightFlockAppleNonce {
        NightFlockAppleNonce(rawValue: "test", requestValue: "test")
    }
}
enum FarmBackupRemoteError: Error { case headChanged }
enum FarmBackupTransportError: Error { case unavailable }
actor FarmBackupService {
    var remote: FarmBackupLookup
    var commands: [FarmBackupCommand] = []
    var lookups = 0
    var beforeSend: (@MainActor () -> Void)?
    var failNextSend = false
    var failNextLookup = false
    init(remote: FarmBackupLookup) { self.remote = remote }
    func acceptAccountSync(owner: UUID, authorization: @escaping @MainActor @Sendable () -> Bool) async throws {
        guard await authorization() else { throw FarmSaveError.unavailable }
    }
    func clearHead() { remote.head = nil }
    func setBeforeSend(_ hook: @escaping @MainActor () -> Void) { beforeSend = hook }
    func failNextUpload() { failNextSend = true }
    func failNextAccountLookup() { failNextLookup = true }
    func lookup(owner: UUID, revisionID: UUID? = nil,
                authorization: @escaping @MainActor @Sendable () -> Bool) async throws -> FarmBackupLookup {
        guard await authorization() else { throw FarmSaveError.unavailable }
        if failNextLookup {
            failNextLookup = false
            throw FarmBackupTransportError.unavailable
        }
        lookups += 1
        return remote
    }
    func send(_ command: FarmBackupCommand, owner: UUID,
              authorization: @escaping @MainActor @Sendable () -> Bool) async throws -> FarmBackupReceipt {
        await beforeSend?()
        guard await authorization() else { throw FarmSaveError.unavailable }
        if failNextSend {
            failNextSend = false
            throw FarmBackupTransportError.unavailable
        }
        commands.append(command)
        return FarmBackupReceipt(status: "saved", generation: remote.generation,
            revision: FarmBackupRevision(id: UUID(), digest: "test", createdAt: Date(), conflict: false))
    }
}
