import Foundation

/// Category-only sharing remains available under the original agreement.
enum CampfireActivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case phoneAway, reading, studying, making, chores, resting
    var id: String { rawValue }
    var title: String {
        switch self {
        case .phoneAway: return "Phone Away"
        case .reading: return "Reading"
        case .studying: return "Studying"
        case .making: return "Making something"
        case .chores: return "Chores"
        case .resting: return "Resting"
        }
    }
}

struct CampfireAgreement: Codable, Equatable, Sendable {
    var id: UUID
    var version: Int
    var revision: Int
    var enabled: Bool
    var acceptedAt: Date
    var permitsSharing: Bool { (version == 1 || version == 2) && enabled }
}

struct CampfireSession: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var memberID: UUID
    var kind: NightFlockV4ActivityKind
    var activity: CampfireActivity?
    var startedAt: Date
    var observedAt: Date
    var expiresAt: Date
    var ended: Bool
    var revision: Int
    var intendedBedtime: Date? = nil
    var title: String { CampfireRules.sessionTitle(kind: kind, activity: activity) }
    var validIntendedBedtime: Date? {
        guard kind == .windDown, let intendedBedtime, intendedBedtime.timeIntervalSince1970.isFinite,
              intendedBedtime <= expiresAt else { return nil }
        return intendedBedtime
    }
    func pose(at date: Date) -> CampfireShepherdPose {
        guard isCurrent(at: date), let bedtime = validIntendedBedtime, date >= bedtime else { return .awake }
        return .bedtime
    }
    func isCurrent(at date: Date) -> Bool {
        !ended && revision == 1 && startedAt <= date && observedAt <= date.addingTimeInterval(300) && expiresAt > date
            && expiresAt <= startedAt.addingTimeInterval(CampfireRules.maximumDuration)
    }
}

enum CampfireShepherdPose: Equatable, Sendable {
    case awake, bedtime
    var accessibilityDescription: String {
        self == .bedtime ? "Shepherd tucked in for bedtime" : "Shepherd awake by the Campfire"
    }
}

extension CampfireSession {
    private enum CodingKeys: String, CodingKey {
        case id, memberID, kind, activity, startedAt, observedAt, expiresAt, ended, revision, intendedBedtime
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        memberID = try c.decode(UUID.self, forKey: .memberID)
        kind = try c.decode(NightFlockV4ActivityKind.self, forKey: .kind)
        activity = try c.decodeIfPresent(CampfireActivity.self, forKey: .activity)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        observedAt = try c.decode(Date.self, forKey: .observedAt)
        expiresAt = try c.decode(Date.self, forKey: .expiresAt)
        ended = try c.decode(Bool.self, forKey: .ended)
        revision = try c.decode(Int.self, forKey: .revision)
        // Optional art metadata must not make an otherwise valid party unreadable.
        intendedBedtime = try? c.decodeIfPresent(Date.self, forKey: .intendedBedtime)
    }
}

struct CampfireState: Codable, Equatable, Sendable {
    var version: Int = 1
    var agreement: CampfireAgreement?
    var sessions: [CampfireSession] = []
    var buddies: CampfireBuddiesState? = nil
    var supportsIntendedBedtime = false
    var isSupported: Bool { version == 1 }
}

enum CampfireRules {
    static func intendedBedtime(for run: FocusRun, supported: Bool) -> Date? {
        guard supported, let plan = run.nightWatchPlan, plan.role == .primarySleepBookend,
              let expiry = end(for: run), plan.intendedBedtime.timeIntervalSince1970.isFinite,
              plan.intendedBedtime <= expiry else { return nil }
        return plan.intendedBedtime
    }

    /// Local presentation only; neither these dates nor their ticks publish activity.
    static func displayInvalidationDates(in state: CampfireState?, at date: Date) -> [Date] {
        guard let state, state.isSupported else { return [] }
        let sessions = state.sessions.filter { !$0.ended && $0.revision == 1 }
        let boundaries = sessions.flatMap { [$0.startedAt, $0.expiresAt] + [$0.validIntendedBedtime].compactMap { $0 } }
        let buddyDates = state.buddies?.sessions.flatMap {
            [$0.expiresAt, $0.checkInAfter, $0.startedAt.addingTimeInterval(CampfireBuddiesRules.retention)]
        } ?? []
        // TimelineView can round its delivered timestamp just below the requested
        // instant. One millisecond crosses that boundary without a polling clock.
        return Array(Set((boundaries + buddyDates).filter { $0.timeIntervalSince1970.isFinite && $0 > date }))
            .map { $0.addingTimeInterval(0.001) }.sorted()
    }
    static func sessionTitle(kind: NightFlockV4ActivityKind, activity: CampfireActivity?) -> String {
        guard kind == .phoneAway else { return "Wind Down" }
        guard let activity, activity != .phoneAway else { return "Phone Away" }
        return "Phone Away · \(activity.title)"
    }
    static let maximumDuration: TimeInterval = 24 * 60 * 60
    static let fire = PastureScenePoint(x: 0.5, y: 0.89)

    static func currentSessions(_ state: CampfireState?, members: Set<UUID>, isFresh: Bool, at date: Date) -> [CampfireSession] {
        guard isFresh, let state, state.isSupported else { return [] }
        // Choose the factual latest source before filtering ended/expired rows;
        // an older live start must not win over a newer terminal source.
        return Dictionary(grouping: state.sessions.filter { members.contains($0.memberID) }, by: \.memberID)
            .values.compactMap { rows in
                rows.max {
                    if $0.startedAt != $1.startedAt { return $0.startedAt < $1.startedAt }
                    if $0.revision != $1.revision { return $0.revision < $1.revision }
                    return $0.observedAt < $1.observedAt
                }
            }.filter { $0.isCurrent(at: date) }.sorted { $0.memberID.uuidString < $1.memberID.uuidString }
    }

    /// Temporary rendering anchors. These never enter the arrangement/outbox.
    static func seat(index: Int, count: Int) -> PastureScenePoint {
        if count == 1 { return .init(x: 0.5, y: 0.63) }
        if count == 2 { return .init(x: index == 0 ? 0.28 : 0.72, y: 0.67) }
        // Four columns on the wide canvas; two rows leave room for names.
        let columns = min(max(count, 1), 4)
        let column = max(0, index) % columns
        let row = max(0, index) / columns
        return .init(x: 0.14 + Double(column) * 0.72 / Double(max(1, columns - 1)),
                     y: count <= 4 ? 0.61 : (row == 0 ? 0.76 : 0.43))
    }

    static func participants(in members: [NightFlockV4Membership], sessions: [CampfireSession]) -> [NightFlockV4Membership] {
        // Membership is not presence. Only the same current rows used by the
        // activity labels may place a person at the fire.
        sessions.compactMap { session in members.first { $0.memberID == session.memberID } }
    }

    static func showsLocalSession(_ run: FocusRun, at date: Date) -> Bool {
        ![.setup, .completed, .endedEarly].contains(run.state) && run.startedAt <= date
            && end(for: run).map { $0 > date } == true
    }

    static let foregroundRefreshInterval: TimeInterval = 20

    static func permitsOwner(captured: UUID?, current: UUID?) -> Bool {
        guard let captured, let current else { return false }
        return captured == current
    }

    static func end(for run: FocusRun) -> Date? {
        guard !run.isPractice, let plan = run.nightWatchPlan else { return nil }
        switch plan.role {
        case .primarySleepBookend: return min(plan.wakeTime, run.startedAt.addingTimeInterval(maximumDuration))
        case .additionalQuiet: return min(run.plannedEndAt, run.startedAt.addingTimeInterval(maximumDuration))
        }
    }
}

extension CampfireState {
    private enum CodingKeys: String, CodingKey { case version, agreement, sessions, buddies, supportsIntendedBedtime }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard version == 1 else {
            // Do not decode a future schema's fields as if they were v1.
            agreement = nil; sessions = []; buddies = nil; return
        }
        buddies = try container.decodeIfPresent(CampfireBuddiesState.self, forKey: .buddies)
        supportsIntendedBedtime = try container.decodeIfPresent(Bool.self, forKey: .supportsIntendedBedtime) ?? false
        agreement = try container.decodeIfPresent(CampfireAgreement.self, forKey: .agreement)
        sessions = try container.decodeIfPresent([CampfireSession].self, forKey: .sessions) ?? []
    }
}

/// Eight local seats. Membership changes fill vacancies without moving people
/// already seated; no coordinates are published or added to a Farm arrangement.
struct CampfireSeating {
    private(set) var slots: [UUID: Int] = [:]
    static let order = [0, 3, 2, 1, 5, 4, 6, 7]
    // Composed clearings leave room for text and the fire; refreshes never roll new positions.
    static let anchors: [PastureScenePoint] = [
        .init(x: 0.245, y: 0.17), .init(x: 0.735, y: 0.19),
        .init(x: 0.30, y: 0.50), .init(x: 0.765, y: 0.525),
        .init(x: 0.23, y: 0.69), .init(x: 0.71, y: 0.72),
        .init(x: 0.285, y: 0.88), .init(x: 0.75, y: 0.905)
    ]

    static func point(for slot: Int) -> PastureScenePoint {
        anchors[((slot % anchors.count) + anchors.count) % anchors.count]
    }
    mutating func reconcile(_ ids: [UUID]) {
        let current = Set(ids.prefix(8))
        slots = slots.filter { current.contains($0.key) }
        for id in ids.prefix(8) where slots[id] == nil {
            if let vacancy = Self.order.first(where: { !slots.values.contains($0) }) { slots[id] = vacancy }
        }
    }
    func position(_ id: UUID) -> PastureScenePoint { Self.point(for: slots[id] ?? 0) }
    mutating func move(_ id: UUID, to point: PastureScenePoint) {
        guard let old = slots[id], point.x.isFinite, point.y.isFinite else { return }
        let nearest = (0..<8).min {
            Self.point(for: $0).distance(to: point) < Self.point(for: $1).distance(to: point)
        } ?? old
        if let neighbour = slots.first(where: { $0.value == nearest })?.key { slots[neighbour] = old }
        slots[id] = nearest
    }
}

/// Refreshing does not extend the authority or freshness of a presence snapshot.
enum CampfireScenePhase: Equatable {
    case loading, populated, empty, unavailable

    static func resolve(hasCurrentSnapshot: Bool, isRefreshing: Bool, hasPeople: Bool) -> Self {
        guard hasCurrentSnapshot else { return isRefreshing ? .loading : .unavailable }
        return hasPeople ? .populated : .empty
    }

    var showsPeople: Bool { self == .populated }
    var isUpdating: Bool { self == .loading }
}

/// Display whitespace is normalized without shortening or rewriting someone's shared plan.
enum CampfirePlanText {
    static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let text = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return text.isEmpty ? nil : text
    }
}
