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

/// Three independently authored landmarks register every neck-worn garment to Ollie's pose.
/// Coordinates belong to the uncropped 512-point sprite, not the Shop thumbnail.
struct OllieNeckwearPose: Equatable {
    let neckLeft: CGPoint
    let neckRight: CGPoint
    let bibTip: CGPoint
    var showsTie = true
    var showsFrontDetail = true

    static func forAsset(_ name: String) -> Self? {
        if let index = NightJourneyAssets.ollieHomeIdleFrames.firstIndex(of: name) {
            return home[index]
        }
        if let index = NightJourneyAssets.ollieRunFrames.firstIndex(of: name) {
            return running[index]
        }
        if name == "dog/dog_classic_farm_idle" { return pose(236, 249, 361, 256, 307, 332) }
        guard name.hasPrefix("dog/dog_ollie_motion_pose_"), let number = Int(name.suffix(2)) else { return nil }
        switch number {
        case 2: return pose(233, 246, 351, 254, 301, 327)
        case 3: return pose(237, 261, 365, 270, 310, 340)
        case 4: return pose(241, 254, 364, 258, 310, 332)
        case 5: return pose(253, 359, 368, 375, 315, 417, tie: false)
        case 6: return pose(239, 371, 372, 398, 321, 427, tie: false)
        case 7: return pose(228, 346, 256, 398, 235, 392, tie: false, detail: false)
        case 8: return pose(235, 328, 264, 395, 236, 374, tie: false, detail: false)
        case 9: return pose(238, 332, 264, 400, 238, 376, tie: false, detail: false)
        case 10: return pose(253, 357, 381, 399, 331, 419, tie: false)
        case 11: return pose(264, 279, 376, 298, 306, 355)
        default: return nil
        }
    }

    // Blink frames share anatomy. During the tilt the neckline follows the head,
    // while the bib remains on the chest instead of rotating like a rigid sticker.
    private static let home: [Self] = [
        pose(242, 249, 367, 253, 309, 330),
        pose(242, 249, 367, 253, 309, 330),
        pose(242, 249, 367, 253, 309, 330),
        pose(240, 250, 366, 252, 309, 330),
        pose(231, 254, 351, 234, 307, 330),
        pose(239, 251, 363, 247, 309, 330)
    ]

    private static let running: [Self] = [
        pose(344, 261, 435, 294, 401, 353),
        pose(303, 287, 394, 322, 350, 371),
        pose(307, 260, 403, 295, 367, 345),
        pose(330, 258, 422, 290, 393, 342),
        pose(295, 291, 388, 326, 341, 372),
        pose(318, 260, 410, 292, 375, 343)
    ]

    private static func pose(_ lx: Double, _ ly: Double, _ rx: Double, _ ry: Double,
                             _ tx: Double, _ ty: Double, tie: Bool = true, detail: Bool = true) -> Self {
        .init(neckLeft: .init(x: lx, y: ly), neckRight: .init(x: rx, y: ry),
              bibTip: .init(x: tx, y: ty), showsTie: tie, showsFrontDetail: detail)
    }
}


