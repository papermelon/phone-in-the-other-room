import Foundation

/// Inventory identity is unchanged; the same fitted garment follows every pose.
enum OllieGarment: String, CaseIterable {
    case mossBandana = "ollie_moss_bandana"
    case moonKerchief = "ollie_moon_kerchief"
    case brassBell = "ollie_brass_bell"
    case cloverCollar = "ollie_clover_collar"
    case sunriseScarf = "ollie_sunrise_scarf"
    case starKeeperCape = "ollie_star_keeper_cape"

    init?(itemID: String?) {
        guard let itemID else { return nil }
        self.init(rawValue: itemID)
    }
}

/// Authored neck registration in the original 512-point canvas. Curled poses
/// expose only the side of the neck, so cloth folds away instead of covering paws.
struct OllieGarmentFit: Equatable {
    let x: Double
    let y: Double
    let width: Double
    let angle: Double
    var drape: Double = 1

    static func forAsset(_ name: String) -> Self? {
        if name == "dog/dog_classic_farm_idle" {
            return .init(x: 231, y: 253, width: 129, angle: 2)
        }
        if NightJourneyAssets.ollieHomeIdleFrames.contains(name) {
            return .init(x: 241, y: 253, width: 127, angle: 1)
        }
        if let index = NightJourneyAssets.ollieRunFrames.firstIndex(of: name) {
            return runFits[index]
        }
        guard let pose = Int(name.suffix(2)), name.hasPrefix("dog/dog_ollie_motion_pose_") else { return nil }
        switch pose {
        case 2, 3: return .init(x: 229, y: 268, width: 130, angle: 1)
        case 4: return .init(x: 240, y: 265, width: 128, angle: 0)
        case 5: return .init(x: 257, y: 365, width: 112, angle: 9, drape: 0.40)
        case 6: return .init(x: 243, y: 387, width: 128, angle: 6, drape: 0.20)
        case 7: return .init(x: 237, y: 360, width: 74, angle: 52, drape: 0.24)
        case 8: return .init(x: 239, y: 336, width: 73, angle: 64, drape: 0.22)
        case 9: return .init(x: 235, y: 344, width: 68, angle: 67, drape: 0.20)
        case 10: return .init(x: 261, y: 365, width: 117, angle: 18, drape: 0.28)
        case 11: return .init(x: 267, y: 281, width: 118, angle: 6, drape: 0.85)
        default: return nil
        }
    }

    private static let runFits: [Self] = [
        .init(x: 346, y: 271, width: 94, angle: 23),
        .init(x: 307, y: 300, width: 94, angle: 19),
        .init(x: 307, y: 272, width: 101, angle: 22),
        .init(x: 331, y: 274, width: 93, angle: 22),
        .init(x: 297, y: 306, width: 96, angle: 20),
        .init(x: 320, y: 273, width: 97, angle: 21)
    ]
}
