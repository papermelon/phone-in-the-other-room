import CryptoKit
import Foundation
import Security
import Supabase

struct NightFlockAppleNonce: Equatable, Sendable {
    var rawValue: String
    var requestValue: String
}

enum NightFlockAccountError: LocalizedError, Equatable {
    case identityChanged
    case expectedIdentityMissing
    case accountIsNotAnonymous
    case existingIdentityBinding
    case invalidExpectedIdentityBinding
    case unsupportedAuthenticatedSession
    case reauthenticationRequired
    case identityTokenMissing
    case nonceUnavailable

    var errorDescription: String? {
        switch self {
        case .identityChanged:
            return "That Apple account does not match this Slumber Party. Your local Wind Down and shared updates were kept safe."
        case .expectedIdentityMissing:
            return "This Slumber Party cannot safely reconnect without its original account record. Your local Wind Down and shared updates were kept safe."
        case .accountIsNotAnonymous:
            return "This account is not anonymous, so Counting Sheep will not replace or relink it."
        case .existingIdentityBinding:
            return "This Slumber Party already has an Apple account binding, so Counting Sheep will not relink it."
        case .invalidExpectedIdentityBinding:
            return "This Slumber Party account record cannot be safely read, so Counting Sheep will not reconnect or replace it. Your local Wind Down and shared updates were kept safe."
        case .unsupportedAuthenticatedSession:
            return "This signed-in account is not linked to Apple for Slumber Party. Counting Sheep kept your local data safe."
        case .reauthenticationRequired:
            return "Reconnect your Apple account to reopen this Slumber Party. Your local Wind Down and queued updates are safe here."
        case .identityTokenMissing:
            return "Apple did not return an identity token. Please try again."
        case .nonceUnavailable:
            return "A secure sign-in request could not be prepared. Please try again."
        }
    }
}

actor NightFlockAccountService {
    static let expectedLinkedUserIDKey = "ollie.nightFlock.expectedLinkedUserID"
    private let provider: SupabaseClientProviding
    private let defaults: UserDefaults

    init(provider: SupabaseClientProviding, defaults: UserDefaults = .standard) {
        self.provider = provider
        self.defaults = defaults
    }

    func currentState(createAnonymousIfMissing: Bool) async throws -> NightFlockAccountState {
        let client = try provider.client()
        let binding = expectedLinkedUserID
        let observed: NightFlockObservedAccountSession
        do {
            let user = try await client.auth.session.user
            observed = Self.observedSession(for: user)
        } catch let error as AuthError where error == .sessionMissing {
            observed = .missing
        }

        switch NightFlockAccountSessionPolicy.decide(
            observed: observed,
            expectedIdentity: binding,
            createAnonymousIfMissing: createAnonymousIfMissing
        ) {
        case .returnAnonymous:
            return .anonymous
        case .createAnonymous:
            _ = try await client.auth.signInAnonymously()
            return .anonymous
        case let .returnLinked(adopting):
            if let adopting { persistExpectedLinkedUserID(adopting) }
            return .linked
        case let .reauthenticateApple(signOutLocalSession):
            if signOutLocalSession { try? await client.auth.signOut(scope: .local) }
            throw NightFlockAccountError.reauthenticationRequired
        case let .failClosed(signOutLocalSession):
            if signOutLocalSession { try? await client.auth.signOut(scope: .local) }
            throw Self.failureError(for: observed, binding: binding)
        }
    }

    func linkAppleIdentity(identityToken: String, nonce: String) async throws {
        let client = try provider.client()
        let originalUser = try await client.auth.session.user
        let binding = expectedLinkedUserID
        let observed = Self.observedSession(for: originalUser)
        guard NightFlockAccountSessionPolicy.mayLinkAppleIdentity(
            observed: observed,
            expectedIdentity: binding
        ) else {
            if binding == .invalid {
                try? await client.auth.signOut(scope: .local)
                throw NightFlockAccountError.invalidExpectedIdentityBinding
            }
            if !binding.permitsInitialBinding {
                throw NightFlockAccountError.existingIdentityBinding
            }
            if observed != .anonymous {
                try? await client.auth.signOut(scope: .local)
            }
            throw NightFlockAccountError.accountIsNotAnonymous
        }
        let credentials = OpenIDConnectCredentials(
            provider: .apple,
            idToken: identityToken,
            nonce: nonce
        )
        let session: Session
        do {
            session = try await client.auth.linkIdentityWithIdToken(credentials: credentials)
        } catch let error as AuthError where error.errorCode == .identityAlreadyExists {
            // A previous link request may have committed on the server before
            // the client persisted its UUID. Signing in is safe only when it
            // proves that Apple returns to the exact anonymous account that
            // initiated this request.
            session = try await client.auth.signInWithIdToken(credentials: credentials)
        }
        guard NightFlockAppleIdentityEvidence.preservesOriginalAccount(
            originalUserID: originalUser.id,
            recoveredUserID: session.user.id,
            hasAppleIdentity: Self.hasAppleIdentity(session.user)
        ) else {
            try? await client.auth.signOut(scope: .local)
            throw NightFlockAccountError.identityChanged
        }
        persistExpectedLinkedUserID(session.user.id)
    }

    /// Reauthentication is intentionally a sign-in exchange, not an identity
    /// link. The returned Supabase UUID must equal the locally bound account.
    func reauthenticateAppleIdentity(identityToken: String, nonce: String) async throws {
        let binding = expectedLinkedUserID
        guard let expected = binding.validUserID else {
            if binding == .invalid {
                throw NightFlockAccountError.invalidExpectedIdentityBinding
            }
            throw NightFlockAccountError.expectedIdentityMissing
        }
        let client = try provider.client()
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: identityToken,
                    nonce: nonce
                )
            )
            guard session.user.id == expected, Self.hasAppleIdentity(session.user) else {
                try? await client.auth.signOut(scope: .local)
                throw NightFlockAccountError.identityChanged
            }
            persistExpectedLinkedUserID(session.user.id)
        } catch {
            if !(error is NightFlockAccountError) { throw error }
            throw error
        }
    }

    func signOutAfterAccountDeletion() async -> Bool {
        guard let client = try? provider.client() else { return false }
        do {
            try await client.auth.signOut(scope: .local)
            defaults.removeObject(forKey: Self.expectedLinkedUserIDKey)
            return true
        } catch let error as AuthError where error == .sessionMissing {
            defaults.removeObject(forKey: Self.expectedLinkedUserIDKey)
            return true
        } catch {
            return false
        }
    }

    func currentLinkedAccountID() async throws -> UUID? {
        let client = try provider.client()
        let user = try await client.auth.session.user
        guard !user.isAnonymous, Self.hasAppleIdentity(user) else { return nil }
        return user.id
    }

    func signOutLocallyAfterFailedRecovery() async {
        guard let client = try? provider.client() else { return }
        try? await client.auth.signOut(scope: .local)
    }

    nonisolated static func linkFailureMessage(for error: Error) -> String {
        if let accountError = error as? NightFlockAccountError {
            return accountError.localizedDescription
        }
        if let authError = error as? AuthError {
            switch authError.errorCode {
            case .manualLinkingDisabled:
                return "Apple sign-in finished, but account linking is not available yet. Your current account and local data were left unchanged."
            case .oauthProviderNotSupported, .providerDisabled, .unexpectedAudience:
                return "Apple sign-in is not fully configured for this build yet. Your current account and local data were left unchanged."
            case .identityAlreadyExists:
                return "That Apple ID is already linked to another Counting Sheep account. This account was left unchanged."
            default:
                return "Apple sign-in could not link this account. Your current account and local data were left unchanged. \(authError.localizedDescription)"
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return "The connection dropped before Apple sign-in could finish. Your current account was left unchanged."
            default:
                break
            }
        }
        return "Apple sign-in could not link this account. Your current account and local data were left unchanged."
    }

    nonisolated static func makeAppleNonce() throws -> NightFlockAppleNonce {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw NightFlockAccountError.nonceUnavailable
        }
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let rawValue = String(bytes.map { alphabet[Int($0) % alphabet.count] })
        let requestValue = SHA256.hash(data: Data(rawValue.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return NightFlockAppleNonce(rawValue: rawValue, requestValue: requestValue)
    }

    private static func hasAppleIdentity(_ user: User) -> Bool {
        NightFlockAppleIdentityEvidence.isLinked(
            isAnonymous: user.isAnonymous,
            identityProviders: user.identities?.map(\.provider) ?? [],
            primaryProvider: user.appMetadata["provider"]?.stringValue,
            providers: user.appMetadata["providers"]?.arrayValue?.compactMap(\.stringValue) ?? []
        )
    }

    private static func observedSession(for user: User) -> NightFlockObservedAccountSession {
        if user.isAnonymous { return .anonymous }
        if hasAppleIdentity(user) { return .appleLinked(user.id) }
        return .unsupported
    }

    private static func failureError(
        for observed: NightFlockObservedAccountSession,
        binding: NightFlockExpectedIdentity
    ) -> NightFlockAccountError {
        if binding == .invalid { return .invalidExpectedIdentityBinding }
        switch observed {
        case .unsupported:
            return .unsupportedAuthenticatedSession
        case .appleLinked:
            return .identityChanged
        case .anonymous, .missing:
            return .expectedIdentityMissing
        }
    }

    private var expectedLinkedUserID: NightFlockExpectedIdentity {
        NightFlockExpectedIdentityBinding.classify(
            defaults.string(forKey: Self.expectedLinkedUserIDKey)
        )
    }

    private func persistExpectedLinkedUserID(_ id: UUID) {
        guard expectedLinkedUserID.permitsInitialBinding else { return }
        defaults.set(id.uuidString.lowercased(), forKey: Self.expectedLinkedUserIDKey)
    }
}

enum NightFlockInviteCredentialServiceError: LocalizedError {
    case encoding
    case keychain(OSStatus)
    var errorDescription: String? {
        "Counting Sheep could not safely keep this invitation on this phone. No invitation was sent."
    }
}

@MainActor
final class NightFlockInviteCredentialService {
    private let service = "com.ngawangchime.countingsheep.night-flock-invite"
    private let account = "active-invite-credential"

    func load() throws -> NightFlockInviteCredential? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw NightFlockInviteCredentialServiceError.keychain(status)
        }
        return try JSONDecoder().decode(NightFlockInviteCredential.self, from: data)
    }

    func save(_ credential: NightFlockInviteCredential) throws {
        guard let data = try? JSONEncoder().encode(credential) else {
            throw NightFlockInviteCredentialServiceError.encoding
        }
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            ] as CFDictionary
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update)
            guard updateStatus == errSecSuccess else { throw NightFlockInviteCredentialServiceError.keychain(updateStatus) }
        } else if status != errSecSuccess {
            throw NightFlockInviteCredentialServiceError.keychain(status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NightFlockInviteCredentialServiceError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
        ]
    }
}
