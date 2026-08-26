import Foundation
import OSLog
import Supabase

@available(iOS 16.1, *)
@MainActor
final class SupabaseLiveActivityRemoteSink: FocusRunLiveActivityRemoteSink {
    private struct AcceptedResponse: Decodable {
        var accepted: Bool
    }

    private struct CancellationResponse: Decodable {
        var cancelled: Bool
    }

    private let provider: SupabaseClientProviding
    private let authentication: SupabaseAuthenticating
    private let logger = Logger(
        subsystem: "com.ngawangchime.countingsheep",
        category: "LiveActivityTransport"
    )
#if DEBUG
    private var debugRequestAttemptCount = 0
#endif

    init(provider: SupabaseClientProviding, authentication: SupabaseAuthenticating) {
        self.provider = provider
        self.authentication = authentication
    }

    func sync(_ run: FocusRunCloudSync) async {
        await sendWithRetry(operation: "run sync") {
            _ = try await self.authentication.authenticatedUserID()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let client = try self.provider.client()
            let _: AcceptedResponse = try await client.functions.invoke(
                "focus-run-sync",
                options: FunctionInvokeOptions(
                    headers: ["Idempotency-Key": run.idempotencyKey],
                    body: run,
                    encoder: encoder
                )
            )
        }
    }

    func upsert(_ registration: FocusRunLiveActivityPushRegistration) async {
        await sendWithRetry(operation: "registration") {
            _ = try await self.authentication.authenticatedUserID()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let client = try self.provider.client()
            let _: AcceptedResponse = try await client.functions.invoke(
                "live-activity-registration",
                options: FunctionInvokeOptions(
                    headers: ["Idempotency-Key": registration.idempotencyKey ?? registration.activityID],
                    body: registration,
                    encoder: encoder
                )
            )
        }
    }

    func cancel(_ cancellation: FocusRunLiveActivityCancellation) async {
        await sendWithRetry(operation: "cancellation") {
            _ = try await self.authentication.authenticatedUserID()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let client = try self.provider.client()
            let _: CancellationResponse = try await client.functions.invoke(
                "live-activity-cancellation",
                options: FunctionInvokeOptions(
                    headers: ["Idempotency-Key": cancellation.idempotencyKey ?? cancellation.activityID],
                    body: cancellation,
                    encoder: encoder
                )
            )
        }
    }

    private func sendWithRetry(
        operation: String,
        action: @escaping @MainActor () async throws -> Void
    ) async {
        let delays: [Duration] = [.zero, .seconds(2), .seconds(8)]
        for (index, delay) in delays.enumerated() {
            if delay != .zero { try? await Task.sleep(for: delay) }
            guard !Task.isCancelled else { return }
#if DEBUG
            debugRequestAttemptCount += 1
            logger.debug(
                "Network attempt count=\(self.debugRequestAttemptCount) operation=\(operation, privacy: .public) attempt=\(index + 1)"
            )
#endif
            do {
                try await action()
#if DEBUG
                logger.debug(
                    "Network success operation=\(operation, privacy: .public) attempt=\(index + 1)"
                )
#endif
                return
            } catch {
                guard index < delays.count - 1, Self.isTemporary(error) else {
#if DEBUG
                    logger.notice("Supabase \(operation, privacy: .public) unavailable; local run continues. Error type=\(String(describing: type(of: error)), privacy: .public)")
#endif
                    return
                }
            }
        }
    }

    private static func isTemporary(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [
                .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost,
                .dnsLookupFailed, .notConnectedToInternet, .internationalRoamingOff
            ].contains(urlError.code)
        }
        if let functionsError = error as? FunctionsError {
            switch functionsError {
            case .relayError:
                return true
            case .httpError(let code, _):
                return code == 408 || code == 429 || code >= 500
            }
        }
        return false
    }
}
