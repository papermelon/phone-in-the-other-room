import Foundation
import Observation

/// Fetch has one ball and one cancellable round; it never writes Farm progress.
@MainActor @Observable
final class PastureFetchViewModel {
    private(set) var isPresented = false
    private(set) var isReady = true
    private(set) var positions: [PastureSceneEntityID: PastureScenePoint] = [:]
    private(set) var frame: PastureFetchRound.Frame?
    private(set) var elapsed = 0.0
    private(set) var wakeAssetName: String?
    private(set) var aim: PastureScenePoint?
    private(set) var message = "Tap a spot, or drag and release. Flick faster to throw farther."
    let origin = PastureScenePoint(x: 0.22, y: 0.83)
    private var ollie: PastureSceneEntityID?
    private var task: Task<Void, Never>?
    private var reduceMotion = false
    private var generation = 0

    func begin(positions: [PastureSceneEntityID: PastureScenePoint], ollie: PastureSceneEntityID, reduceMotion: Bool, restingAsset: String? = nil) {
        stop()
        self.positions = positions
        self.ollie = ollie
        self.reduceMotion = reduceMotion
        isPresented = true
        isReady = true
        message = "Tap a spot, or drag and release. Flick faster to throw farther."
        let wakeFrames = PastureFetchWakeUp.frames(from: restingAsset)
        guard !wakeFrames.isEmpty else { return }
        isReady = false
        message = "Ollie is getting up."
        wakeAssetName = wakeFrames[0].assetName
        let current = generation
        task = Task { [weak self] in
            for frame in wakeFrames {
                guard let self, self.generation == current, !Task.isCancelled else { return }
                // Reduce Motion holds the rest pose, then shows the upright pose without cycling.
                if !reduceMotion { self.wakeAssetName = frame.assetName }
                do { try await Task.sleep(for: .seconds(frame.duration)) } catch { return }
            }
            guard let self, self.generation == current, !Task.isCancelled else { return }
            self.wakeAssetName = nil
            self.isReady = true
            self.message = "Ollie’s ready. Tap a spot, or drag and release."
            self.task = nil
        }
    }

    func updateAim(release: PastureScenePoint, predicted: PastureScenePoint) {
        guard isPresented, isReady else { return }
        aim = PastureFetchRound.throwTarget(release: release, predicted: predicted)
    }

    func throwBall(at target: PastureScenePoint) {
        guard isPresented, isReady, let ollie, let start = positions[ollie] else { return }
        let round = PastureFetchRound(origin: origin, target: target, ollieStart: start)
        isReady = false
        aim = nil
        elapsed = 0
        frame = round.frame(at: 0, reduceMotion: reduceMotion)
        message = "Ollie is chasing the ball."
        let current = generation
        task = Task { [weak self] in
            let clock = ContinuousClock()
            let began = clock.now
            var previous = 0.0
            while !Task.isCancelled {
                guard let self, self.generation == current else { return }
                let duration = began.duration(to: clock.now).components
                let t = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
                self.advance(round: round, elapsed: t, delta: t - previous, ollie: ollie)
                previous = t
                if t >= round.duration {
                    self.isReady = true
                    self.message = "Back with you. Choose your next throw."
                    self.task = nil
                    return
                }
                do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
            }
        }
    }

    private func advance(round: PastureFetchRound, elapsed: Double, delta: Double, ollie: PastureSceneEntityID) {
        self.elapsed = elapsed
        let sample = round.frame(at: elapsed, reduceMotion: reduceMotion)
        frame = sample
        positions[ollie] = sample.ollie
        let ahead = round.frame(at: min(round.returnTime, elapsed + 0.55)).ollie
        let sheep = positions.keys.filter { $0.kind == .sheep }.sorted { $0.id < $1.id }
        for entity in sheep {
            guard let point = positions[entity] else { continue }
            positions[entity] = PastureFetchRound.sheepStep(from: point, ollie: sample.ollie, ahead: ahead,
                neighbours: positions.keys.filter { $0 != entity && $0 != ollie }.sorted { $0.id < $1.id }
                    .compactMap { positions[$0] }, delta: delta)
        }
        if sample.phase == .pickup { message = "Ollie is picking up the ball." }
        if sample.phase == .returning { message = "Ollie is bringing it back." }
    }

    func stop() {
        generation &+= 1
        task?.cancel()
        task = nil
        isPresented = false
        isReady = true
        frame = nil
        wakeAssetName = nil
        aim = nil
        positions = [:]
    }
}
