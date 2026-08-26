import Foundation
import Supabase

protocol SupabaseAuthenticating: Sendable {
    func authenticatedUserID() async throws -> UUID
}

actor SupabaseAuthenticationService: SupabaseAuthenticating {
    private let provider: SupabaseClientProviding

    init(provider: SupabaseClientProviding) {
        self.provider = provider
    }

    func authenticatedUserID() async throws -> UUID {
        let client = try provider.client()
        do {
            // This restores persisted auth and refreshes it when necessary.
            return try await client.auth.session.user.id
        } catch let error as AuthError where error == .sessionMissing {
            // A network/refresh failure is deliberately not treated as a missing account;
            // only an actual absent session may create a new anonymous identity.
            return try await client.auth.signInAnonymously().user.id
        }
    }
}
