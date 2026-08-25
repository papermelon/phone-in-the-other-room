import Foundation

/// A small, stable play temperament derived from a sheep's catalogue identity.
/// It is presentation-only and deliberately does not live in Farm persistence.
enum PastureScenePersonality: String, CaseIterable, Equatable {
    case gentle
    case curious
    case bouncy
    case brave
    case dreamy
}

enum PastureSceneEffectKind: Equatable {
    case heart
    case sparkle
    case woolPuff
    case pawprint
}

struct PastureSceneEffect: Identifiable, Equatable {
    let id: UUID
    let kind: PastureSceneEffectKind
    let point: PastureScenePoint
    let entityID: PastureSceneEntityID?

    init(
        id: UUID = UUID(),
        kind: PastureSceneEffectKind,
        point: PastureScenePoint,
        entityID: PastureSceneEntityID?
    ) {
        self.id = id
        self.kind = kind
        self.point = point
        self.entityID = entityID
    }
}

struct PastureSceneBall: Equatable {
    var position: PastureScenePoint
    var isCarried: Bool
}

enum PastureSceneInteractionRules {
    static let maximumTossDistance = 0.18

    static func personality(for definitionID: String) -> PastureScenePersonality {
        switch definitionID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "mabel", "oat":
            return .gentle
        case "pippin", "juniper":
            return .curious
        case "bramble", "clementine", "marigold":
            return .bouncy
        case "ramsey", "hazel":
            return .brave
        case "midnight", "luna", "wisp":
            return .dreamy
        default:
            // Unknown or retired catalogue entries should be calm and safe.
            return .gentle
        }
    }

    /// Converts a normalized predicted drag remainder into a short, soft landing.
    /// Inputs from gesture systems are treated as untrusted: malformed values settle
    /// in place, and only entities on the visible pasture affect collision resolution.
    static func tossTarget(
        for entity: PastureSceneEntityID,
        from point: PastureScenePoint,
        predictedTranslation: PastureScenePoint,
        among positions: [PastureSceneEntityID: PastureScenePoint]
    ) -> PastureScenePoint {
        let fallback = positions[entity].flatMap(finitePoint) ?? PastureSceneLayout.seededPosition(
            for: entity,
            seed: 0
        )
        let origin = PastureSceneLayout.clamped(
            finitePoint(point) ?? fallback,
            footprint: PastureSceneLayout.footprint(for: entity)
        )
        let translation = finitePoint(predictedTranslation) ?? .zero
        let cappedTranslation = capped(translation)

        let visiblePositions = positions.reduce(into: [PastureSceneEntityID: PastureScenePoint]()) { result, entry in
            guard entry.key.pastureIndex == entity.pastureIndex,
                  let safePoint = finitePoint(entry.value) else { return }
            result[entry.key] = safePoint
        }
        let settled = PastureSceneLayout.settledPosition(
            proposed: PastureScenePoint(
                x: origin.x + cappedTranslation.x,
                y: origin.y + cappedTranslation.y
            ),
            for: entity,
            among: visiblePositions
        )
        return boundedDistance(
            from: origin,
            to: settled,
            footprint: PastureSceneLayout.footprint(for: entity)
        )
    }

    private static func finitePoint(_ point: PastureScenePoint) -> PastureScenePoint? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        return point
    }

    private static func capped(_ translation: PastureScenePoint) -> PastureScenePoint {
        let largestComponent = max(abs(translation.x), abs(translation.y))
        guard largestComponent.isFinite, largestComponent > 0 else { return .zero }
        guard largestComponent > maximumTossDistance else { return translation }

        // Scaling before `hypot` avoids overflow for a finite but enormous drag prediction.
        let scaledX = translation.x / largestComponent
        let scaledY = translation.y / largestComponent
        let scaledMagnitude = hypot(scaledX, scaledY)
        guard scaledMagnitude.isFinite, scaledMagnitude > 0 else { return .zero }
        let scale = maximumTossDistance / scaledMagnitude
        return PastureScenePoint(x: scaledX * scale, y: scaledY * scale)
    }

    private static func boundedDistance(
        from origin: PastureScenePoint,
        to point: PastureScenePoint,
        footprint: PastureSceneFootprint
    ) -> PastureScenePoint {
        let deltaX = point.x - origin.x
        let deltaY = point.y - origin.y
        let largestComponent = max(abs(deltaX), abs(deltaY))
        guard largestComponent.isFinite, largestComponent > 0 else {
            return PastureSceneLayout.clamped(origin, footprint: footprint)
        }
        let scaledMagnitude = hypot(deltaX / largestComponent, deltaY / largestComponent)
        guard scaledMagnitude.isFinite, scaledMagnitude > 0 else {
            return PastureSceneLayout.clamped(origin, footprint: footprint)
        }
        let distanceExceedsLimit = largestComponent > maximumTossDistance / scaledMagnitude
        guard distanceExceedsLimit else {
            return PastureSceneLayout.clamped(point, footprint: footprint)
        }
        let scale = maximumTossDistance / scaledMagnitude
        return PastureSceneLayout.clamped(
            PastureScenePoint(x: origin.x + (deltaX / largestComponent) * scale, y: origin.y + (deltaY / largestComponent) * scale),
            footprint: footprint
        )
    }
}
