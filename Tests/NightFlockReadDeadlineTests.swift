import XCTest

final class NightFlockReadDeadlineTests: XCTestCase {
    func testSuccessfulReadAndServerErrorsArePreserved() async throws {
        let value = try await NightFlockReadDeadline.run { 42 }
        XCTAssertEqual(value, 42)
        do {
            _ = try await NightFlockReadDeadline.run { throw URLError(.notConnectedToInternet) }
            XCTFail("Expected the original network error")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
    }

    func testTimeoutCancelsThePendingRead() async {
        let cancelled = expectation(description: "Network read cancelled")
        do {
            _ = try await NightFlockReadDeadline.run(timeout: .milliseconds(30)) {
                do { try await Task.sleep(for: .seconds(60)) }
                catch { cancelled.fulfill(); throw error }
            }
            XCTFail("Expected timeout")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
        await fulfillment(of: [cancelled], timeout: 1)
    }

    func testLeavingTheScreenCancelsTheReadWithoutWaitingForDeadline() async {
        let started = expectation(description: "Read started")
        let task = Task {
            try await NightFlockReadDeadline.run {
                started.fulfill()
                try await Task.sleep(for: .seconds(60))
            }
        }
        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        do { try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
}
