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
    case identityTokenMissing
    case nonceUnavailable

    var errorDescription: String? {
        switch self {
        case .identityChanged:
            return "That Apple identity could not be linked without changing this account."
        case .identityTokenMissing:
            return "Apple did not return an identity token. Please try again."
        case .nonceUnavailable:
            return "A secure sign-in request could not be prepared. Please try again."
        }
    }
}

actor NightFlockAccountService {
    private let provider: SupabaseClientProviding

    init(provider: SupabaseClientProviding) {
        self.provider = provider
    }

    func currentState(createAnonymousIfMissing: Bool) async throws -> NightFlockAccountState {
        let client = try provider.client()
        do {
            let user = try await client.auth.session.user
            return Self.hasAppleIdentity(user) ? .linked : .anonymous
        } catch let error as AuthError where error == .sessionMissing {
            guard createAnonymousIfMissing else { return .anonymous }
            _ = try await client.auth.signInAnonymously()
            return .anonymous
        }
    }

    func linkAppleIdentity(identityToken: String, nonce: String) async throws {
        let client = try provider.client()
        let originalUser = try await client.auth.session.user
        let session = try await client.auth.linkIdentityWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: identityToken,
                nonce: nonce
            )
        )
        guard session.user.id == originalUser.id else {
            throw NightFlockAccountError.identityChanged
        }
        guard Self.hasAppleIdentity(session.user) else {
            throw NightFlockAccountError.identityChanged
        }
    }

    func signOutAfterAccountDeletion() async {
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
        user.identities?.contains(where: { $0.provider == "apple" }) == true
    }
}
