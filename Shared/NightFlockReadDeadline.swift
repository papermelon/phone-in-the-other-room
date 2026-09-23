import Foundation

/// Presence reads must give control back to the person when the connection stalls.
/// Commands keep their existing idempotent recovery; a timeout is not a rejection.
enum NightFlockReadDeadline {
    static func run<Value>(
        timeout: Duration = .seconds(12),
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask(operation: operation)
            group.addTask {
                try await Task.sleep(for: timeout)
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            guard let value = try await group.next() else { throw CancellationError() }
            return value
        }
    }
}
