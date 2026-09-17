import Foundation

// MARK: - Shared meadow prototype domain
//
// A Slumber Party's shared Farm becomes one living meadow: each member's chosen
// character stands in it, and members can send one of their own sheep to visit
// for a bounded stay. Everything here is pure presentation/domain logic. It
// never reads a private Farm document and never decides reward eligibility.
//
// Two kinds of activity are deliberately kept apart:
//   • local play — arranging characters, nudging them, watching them settle.
//     Only this phone sees it. Nothing is uploaded.
//   • sent actions — a greeting (existing fixed cheer) or a sheep visit.
//     These reach another person's app and are described as such.

/// A sheep that a member has sent to the shared meadow for a bounded stay.
/// Only the catalogue identity and a display name travel; wool, rarity
/// history, favourites and the owning Farm document stay private.
struct SharedFarmVisit: Identifiable, Codable, Equatable, Hashable, Sendable {
    static let stayNights = 7

    var id: UUID
    var partyID: UUID
    var memberID: UUID
    var sheepDefinitionID: String
    var sheepDisplayName: String
    var sentAt: Date
    var expiresAt: Date

    init(id: UUID = UUID(), partyID: UUID, memberID: UUID, sheepDefinitionID: String,
         sheepDisplayName: String, sentAt: Date, expiresAt: Date? = nil) {
        self.id = id
        self.partyID = partyID
        self.memberID = memberID
        self.sheepDefinitionID = sheepDefinitionID
        self.sheepDisplayName = sheepDisplayName
        self.sentAt = sentAt
        self.expiresAt = expiresAt ?? sentAt.addingTimeInterval(TimeInterval(Self.stayNights * 86_400))
    }

    func isCurrent(at date: Date) -> Bool { sentAt <= date && date < expiresAt }

    func nightsRemaining(at date: Date) -> Int {
        max(0, Int(ceil(expiresAt.timeIntervalSince(date) / 86_400)))
    }
}

/// Where a greeting is attached. A greeting on an update reuses the existing
/// fixed-cheer contract exactly; the other contexts need the additive contract
/// described in the prototype handoff.
enum SharedFarmGreetingContext: Codable, Equatable, Hashable, Sendable {
    case update(activityID: UUID)
    case visit(visitID: UUID)
    case meadow
}

enum SharedFarmGreetingDelivery: String, Codable, Equatable, Sendable {
    case pending
    case accepted
    case receivedByApp
    case failed

    /// Never a read receipt. "Received" means the other person's app has it.
    var title: String {
        switch self {
        case .pending: return "Sending…"
        case .accepted: return "Saved to the party"
        case .receivedByApp: return "Reached their app"
        case .failed: return "Not sent yet"
        }
    }

    var isSettled: Bool { self == .accepted || self == .receivedByApp }
}

struct SharedFarmGreeting: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var partyID: UUID
    var senderMemberID: UUID
    var recipientMemberID: UUID
    var cheer: NightFlockV4Cheer
    var context: SharedFarmGreetingContext
    var sentAt: Date
    var delivery: SharedFarmGreetingDelivery

    /// One greeting of each kind per sender, recipient and context. Repeated
    /// taps therefore replay the same idempotent intent instead of stacking.
    var identity: String {
        "\(partyID):\(senderMemberID):\(recipientMemberID):\(cheer.rawValue):\(context)"
    }
}

// MARK: - Copy that explains what travels and to whom

enum SharedFarmSocialCopy {
    static func cheerTitle(_ cheer: NightFlockV4Cheer) -> String {
        switch cheer {
        case .warmWave: return "Warm wave"
        case .moonGlow: return "Moon glow"
        case .pawPrint: return "Paw print"
        }
    }

    static func cheerSymbol(_ cheer: NightFlockV4Cheer) -> String {
        switch cheer {
        case .warmWave: return "hand.wave.fill"
        case .moonGlow: return "moon.stars.fill"
        case .pawPrint: return "pawprint.fill"
        }
    }

    private static func noun(_ cheer: NightFlockV4Cheer) -> String {
        cheerTitle(cheer).lowercased()
    }

    /// Shown to the sender before they confirm. Names the recipient and what
    /// their app will show; promises nothing about attention.
    static func senderPreview(cheer: NightFlockV4Cheer, recipientName: String, contextTitle: String?) -> String {
        if let contextTitle {
            return "\(recipientName)’s app will show a \(noun(cheer)) from you beside \(contextTitle)."
        }
        return "\(recipientName)’s app will show a \(noun(cheer)) from you on the shared Farm."
    }

    /// Shown to the recipient as a durable row.
    static func recipientLine(cheer: NightFlockV4Cheer, senderName: String, contextTitle: String?) -> String {
        if let contextTitle {
            return "\(senderName) sent a \(noun(cheer)) for \(contextTitle)."
        }
        return "\(senderName) left a \(noun(cheer)) on the shared Farm."
    }

    static func visitSenderPreview(sheepName: String) -> String {
        "\(sheepName) will visit the shared Farm for \(SharedFarmVisit.stayNights) nights. Friends see \(sheepName)’s name and look; nothing else from your Farm is shared."
    }

    static func visitLine(sheepName: String, ownerName: String, isMe: Bool, nightsRemaining: Int) -> String {
        let owner = isMe ? "Your \(sheepName)" : "\(ownerName)’s \(sheepName)"
        switch nightsRemaining {
        case 0: return "\(owner) is heading home."
        case 1: return "\(owner) is visiting · last night"
        default: return "\(owner) is visiting · \(nightsRemaining) nights left"
        }
    }

    static let localArrangementNote = "Only you see how the Farm is arranged. Moving characters sends nothing."

    /// One human line for a member's latest shared update. Zero before-bed
    /// minutes with a completed outcome is truthful (Wind Down started at or
    /// after bedtime); it must not read as "nothing happened".
    static func updateLine(kind: NightFlockV4ActivityKind, status: NightFlockV4ActivityStatus, roundedMinutes: Int, occurredAt: Date, now: Date, calendar: Calendar = .current) -> String {
        let mode = kind == .windDown ? "Wind Down" : "Phone Away"
        let when = relativeNight(occurredAt, now: now, calendar: calendar)
        let outcome: String
        switch (status, roundedMinutes > 0) {
        case (.completed, true):
            outcome = kind == .windDown ? "wound down \(roundedMinutes) min before bed" : "kept the phone away \(roundedMinutes) min"
        case (.completed, false):
            outcome = kind == .windDown ? "completed Wind Down · 0 before-bed min recorded" : "completed Phone Away · under a minute counted"
        case (_, true):
            outcome = "\(mode) ended early after \(roundedMinutes) min"
        case (_, false):
            outcome = "\(mode) ended early"
        }
        return "\(outcome.prefix(1).uppercased())\(outcome.dropFirst()) · \(when)"
    }

    static func relativeNight(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0
        switch days {
        case 0: return "today"
        case 1: return "last night"
        case 2...6:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = calendar.locale
            formatter.setLocalizedDateFormatFromTemplate("EEEE")
            return "\(formatter.string(from: date)) night"
        default:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = calendar.locale
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
            return formatter.string(from: date)
        }
    }
}

// MARK: - Meadow layout

/// Who stands on the shared meadow. Keys are stable across refreshes so a
/// local arrangement survives a party projection update.
enum SharedMeadowOccupant: Hashable, Equatable, Sendable {
    case member(UUID)
    case visitor(UUID)
    case lantern(UUID)
    case companion(UUID)

    var key: String {
        switch self {
        case .member(let id): return "member-\(id.uuidString)"
        case .visitor(let id): return "visitor-\(id.uuidString)"
        case .lantern(let id): return "lantern-\(id.uuidString)"
        case .companion(let id): return "companion-\(id.uuidString)"
        }
    }

    var footprint: PastureSceneFootprint {
        switch self {
        case .member: return .shepherd
        case .visitor, .companion: return .sheep
        case .lantern: return .shepherd
        }
    }
}

struct SharedMeadowArrangement: Codable, Equatable {
    static let currentSchemaVersion = 1
    var schemaVersion: Int = currentSchemaVersion
    var positions: [String: PastureScenePoint] = [:]

    static func decodeSafely(_ data: Data?) -> Self? {
        guard let data, let value = try? JSONDecoder().decode(Self.self, from: data),
              value.schemaVersion == currentSchemaVersion else { return nil }
        return value
    }
}

enum SharedMeadowLayout {
    /// Members take the front row in join order; visitors stand beside the
    /// member who sent them. Positions are deterministic so two phones that
    /// have not rearranged anything see the same picture.
    static func seededPosition(for occupant: SharedMeadowOccupant, memberIndex: Int, memberCount: Int,
                               visitorIndex: Int = 0, seed: UInt64) -> PastureScenePoint {
        // Authored places around the courtyard: tree, path, grazing lawn and
        // barn approach. Larger parties use a connected horizontal ground plane.
        let small = [(0.36, 0.65), (0.67, 0.76), (0.67, 0.49), (0.32, 0.87)]
        let medium = [(0.22, 0.54), (0.66, 0.57), (0.26, 0.88), (0.70, 0.88)]
        let large = [(0.16, 0.65), (0.34, 0.78), (0.42, 0.49), (0.57, 0.66),
                     (0.75, 0.50), (0.85, 0.79), (0.63, 0.87), (0.23, 0.46)]
        let places = memberCount > 4 ? large : (memberCount > 2 ? medium : small)
        let place = places[max(0, memberIndex) % places.count]
        let point: PastureScenePoint
        switch occupant {
        case .member:
            point = .init(x: place.0, y: place.1)
        case .lantern:
            point = .init(x: 0.32, y: 0.60)
        case .companion:
            point = .init(x: place.0 - 0.08, y: place.1 + 0.09)
        case .visitor:
            point = .init(x: place.0 + (memberCount > 4 ? 0.075 : (memberCount > 2 ? 0.18 : 0.14)), y: place.1 + 0.04)
        }
        return SharedPastureRules.bounded(point)
    }

    static func neighbours(_ positions: [SharedMeadowOccupant: PastureScenePoint]) -> [PastureSceneNeighbour] {
        positions.keys.sorted { $0.key < $1.key }.compactMap { occupant in
            positions[occupant].map { PastureSceneNeighbour(key: occupant.key, point: $0, footprint: occupant.footprint) }
        }
    }

    /// A dragged character dropped onto a friend is a *local* gesture. It
    /// becomes a social action only when the person confirms a greeting.
    static func greetingCandidate(droppedIsMine: Bool, at point: PastureScenePoint,
                                  positions: [SharedMeadowOccupant: PastureScenePoint], me: UUID?) -> UUID? {
        guard droppedIsMine else { return nil }
        var best: (UUID, Double)?
        for (occupant, position) in positions {
            guard case .member(let id) = occupant, id != me else { continue }
            let distance = position.distance(to: point)
            guard distance < PastureSceneLayout.minimumSpacing(.shepherd, .sheep) * 1.15 else { continue }
            if best == nil || distance < best!.1 { best = (id, distance) }
        }
        return best?.0
    }
}
