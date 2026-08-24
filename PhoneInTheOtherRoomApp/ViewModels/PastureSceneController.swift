import Foundation
import Observation

/// Lifecycle-bound presentation coordinator for one Farm pasture card. It owns
/// transient behavior only; the standalone snapshot records completed drags.
@MainActor
@Observable
final class PastureSceneController {
    private(set) var positions: [PastureSceneEntityID: PastureScenePoint] = [:]
    private(set) var behaviors: [PastureSceneEntityID: PastureSceneBehavior] = [:]
    private(set) var isInteractionActive = false

    private var settledPositions: [PastureSceneEntityID: PastureScenePoint] = [:]
    private var entityIDs = Set<PastureSceneEntityID>()
    private var slotByEntity: [PastureSceneEntityID: Int] = [:]
    private var sceneSeed: UInt64 = 0
    private var activePastureIndex = 0
    private var reduceMotion = false
    private var loadedSnapshot = false
    private var interaction: DragInteraction?
    private var suppressedTapEntity: PastureSceneEntityID?
    private var suppressedTapUntil: Date?
    private var schedulerTask: Task<Void, Never>?
    private var schedulerGeneration = 0
    private var eventCount: UInt64 = 0
    private var persistSnapshot: ((PastureSceneSnapshot) -> Void)?

    func configure(
        activeSheep: [FlockSheep],
        pastureCount: Int,
        layoutSeed: UInt64,
        activePastureIndex: Int,
        persistedSnapshot: PastureSceneSnapshot?,
        reduceMotion: Bool,
        onPersist: @escaping (PastureSceneSnapshot) -> Void
    ) {
        let membership = Self.membership(for: activeSheep, pastureCount: pastureCount)
        let newIDs = Set(membership.ids)
        let sceneChanged = sceneSeed != layoutSeed || entityIDs != newIDs
        let activePastureChanged = self.activePastureIndex != activePastureIndex
        if sceneChanged || activePastureChanged {
            stopAutonomyAndSettle()
            cancelInteraction(restartAutonomy: false)
        }
        sceneSeed = layoutSeed
        self.activePastureIndex = activePastureIndex
        self.reduceMotion = reduceMotion
        persistSnapshot = onPersist

        if !loadedSnapshot {
            settledPositions = PastureSceneLayout.pruned(persistedSnapshot, keeping: newIDs)
            loadedSnapshot = true
        } else {
            settledPositions = settledPositions.filter { newIDs.contains($0.key) }
        }

        entityIDs = newIDs
        slotByEntity = membership.slots
        for entity in newIDs where settledPositions[entity] == nil {
            settledPositions[entity] = PastureSceneLayout.seededPosition(
                for: entity,
                slot: membership.slots[entity],
                seed: layoutSeed
            )
        }
        positions = positions.filter { newIDs.contains($0.key) }
        if !isInteractionActive || sceneChanged {
            positions = settledPositions
        }
        behaviors = behaviors.filter { newIDs.contains($0.key) }
        for entity in newIDs where behaviors[entity] == nil {
            behaviors[entity] = .idle
        }

        if reduceMotion {
            stopAutonomyAndSettle()
        } else if !isInteractionActive {
            startSchedulerIfNeeded()
        }
    }

    func position(for entity: PastureSceneEntityID) -> PastureScenePoint {
        positions[entity]
            ?? settledPositions[entity]
            ?? PastureSceneLayout.seededPosition(for: entity, slot: slotByEntity[entity], seed: sceneSeed)
    }

    func behavior(for entity: PastureSceneEntityID) -> PastureSceneBehavior {
        behaviors[entity] ?? .idle
    }

    func beginDrag(_ entity: PastureSceneEntityID) {
        guard entityIDs.contains(entity), interaction == nil else { return }
        stopAutonomyAndSettle()
        interaction = DragInteraction(entity: entity, start: position(for: entity))
        isInteractionActive = true
        behaviors[entity] = .dragging
    }

    func updateDrag(_ entity: PastureSceneEntityID, translation: PastureScenePoint) {
        guard let interaction, interaction.entity == entity else { return }
        let proposed = PastureScenePoint(
            x: interaction.start.x + translation.x,
            y: interaction.start.y + translation.y
        )
        positions[entity] = PastureSceneLayout.clamped(
            proposed,
            footprint: PastureSceneLayout.footprint(for: entity)
        )
    }

    func finishDrag(_ entity: PastureSceneEntityID) {
        guard let interaction, interaction.entity == entity else {
            cancelInteraction()
            return
        }
        defer {
            self.interaction = nil
            isInteractionActive = false
            suppressedTapEntity = entity
            suppressedTapUntil = Date().addingTimeInterval(0.18)
            settleSceneBehaviors()
            if !reduceMotion { startSchedulerIfNeeded() }
        }
        let proposed = position(for: entity)
        let settled = PastureSceneLayout.settledPosition(
            proposed: proposed,
            for: entity,
            among: settledPositions
        )
        guard settled.distance(to: interaction.start) > 0.001 else { return }
        settledPositions[entity] = settled
        positions[entity] = settled
        persistCurrentSnapshot()
    }

    func cancelInteraction(restartAutonomy: Bool = true) {
        guard interaction != nil else {
            isInteractionActive = false
            if restartAutonomy, !reduceMotion { startSchedulerIfNeeded() }
            return
        }
        self.interaction = nil
        isInteractionActive = false
        settleSceneBehaviors()
        if restartAutonomy, !reduceMotion { startSchedulerIfNeeded() }
    }

    func shouldAcceptTap(for entity: PastureSceneEntityID) -> Bool {
        if suppressedTapEntity == entity {
            suppressedTapEntity = nil
            defer { suppressedTapUntil = nil }
            if let suppressedTapUntil, Date() < suppressedTapUntil {
                return false
            }
        }
        return !isInteractionActive
    }

    func stop() {
        stopAutonomyAndSettle()
        cancelInteraction(restartAutonomy: false)
    }

    private func persistCurrentSnapshot() {
        let stored = settledPositions
            .map { PastureSceneStoredPosition(entityID: $0.key, point: $0.value) }
            .sorted { $0.entityID.id < $1.entityID.id }
        persistSnapshot?(PastureSceneSnapshot(positions: stored))
    }

    private func startSchedulerIfNeeded() {
        guard !reduceMotion, !isInteractionActive, schedulerTask == nil, !entityIDs.isEmpty else { return }
        let generation = schedulerGeneration
        schedulerTask = Task { [weak self] in
            await self?.schedulerLoop(generation: generation)
        }
    }

    private func stopAutonomyAndSettle() {
        schedulerGeneration &+= 1
        schedulerTask?.cancel()
        schedulerTask = nil
        settleSceneBehaviors(preservingDrag: true)
    }

    private func settleSceneBehaviors(preservingDrag: Bool = false) {
        positions = settledPositions
        for entity in entityIDs where !preservingDrag || behaviors[entity] != .dragging {
            behaviors[entity] = .idle
        }
    }

    private func schedulerLoop(generation: Int) async {
        while !Task.isCancelled {
            let pause = UInt64(6_000_000_000 + (eventCount % 5) * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: pause)
            } catch {
                return
            }
            guard generation == schedulerGeneration, !reduceMotion, !isInteractionActive else { return }
            eventCount &+= 1
            await performAutonomousSequence(generation: generation, seed: sceneSeed ^ eventCount &* 2_685_821_657_736_338_717)
        }
    }

    private func performAutonomousSequence(generation: Int, seed: UInt64) async {
        guard generation == schedulerGeneration, !reduceMotion, !isInteractionActive else { return }
        let ordered = entityIDs
            .filter { $0.pastureIndex == activePastureIndex }
            .sorted { $0.id < $1.id }
        guard !ordered.isEmpty else { return }

        if seed % 13 == 0,
           let ollie = ordered.first(where: { $0.kind == .ollie }),
           let plan = PastureSceneLayout.chasePlan(
            ollieID: ollie,
            sheep: ordered.filter { $0.kind == .sheep },
            positions: settledPositions,
            seed: seed
           ) {
            behaviors[ollie] = .chasing
            behaviors[plan.sheepID] = .reacting
            positions[ollie] = plan.ollieTarget
            positions[plan.sheepID] = plan.sheepTarget
            await waitForSequence(generation: generation, nanoseconds: 1_050_000_000)
            guard generation == schedulerGeneration, !isInteractionActive else { return }
            positions = settledPositions
            behaviors[ollie] = .idle
            behaviors[plan.sheepID] = .idle
            return
        }

        let entity = ordered[Int(seed % UInt64(ordered.count))]
        switch entity.kind {
        case .sheep:
            if seed % 3 == 0 {
                behaviors[entity] = .ambient(seed % 2 == 0 ? .graze : .tinyHop)
                await waitForSequence(generation: generation, nanoseconds: 700_000_000)
            } else {
                behaviors[entity] = .wandering
                positions[entity] = PastureSceneLayout.scamperTarget(
                    for: entity,
                    from: settledPositions[entity] ?? position(for: entity),
                    seed: seed,
                    among: settledPositions
                )
                await waitForSequence(generation: generation, nanoseconds: 850_000_000)
            }
        case .ollie:
            behaviors[entity] = .ambient(seed % 2 == 0 ? .sniff : .pause)
            await waitForSequence(generation: generation, nanoseconds: 800_000_000)
        case .shepherd:
            behaviors[entity] = .ambient(seed % 2 == 0 ? .stanceShift : .wave)
            await waitForSequence(generation: generation, nanoseconds: 650_000_000)
        }
        guard generation == schedulerGeneration, !isInteractionActive else { return }
        positions = settledPositions
        behaviors[entity] = .idle
    }

    private func waitForSequence(generation: Int, nanoseconds: UInt64) async {
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            return
        }
        guard generation == schedulerGeneration else { return }
    }

    private static func membership(
        for activeSheep: [FlockSheep],
        pastureCount: Int
    ) -> (ids: [PastureSceneEntityID], slots: [PastureSceneEntityID: Int]) {
        var ids: [PastureSceneEntityID] = []
        var slots: [PastureSceneEntityID: Int] = [:]
        for pasture in 0..<max(1, pastureCount) {
            let sheep = Array(activeSheep.dropFirst(pasture * 12).prefix(12))
            let slotAssignments = Self.slotAssignments(for: sheep)
            for sheep in sheep {
                let entity = PastureSceneEntityID.sheep(sheep.id, pastureIndex: pasture)
                ids.append(entity)
                slots[entity] = slotAssignments[sheep.id] ?? 0
            }
            ids.append(.ollie(pastureIndex: pasture))
            ids.append(.shepherd(pastureIndex: pasture))
        }
        return (ids, slots)
    }

    private static func slotAssignments(for sheep: [FlockSheep]) -> [UUID: Int] {
        var assignments: [UUID: Int] = [:]
        var used = Set<Int>()
        for entry in sheep.sorted(by: {
            if $0.arrivedAt == $1.arrivedAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.arrivedAt < $1.arrivedAt
        }) {
            let entity = PastureSceneEntityID.sheep(entry.id, pastureIndex: 0)
            let preferred = Int(PastureSceneLayout.stableHash(for: entity) % 12)
            let slot = (0..<12)
                .map { (preferred + $0) % 12 }
                .first { !used.contains($0) } ?? preferred
            assignments[entry.id] = slot
            used.insert(slot)
        }
        return assignments
    }
}

private struct DragInteraction {
    let entity: PastureSceneEntityID
    let start: PastureScenePoint
}
