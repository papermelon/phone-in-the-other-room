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

    func stateV2() async throws -> NightFlockSnapshot? {
        let client = try provider.client()
        let response: NightFlockV2StateResponse = try await client.functions.invoke(
            "night-flock-state",
            options: FunctionInvokeOptions(body: NightFlockV2StateRequest()),
            decoder: decoder
        )
        guard response.schemaVersion == 2 else { throw NightFlockServiceError.unsupportedResponse }
        return response.snapshot
    }

    func sendV2(_ command: NightFlockV2Command) async throws -> NightFlockV2CommandResponse {
        let request = NightFlockV2CommandRequest(command: command)
        let client = try provider.client()
        let response: NightFlockV2CommandResponse = try await client.functions.invoke(
            "night-flock-command",
            options: FunctionInvokeOptions(
                headers: ["Idempotency-Key": command.idempotencyKey],
                body: request
            ),
            decoder: decoder
        )
        guard response.schemaVersion == 2 else { throw NightFlockServiceError.unsupportedResponse }
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

private extension NightFlockV2Command {
    var idempotencyKey: String {
        switch self {
        case let .createParty(_, _, _, key), let .createInvite(key), let .previewInvite(_, key), let .redeemInvite(_, key),
             let .acceptGoal(_, key), let .setLocalSetup(_, _, _, key),
             let .setSharingPreferences(_, _, key), let .setRoutineIdeas(_, _, key),
             let .startChallenge(_, key), let .publishProgress(_, _, _, _, key):
            return key
        }
    }
}
