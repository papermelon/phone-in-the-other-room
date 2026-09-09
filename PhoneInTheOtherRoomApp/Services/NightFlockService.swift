import Foundation
import os
import Supabase

actor NightFlockService {
    private struct V4RealtimeSubscription {
        var channel: RealtimeChannelV2
        var tasks: [Task<Void, Never>]
    }

    private let provider: SupabaseClientProviding
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.ngawangchime.countingsheep", category: "NightFlock")
    private var v4RealtimeSubscriptions: [UUID: V4RealtimeSubscription] = [:]

    init(provider: SupabaseClientProviding) {
        self.provider = provider
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func state() async throws -> NightFlockSnapshot? {
        try await invokeState(schemaVersion: 1, request: NightFlockStateRequest(), operation: "state-v1")
    }

    func send(_ command: NightFlockCommand) async throws -> NightFlockCommandResponse {
        let request = NightFlockCommandRequest(command: command)
        do {
            let envelope: NightFlockCommandEnvelope = try await invoke(
                "night-flock-command",
                headers: commandHeaders(idempotencyKey: command.idempotencyKey),
                body: request,
                operation: "command-v1"
            )
            guard envelope.schemaVersion == 1 else { throw NightFlockServiceError.unsupportedResponse }
            logSuccess(operation: "command-v1", requestID: envelope.requestID)
            return envelope.v1
        } catch { throw mapError(error, operation: "command-v1") }
    }

    func stateV2() async throws -> NightFlockSnapshot? {
        try await invokeState(schemaVersion: 2, request: NightFlockV2StateRequest(), operation: "state-v2")
    }

    func sendV2(_ command: NightFlockV2Command) async throws -> NightFlockV2CommandResponse {
        let request = NightFlockV2CommandRequest(command: command)
        do {
            let envelope: NightFlockV2CommandEnvelope = try await invoke(
                "night-flock-command",
                headers: commandHeaders(idempotencyKey: command.idempotencyKey),
                body: request,
                operation: "command-v2"
            )
            guard envelope.schemaVersion == 2 else { throw NightFlockServiceError.unsupportedResponse }
            logSuccess(operation: "command-v2", requestID: envelope.requestID)
            return envelope.v2
        } catch { throw mapError(error, operation: "command-v2") }
    }

    func stateV3() async throws -> NightFlockSnapshot? {
        try await invokeState(schemaVersion: 3, request: NightFlockV3StateRequest(), operation: "state-v3")
    }

    func sendV3(_ command: NightFlockV3Command) async throws -> NightFlockV3CommandResponse {
        let request = NightFlockV3CommandRequest(command: command)
        do {
            let envelope: NightFlockV3CommandEnvelope = try await invoke(
                "night-flock-command",
                headers: commandHeaders(idempotencyKey: command.idempotencyKey),
                body: request,
                operation: "command-v3"
            )
            guard envelope.schemaVersion == 3 else { throw NightFlockServiceError.unsupportedResponse }
            logSuccess(operation: "command-v3", requestID: envelope.requestID)
            return envelope.v3
        } catch { throw mapError(error, operation: "command-v3") }
    }

    func stateV4List() async throws -> NightFlockV4ListStateResponse {
        try await stateV4(request: NightFlockV4ListStateRequest(), operation: "state-v4-list")
    }

    func stateV4Party(
        partyID: UUID,
        cursor: NightFlockV4PaginationCursor? = nil
    ) async throws -> NightFlockV4PartyStateResponse {
        try await stateV4(
            request: NightFlockV4PartyStateRequest(partyID: partyID, cursor: cursor),
            operation: "state-v4-party"
        )
    }

    func sendV4(_ command: NightFlockV4Command) async throws -> NightFlockV4CommandResponse {
        let request = NightFlockV4CommandRequest(command: command)
        do {
            let envelope: NightFlockV4CommandResponse = try await invoke(
                "night-flock-command",
                headers: commandHeaders(idempotencyKey: command.idempotencyKey),
                body: request,
                operation: "command-v4"
            )
            guard envelope.schemaVersion == NightFlockV4Rules.schemaVersion else {
                throw NightFlockServiceError.unsupportedResponse
            }
            logSuccess(operation: "command-v4", requestID: envelope.requestID)
            return envelope
        } catch { throw mapError(error, operation: "command-v4") }
    }

    func stateSharedHabits(
        partyID: UUID,
        cursor: String? = nil
    ) async throws -> NightFlockSharedHabitsStateResponse {
        try await stateV4(
            request: NightFlockSharedHabitsStateRequest(partyID: partyID, cursor: cursor),
            operation: "state-shared-habits"
        )
    }

    /// V2 plans and receipts have their own cursor so a party-lifetime archive
    /// cannot be truncated by the legacy shared-habits page.
    func stateSharedNights(
        partyID: UUID,
        cursor: String? = nil
    ) async throws -> NightFlockSharedHabitsStateResponse {
        try await stateV4(
            request: NightFlockSharedHabitsStateRequest(partyID: partyID, cursor: cursor, scope: "sharedNights"),
            operation: "state-shared-nights"
        )
    }

    func sendSharedHabits(
        _ command: NightFlockSharedHabitsCommand
    ) async throws -> NightFlockSharedHabitsCommandResponse {
        let request = NightFlockSharedHabitsCommandRequest(command: command)
        do {
            let response: NightFlockSharedHabitsCommandResponse = try await invoke(
                "night-flock-command",
                headers: commandHeaders(idempotencyKey: sharedHabitsIdempotencyKey(for: command)),
                body: request,
                operation: "command-shared-habits"
            )
            guard response.accepted else { throw NightFlockServiceError.unsupportedResponse }
            return response
        } catch { throw mapError(error, operation: "command-shared-habits") }
    }

    /// Realtime is merely a prompt to reload the server-authoritative party
    /// projection. No raw Realtime payload is decoded into product state.
    func startV4Realtime(
        partyID: UUID,
        onSignal: @escaping @Sendable () async -> Void
    ) async throws {
        guard v4RealtimeSubscriptions[partyID] == nil else { return }
        let client = try provider.client()
        let channel = client.realtimeV2.channel("night-flock-v4-\(partyID.uuidString.lowercased())")
        let statusChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "night_flock_v4_statuses",
            filter: .eq("party_id", value: partyID.uuidString.lowercased())
        )
        let partySignals = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "night_flock_v4_party_signals",
            filter: .eq("party_id", value: partyID.uuidString.lowercased())
        )
        // Reactions do not carry party_id. Row-level security is the boundary;
        // the following refresh still re-reads the selected party through RPC.
        let reactionChanges = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "night_flock_v4_reactions"
        )
        try await channel.subscribeWithError()
        v4RealtimeSubscriptions[partyID] = V4RealtimeSubscription(
            channel: channel,
            tasks: [
                Task { for await _ in statusChanges { await onSignal() } },
                Task { for await _ in partySignals { await onSignal() } },
                Task { for await _ in reactionChanges { await onSignal() } },
            ]
        )
    }

    /// Removes one selected party's signal stream. A list refresh may leave
    /// streams open for other active parties so silent cheers still reach an
    /// already-running Wind Down.
    func stopV4Realtime(partyID: UUID) async {
        guard let subscription = v4RealtimeSubscriptions.removeValue(forKey: partyID) else { return }
        subscription.tasks.forEach { $0.cancel() }
        guard let client = try? provider.client() else {
            await subscription.channel.unsubscribe()
            return
        }
        await client.realtimeV2.removeChannel(subscription.channel)
    }

    func stopV4Realtime() async {
        let partyIDs = Array(v4RealtimeSubscriptions.keys)
        for partyID in partyIDs {
            await stopV4Realtime(partyID: partyID)
        }
    }

    private func stateV4<Response: Decodable, Request: Encodable>(
        request: Request,
        operation: String
    ) async throws -> Response {
        do {
            let envelope: NightFlockV4StateEnvelope<Response> = try await invoke(
                "night-flock-state",
                headers: ["X-Request-ID": UUID().uuidString.lowercased()],
                body: request,
                operation: operation
            )
            guard envelope.schemaVersion == NightFlockV4Rules.schemaVersion else {
                throw NightFlockServiceError.unsupportedResponse
            }
            logSuccess(operation: operation, requestID: envelope.requestID)
            return envelope.snapshot
        } catch { throw mapError(error, operation: operation) }
    }

    private func sharedHabitsIdempotencyKey(
        for command: NightFlockSharedHabitsCommand
    ) -> String {
        switch command {
        case let .acceptAgreement(_, _, _, key),
             let .publish(_, _, _, key),
             let .deleteSource(_, _, key),
             let .deleteAll(_, key),
             let .migrate(_, _, key),
             let .publishNightPlan(_, key),
             let .cancelNightPlan(_, key),
             let .publishNightReceipt(_, key):
            return key
        }
    }

    private func invokeState<Request: Encodable>(schemaVersion: Int, request: Request, operation: String) async throws -> NightFlockSnapshot? {
        do {
            let envelope: NightFlockStateEnvelope = try await invoke(
                "night-flock-state",
                headers: ["X-Request-ID": UUID().uuidString.lowercased()],
                body: request,
                operation: operation
            )
            guard envelope.schemaVersion == schemaVersion else { throw NightFlockServiceError.unsupportedResponse }
            logSuccess(operation: operation, requestID: envelope.requestID)
            return envelope.snapshot
        } catch { throw mapError(error, operation: operation) }
    }

    private func invoke<Response: Decodable, Body: Encodable>(
        _ function: String,
        headers: [String: String],
        body: Body,
        operation: String
    ) async throws -> Response {
        let client = try provider.client()
        return try await client.functions.invoke(
            function,
            options: FunctionInvokeOptions(headers: headers, body: body),
            decoder: decoder
        )
    }

    private func commandHeaders(idempotencyKey: String) -> [String: String] {
        ["Idempotency-Key": idempotencyKey, "X-Request-ID": UUID().uuidString.lowercased()]
    }

    private func mapError(_ error: Error, operation: String) -> Error {
        if let error = error as? NightFlockRemoteError {
            logFailure(error, operation: operation)
            return error
        }
        let remote: NightFlockRemoteError
        if let functionsError = error as? FunctionsError {
            switch functionsError {
            case .httpError(let status, let data):
                remote = NightFlockRemoteError.decode(statusCode: status, data: data)
            case .relayError:
                remote = .network()
            }
        } else if error is URLError {
            remote = .network()
        } else {
            return error
        }
        logFailure(remote, operation: operation)
        return remote
    }

    private func logSuccess(operation: String, requestID: String?) {
        let safeID = requestID.flatMap { UUID(uuidString: $0)?.uuidString.lowercased() } ?? UUID().uuidString.lowercased()
        logger.info("requestID=\(safeID, privacy: .public) code=ok operation=\(operation, privacy: .public) status=200")
    }

    private func logFailure(_ error: NightFlockRemoteError, operation: String) {
        let fields = NightFlockDiagnosticRecord(
            requestID: error.requestID,
            code: error.code.rawValue,
            operation: operation,
            status: error.statusCode
        )
        logger.error("requestID=\(fields.requestID, privacy: .public) code=\(fields.code, privacy: .public) operation=\(fields.operation, privacy: .public) status=\(fields.status, privacy: .public)")
    }
}

enum NightFlockServiceError: LocalizedError {
    case unsupportedResponse

    var errorDescription: String? {
        "Slumber Party returned an unsupported response."
    }
}

private struct NightFlockStateEnvelope: Decodable {
    let schemaVersion: Int
    let requestID: String?
    let snapshot: NightFlockSnapshot?
}

private struct NightFlockCommandEnvelope: Decodable {
    let schemaVersion: Int
    let requestID: String?
    let accepted: Bool
    let inviteCode: String?
    let inviteID: UUID?
    let invitePreview: NightFlockInvitePreview?
    let snapshot: NightFlockSnapshot?

    var v1: NightFlockCommandResponse {
        NightFlockCommandResponse(schemaVersion: schemaVersion, accepted: accepted, inviteCode: inviteCode, inviteID: inviteID, snapshot: snapshot)
    }

    var v2: NightFlockV2CommandResponse {
        NightFlockV2CommandResponse(schemaVersion: schemaVersion, accepted: accepted, inviteCode: inviteCode, inviteID: inviteID, invitePreview: invitePreview, snapshot: snapshot)
    }

    var v3: NightFlockV3CommandResponse {
        NightFlockV3CommandResponse(schemaVersion: schemaVersion, accepted: accepted, snapshot: snapshot)
    }
}

private typealias NightFlockV2CommandEnvelope = NightFlockCommandEnvelope
private typealias NightFlockV3CommandEnvelope = NightFlockCommandEnvelope

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
        case let .createParty(_, _, _, key), let .createInvite(_, _, key), let .replaceInvite(_, _, _, key),
             let .previewInvite(_, key), let .redeemInvite(_, key),
             let .acceptGoal(_, key), let .setLocalSetup(_, _, _, key),
             let .setSharingPreferences(_, _, key), let .setRoutineIdeas(_, _, key),
             let .startChallenge(_, key), let .publishProgress(_, _, _, _, key):
            return key
        }
    }
}

private extension NightFlockV3Command {
    var idempotencyKey: String {
        switch self {
        case let .setSharingPreferences(_, key), let .publishNightMetrics(_, _, _, _, _, _, _, _, key),
             let .acknowledgeGrant(_, key):
            return key
        }
    }
}

private extension NightFlockV4Command {
    var idempotencyKey: String {
        switch self {
        case let .createParty(_, _, key), let .renameParty(_, _, key), let .startRound(_, _, key),
             let .createInvite(_, key), let .replaceInvite(_, _, key), let .revokeInvite(_, _, key),
             let .retrieveInvite(_, key), let .previewInvite(_, key), let .redeemInvite(_, key),
             let .leaveParty(_, key), let .deleteParty(_, key),
             let .blockMember(_, _, key), let .reportMember(_, _, _, key), let .deleteAccount(key),
             let .cheerMember(_, _, _, key), let .cheerMembershipMember(_, _, _, _, key),
             let .updatePublicProfile(_, _, _, _, _, key), let .publishStatus(_, _, _, _, key), let .publishMembershipStatus(_, _, _, _, key),
             let .completeBackfill(_, _, _, key), let .react(_, _, _, key), let .reactMembership(_, _, _, key), let .acknowledgeGrant(_, key), let .acknowledgeUpdateCheer(_, _, key):
            return key
        case let .publishActivity(record):
            return record.idempotencyKey
        }
    }
}
