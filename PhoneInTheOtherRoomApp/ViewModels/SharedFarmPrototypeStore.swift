import Foundation
import SwiftUI

/// Prototype-only stand-in for the shared Farm backend contract described in
/// `docs/plans/shared-farm-prototype-2026-09-12.md`. It keeps visits and
/// greetings in memory (plus a disposable defaults suite for the local
/// arrangement), simulates delivery states with a short latency, and can
/// fabricate inbound activity so the recipient side can be judged on one phone.
///
/// Nothing here contacts Supabase, reads the account Farm document, or awards
/// credit. Production integration replaces this object behind the same calls.
@MainActor
final class SharedFarmPrototypeStore: ObservableObject {
    struct Member: Equatable {
        var memberID: UUID
        var displayName: String
    }

    @Published private(set) var visits: [SharedFarmVisit] = []
    @Published private(set) var greetings: [SharedFarmGreeting] = []
    @Published private(set) var lastSimulatedFriendActivityAt: Date?
    /// Set by the fixture to demonstrate a failed send and its retry path.
    var failsNextSend = false

    let partyID: UUID
    let myMemberID: UUID
    let now: () -> Date
    private let defaults: UserDefaults
    private let members: [Member]
    private var deliveryTasks: [UUID: Task<Void, Never>] = [:]

    init(partyID: UUID, myMemberID: UUID, members: [Member], defaults: UserDefaults, now: @escaping () -> Date = Date.init) {
        self.partyID = partyID
        self.myMemberID = myMemberID
        self.members = members
        self.defaults = defaults
        self.now = now
    }

    func displayName(for memberID: UUID) -> String {
        members.first { $0.memberID == memberID }?.displayName ?? "A group member"
    }

    // MARK: Visits

    var currentVisits: [SharedFarmVisit] {
        let date = now()
        return visits.filter { $0.isCurrent(at: date) }.sorted { $0.sentAt < $1.sentAt }
    }

    var myVisit: SharedFarmVisit? { currentVisits.first { $0.memberID == myMemberID } }

    func visit(from memberID: UUID) -> SharedFarmVisit? {
        currentVisits.first { $0.memberID == memberID }
    }

    /// One visiting sheep per member; sending another replaces the stay.
    @discardableResult
    func sendVisit(sheepDefinitionID: String, sheepDisplayName: String) -> SharedFarmVisit {
        let visit = SharedFarmVisit(partyID: partyID, memberID: myMemberID, sheepDefinitionID: sheepDefinitionID,
                                    sheepDisplayName: sheepDisplayName, sentAt: now())
        visits.removeAll { $0.memberID == myMemberID }
        visits.append(visit)
        return visit
    }

    func bringVisitHome() {
        visits.removeAll { $0.memberID == myMemberID }
    }

    // MARK: Greetings

    func greetingsSent(to recipient: UUID) -> [SharedFarmGreeting] {
        greetings.filter { $0.senderMemberID == myMemberID && $0.recipientMemberID == recipient }
            .sorted { $0.sentAt > $1.sentAt }
    }

    var greetingsReceived: [SharedFarmGreeting] {
        greetings.filter { $0.recipientMemberID == myMemberID && $0.delivery.isSettled }
            .sorted { $0.sentAt > $1.sentAt }
    }

    func greeting(from sender: UUID, cheer: NightFlockV4Cheer, context: SharedFarmGreetingContext, to recipient: UUID) -> SharedFarmGreeting? {
        greetings.first {
            $0.senderMemberID == sender && $0.recipientMemberID == recipient && $0.cheer == cheer && $0.context == context
        }
    }

    /// Repeated taps replay one idempotent intent; only a failed attempt is retried.
    @discardableResult
    func sendGreeting(to recipient: UUID, cheer: NightFlockV4Cheer, context: SharedFarmGreetingContext) -> SharedFarmGreeting {
        if let existing = greeting(from: myMemberID, cheer: cheer, context: context, to: recipient) {
            if existing.delivery == .failed { retry(existing) }
            return greetings.first { $0.id == existing.id } ?? existing
        }
        let greeting = SharedFarmGreeting(id: UUID(), partyID: partyID, senderMemberID: myMemberID, recipientMemberID: recipient,
                                          cheer: cheer, context: context, sentAt: now(), delivery: .pending)
        greetings.append(greeting)
        scheduleDelivery(for: greeting.id)
        return greeting
    }

    func retry(_ greeting: SharedFarmGreeting) {
        guard let index = greetings.firstIndex(where: { $0.id == greeting.id }), greetings[index].delivery == .failed else { return }
        greetings[index].delivery = .pending
        greetings[index].sentAt = now()
        scheduleDelivery(for: greeting.id)
    }

    private func scheduleDelivery(for id: UUID) {
        deliveryTasks[id]?.cancel()
        let shouldFail = failsNextSend
        failsNextSend = false
        deliveryTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, !Task.isCancelled else { return }
            self.update(id) { $0.delivery = shouldFail ? .failed : .accepted }
            guard !shouldFail else { return }
            try? await Task.sleep(for: .milliseconds(1_400))
            guard !Task.isCancelled else { return }
            self.update(id) { $0.delivery = .receivedByApp }
        }
    }

    private func update(_ id: UUID, _ body: (inout SharedFarmGreeting) -> Void) {
        guard let index = greetings.firstIndex(where: { $0.id == id }) else { return }
        body(&greetings[index])
    }

    // MARK: Simulated inbound activity

    /// Pretends a friend acted from their phone: a visiting sheep plus a
    /// greeting bound to my latest update. The fixture calls this so the
    /// recipient experience can be inspected without a second account.
    func simulateFriendActivity(from friendID: UUID, sheepDefinitionID: String, sheepDisplayName: String,
                                cheer: NightFlockV4Cheer, context: SharedFarmGreetingContext) {
        let date = now()
        if visit(from: friendID) == nil {
            visits.append(SharedFarmVisit(partyID: partyID, memberID: friendID, sheepDefinitionID: sheepDefinitionID,
                                          sheepDisplayName: sheepDisplayName, sentAt: date.addingTimeInterval(-86_400 * 2)))
        }
        if greeting(from: friendID, cheer: cheer, context: context, to: myMemberID) == nil {
            greetings.append(SharedFarmGreeting(id: UUID(), partyID: partyID, senderMemberID: friendID, recipientMemberID: myMemberID,
                                                cheer: cheer, context: context, sentAt: date, delivery: .receivedByApp))
        }
        lastSimulatedFriendActivityAt = date
    }

    func seed(visits: [SharedFarmVisit], greetings: [SharedFarmGreeting]) {
        self.visits = visits
        self.greetings = greetings
    }

    // MARK: Local arrangement (never uploaded)

    private var arrangementKey: String { "ollie.sharedMeadow.arrangement.\(partyID.uuidString)" }

    func loadArrangement() -> SharedMeadowArrangement? {
        SharedMeadowArrangement.decodeSafely(defaults.data(forKey: arrangementKey))
    }

    func saveArrangement(_ arrangement: SharedMeadowArrangement) {
        guard let data = try? JSONEncoder().encode(arrangement) else { return }
        defaults.set(data, forKey: arrangementKey)
    }
}

// MARK: - Environment plumbing

private struct SharedFarmPrototypeKey: EnvironmentKey {
    static let defaultValue: SharedFarmPrototypeStore? = nil
}

extension EnvironmentValues {
    /// Present only in the prototype fixture. Release code paths see `nil`
    /// and keep today's shared Farm behavior.
    var sharedFarmPrototype: SharedFarmPrototypeStore? {
        get { self[SharedFarmPrototypeKey.self] }
        set { self[SharedFarmPrototypeKey.self] = newValue }
    }
}
