import Foundation
import Supabase

extension NightFlockAccountService {
    func signInWithPassword(identifier: String, password: String) async throws {
        let client = try provider.client()
        let identifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let session: Session
        if identifier.contains("@"), !identifier.hasPrefix("@") {
            session = try await client.auth.signIn(email: identifier, password: password)
        } else {
            guard let username = AccountUsername.normalized(identifier) else { throw AccountCredentialError.invalidCredentials }
            struct Body: Encodable { let username: String; let password: String }
            struct Tokens: Decodable { let access_token: String; let refresh_token: String }
            let tokens: Tokens = try await client.functions.invoke("account-password-login",
                options: FunctionInvokeOptions(body: Body(username: username, password: password)))
            session = try await client.auth.setSession(accessToken: tokens.access_token, refreshToken: tokens.refresh_token)
        }
        try await acceptCredentialSession(session.user)
    }

    func registerPassword(email: String, password: String, username: String) async throws -> Bool {
        guard let username = AccountUsername.normalized(username) else { throw AccountCredentialError.invalidUsername }
        guard expectedLinkedUserID == .absent else { throw AccountCredentialError.differentAccount }
        let response = try await provider.client().auth.signUp(email: email, password: password,
            data: ["requested_username": .string(username)])
        guard let session = response.session else { return false }
        try await acceptCredentialSession(session.user)
        return true
    }

    func verifyEmailCode(email: String, code: String, recovery: Bool = false, emailChange: Bool = false) async throws {
        let response = try await provider.client().auth.verifyOTP(email: email, token: code,
            type: recovery ? .recovery : (emailChange ? .emailChange : .signup))
        // Secure email changes can require confirmations for both addresses.
        // Supabase may acknowledge the first code without issuing a session;
        // that is progress, not proof that the address has changed.
        if let user = response.session?.user {
            try await acceptCredentialSession(user)
        } else if !emailChange {
            throw AccountCredentialError.verifyEmail
        }
    }

    func resendVerification(email: String) async throws {
        try await provider.client().auth.resend(email: email, type: .signup)
    }

    func sendPasswordRecovery(email: String) async throws {
        try await provider.client().auth.resetPasswordForEmail(email)
    }

    func changePassword(_ password: String, nonce: String? = nil) async throws {
        guard let expected = try await currentLinkedAccountID() else { throw AccountCredentialError.verifyEmail }
        let user = try await provider.client().auth.update(user: UserAttributes(password: password, nonce: nonce))
        guard user.id == expected else { throw AccountCredentialError.differentAccount }
        // Other devices must reauthenticate after credential recovery/change.
        try await provider.client().auth.signOut(scope: .others)
    }

    func sendPasswordChangeCode() async throws { try await provider.client().auth.reauthenticate() }

    func changeRecoveryEmail(_ email: String) async throws {
        guard let expected = try await currentLinkedAccountID() else { throw AccountCredentialError.verifyEmail }
        let user = try await provider.client().auth.update(user: UserAttributes(email: email))
        guard user.id == expected else { throw AccountCredentialError.differentAccount }
    }

    func claimUsername(_ raw: String) async throws {
        guard let name = AccountUsername.normalized(raw) else { throw AccountCredentialError.invalidUsername }
        struct Parameters: Encodable { let p_action = "claim"; let p_username: String }
        do {
            _ = try await provider.client().rpc("account_username_v1", params: Parameters(p_username: name)).execute()
        } catch let error as PostgrestError {
            switch error.message {
            case "account_username_unavailable": throw AccountCredentialError.usernameUnavailable
            case "account_username_already_claimed": throw AccountCredentialError.usernameAlreadyClaimed
            case "account_username_invalid", "account_username_reserved": throw AccountCredentialError.invalidUsername
            default: throw error
            }
        }
    }

    func credentialProfile() async throws -> AccountCredentialProfile {
        let client = try provider.client()
        let user = try await client.auth.user()
        guard Self.hasSupportedIdentity(user), user.id == (try await currentLinkedAccountID()) else {
            throw AccountCredentialError.verifyEmail
        }
        struct Parameters: Encodable { let p_action = "get" }
        struct Reply: Decodable { let username: String? }
        // A username lookup is secondary to the verified sign-in methods.
        // Keep Apple visible if that separate endpoint is temporarily unavailable.
        let reply: Reply? = try? await client.rpc("account_username_v1", params: Parameters()).execute().value
        return AccountCredentialProfile(id: user.id, email: user.email, username: reply?.username,
            hasApple: user.identities?.contains { $0.provider == "apple" } == true,
            hasEmail: user.identities?.contains { $0.provider == "email" } == true,
            usernameLookupSucceeded: reply != nil)
    }

    func connectApple(identityToken: String, nonce: String) async throws {
        guard let owner = try await currentLinkedAccountID() else { throw AccountCredentialError.verifyEmail }
        let session = try await provider.client().auth.linkIdentityWithIdToken(credentials:
            OpenIDConnectCredentials(provider: .apple, idToken: identityToken, nonce: nonce))
        guard session.user.id == owner else {
            try? await provider.client().auth.signOut(scope: .local)
            throw AccountCredentialError.differentAccount
        }
    }

    private func acceptCredentialSession(_ user: User) async throws {
        guard Self.hasSupportedIdentity(user) else { throw AccountCredentialError.verifyEmail }
        guard expectedLinkedUserID == .absent || expectedLinkedUserID.validUserID == user.id else {
            try? await provider.client().auth.signOut(scope: .local)
            throw AccountCredentialError.differentAccount
        }
        persistExpectedLinkedUserID(user.id)
    }
}
