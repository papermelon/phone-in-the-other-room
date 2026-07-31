import Foundation
import OSLog
import Supabase

enum ImpactDataSyncState: Equatable {
    case idle
    case syncing
    case synced
    case unavailable
    case failed
}

actor ImpactDataSyncService {
    private let provider: SupabaseClientProviding?
    private let authentication: SupabaseAuthenticating?
    private let logger = Logger(
        subsystem: "com.ngawangchime.countingsheep",
        category: "ImpactData"
    )

    init(bundle: Bundle = .main) {
        do {
            let configuration = try SupabaseConfiguration.load(bundle: bundle)
            let provider = ConfiguredSupabaseClientProvider(configuration: configuration)
            self.provider = provider
            authentication = SupabaseAuthenticationService(provider: provider)
        } catch {
            provider = nil
            authentication = nil
        }
    }

    func sync(_ records: [ImpactUploadRecord]) async -> ImpactDataSyncState {
        guard !records.isEmpty,
              let provider,
              let authentication else { return .unavailable }
        do {
            _ = try await authentication.authenticatedUserID()
            let client = try provider.client()
            try await client
                .from("impact_nights")
                .upsert(records, onConflict: "user_id,relative_night")
                .execute()
            return .synced
        } catch {
#if DEBUG
            logger.notice(
                "Optional impact sync failed; local history is unchanged. Error type=\(String(describing: type(of: error)), privacy: .public)"
            )
#endif
            return .failed
        }
    }

    func deleteSharedData() async -> ImpactDataSyncState {
        guard let provider,
              let authentication else { return .unavailable }
        do {
            _ = try await authentication.authenticatedUserID()
            let client = try provider.client()
            try await client.rpc("delete_my_impact_data").execute()
            return .synced
        } catch {
#if DEBUG
            logger.notice(
                "Optional impact deletion failed. Error type=\(String(describing: type(of: error)), privacy: .public)"
            )
#endif
            return .failed
        }
    }
}
