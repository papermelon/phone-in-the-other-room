import XCTest

final class NightFlockRequestSchedulingTests: XCTestCase {
    private let scope = NightFlockRequestScope(ownerID: UUID(), generation: 1, transportEpoch: 2, privacyEpoch: 3)

    func testConcurrentReadsShareOneRequestAndCompletedReadsAreNotCached() async throws {
        let coordinator = NightFlockListReadCoordinator()
        let started = expectation(description: "read started")
        let release = ReadRelease()
        let first = Task {
            try await coordinator.read(scope: scope) {
                started.fulfill()
                await release.wait()
                return .init(parties: [], sharedHabitsVersion: 1)
            }
        }
        await fulfillment(of: [started], timeout: 1)
        let joined = Task {
            try await coordinator.read(scope: scope) {
                XCTFail("Concurrent list read must join the pending request")
                return .init(parties: [])
            }
        }
        // Let the joining task enter the coordinator before releasing the read.
        for _ in 0..<20 { await Task.yield() }
        await release.resume()
        let firstResult = try await first.value
        let joinedResult = try await joined.value
        XCTAssertEqual(firstResult.sharedHabitsVersion, 1)
        XCTAssertEqual(joinedResult.sharedHabitsVersion, 1)
        let fresh = try await coordinator.read(scope: scope) { .init(parties: [], sharedHabitsVersion: 2) }
        XCTAssertEqual(fresh.sharedHabitsVersion, 2)
    }

    func testOwnerAndPrivacyChangesDoNotJoinAnOlderReadAndMutationInvalidatesIt() async throws {
        let coordinator = NightFlockListReadCoordinator()
        let started = expectation(description: "old read started")
        let release = ReadRelease()
        let old = Task {
            try await coordinator.read(scope: scope) {
                started.fulfill()
                await release.wait()
                return .init(parties: [])
            }
        }
        await fulfillment(of: [started], timeout: 1)
        for changed in [
            NightFlockRequestScope(ownerID: UUID(), generation: 1, transportEpoch: 2, privacyEpoch: 3),
            NightFlockRequestScope(ownerID: scope.ownerID, generation: 1, transportEpoch: 2, privacyEpoch: 4),
            NightFlockRequestScope(ownerID: scope.ownerID, generation: 1, transportEpoch: 3, privacyEpoch: 3)
        ] {
            let fresh = try await coordinator.read(scope: changed) { .init(parties: [], sharedHabitsVersion: 2) }
            XCTAssertEqual(fresh.sharedHabitsVersion, 2)
        }
        await coordinator.invalidate()
        let afterMutation = try await coordinator.read(scope: scope) { .init(parties: [], sharedHabitsVersion: 3) }
        XCTAssertEqual(afterMutation.sharedHabitsVersion, 3)
        await release.resume()
        do { _ = try await old.value; XCTFail("Pre-mutation result must not be applied") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testLateAcknowledgementAndFailureLeaveNewerQueuedActivityIntact() async throws {
        let suite = "NightFlockRequestSchedulingTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let outbox = NightFlockOutboxService(defaults: defaults)
        let original = NightFlockV4OutboxSourceRecord(source: .init(
            sourceEventID: UUID(), kind: .windDown, outcome: .completed,
            startedAt: Date(timeIntervalSince1970: 0), endedAt: Date(timeIntervalSince1970: 60),
            windDownMinutes: 1, phoneAwayMinutes: 0, statusRevision: 1
        ), origin: .live, idempotencyKey: "stable-first")
        await outbox.enqueueV4(original, epoch: 0)
        await outbox.markV4Attempt(original, epoch: 0)
        let retry = await outbox.v4Records()
        XCTAssertEqual(retry.first?.idempotencyKey, original.idempotencyKey)
        XCTAssertEqual(retry.first?.attemptCount, 1)
        var newer = original
        newer.source.statusRevision = 2
        newer.idempotencyKey = "stable-second"
        await outbox.enqueueV4(newer, epoch: 0)
        await outbox.removeV4(original, epoch: 0)
        await outbox.markV4Attempt(original, epoch: 0)
        let remaining = await outbox.v4Records()
        XCTAssertEqual(remaining.first?.source.statusRevision, 2)
        XCTAssertEqual(remaining.first?.attemptCount, 1)
        let reopened = NightFlockOutboxService(defaults: defaults)
        let persisted = await reopened.v4Records()
        XCTAssertEqual(persisted, remaining)
        await outbox.removeV4(newer, epoch: 0)
        let empty = await outbox.v4Records()
        XCTAssertTrue(empty.isEmpty)
    }

    func testFailureFromBeforeAMutationCannotReplaceItsFreshResult() async throws {
        let coordinator = NightFlockListReadCoordinator()
        let started = expectation(description: "old read started")
        let release = ReadRelease()
        let old = Task {
            try await coordinator.read(scope: scope) {
                started.fulfill()
                await release.wait()
                throw URLError(.timedOut)
            }
        }
        await fulfillment(of: [started], timeout: 1)
        await coordinator.invalidate()
        _ = try await coordinator.read(scope: scope) { .init(parties: []) }
        await release.resume()
        do { _ = try await old.value; XCTFail("Superseded errors must not replace a fresh result") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testDrainSerializesTrailingWorkAndBacksOffFailuresWithoutDroppingIt() {
        var gate = NightFlockOutboxDrainGate()
        let now = Date(timeIntervalSince1970: 1000)
        XCTAssertTrue(gate.begin(scope: scope, now: now))
        XCTAssertFalse(gate.begin(scope: scope, now: now))
        XCTAssertTrue(gate.finish(now: now))
        XCTAssertTrue(gate.begin(scope: scope, now: now))
        gate.recordFailure()
        XCTAssertFalse(gate.begin(scope: scope, now: now))
        XCTAssertFalse(gate.finish(now: now))
        XCTAssertFalse(gate.begin(scope: scope, now: now.addingTimeInterval(4)))
        XCTAssertTrue(gate.begin(scope: scope, now: now.addingTimeInterval(5)))
        gate.recordFailure()
        XCTAssertFalse(gate.finish(now: now.addingTimeInterval(5)))
        XCTAssertFalse(gate.begin(scope: scope, now: now.addingTimeInterval(14)))
        XCTAssertTrue(gate.begin(scope: scope, now: now.addingTimeInterval(15)))
        XCTAssertFalse(gate.finish(now: now.addingTimeInterval(15)))
        XCTAssertTrue(gate.begin(scope: scope, now: now.addingTimeInterval(15)))
        let changed = NightFlockRequestScope(ownerID: UUID(), generation: 2, transportEpoch: 2, privacyEpoch: 3)
        XCTAssertFalse(gate.begin(scope: changed, now: now))
        gate.recordFailure()
        XCTAssertTrue(gate.finish(now: now))
        XCTAssertTrue(gate.begin(scope: changed, now: now))
    }
}

private actor ReadRelease {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false

    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func resume() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}
