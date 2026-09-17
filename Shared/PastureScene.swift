import Foundation

/// Local, presentation-only pasture layout. This snapshot intentionally stays
/// outside `FarmState`: rearranging a character is not Farm progression.
struct PastureSceneSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let positions: [PastureSceneStoredPosition]

    init(positions: [PastureSceneStoredPosition], schemaVersion: Int = currentSchemaVersion) {
        self.schemaVersion = schemaVersion
        self.positions = positions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported pasture scene schema."
            )
        }
        self.schemaVersion = schemaVersion
        self.positions = try container.decode([PastureSceneStoredPosition].self, forKey: .positions)
    }

    static func decodeSafely(from data: Data?) -> Self? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}

struct PastureSceneStoredPosition: Codable, Equatable, Identifiable {
    let entityID: PastureSceneEntityID
    let point: PastureScenePoint

    var id: PastureSceneEntityID { entityID }
}

struct PastureSceneEntityID: Hashable, Codable, Identifiable {
    enum Kind: String, Codable {
        case sheep
        case ollie
        case shepherd
    }

    let kind: Kind
    let sheepID: UUID?
    let pastureIndex: Int

    static func sheep(_ id: UUID, pastureIndex: Int) -> Self {
        Self(kind: .sheep, sheepID: id, pastureIndex: pastureIndex)
    }

    static func ollie(pastureIndex: Int) -> Self {
        Self(kind: .ollie, sheepID: nil, pastureIndex: pastureIndex)
    }

    static func shepherd(pastureIndex: Int) -> Self {
        Self(kind: .shepherd, sheepID: nil, pastureIndex: pastureIndex)
    }

    var id: String {
        switch kind {
        case .sheep: return "sheep-\(sheepID?.uuidString ?? "missing")-\(pastureIndex)"
        case .ollie: return "ollie-\(pastureIndex)"
        case .shepherd: return "shepherd-\(pastureIndex)"
        }
    }
}

struct PastureScenePoint: Codable, Equatable {
    var x: Double
    var y: Double

    static let zero = Self(x: 0, y: 0)

    func distance(to other: Self) -> Double {
        hypot(x - other.x, y - other.y)
    }
}

struct PastureSceneFootprint: Equatable {
    var halfWidth: Double
    var halfHeight: Double

    static let sheep = Self(halfWidth: 0.055, halfHeight: 0.085)
    static let ollie = Self(halfWidth: 0.085, halfHeight: 0.115)
    static let shepherd = Self(halfWidth: 0.085, halfHeight: 0.115)
}

enum PastureSceneBehavior: Equatable {
    case idle
    case wandering
    case dragging
    case chasing
    case reacting
    case ambient(PastureSceneAmbientAction)
}

enum PastureSceneAmbientAction: Equatable {
    case graze
    case tinyHop
    case sniff
    case pause
    case stanceShift
    case wave
}

struct PastureSceneChasePlan: Equatable {
    let sheepID: PastureSceneEntityID
    let ollieTarget: PastureScenePoint
    let sheepTarget: PastureScenePoint
}

enum PastureSceneLayout {
    /// The lower part of the card is the usable pasture. The label and horizon
    /// remain deliberately out of bounds for direct manipulation.
    static let groundMinimum = PastureScenePoint(x: 0.04, y: 0.45)
    static let groundMaximum = PastureScenePoint(x: 0.96, y: 0.93)

    static func footprint(for entity: PastureSceneEntityID) -> PastureSceneFootprint {
        switch entity.kind {
        case .sheep: return .sheep
        case .ollie: return .ollie
        case .shepherd: return .shepherd
        }
    }

    static func clamped(_ point: PastureScenePoint, footprint: PastureSceneFootprint) -> PastureScenePoint {
        PastureScenePoint(
            x: min(max(point.x, groundMinimum.x + footprint.halfWidth), groundMaximum.x - footprint.halfWidth),
            y: min(max(point.y, groundMinimum.y + footprint.halfHeight), groundMaximum.y - footprint.halfHeight)
        )
    }

    static func settledPosition(
        proposed: PastureScenePoint,
        for entity: PastureSceneEntityID,
        among positions: [PastureSceneEntityID: PastureScenePoint]
    ) -> PastureScenePoint {
        let neighbours = positions.keys
            .filter { $0 != entity && $0.pastureIndex == entity.pastureIndex }
            .sorted { $0.id < $1.id }
            .compactMap { other in
                positions[other].map { PastureSceneNeighbour(key: other.id, point: $0, footprint: footprint(for: other)) }
            }
        return settledPosition(
            proposed: proposed,
            footprint: footprint(for: entity),
            entityKey: entity.id,
            among: neighbours
        )
    }

    /// Renderer-agnostic settling. The personal pasture and the shared meadow
    /// use the same spacing rule so characters feel the same everywhere.
    static func settledPosition(
        proposed: PastureScenePoint,
        footprint entityFootprint: PastureSceneFootprint,
        entityKey: String,
        among neighbours: [PastureSceneNeighbour]
    ) -> PastureScenePoint {
        var settled = clamped(proposed, footprint: entityFootprint)
        for other in neighbours where other.key != entityKey {
            let minimum = minimumSpacing(entityFootprint, other.footprint)
            let distance = settled.distance(to: other.point)
            guard distance < minimum else { continue }

            let angle: Double
            if distance > 0.000_1 {
                angle = atan2(settled.y - other.point.y, settled.x - other.point.x)
            } else {
                angle = deterministicUnit(seed: stableHash(forKey: entityKey) ^ stableHash(forKey: other.key))
            }
            settled = clamped(
                PastureScenePoint(
                    x: other.point.x + cos(angle) * minimum,
                    y: other.point.y + sin(angle) * minimum
                ),
                footprint: entityFootprint
            )
        }
        return settled
    }

    static func minimumSpacing(_ lhs: PastureSceneFootprint, _ rhs: PastureSceneFootprint) -> Double {
        min(0.19, max(0.075, lhs.halfWidth + rhs.halfWidth))
    }

    /// A dropped character that lands on a neighbour gently nudges that
    /// neighbour aside instead of being bounced away itself. The nudge is a
    /// local, presentation-only reaction: it never changes who owns what.
    static func nudgePlan(
        dropped entityKey: String,
        footprint entityFootprint: PastureSceneFootprint,
        at point: PastureScenePoint,
        among neighbours: [PastureSceneNeighbour],
        seed: UInt64
    ) -> PastureSceneNudgePlan {
        let landing = clamped(point, footprint: entityFootprint)
        var displaced: [PastureSceneNudge] = []
        var occupied = neighbours
        for other in neighbours.sorted(by: { $0.key < $1.key }) where other.key != entityKey {
            let minimum = minimumSpacing(entityFootprint, other.footprint)
            guard landing.distance(to: other.point) < minimum * 0.9 else { continue }
            let direction: Double
            let distance = other.point.distance(to: landing)
            if distance > 0.000_1 {
                direction = atan2(other.point.y - landing.y, other.point.x - landing.x)
            } else {
                direction = deterministicUnit(seed: seed ^ stableHash(forKey: other.key))
            }
            let hop = minimum + 0.02 + Double((seed >> 7) % 17) / 1_000
            let proposed = PastureScenePoint(
                x: landing.x + cos(direction) * hop,
                y: landing.y + sin(direction) * hop
            )
            let others = occupied.filter { $0.key != other.key }
                + [PastureSceneNeighbour(key: entityKey, point: landing, footprint: entityFootprint)]
            let target = settledPosition(proposed: proposed, footprint: other.footprint, entityKey: other.key, among: others)
            displaced.append(PastureSceneNudge(key: other.key, target: target))
            if let index = occupied.firstIndex(where: { $0.key == other.key }) {
                occupied[index].point = target
            }
        }
        return PastureSceneNudgePlan(landing: landing, displaced: displaced)
    }

    static func pruned(
        _ snapshot: PastureSceneSnapshot?,
        keeping entityIDs: Set<PastureSceneEntityID>
    ) -> [PastureSceneEntityID: PastureScenePoint] {
        guard let snapshot, snapshot.schemaVersion == PastureSceneSnapshot.currentSchemaVersion else { return [:] }
        return snapshot.positions.reduce(into: [:]) { result, stored in
            guard entityIDs.contains(stored.entityID), stored.point.x.isFinite, stored.point.y.isFinite else { return }
            result[stored.entityID] = clamped(stored.point, footprint: footprint(for: stored.entityID))
        }
    }

    static func seededPosition(
        for entity: PastureSceneEntityID,
        slot: Int? = nil,
        seed: UInt64
    ) -> PastureScenePoint {
        let random = stableHash(for: entity) ^ seed ^ UInt64(entity.pastureIndex &+ 1) &* 11_400_714_819_323_198_485
        let jitterX = (Double((random >> 11) % 1_001) / 1_000 - 0.5) * 0.026
        let jitterY = (Double((random >> 29) % 1_001) / 1_000 - 0.5) * 0.014
        let point: PastureScenePoint
        switch entity.kind {
        case .sheep:
            let slots: [(Double, Double)] = [
                (0.25, 0.62), (0.41, 0.62), (0.57, 0.62), (0.73, 0.62),
                (0.30, 0.75), (0.46, 0.75), (0.62, 0.75), (0.78, 0.75),
                (0.25, 0.84), (0.41, 0.84), (0.57, 0.84), (0.73, 0.84)
            ]
            let value = slots[min(max(slot ?? 0, 0), slots.count - 1)]
            point = PastureScenePoint(x: value.0 + jitterX, y: value.1 + jitterY)
        case .ollie:
            point = PastureScenePoint(x: 0.12 + jitterX, y: 0.79 + jitterY)
        case .shepherd:
            point = PastureScenePoint(x: 0.87 + jitterX, y: 0.73 + jitterY)
        }
        return clamped(point, footprint: footprint(for: entity))
    }

    static func scamperTarget(
        for entity: PastureSceneEntityID,
        from point: PastureScenePoint,
        seed: UInt64,
        among positions: [PastureSceneEntityID: PastureScenePoint]
    ) -> PastureScenePoint {
        let direction = deterministicUnit(seed: seed ^ stableHash(for: entity))
        let distance = 0.035 + Double((seed >> 9) % 31) / 1_000
        return settledPosition(
            proposed: PastureScenePoint(
                x: point.x + cos(direction) * distance,
                y: point.y + sin(direction) * distance
            ),
            for: entity,
            among: positions
        )
    }

    static func chasePlan(
        ollieID: PastureSceneEntityID,
        sheep: [PastureSceneEntityID],
        positions: [PastureSceneEntityID: PastureScenePoint],
        seed: UInt64
    ) -> PastureSceneChasePlan? {
        guard let olliePoint = positions[ollieID] else { return nil }
        let candidates = sheep
            .filter { $0.kind == .sheep && $0.pastureIndex == ollieID.pastureIndex }
            .compactMap { id -> (PastureSceneEntityID, PastureScenePoint)? in
            positions[id].map { (id, $0) }
        }
            .filter { $0.1.distance(to: olliePoint) <= 0.38 }
        guard let selected = candidates.min(by: { lhs, rhs in
            let lhsDistance = lhs.1.distance(to: olliePoint)
            let rhsDistance = rhs.1.distance(to: olliePoint)
            return lhsDistance == rhsDistance ? lhs.0.id < rhs.0.id : lhsDistance < rhsDistance
        }) else { return nil }

        let direction = deterministicUnit(seed: seed ^ stableHash(for: selected.0))
        let sheepTarget = settledPosition(
            proposed: PastureScenePoint(
                x: selected.1.x + cos(direction) * 0.07,
                y: selected.1.y + sin(direction) * 0.07
            ),
            for: selected.0,
            among: positions
        )
        let ollieTarget = settledPosition(
            proposed: PastureScenePoint(
                x: selected.1.x - cos(direction) * 0.075,
                y: selected.1.y - sin(direction) * 0.075
            ),
            for: ollieID,
            among: positions
        )
        return PastureSceneChasePlan(sheepID: selected.0, ollieTarget: ollieTarget, sheepTarget: sheepTarget)
    }

    static func stableHash(for entity: PastureSceneEntityID) -> UInt64 {
        stableHash(forKey: entity.id)
    }

    static func stableHash(forKey key: String) -> UInt64 {
        key.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    static func deterministicUnit(seed: UInt64) -> Double {
        Double(seed % 6_283) / 1_000
    }
}

struct PastureSceneNeighbour: Equatable {
    var key: String
    var point: PastureScenePoint
    var footprint: PastureSceneFootprint
}

struct PastureSceneNudge: Equatable {
    var key: String
    var target: PastureScenePoint
}

struct PastureSceneNudgePlan: Equatable {
    var landing: PastureScenePoint
    var displaced: [PastureSceneNudge]
}
