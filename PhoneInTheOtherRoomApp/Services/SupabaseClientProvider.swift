import Foundation
import Supabase

protocol SupabaseClientProviding: Sendable {
    func client() throws -> SupabaseClient
}

final class ConfiguredSupabaseClientProvider: SupabaseClientProviding, @unchecked Sendable {
    let configuration: SupabaseConfiguration
    private let configuredClient: SupabaseClient

    init(configuration: SupabaseConfiguration) {
        self.configuration = configuration
        self.configuredClient = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey
        )
    }

    func client() throws -> SupabaseClient {
        configuredClient
    }
}

struct UnavailableSupabaseClientProvider: SupabaseClientProviding {
    let error: Error

    func client() throws -> SupabaseClient {
        throw error
    }
}
