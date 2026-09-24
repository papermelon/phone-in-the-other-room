import Foundation
import Observation

/// One cancellable throw at a time; completed practice is handed to the Farm save owner.
@MainActor @Observable
final class PastureFetchViewModel {
    private(set) var isPresented = false
    private(set) var isReady = true
    private(set) var positions: [PastureSceneEntityID: PastureScenePoint] = [:]
    private(set) var frame: PastureFetchRound.Frame?
    private(set) var elapsed = 0.0
    private(set) var wakeAssetName: String?
    private(set) var aim: PastureScenePoint?
    private(set) var message = "Swipe the ball to throw. A quicker flick goes farther."
    private(set) var practice: PastureFetchPractice?
    private(set) var landingFeedback: String?
    private var thrownTarget: PastureFetchPractice.Target?
    private var recordedLanding = false
    private var onPracticeComplete: ((PastureFetchPractice) -> Void)?
    var canThrow: Bool { isPresented && isReady && practice?.isComplete != true }
    var practiceTarget: PastureFetchPractice.Target? { isReady ? practice?.target : thrownTarget }
    let origin = PastureScenePoint(x: 0.50, y: 0.76)
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
        message = "Swipe the ball to throw. A quicker flick goes farther."
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
            self.message = "Ollie’s ready. Swipe the ball to throw."
            self.task = nil
        }
    }

    func updateAim(translation: PastureScenePoint, predictedTranslation: PastureScenePoint) {
        guard canThrow else { return }
        aim = PastureFetchRound.throwTarget(origin: origin, translation: translation,
                                           predictedTranslation: predictedTranslation)
    }

    func cancelAim() { aim = nil }

    func setReduceMotion(_ enabled: Bool) { reduceMotion = enabled }

    func flickBall(translation: PastureScenePoint, predictedTranslation: PastureScenePoint) {
        cancelAim()
        guard let target = PastureFetchRound.throwTarget(origin: origin, translation: translation,
                                                        predictedTranslation: predictedTranslation) else { return }
        launch(at: target)
    }

    func startPractice(onComplete: @escaping (PastureFetchPractice) -> Void) {
        guard isPresented, isReady else { return }
        practice = PastureFetchPractice()
        landingFeedback = nil
        aim = nil
        onPracticeComplete = onComplete
        message = "Aim for the clover. Inner ring: 3 points. Outer ring: 1 point."
    }

    func freeFetch() {
        guard isPresented, isReady else { return }
        practice = nil
        landingFeedback = nil
        aim = nil
        onPracticeComplete = nil
        message = "Swipe the ball to throw. A quicker flick goes farther."
    }

    func aimBall(heading: Double, strength: Double, launch: Bool = false) {
        guard let travel = PastureFetchPractice.translation(heading: heading, strength: strength) else { return }
        if launch { flickBall(translation: travel, predictedTranslation: travel) }
        else { updateAim(translation: travel, predictedTranslation: travel) }
    }

    /// Destination presets are free-play only; practice always requires a deliberate throw.
    func throwBall(at target: PastureScenePoint) {
        guard practice == nil else { return }
        launch(at: target)
    }

    private func launch(at target: PastureScenePoint) {
        guard canThrow, let ollie, let start = positions[ollie] else { return }
        task?.cancel()
        let round = PastureFetchRound(origin: origin, target: target, ollieStart: start)
        thrownTarget = practice?.target
        recordedLanding = false
        landingFeedback = nil
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
                    self.task = nil
                    return
                }
                do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
            }
        }
    }

    func advance(round: PastureFetchRound, elapsed: Double, delta: Double, ollie: PastureSceneEntityID) {
        guard isPresented, !isReady else { return }
        self.elapsed = elapsed
        let sample = round.frame(at: elapsed, reduceMotion: reduceMotion)
        frame = sample
        if elapsed >= round.flightDuration, !recordedLanding {
            recordedLanding = true
            if practice != nil {
                practice?.record(landing: round.target)
                switch practice?.scores.last {
                case 3: landingFeedback = "Right in the middle. 3 points."
                case 1: landingFeedback = "In the clover. 1 point."
                default: landingFeedback = "Outside the clover. 0 points."
                }
            }
        }
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
        if sample.phase == .ready {
            isReady = true
            if let practice, practice.isComplete {
                message = "Five throws, well played. \(practice.score) of \(PastureFetchPractice.maximumScore) points."
                let completion = onPracticeComplete
                onPracticeComplete = nil
                completion?(practice)
            } else {
                message = "Back with you. Swipe the ball again."
            }
        }
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
        practice = nil
        thrownTarget = nil
        landingFeedback = nil
        onPracticeComplete = nil
    }
}
