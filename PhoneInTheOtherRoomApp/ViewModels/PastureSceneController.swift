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
    private(set) var isPlayMode = false
    private(set) var effects: [PastureSceneEffect] = []
    private(set) var ball: PastureSceneBall?
    private(set) var feedbackTick = 0

    private var settledPositions: [PastureSceneEntityID: PastureScenePoint] = [:]
    private var entityIDs = Set<PastureSceneEntityID>()
    private var slotByEntity: [PastureSceneEntityID: Int] = [:]
    private var definitionIDBySheepID: [UUID: String] = [:]
    private var sceneSeed: UInt64 = 0
    private var activePastureIndex = 0
    private var reduceMotion = false
    private var isWindDownActive = false
    private var loadedSnapshot = false
    private var interaction: DragInteraction?
    private var suppressedTapEntity: PastureSceneEntityID?
    private var suppressedTapUntil: Date?
    private var schedulerTask: Task<Void, Never>?
    private var schedulerGeneration = 0
    private var playTask: Task<Void, Never>?
    private var playGeneration = 0
    private var lastPetFeedbackAt: Date?
    private var eventCount: UInt64 = 0
    private var persistSnapshot: ((PastureSceneSnapshot) -> Void)?

    func configure(
        activeSheep: [FlockSheep],
        pastureCount: Int,
        layoutSeed: UInt64,
        activePastureIndex: Int,
        persistedSnapshot: PastureSceneSnapshot?,
        reduceMotion: Bool,
        isWindDownActive: Bool = false,
        onPersist: @escaping (PastureSceneSnapshot) -> Void
    ) {
        let membership = Self.membership(for: activeSheep, pastureCount: pastureCount)
        let newIDs = Set(membership.ids)
        let sceneChanged = sceneSeed != layoutSeed || entityIDs != newIDs
        let activePastureChanged = self.activePastureIndex != activePastureIndex
        let windDownBegan = isWindDownActive && !self.isWindDownActive
        if sceneChanged || activePastureChanged || windDownBegan {
            stopAutonomyAndSettle()
            cancelInteraction(restartAutonomy: false)
            clearPlayPresentation()
        }
        sceneSeed = layoutSeed
        self.activePastureIndex = activePastureIndex
        self.reduceMotion = reduceMotion
        self.isWindDownActive = isWindDownActive
        if isWindDownActive { isPlayMode = false }
        persistSnapshot = onPersist
        definitionIDBySheepID = Dictionary(uniqueKeysWithValues: activeSheep.map { ($0.id, $0.definitionID) })

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

        if reduceMotion || isWindDownActive {
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

    func setPlayMode(_ enabled: Bool) {
        let allowed = enabled && !isWindDownActive
        guard isPlayMode != allowed else { return }
        isPlayMode = allowed
        if !allowed {
            cancelInteraction(restartAutonomy: false)
            clearPlayPresentation()
            if !reduceMotion && !isWindDownActive { startSchedulerIfNeeded() }
        }
    }

    func personality(for entity: PastureSceneEntityID) -> PastureScenePersonality {
        switch entity.kind {
        case .sheep:
            return PastureSceneInteractionRules.personality(
                for: entity.sheepID.flatMap { definitionIDBySheepID[$0] } ?? ""
            )
        case .ollie:
            return .curious
        case .shepherd:
            return .gentle
        }
    }

    func reactToTap(_ entity: PastureSceneEntityID) {
        guard canPlay(with: entity), interaction == nil else { return }
        clearPlayPresentation()
        stopAutonomyAndSettle()
        let reaction: PastureSceneBehavior = personality(for: entity) == .bouncy ? .greeting : .reacting
        behaviors[entity] = reaction
        addEffect(personality(for: entity) == .dreamy ? .sparkle : .heart, for: entity)
        if let ollie = ollieNear(entity), ollie != entity {
            behaviors[ollie] = .observing
            addEffect(.pawprint, for: ollie)
        }
        schedulePlayReset(after: 750_000_000)
    }

    func beginPress(_ entity: PastureSceneEntityID) {
        guard canPlay(with: entity), interaction == nil else { return }
        clearPlayPresentation()
        stopAutonomyAndSettle()
        isInteractionActive = true
        behaviors[entity] = .squishing
        if entity.kind == .sheep { addEffect(.woolPuff, for: entity) }
    }

    func pet(_ entity: PastureSceneEntityID) {
        guard canPlay(with: entity), interaction == nil else { return }
        let continuingPet = isInteractionActive && behaviors[entity] == .petting
        if !continuingPet {
            clearPlayPresentation()
            stopAutonomyAndSettle()
        }
        isInteractionActive = true
        behaviors[entity] = .petting
        let now = Date()
        if lastPetFeedbackAt.map({ now.timeIntervalSince($0) >= 0.18 }) ?? true {
            lastPetFeedbackAt = now
            addEffect(.heart, for: entity)
        }
        if let ollie = ollieNear(entity), ollie != entity {
            behaviors[ollie] = .observing
        }
    }

    func endPress(_ entity: PastureSceneEntityID) {
        guard entityIDs.contains(entity), interaction == nil else { return }
        isInteractionActive = false
        lastPetFeedbackAt = nil
        guard isPlayMode, !isWindDownActive else {
            settleSceneBehaviors()
            if !reduceMotion && !isWindDownActive { startSchedulerIfNeeded() }
            return
        }
        behaviors[entity] = .greeting
        schedulePlayReset(after: reduceMotion ? 180_000_000 : 480_000_000)
    }

    func tossBall(toward point: PastureScenePoint? = nil) {
        guard isPlayMode, !isWindDownActive, interaction == nil,
              let ollie = entityIDs.first(where: { $0.kind == .ollie && $0.pastureIndex == activePastureIndex }) else { return }
        clearPlayPresentation()
        stopAutonomyAndSettle()
        let origin = position(for: ollie)
        if reduceMotion {
            ball = PastureSceneBall(position: origin, isCarried: false)
            behaviors[ollie] = .greeting
            addEffect(.sparkle, point: origin, entityID: ollie)
            schedulePlayReset(after: 420_000_000)
            return
        }
        let target = PastureSceneInteractionRules.tossTarget(
            for: ollie,
            from: point ?? PastureScenePoint(x: 0.54, y: 0.70),
            predictedTranslation: .zero,
            among: settledPositions
        )
        ball = PastureSceneBall(position: target, isCarried: false)
        behaviors[ollie] = .fetching
        positions[ollie] = target
        addEffect(.pawprint, point: origin, entityID: ollie)
        if let sheep = nearestSheep(to: target) {
            behaviors[sheep] = .observing
        }
        scheduleFetchReturn(ollie: ollie, target: target, returningTo: origin)
    }

    func beginDrag(_ entity: PastureSceneEntityID) {
        guard entityIDs.contains(entity), interaction == nil else { return }
        clearPlayPresentation()
        stopAutonomyAndSettle()
        interaction = DragInteraction(entity: entity, start: position(for: entity))
        isInteractionActive = true
        behaviors[entity] = .dragging
    }

    func updateDrag(_ entity: PastureSceneEntityID, translation: PastureScenePoint) {
        guard let interaction, interaction.entity == entity,
              translation.x.isFinite, translation.y.isFinite else { return }
        let proposed = PastureScenePoint(
            x: interaction.start.x + translation.x,
            y: interaction.start.y + translation.y
        )
        positions[entity] = PastureSceneLayout.clamped(
            proposed,
            footprint: PastureSceneLayout.footprint(for: entity)
        )
    }

    func finishDrag(
        _ entity: PastureSceneEntityID,
        predictedTranslation: PastureScenePoint = .zero
    ) {
        guard let interaction, interaction.entity == entity else {
            cancelInteraction()
            return
        }
        self.interaction = nil
        isInteractionActive = false
        lastPetFeedbackAt = nil
        suppressedTapEntity = entity
        suppressedTapUntil = Date().addingTimeInterval(0.18)
        let proposed = position(for: entity)
        let shouldToss = isPlayMode
            && !isWindDownActive
            && !reduceMotion
            && predictedTranslation.x.isFinite
            && predictedTranslation.y.isFinite
            && hypot(predictedTranslation.x, predictedTranslation.y) > 0.006
        let settled: PastureScenePoint
        if shouldToss {
            settled = PastureSceneInteractionRules.tossTarget(
                for: entity,
                from: proposed,
                predictedTranslation: predictedTranslation,
                among: settledPositions
            )
        } else {
            settled = PastureSceneLayout.settledPosition(
                proposed: proposed,
                for: entity,
                among: settledPositions
            )
        }
        let moved = settled.distance(to: interaction.start) > 0.001
        settledPositions[entity] = settled
        positions[entity] = settled
        if moved { persistCurrentSnapshot() }
        if shouldToss {
            behaviors[entity] = .landing
            addEffect(.woolPuff, for: entity)
            if let ollie = ollieNear(entity), ollie != entity { behaviors[ollie] = .observing }
            schedulePlayReset(after: 560_000_000)
        } else {
            settleSceneBehaviors()
            if !reduceMotion && !isWindDownActive { startSchedulerIfNeeded() }
        }
    }

    func cancelInteraction(restartAutonomy: Bool = true) {
        self.interaction = nil
        isInteractionActive = false
        lastPetFeedbackAt = nil
        cancelPlayTask()
        effects = []
        ball = nil
        settleSceneBehaviors()
        if restartAutonomy, !reduceMotion, !isWindDownActive { startSchedulerIfNeeded() }
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
        clearPlayPresentation()
    }

    private func canPlay(with entity: PastureSceneEntityID) -> Bool {
        entityIDs.contains(entity) && isPlayMode && !isWindDownActive
    }

    private func ollieNear(_ entity: PastureSceneEntityID) -> PastureSceneEntityID? {
        entityIDs.first { $0.kind == .ollie && $0.pastureIndex == entity.pastureIndex }
    }

    private func nearestSheep(to point: PastureScenePoint) -> PastureSceneEntityID? {
        entityIDs
            .filter { $0.kind == .sheep && $0.pastureIndex == activePastureIndex }
            .min { position(for: $0).distance(to: point) < position(for: $1).distance(to: point) }
    }

    private func addEffect(_ kind: PastureSceneEffectKind, for entity: PastureSceneEntityID) {
        addEffect(kind, point: position(for: entity), entityID: entity)
    }

    private func addEffect(
        _ kind: PastureSceneEffectKind,
        point: PastureScenePoint,
        entityID: PastureSceneEntityID?
    ) {
        guard point.x.isFinite, point.y.isFinite else { return }
        effects.append(PastureSceneEffect(kind: kind, point: point, entityID: entityID))
        if effects.count > 6 { effects.removeFirst(effects.count - 6) }
        feedbackTick &+= 1
    }

    private func schedulePlayReset(after nanoseconds: UInt64) {
        cancelPlayTask()
        let generation = playGeneration
        playTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }
            guard let self, generation == self.playGeneration, !self.isWindDownActive else { return }
            self.effects = []
            self.ball = nil
            self.settleSceneBehaviors()
            self.playTask = nil
            if !self.reduceMotion { self.startSchedulerIfNeeded() }
        }
    }

    private func scheduleFetchReturn(
        ollie: PastureSceneEntityID,
        target: PastureScenePoint,
        returningTo origin: PastureScenePoint
    ) {
        cancelPlayTask()
        let generation = playGeneration
        playTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 650_000_000)
            } catch {
                return
            }
            guard let self, generation == self.playGeneration, !self.isWindDownActive else { return }
            self.ball = PastureSceneBall(position: origin, isCarried: true)
            self.positions[ollie] = origin
            self.addEffect(.sparkle, point: target, entityID: ollie)
            do {
                try await Task.sleep(nanoseconds: 520_000_000)
            } catch {
                return
            }
            guard generation == self.playGeneration, !self.isWindDownActive else { return }
            self.ball = nil
            self.effects = []
            self.settleSceneBehaviors()
            self.playTask = nil
            self.startSchedulerIfNeeded()
        }
    }

    private func cancelPlayTask() {
        playGeneration &+= 1
        playTask?.cancel()
        playTask = nil
    }

    private func clearPlayPresentation() {
        cancelPlayTask()
        effects = []
        ball = nil
    }

    private func persistCurrentSnapshot() {
        let stored = settledPositions
            .map { PastureSceneStoredPosition(entityID: $0.key, point: $0.value) }
            .sorted { $0.entityID.id < $1.entityID.id }
        persistSnapshot?(PastureSceneSnapshot(positions: stored))
    }

    private func startSchedulerIfNeeded() {
        guard !reduceMotion, !isWindDownActive, !isInteractionActive, schedulerTask == nil, !entityIDs.isEmpty else { return }
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
            guard generation == schedulerGeneration, !reduceMotion, !isWindDownActive, !isInteractionActive else { return }
            eventCount &+= 1
            await performAutonomousSequence(generation: generation, seed: sceneSeed ^ eventCount &* 2_685_821_657_736_338_717)
        }
    }

    private func performAutonomousSequence(generation: Int, seed: UInt64) async {
        guard generation == schedulerGeneration, !reduceMotion, !isWindDownActive, !isInteractionActive else { return }
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
            guard generation == schedulerGeneration, !isWindDownActive, !isInteractionActive else { return }
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
        guard generation == schedulerGeneration, !isWindDownActive, !isInteractionActive else { return }
        positions = settledPositions
        behaviors[entity] = .idle
    }

    private func waitForSequence(generation: Int, nanoseconds: UInt64) async {
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            return
        }
        guard generation == schedulerGeneration, !isWindDownActive else { return }
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
