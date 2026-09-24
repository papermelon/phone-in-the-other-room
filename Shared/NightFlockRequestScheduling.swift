import Foundation

struct NightFlockRequestScope: Equatable, Sendable {
    let ownerID: UUID?
    let generation: UInt64
    let transportEpoch: UInt64
    let privacyEpoch: UInt64
}

/// Only concurrent reads share work; completed snapshots are never cached here.
actor NightFlockListReadCoordinator {
    private var active: (id: UUID, scope: NightFlockRequestScope, task: Task<NightFlockV4ListStateResponse, Error>)?
    private var revision: UInt64 = 0

    func invalidate() {
        revision &+= 1
        active = nil
    }

    func read(
        scope: NightFlockRequestScope,
        operation: @escaping @Sendable () async throws -> NightFlockV4ListStateResponse
    ) async throws -> NightFlockV4ListStateResponse {
        let currentRevision = revision
        let flight: (id: UUID, scope: NightFlockRequestScope, task: Task<NightFlockV4ListStateResponse, Error>)
        if let active, active.scope == scope {
            flight = active
        } else {
            flight = (UUID(), scope, Task { try await operation() })
            active = flight
        }
        defer { if active?.id == flight.id { active = nil } }
        let result = await flight.task.result
        try Task.checkCancellation()
        // A mutation makes any older read unsuitable for its follow-up refresh.
        guard currentRevision == revision else { throw CancellationError() }
        return try result.get()
    }
}

/// One drain owns read/send/remove across suspension points. Failed work remains durable.
struct NightFlockOutboxDrainGate {
    private var activeScope: NightFlockRequestScope?
    private var pendingScope: NightFlockRequestScope?
    private var retryScope: NightFlockRequestScope?
    private var failureCount = 0
    private var nextAttempt = Date.distantPast
    private(set) var failed = false

    mutating func begin(scope: NightFlockRequestScope, now: Date = Date()) -> Bool {
        if activeScope != nil {
            pendingScope = scope
            return false
        }
        if retryScope != scope {
            failureCount = 0
            nextAttempt = .distantPast
            retryScope = scope
        }
        guard now >= nextAttempt else { return false }
        activeScope = scope
        failed = false
        return true
    }

    mutating func recordFailure() { if activeScope != nil { failed = true } }

    mutating func finish(now: Date = Date()) -> Bool {
        let shouldDrainAgain = pendingScope != nil && (!failed || pendingScope != activeScope)
        if failed {
            failureCount = min(failureCount + 1, 7)
            nextAttempt = now.addingTimeInterval(min(300, 5 * pow(2, Double(failureCount - 1))))
        } else {
            failureCount = 0
            nextAttempt = .distantPast
        }
        activeScope = nil
        pendingScope = nil
        return shouldDrainAgain
    }
}
