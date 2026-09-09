import Foundation

/// Drawing vocabulary shared by the production avatar and the isolated art study.
enum ShepherdStudySilhouette: String, CaseIterable, Identifiable {
    case pear, round, boxy, triangular
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pear: return "Pear · B"
        case .round: return "Round · C"
        case .boxy: return "Boxy · exploration"
        case .triangular: return "Triangular · exploration"
        }
    }
}

enum ShepherdStudyDirection: String, CaseIterable, Identifiable {
    case front, threeQuarter, side, rearThreeQuarter, back
    var id: String { rawValue }
    var hidesFace: Bool { self == .rearThreeQuarter || self == .back }
    var title: String {
        switch self {
        case .front: return "Front"
        case .threeQuarter: return "Three-quarter"
        case .side: return "Side"
        case .rearThreeQuarter: return "Back three-quarter"
        case .back: return "Back"
        }
    }
    var next: Self {
        let index = Self.allCases.firstIndex(of: self) ?? 0
        return Self.allCases[(index + 1) % Self.allCases.count]
    }
}

enum ShepherdStudyHair: String, CaseIterable, Identifiable {
    case short, long, waves, curls, coils
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ShepherdStudyOutfit: String, CaseIterable, Identifiable {
    case shirt, coat, dress, moonCoat, overalls, cloak
    var id: String { rawValue }
    var title: String {
        switch self {
        case .shirt: return "Shirt + trousers"
        case .coat: return "Moss coat"
        case .dress: return "Berry dress"
        case .moonCoat: return "Moonlit coat"
        case .overalls: return "Field overalls"
        case .cloak: return "Star-Keeper cloak"
        }
    }
}

enum ShepherdStudyEyes: String, CaseIterable, Identifiable {
    case calm, open
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum ShepherdStudyMotion: String, CaseIterable, Identifiable {
    case still, idle, walk
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct ShepherdStudyAppearance: Equatable {
    var head: ShepherdStudySilhouette = .pear
    var hair: ShepherdStudyHair = .short
    var eyes: ShepherdStudyEyes = .calm
    var skin: ShepherdSkinTone = .warm
    var outfit: ShepherdStudyOutfit = .coat
    var hat = false
    var faceLeft = false
    var headwear: ShepherdStudyHeadwear = .fieldHat

    static let round = Self(head: .round, hair: .long, eyes: .open, outfit: .dress)
}

struct ShepherdStudyFoot: Equatable {
    let travel: Double
    let lift: Double
}

struct ShepherdStudyPose: Equatable {
    var leftFoot = ShepherdStudyFoot(travel: 0, lift: 0)
    var rightFoot = ShepherdStudyFoot(travel: 0, lift: 0)
    var armSwing: Double = 0
    var bodyLift: Double = 0
    var headTilt: Double = 0
    var eyesClosed = false

    static let still = Self()
}

enum ShepherdStudyMotionRules {
    static let cycleDuration: TimeInterval = 0.9

    static func canAnimate(_ motion: ShepherdStudyMotion, reduceMotion: Bool, isActive: Bool) -> Bool {
        motion != .still && !reduceMotion && isActive
    }

    static func pose(
        at elapsed: TimeInterval,
        motion: ShepherdStudyMotion,
        reduceMotion: Bool = false,
        isActive: Bool = true
    ) -> ShepherdStudyPose {
        guard canAnimate(motion, reduceMotion: reduceMotion, isActive: isActive), elapsed.isFinite else {
            return .still
        }
        let time = max(0, elapsed)
        if motion == .idle {
            let blink = time.truncatingRemainder(dividingBy: 4.6)
            return ShepherdStudyPose(headTilt: sin(time * 1.2) * 0.8, eyesClosed: blink > 4.35 && blink < 4.49)
        }
        let phase = (time / cycleDuration).truncatingRemainder(dividingBy: 1)
        return ShepherdStudyPose(
            leftFoot: foot(at: phase),
            rightFoot: foot(at: (phase + 0.5).truncatingRemainder(dividingBy: 1)),
            armSwing: sin(phase * 2 * .pi) * 13,
            bodyLift: abs(sin(phase * 2 * .pi)) * 1.4,
            headTilt: sin(phase * 2 * .pi) * 0.45
        )
    }

    /// Stance stays on the ground for 60% of the cycle; only the recovery foot lifts.
    static func foot(at phase: Double) -> ShepherdStudyFoot {
        if phase < 0.6 { return ShepherdStudyFoot(travel: 7 - phase / 0.6 * 14, lift: 0) }
        let recovery = (phase - 0.6) / 0.4
        let eased = recovery * recovery * (3 - 2 * recovery)
        return ShepherdStudyFoot(travel: -7 + eased * 14, lift: sin(recovery * .pi) * 6)
    }
}
