import SwiftUI

/// Drives a visible-scene-relative animation clock. It wakes only for an
/// action boundary or an authored-frame boundary, never a display-frame loop.
struct OllieCompanionAnimationView<Content: View>: View {
    var schedule: OllieCompanionAnimationSchedule = .gentle
    var isMotionEnabled = true
    var detailRevision = 0
    var nextDetailFrameTransition: ((OllieCompanionAnimationFrame) -> TimeInterval?)? = nil
    @ViewBuilder var content: (OllieCompanionAnimationFrame, Date) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var playback = OllieCompanionAnimationPlayback()
    @State private var renderedFrame = OllieCompanionAnimationFrame.neutral
    @State private var renderedAt = Date()

    var body: some View {
        content(renderedFrame, renderedAt)
            .onAppear { isVisible = true }
            .onDisappear {
                isVisible = false
                pauseOrSettle()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { pauseOrSettle() }
            }
            .onChange(of: reduceMotion) { _, enabled in
                if enabled { pauseOrSettle() }
            }
            .task(id: DriverKey(isRunning: shouldRun, detailRevision: detailRevision)) {
                guard shouldRun else {
                    pauseOrSettle()
                    return
                }

                if playback.startedAt == nil {
                    let start = ProcessInfo.processInfo.systemUptime
                    playback.resume(at: start)
                    renderedAt = Date()
                    renderedFrame = playback.frame(at: start, schedule: schedule)
                }

                while !Task.isCancelled {
                    let now = ProcessInfo.processInfo.systemUptime
                    let frame = playback.frame(at: now, schedule: schedule)
                    renderedAt = Date()
                    renderedFrame = frame

                    guard let next = nextTransition(after: now, frame: frame) else { return }
                    let delay = next - now
                    guard delay > 0 else { return }
                    do {
                        try await Task.sleep(for: .seconds(delay))
                    } catch {
                        return
                    }
                }
            }
    }

    private var shouldRun: Bool {
        isVisible && isMotionEnabled && !reduceMotion && scenePhase == .active
    }

    private func pauseOrSettle() {
        let now = ProcessInfo.processInfo.systemUptime
        renderedAt = Date()
        if reduceMotion {
            playback.settleForReducedMotion()
        } else {
            playback.pause(at: now, schedule: schedule)
        }
        renderedFrame = playback.frozenFrame
    }

    private func nextTransition(
        after monotonicTime: TimeInterval,
        frame: OllieCompanionAnimationFrame
    ) -> TimeInterval? {
        guard let startedAt = playback.startedAt,
              let elapsed = playback.elapsed(at: monotonicTime) else { return nil }

        let actionTransition = schedule.nextTransition(after: elapsed).map {
            startedAt + $0
        }
        let detailTransition: TimeInterval?
        if let nextDetailFrameTransition,
           let actionElapsed = nextDetailFrameTransition(frame),
           actionElapsed > frame.actionElapsed {
            let actionStart = elapsed - frame.actionElapsed
            let deadline = startedAt + actionStart + actionElapsed
            detailTransition = deadline > monotonicTime ? deadline : nil
        } else {
            detailTransition = nil
        }
        switch (actionTransition, detailTransition) {
        case let (actionTransition?, detailTransition?): return min(actionTransition, detailTransition)
        case let (actionTransition?, nil): return actionTransition
        case let (nil, detailTransition?): return detailTransition
        case (nil, nil): return nil
        }
    }

    private struct DriverKey: Hashable {
        let isRunning: Bool
        let detailRevision: Int
    }
}
