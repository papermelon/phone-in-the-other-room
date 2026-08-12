import Foundation
import Supabase

actor NightFlockService {
    private let provider: SupabaseClientProviding
    private let decoder: JSONDecoder

    init(provider: SupabaseClientProviding) {
        self.provider = provider
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func state() async throws -> NightFlockSnapshot? {
        let client = try provider.client()
        let response: NightFlockStateResponse = try await client.functions.invoke(
            "night-flock-state",
            options: FunctionInvokeOptions(body: NightFlockStateRequest()),
            decoder: decoder
        )
        guard response.schemaVersion == 1 else { throw NightFlockServiceError.unsupportedResponse }
        return response.snapshot
    }

    func send(_ command: NightFlockCommand) async throws -> NightFlockCommandResponse {
        let request = NightFlockCommandRequest(command: command)
        let client = try provider.client()
        let response: NightFlockCommandResponse = try await client.functions.invoke(
            "night-flock-command",
            options: FunctionInvokeOptions(
                headers: ["Idempotency-Key": command.idempotencyKey],
                body: request
            ),
            decoder: decoder
        )
        guard response.schemaVersion == 1 else { throw NightFlockServiceError.unsupportedResponse }
        return response
    }
}

enum NightFlockServiceError: LocalizedError {
    case unsupportedResponse

    var errorDescription: String? {
        "Slumber Party returned an unsupported response."
    }
}

private extension NightFlockCommand {
    var idempotencyKey: String {
        switch self {
        case let .createFlock(_, _, key), let .createInvite(key), let .revokeInvite(_, key), let .join(_, key),
             let .leave(key), let .setSharing(_, key), let .block(_, key), let .report(_, _, key),
             let .publishCheckIn(_, _, _, key), let .react(_, _, key),
             let .deleteNightFlockData(key), let .deleteAccount(key):
            return key
        }
    }
}
