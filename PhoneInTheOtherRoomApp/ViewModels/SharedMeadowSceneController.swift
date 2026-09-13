import Foundation
import Observation

/// Presentation coordinator for one shared meadow. It owns transient behavior
/// (drags, nudges, ambient poses) and a local-only arrangement. It never sends
/// anything: a drop near a friend is *reported* as a candidate and the view
/// asks the person before any greeting leaves the phone.
@MainActor
@Observable
final class SharedMeadowSceneController: PastureInteractionControlling {
    struct Configuration: Equatable {
        struct Occupant: Equatable {
            var occupant: SharedMeadowOccupant
            var ownerMemberID: UUID
            var memberIndex: Int
            var visitorIndex: Int
            var isCompanionLike: Bool
        }
        var occupants: [Occupant]
        var memberCount: Int
        var myMemberID: UUID?
        var seed: UInt64
    }

    struct DropResult: Equatable {
        var moved: Bool
        var nudgedKeys: [String]
        var greetingCandidate: UUID?
    }

    private(set) var positions: [SharedMeadowOccupant: PastureScenePoint] = [:]
    private(set) var behaviors: [SharedMeadowOccupant: PastureSceneBehavior] = [:]
    private(set) var isInteractionActive = false
    private(set) var lastMovedKey: String?
    private var lastCanonicalArrangement: SharedMeadowArrangement?
    private(set) var lastDrop: DropResult?
    private(set) var toyPosition: PastureScenePoint?
    private(set) var playMessage: String?

    private var settled: [SharedMeadowOccupant: PastureScenePoint] = [:]
    private var configuration: Configuration?
    private var reduceMotion = false
    private var isQuiet = false
    private var loadedArrangement = false
    private var dragStart: (SharedMeadowOccupant, PastureScenePoint)?
    private var suppressedTap: (SharedMeadowOccupant, Date)?
    private var schedulerTask: Task<Void, Never>?
    private var generation = 0
    private var eventCount: UInt64 = 0
    private var persist: ((SharedMeadowArrangement) -> Void)?

    func configure(_ configuration: Configuration, arrangement: SharedMeadowArrangement?, reduceMotion: Bool,
                   isQuiet: Bool, onPersist: @escaping (SharedMeadowArrangement) -> Void) {
        let occupants = Set(configuration.occupants.map(\.occupant))
        let sceneChanged = self.configuration.map { Set($0.occupants.map(\.occupant)) != occupants || $0.seed != configuration.seed } ?? true
        if sceneChanged || (isQuiet && !self.isQuiet) {
            stopAutonomy()
            dragStart = nil
            isInteractionActive = false
        }
        self.configuration = configuration
        self.reduceMotion = reduceMotion
        self.isQuiet = isQuiet
        persist = onPersist

        if !loadedArrangement || arrangement != lastCanonicalArrangement {
            lastCanonicalArrangement = arrangement
            loadedArrangement = true
            for entry in configuration.occupants {
                if let stored = arrangement?.positions[entry.occupant.key], stored.x.isFinite, stored.y.isFinite {
                    settled[entry.occupant] = SharedPastureRules.bounded(stored)
                }
            }
        }
        settled = settled.filter { occupants.contains($0.key) }
        for entry in configuration.occupants where settled[entry.occupant] == nil {
            settled[entry.occupant] = SharedMeadowLayout.seededPosition(
                for: entry.occupant, memberIndex: entry.memberIndex, memberCount: configuration.memberCount,
                visitorIndex: entry.visitorIndex, seed: configuration.seed
            )
        }
        if !isInteractionActive || sceneChanged { positions = settled }
        behaviors = behaviors.filter { occupants.contains($0.key) }
        for occupant in occupants where behaviors[occupant] == nil { behaviors[occupant] = .idle }

        if reduceMotion || isQuiet { stopAutonomy() } else if !isInteractionActive { startAutonomyIfNeeded() }
    }

    func position(for occupant: SharedMeadowOccupant) -> PastureScenePoint {
        positions[occupant] ?? settled[occupant] ?? PastureScenePoint(x: 0.5, y: 0.75)
    }

    func behavior(for occupant: SharedMeadowOccupant) -> PastureSceneBehavior {
        behaviors[occupant] ?? .idle
    }

    // MARK: Drag

    func beginDrag(_ occupant: SharedMeadowOccupant) {
        guard settled[occupant] != nil, dragStart == nil else { return }
        stopAutonomy()
        dragStart = (occupant, position(for: occupant))
        isInteractionActive = true
        behaviors[occupant] = .dragging
    }

    func updateDrag(_ occupant: SharedMeadowOccupant, translation: PastureScenePoint) {
        guard let dragStart, dragStart.0 == occupant, translation.x.isFinite, translation.y.isFinite else { return }
        let proposed = PastureScenePoint(x: dragStart.1.x + translation.x, y: dragStart.1.y + translation.y)
        positions[occupant] = SharedPastureRules.bounded(proposed)
    }

    func finishDrag(_ occupant: SharedMeadowOccupant) {
        guard let dragStart, dragStart.0 == occupant else {
            cancelInteraction()
            return
        }
        self.dragStart = nil
        isInteractionActive = false
        suppressedTap = (occupant, Date().addingTimeInterval(0.18))

        let landing = position(for: occupant)
        eventCount &+= 1
        let neighbours = SharedMeadowLayout.neighbours(settled)
        let plan = PastureSceneLayout.nudgePlan(
            dropped: occupant.key, footprint: occupant.footprint, at: landing, among: neighbours,
            seed: (configuration?.seed ?? 0) ^ eventCount &* 2_685_821_657_736_338_717
        )
        let droppedIsMine = configuration?.occupants.first { $0.occupant == occupant }?.ownerMemberID == configuration?.myMemberID
        let candidate = SharedMeadowLayout.greetingCandidate(
            droppedIsMine: droppedIsMine, at: plan.landing, positions: settled.filter { $0.key != occupant }, me: configuration?.myMemberID
        )

        settled[occupant] = SharedPastureRules.bounded(plan.landing)
        positions[occupant] = SharedPastureRules.bounded(plan.landing)
        behaviors[occupant] = .idle
        var nudgedKeys: [String] = []
        for nudge in plan.displaced {
            guard let other = settled.keys.first(where: { $0.key == nudge.key }) else { continue }
            nudgedKeys.append(nudge.key)
            settled[other] = nudge.target
            positions[other] = nudge.target
            behaviors[other] = .reacting
        }
        let moved = plan.landing.distance(to: dragStart.1) > 0.001 || !nudgedKeys.isEmpty
        lastDrop = DropResult(moved: moved, nudgedKeys: nudgedKeys, greetingCandidate: candidate)
        lastMovedKey = occupant.key
        if moved { persistArrangement() }
        if !nudgedKeys.isEmpty {
            let generation = self.generation
            let settleDelay = reduceMotion ? 10 : 900
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(settleDelay))
                guard let self, generation == self.generation else { return }
                for key in nudgedKeys {
                    if let other = self.settled.keys.first(where: { $0.key == key }), self.behaviors[other] == .reacting {
                        self.behaviors[other] = .idle
                    }
                }
            }
        }
        if !reduceMotion && !isQuiet { startAutonomyIfNeeded() }
    }

    func cancelInteraction() {
        dragStart = nil
        isInteractionActive = false
        positions = settled
        for occupant in behaviors.keys { behaviors[occupant] = .idle }
        if !reduceMotion && !isQuiet { startAutonomyIfNeeded() }
    }

    func shouldAcceptTap(for occupant: SharedMeadowOccupant) -> Bool {
        if let suppressedTap, suppressedTap.0 == occupant {
            self.suppressedTap = nil
            if Date() < suppressedTap.1 { return false }
        }
        return !isInteractionActive
    }

    func clearLastDrop() { lastDrop = nil }

    func stop() {
        stopAutonomy()
        dragStart = nil
        isInteractionActive = false
    }

    /// A local study of one explicitly invited owned companion. No shared
    /// placement or reward command is emitted by this play interaction.
    func fetchWithCompanion(owner: UUID) {
        let dog = SharedMeadowOccupant.companion(owner)
        guard settled[dog] != nil, !isInteractionActive else { return }
        stopAutonomy()
        let generation = self.generation
        let origin = position(for: dog)
        let target = PasturePlay.fetchTarget(from: origin)
        toyPosition = target
        behaviors[dog] = .chasing
        positions[dog] = target
        playMessage = "Ollie is fetching"
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(self.reduceMotion ? 20 : 850))
            guard generation == self.generation, !self.isInteractionActive else { return }
            self.toyPosition = nil
            self.positions[dog] = origin
            try? await Task.sleep(for: .milliseconds(self.reduceMotion ? 20 : 850))
            guard generation == self.generation, !self.isInteractionActive else { return }
            self.behaviors[dog] = .idle
            self.playMessage = "Ollie brought the toy back"
            if !self.reduceMotion && !self.isQuiet { self.startAutonomyIfNeeded() }
        }
    }

    // MARK: Ambient life

    private func persistArrangement() {
        var arrangement = SharedMeadowArrangement()
        for (occupant, point) in settled { arrangement.positions[occupant.key] = point }
        persist?(arrangement)
    }

    private func startAutonomyIfNeeded() {
        guard !reduceMotion, !isQuiet, !isInteractionActive, schedulerTask == nil, !settled.isEmpty else { return }
        let generation = self.generation
        schedulerTask = Task { [weak self] in
            while !Task.isCancelled {
                let pause = UInt64(7_000_000_000 + ((self?.eventCount ?? 0) % 4) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: pause)
                guard let self, generation == self.generation, !self.isInteractionActive, !Task.isCancelled else { return }
                self.eventCount &+= 1
                await self.performAmbient(generation: generation, seed: (self.configuration?.seed ?? 0) ^ self.eventCount &* 6_364_136_223_846_793_005)
            }
        }
    }

    private func stopAutonomy() {
        generation &+= 1
        toyPosition = nil
        schedulerTask?.cancel()
        schedulerTask = nil
        positions = settled
        for occupant in behaviors.keys where behaviors[occupant] != .dragging { behaviors[occupant] = .idle }
    }

    private func performAmbient(generation: Int, seed: UInt64) async {
        guard let configuration, !configuration.occupants.isEmpty else { return }
        let ordered = configuration.occupants.sorted { $0.occupant.key < $1.occupant.key }
        let entry = ordered[Int(seed % UInt64(ordered.count))]
        let occupant = entry.occupant
        switch occupant {
        case .visitor:
            if seed % 3 == 0 {
                behaviors[occupant] = .ambient(seed % 2 == 0 ? .graze : .tinyHop)
            } else {
                behaviors[occupant] = .wandering
                let neighbours = SharedMeadowLayout.neighbours(settled)
                let direction = PastureSceneLayout.deterministicUnit(seed: seed)
                let from = settled[occupant] ?? position(for: occupant)
                let proposed = PastureScenePoint(x: from.x + cos(direction) * 0.04, y: from.y + sin(direction) * 0.02)
                positions[occupant] = PastureSceneLayout.settledPosition(
                    proposed: proposed, footprint: occupant.footprint, entityKey: occupant.key, among: neighbours
                )
            }
        case .lantern: return
        case .companion:
            behaviors[occupant] = .ambient(.sniff)
        case .member:
            behaviors[occupant] = .ambient(entry.isCompanionLike ? (seed % 2 == 0 ? .sniff : .pause) : (seed % 2 == 0 ? .stanceShift : .wave))
        }
        try? await Task.sleep(nanoseconds: 800_000_000)
        guard generation == self.generation, !isInteractionActive else { return }
        positions[occupant] = settled[occupant]
        behaviors[occupant] = .idle
    }
}
