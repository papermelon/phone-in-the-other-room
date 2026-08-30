import Foundation

/// A deterministic vocabulary shared by Home and Farm. Variations are
/// scheduled independently from rendering, with no session or wall-clock state.
enum OllieCompanionAction: String, CaseIterable, Equatable, Hashable {
    case neutral
    case headTilt
    case earTuck
    case tongueGreeting
    case settleToRest
    case resting
    case rise
}

struct OllieCompanionAnimationFrame: Equatable {
    let action: OllieCompanionAction
    let cycleElapsed: TimeInterval
    let actionElapsed: TimeInterval
    let isAnimated: Bool

    static let neutral = OllieCompanionAnimationFrame(
        action: .neutral,
        cycleElapsed: 0,
        actionElapsed: 0,
        isAnimated: false
    )
}

struct OllieCompanionAnimationSchedule: Equatable {
    private static let timingEpsilon: TimeInterval = 0.000_000_001

    struct Segment: Equatable {
        let action: OllieCompanionAction
        let duration: TimeInterval

        init(_ action: OllieCompanionAction, duration: TimeInterval) {
            self.action = action
            self.duration = duration
        }
    }

    /// A brief first neutral makes the companion feel alive on ordinary Home
    /// visits. The rest sequence remains contiguous and tongue stays separate.
    static let gentle = OllieCompanionAnimationSchedule(segments: [
        .init(.neutral, duration: 1),
        .init(.headTilt, duration: 1.2),
        .init(.neutral, duration: 5),
        .init(.earTuck, duration: 0.60),
        .init(.neutral, duration: 6),
        .init(.tongueGreeting, duration: 0.75),
        .init(.neutral, duration: 8),
        .init(.settleToRest, duration: 1.22),
        .init(.resting, duration: 5),
        .init(.rise, duration: 0.62),
        .init(.neutral, duration: 10)
    ])

    let segments: [Segment]

    init(segments: [Segment]) {
        self.segments = segments.filter { $0.duration.isFinite && $0.duration > 0 }
    }

    var cycleDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    func action(at elapsed: TimeInterval) -> OllieCompanionAction {
        frame(at: elapsed).action
    }

    func frame(at elapsed: TimeInterval) -> OllieCompanionAnimationFrame {
        guard elapsed.isFinite, cycleDuration.isFinite, cycleDuration > 0 else { return .neutral }
        let phase = normalizedPhase(for: elapsed)
        var cursor: TimeInterval = 0
        for segment in segments {
            let start = cursor
            cursor += segment.duration
            if phase < cursor - Self.timingEpsilon {
                return OllieCompanionAnimationFrame(
                    action: segment.action,
                    cycleElapsed: phase,
                    actionElapsed: phase - start,
                    isAnimated: true
                )
            }
        }
        return .neutral
    }

    /// The next semantic transition strictly after `elapsed`. This prevents a
    /// boundary value from creating a zero-delay wake loop.
    func nextTransition(after elapsed: TimeInterval) -> TimeInterval? {
        guard elapsed.isFinite, cycleDuration.isFinite, cycleDuration > 0 else { return nil }
        let cycleStart = floor(elapsed / cycleDuration) * cycleDuration
        let phase = normalizedPhase(for: elapsed)
        var cursor: TimeInterval = 0
        for segment in segments {
            cursor += segment.duration
            let candidate = cycleStart + cursor
            if phase < cursor - Self.timingEpsilon, candidate > elapsed + Self.timingEpsilon {
                return candidate
            }
        }
        let nextCycle = cycleStart + cycleDuration
        return nextCycle > elapsed + Self.timingEpsilon ? nextCycle : nil
    }

    private func normalizedPhase(for elapsed: TimeInterval) -> TimeInterval {
        let remainder = elapsed.truncatingRemainder(dividingBy: cycleDuration)
        return remainder >= 0 ? remainder : remainder + cycleDuration
    }
}

/// An authored frame in a non-looping action sequence. Asset names are shared
/// contracts only; UIKit availability is checked by the iOS renderer.
struct OllieCompanionSpriteFrame: Equatable {
    let assetName: String
    let duration: TimeInterval
    let poseIdentifier: Int
    let overlayFamily: OllieCompanionSpriteOverlayFamily

    init(
        assetName: String,
        duration: TimeInterval,
        poseIdentifier: Int,
        overlayFamily: OllieCompanionSpriteOverlayFamily = .motionPose
    ) {
        self.assetName = assetName
        self.duration = duration
        self.poseIdentifier = poseIdentifier
        self.overlayFamily = overlayFamily
    }
}

struct OllieCompanionSpriteSequence: Equatable {
    private static let timingEpsilon: TimeInterval = 0.000_000_001

    let frames: [OllieCompanionSpriteFrame]

    init(frames: [OllieCompanionSpriteFrame]) {
        self.frames = frames.filter { $0.duration.isFinite && $0.duration > 0 }
    }

    var duration: TimeInterval {
        frames.reduce(0) { $0 + $1.duration }
    }

    func frame(at actionElapsed: TimeInterval) -> OllieCompanionSpriteFrame? {
        guard actionElapsed.isFinite, actionElapsed >= 0 else { return nil }
        var cursor: TimeInterval = 0
        for frame in frames {
            cursor += frame.duration
            if actionElapsed < cursor - Self.timingEpsilon { return frame }
        }
        return nil
    }

    /// The next authored-frame boundary strictly after the supplied elapsed
    /// time. The action scheduler owns the transition after this sequence.
    func nextFrameTransition(after actionElapsed: TimeInterval) -> TimeInterval? {
        guard actionElapsed.isFinite, actionElapsed >= 0 else { return nil }
        var cursor: TimeInterval = 0
        for frame in frames {
            cursor += frame.duration
            if cursor > actionElapsed + Self.timingEpsilon { return cursor }
        }
        return nil
    }
}

/// The production contract for 512-point registered Ollie frames. Pose 01 and
/// 12 reuse canonical idle art so action sequences close without a neutral jump.
struct OllieCompanionSpriteManifest: Equatable {
    let sequences: [OllieCompanionAction: OllieCompanionSpriteSequence]

    static let production = OllieCompanionSpriteManifest(sequences: [
        .headTilt: .init(frames: [
            .init(assetName: "dog/dog_classic_home_idle_frame_02", duration: 0.15, poseIdentifier: 2, overlayFamily: .homeIdle),
            .init(assetName: "dog/dog_classic_home_idle_frame_03", duration: 0.17, poseIdentifier: 3, overlayFamily: .homeIdle),
            .init(assetName: "dog/dog_classic_home_idle_frame_04", duration: 0.26, poseIdentifier: 4, overlayFamily: .homeIdle),
            .init(assetName: "dog/dog_classic_home_idle_frame_05", duration: 0.30, poseIdentifier: 5, overlayFamily: .homeIdle),
            .init(assetName: "dog/dog_classic_home_idle_frame_06", duration: 0.32, poseIdentifier: 6, overlayFamily: .homeIdle)
        ]),
        .earTuck: .init(frames: [
            motionFrame(1, duration: 0.16), motionFrame(2, duration: 0.16), motionFrame(3, duration: 0.28)
        ]),
        .tongueGreeting: .init(frames: [
            motionFrame(1, duration: 0.18), motionFrame(4, duration: 0.36), motionFrame(1, duration: 0.21)
        ]),
        .settleToRest: .init(frames: [
            motionFrame(3, duration: 0.16), motionFrame(5, duration: 0.16), motionFrame(6, duration: 0.18),
            motionFrame(7, duration: 0.20), motionFrame(8, duration: 0.22), motionFrame(9, duration: 0.30)
        ]),
        .resting: .init(frames: [motionFrame(9, duration: 5)]),
        .rise: .init(frames: [
            motionFrame(10, duration: 0.20), motionFrame(11, duration: 0.18), motionFrame(12, duration: 0.24)
        ])
    ])

    func sequence(for action: OllieCompanionAction) -> OllieCompanionSpriteSequence? {
        sequences[action]
    }

    func capabilityActions(for action: OllieCompanionAction) -> [OllieCompanionAction] {
        action.motionGroup
    }

    /// Returns all assets that must be present before an action can start. The
    /// rest triplet is evaluated as one unit, avoiding a neutral-to-rest jump
    /// if a later settle or rise frame has not arrived.
    func requiredAssetNames(
        for action: OllieCompanionAction,
        accessoryItemID: String?
    ) -> Set<String>? {
        guard action != .neutral else { return [] }
        let group = action.motionGroup
        let frames = group.flatMap { sequences[$0]?.frames ?? [] }
        guard !frames.isEmpty else { return nil }

        var names = Set(frames.map(\.assetName))
        if let cosmetic = OllieCompanionMotionCosmetic(itemID: accessoryItemID) {
            names.formUnion(frames.map { cosmetic.overlayAssetName(for: $0) })
        }
        return names
    }

    func canRender(
        action: OllieCompanionAction,
        accessoryItemID: String?,
        availableAssetNames: Set<String>
    ) -> Bool {
        guard let required = requiredAssetNames(for: action, accessoryItemID: accessoryItemID) else {
            return false
        }
        return required.isSubset(of: availableAssetNames)
    }

    func overlayAssetName(
        for accessoryItemID: String?,
        frame: OllieCompanionSpriteFrame
    ) -> String? {
        OllieCompanionMotionCosmetic(itemID: accessoryItemID)?
            .overlayAssetName(for: frame)
    }

    func neutralOverlayAssetName(for accessoryItemID: String?) -> String? {
        OllieCompanionMotionCosmetic(itemID: accessoryItemID)?
            .homeIdleOverlayAssetName(for: 1)
    }

    private static func motionFrame(_ poseIdentifier: Int, duration: TimeInterval) -> OllieCompanionSpriteFrame {
        let assetName: String
        switch poseIdentifier {
        case 1, 12: assetName = "dog/dog_classic_home_idle_frame_01"
        default: assetName = String(format: "dog/dog_ollie_motion_pose_%02d", poseIdentifier)
        }
        return OllieCompanionSpriteFrame(assetName: assetName, duration: duration, poseIdentifier: poseIdentifier)
    }
}

private extension OllieCompanionAction {
    var motionGroup: [OllieCompanionAction] {
        switch self {
        case .settleToRest, .resting, .rise:
            [.settleToRest, .resting, .rise]
        case .neutral:
            []
        default:
            [self]
        }
    }
}

enum OllieCompanionSpriteOverlayFamily: Equatable {
    case homeIdle
    case motionPose
}

private enum OllieCompanionMotionCosmetic: String {
    case mossBandana = "ollie_moss_bandana"
    case moonKerchief = "ollie_moon_kerchief"
    case brassTrailBell = "ollie_brass_bell"

    init?(itemID: String?) {
        guard let itemID else { return nil }
        self.init(rawValue: itemID)
    }

    func overlayAssetName(for frame: OllieCompanionSpriteFrame) -> String {
        switch frame.overlayFamily {
        case .homeIdle:
            return homeIdleOverlayAssetName(for: frame.poseIdentifier)
        case .motionPose:
            return motionPoseOverlayAssetName(for: frame.poseIdentifier)
        }
    }

    func homeIdleOverlayAssetName(for frameIdentifier: Int) -> String {
        let suffix: String
        switch self {
        case .mossBandana: suffix = "moss_bandana"
        case .moonKerchief: suffix = "moon_kerchief"
        case .brassTrailBell: suffix = "brass_trail_bell"
        }
        return String(format: "dog/dog_ollie_home_idle_%@_frame_%02d", suffix, frameIdentifier)
    }

    private func motionPoseOverlayAssetName(for poseIdentifier: Int) -> String {
        let suffix: String
        switch self {
        case .mossBandana: suffix = "moss_bandana"
        case .moonKerchief: suffix = "moon_kerchief"
        case .brassTrailBell: suffix = "brass_trail_bell"
        }
        return String(format: "dog/dog_ollie_motion_%@_pose_%02d", suffix, poseIdentifier)
    }
}

/// Holds a visible-scene-relative epoch. Pausing freezes the last pose, while
/// every resume begins with a fresh neutral hold rather than a mid-flop phase.
struct OllieCompanionAnimationPlayback: Equatable {
    private(set) var startedAt: TimeInterval?
    private(set) var frozenFrame: OllieCompanionAnimationFrame = .neutral

    mutating func resume(at monotonicTime: TimeInterval) {
        startedAt = monotonicTime
        frozenFrame = .neutral
    }

    mutating func frame(at monotonicTime: TimeInterval, schedule: OllieCompanionAnimationSchedule) -> OllieCompanionAnimationFrame {
        guard let startedAt else { return frozenFrame }
        let elapsed = monotonicTime - startedAt
        let frame = schedule.frame(at: elapsed)
        frozenFrame = frame
        return frame
    }

    mutating func pause(at monotonicTime: TimeInterval, schedule: OllieCompanionAnimationSchedule) {
        _ = frame(at: monotonicTime, schedule: schedule)
        startedAt = nil
    }

    mutating func settleForReducedMotion() {
        startedAt = nil
        frozenFrame = .neutral
    }

    func elapsed(at monotonicTime: TimeInterval) -> TimeInterval? {
        guard let startedAt else { return nil }
        let elapsed = monotonicTime - startedAt
        return elapsed.isFinite ? max(0, elapsed) : nil
    }
}
