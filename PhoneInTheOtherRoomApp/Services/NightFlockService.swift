import Foundation
import os
import Supabase

actor NightFlockService {
    private struct V4RealtimeSubscription {
        var channel: RealtimeChannelV2
        var tasks: [Task<Void, Never>]
    }

    private let provider: SupabaseClientProviding
    private let listReads = NightFlockListReadCoordinator()
    private var requestCount = 0
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

    func registerCampfireDevice(_ registration: CampfireDeviceRegistration) async throws {
        struct Result: Decodable { var accepted: Bool }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let result: Result = try await provider.client().functions.invoke("campfire-device", options: FunctionInvokeOptions(body: registration, encoder: encoder))
        guard result.accepted else { throw NightFlockServiceError.unsupportedResponse }
    }

    func globalCampfireState(gathering: String = "all", cursor: UUID? = nil, channelID: Int = 0) async throws -> GlobalCampfireResponse {
        do {
            let client = try provider.client()
            let options = FunctionInvokeOptions(body: GlobalCampfireStateRequest(gathering: gathering, cursor: cursor, channelID: channelID))
            return try await NightFlockReadDeadline.run {
                try await client.functions.invoke("campfire-global", options: options, decoder: Self.campfireDecoder())
            }
        } catch { throw mapError(error, operation: "campfire-global-state") }
    }

    func campfireProfile(participantID: UUID? = nil, memberID: UUID? = nil) async throws -> CampfireProfileResponse {
        struct Request: Encodable { var command = "detail"; var participantID: UUID?; var memberID: UUID? }
        return try await provider.client().functions.invoke("campfire-global", options: FunctionInvokeOptions(
            body: Request(participantID: participantID, memberID: memberID)), decoder: Self.campfireDecoder())
    }

    func sendGlobalCampfire(_ command: GlobalCampfireCommand, ownerID: UUID) async throws -> GlobalCampfireResponse {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        return try await provider.client().functions.invoke("campfire-global", options: FunctionInvokeOptions(
            headers: ["X-Campfire-Owner": ownerID.uuidString.lowercased()], body: command, encoder: encoder), decoder: Self.campfireDecoder())
    }

    private static func campfireDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { value in
            let text = try value.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: value.codingPath, debugDescription: "Invalid Campfire timestamp"))
        }
        return decoder
    }

    func sendPasture(_ command: SharedPastureCommand) async throws -> SharedPastureCommandResponse {
        do {
            return try await invoke("night-flock-command", headers: commandHeaders(idempotencyKey: command.idempotencyKey),
                                    body: command, operation: "command-pasture")
        } catch { throw mapError(error, operation: "command-pasture") }
    }

    func partyConnections(_ request: SlumberPartyConnectionsRequest) async throws -> SlumberPartyConnections {
        struct Parameters: Encodable { var p_request: SlumberPartyConnectionsRequest }
        do {
            let response = try await provider.client().rpc("slumber_party_connections_v1", params: Parameters(p_request: request)).execute()
            let value = try Self.campfireDecoder().decode(SlumberPartyConnections.self, from: response.data)
            guard value.version == 1 else { throw NightFlockServiceError.unsupportedResponse }
            return value
        } catch let error as PostgrestError {
            switch error.message {
            case "party_full": throw SlumberPartyConnectionError.full
            case "party_limit": throw SlumberPartyConnectionError.limit
            case "rate_limited": throw SlumberPartyConnectionError.rateLimited
            case "invite_unavailable", "already_member", "membership_required": throw SlumberPartyConnectionError.unavailable
            default: throw SlumberPartyConnectionError.offline
            }
        } catch { throw SlumberPartyConnectionError.offline }
    }

    func stateV4List(scope: NightFlockRequestScope) async throws -> NightFlockV4ListStateResponse {
        try await listReads.read(scope: scope) {
            try await self.stateV4(request: NightFlockV4ListStateRequest(), operation: "state-v4-list")
        }
    }

    func stateV4Party(
        partyID: UUID,
        cursor: NightFlockV4PaginationCursor? = nil
    ) async throws -> NightFlockV4PartyStateResponse {
        let response: NightFlockV4PartyStateResponse = try await stateV4(
            request: NightFlockV4PartyStateRequest(partyID: partyID, cursor: cursor),
            operation: "state-v4-party"
        )
        // A detail read without a party cannot finish any of its loading views.
        guard response.party?.summary.partyID == partyID else {
            throw NightFlockServiceError.unsupportedResponse
        }
        return response
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
        let isCommand = function == "night-flock-command"
        if isCommand { await listReads.invalidate() }
        let startedAt = ContinuousClock.now
        requestCount += 1
        let requestNumber = requestCount
        let requestID = headers["X-Request-ID"] ?? UUID().uuidString.lowercased()
        let logger = self.logger
        let decoder = self.decoder
        var outcome = "error"
        defer {
            let elapsedMs = Self.milliseconds(startedAt.duration(to: .now))
            logger.info("event=requestCompleted requestID=\(requestID, privacy: .public) operation=\(operation, privacy: .public) requestNumber=\(requestNumber) elapsedMs=\(elapsedMs) outcome=\(outcome, privacy: .public)")
        }
        let execute: @Sendable () async throws -> Response = {
            try await client.functions.invoke(function, options: FunctionInvokeOptions(headers: headers, body: body)) { data, _ in
                let decodeStartedAt = ContinuousClock.now
                defer {
                    let decodeMs = Self.milliseconds(decodeStartedAt.duration(to: .now))
                    logger.info("event=responseDecoded requestID=\(requestID, privacy: .public) operation=\(operation, privacy: .public) decodeMs=\(decodeMs)")
                }
                return try decoder.decode(Response.self, from: data)
            }
        }
        do {
            let result = try await (function == "night-flock-state" ? NightFlockReadDeadline.run(operation: execute) : execute())
            if isCommand { await listReads.invalidate() }
            outcome = "success"
            return result
        } catch {
            if isCommand { await listReads.invalidate() }
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                outcome = "cancelled"
                throw CancellationError()
            }
            if error is DecodingError { outcome = "decodeError" }
            // Keep the outgoing ID even when the gateway cannot return an envelope.
            if let failure = error as? FunctionsError {
                switch failure {
                case .httpError(let status, let data):
                    throw NightFlockRemoteError.decode(statusCode: status, data: data, headerRequestID: requestID)
                case .relayError:
                    throw NightFlockRemoteError.network(requestID: requestID)
                }
            }
            if let error = error as? URLError {
                throw NightFlockRemoteError.network(requestID: requestID, reason: error.code)
            }
            throw error
        }
    }

    private nonisolated static func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1e15
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
        } else if let error = error as? URLError {
            if error.code == .cancelled { return CancellationError() }
            remote = .network(reason: error.code)
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
