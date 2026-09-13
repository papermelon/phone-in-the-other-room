import Foundation
import Supabase

enum FarmBackupRemoteError: Error { case headChanged }

/// Uses the same Supabase client/session as the existing account and party paths.
actor FarmBackupService {
    private var usesAccountSync = false
    private let provider: SupabaseClientProviding
    private let configuration: SupabaseConfiguration

    init(provider: ConfiguredSupabaseClientProvider) {
        self.provider = provider
        self.configuration = provider.configuration
    }

    func acceptAccountSync(owner: UUID, authorization: @escaping @MainActor @Sendable () -> Bool) async throws {
        usesAccountSync = true
        _ = try await request(FarmBackupCommand(action: "accept"), owner: owner, authorization: authorization)
    }

    func lookup(owner: UUID, revisionID: UUID? = nil,
                authorization: @escaping @MainActor @Sendable () -> Bool) async throws -> FarmBackupLookup {
        let data = try await request(FarmBackupCommand(action: revisionID == nil ? "lookup" : "read",
                                                       revisionID: revisionID), owner: owner, authorization: authorization)
        let result = try JSONDecoder().decode(FarmBackupLookup.self, from: data)
        guard ["farm_save_v1", "farm_account_sync_v1"].contains(result.capability) else { throw FarmSaveError.unsupportedSchema }
        return result
    }

    func send(_ command: FarmBackupCommand, owner: UUID,
              authorization: @escaping @MainActor @Sendable () -> Bool) async throws -> FarmBackupReceipt {
        try JSONDecoder().decode(FarmBackupReceipt.self, from: await request(command, owner: owner, authorization: authorization))
    }

    private func request(_ command: FarmBackupCommand, owner: UUID,
              authorization: @escaping @MainActor @Sendable () -> Bool) async throws -> Data {
        guard await authorization() else { throw FarmSaveError.unavailable }
        if let payload = command.payload {
            _ = try FarmBackupPayload.decodeRemote(JSONEncoder().encode(payload))
        }
        let client = try provider.client()
        let session: Session
        do {
            session = try await client.auth.session
        } catch is AuthError {
            // A missing or rejected Auth session needs an explicit sign-in;
            // network failures remain eligible for the bounded retry loop.
            throw NightFlockAccountError.reauthenticationRequired
        }
        let user = session.user
        guard user.id == owner, !user.isAnonymous else { throw NightFlockAccountError.identityChanged }
        struct Parameters: Encodable { var c: FarmBackupCommand }
        // SupabaseClient's request adapter overwrites Authorization with its
        // latest session, even when set explicitly on a query. Use a stateless
        // PostgREST transport to pin this request to the checked account.
        let transport = PostgrestClient(url: configuration.url.appendingPathComponent("rest/v1"),
            headers: ["apikey": configuration.publishableKey, "Authorization": "Bearer \(session.accessToken)"])
        guard await authorization() else { throw FarmSaveError.unavailable }
        let bytes: Data
        do {
            let rpc = usesAccountSync
                ? (command.action == "read" ? "farm_account_sync_revision_v1" : "farm_account_sync_v1")
                : (command.action == "read" ? "farm_save_revision_v1" : "farm_save_v1")
            bytes = try await transport.rpc(rpc,
                params: Parameters(c: command)).execute().data
        } catch let error as PostgrestError where error.message == "farm_head_changed" {
            throw FarmBackupRemoteError.headChanged
        }
        var root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] ?? [:]
        // Postgres timestamps belong to the transport envelope. Farm payload
        // dates retain the established Swift Codable reference-date format.
        func revision(_ value: Any?) throws -> Any? {
            guard var object = value as? [String: Any] else { return value }
            if let payload = object["payload"] {
                _ = try FarmBackupPayload.decodeRemote(JSONSerialization.data(withJSONObject: payload))
            }
            if let raw = object["createdAt"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let date = formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
                guard let date else { throw FarmSaveError.corrupt }
                object["createdAt"] = date.timeIntervalSinceReferenceDate
            }
            return object
        }
        root["head"] = try revision(root["head"])
        root["revision"] = try revision(root["revision"])
        if let revisions = root["revisions"] as? [[String: Any]] {
            root["revisions"] = try revisions.map { try revision($0) }
        }
        return try JSONSerialization.data(withJSONObject: root)
    }
}
