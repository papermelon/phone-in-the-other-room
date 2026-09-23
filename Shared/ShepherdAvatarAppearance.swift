import Foundation

enum ShepherdStudyHeadwear { case fieldHat, headscarf, beanie }

extension ShepherdStudyAppearance {
    init(profile: ShepherdProfile) {
        self.init()
        head = ShepherdStudySilhouette(rawValue: profile.headShape.rawValue) ?? .pear
        skin = profile.skinTone
        eyes = profile.headShape == .round || profile.headShape == .boxy ? .open : .calm
        switch profile.hairStyle {
        case .cropped: hair = .short
        case .waves: hair = .waves
        case .curls: hair = .curls
        case .coils: hair = .coils
        case .long: hair = .long
        }
        switch profile.shirtItemID {
        case "shepherd_berry_shirt": shirt = .berry
        case "shepherd_dusk_shirt": shirt = .dusk
        case "shepherd_amber_shirt": shirt = .amber
        default: shirt = .cream
        }
        switch profile.outfitItemID {
        case "shepherd_open_moss_coat": outfit = .openCoat
        case "shepherd_moss_coat": outfit = .coat
        case "shepherd_moon_coat": outfit = .moonCoat
        case "shepherd_field_overalls": outfit = .overalls
        case "shepherd_star_keeper_cloak": outfit = .cloak
        default: outfit = .shirt
        }
        hat = true
        switch profile.accessoryItemID {
        case "shepherd_wool_hat": headwear = .fieldHat
        case "shepherd_clover_headscarf": headwear = .headscarf
        case "shepherd_moon_beanie": headwear = .beanie
        default: hat = false
        }
    }
}

// Both social poses consume the same bounded appearance and fallback rules.
extension CountingSheepPublicPresentation {
    var shepherdProfile: ShepherdProfile {
        let source = renderableAppearance
        return ShepherdProfile(
            skinTone: ShepherdSkinTone(rawValue: source.skinToneID) ?? .warm,
            hairStyle: ShepherdHairStyle(rawValue: source.hairStyleID) ?? .waves,
            outfitItemID: source.shepherdOutfitID == "shepherd_moss_coat" && source.shepherdOuterwearID == "shepherd_open_moss_coat" ? "shepherd_open_moss_coat" :
                (source.shepherdOutfitID == "none" ? nil : source.shepherdOutfitID),
            accessoryItemID: source.shepherdAccessoryID == "none" ? nil : source.shepherdAccessoryID,
            headShapeID: source.headShapeID,
            shirtItemID: source.shepherdShirtID == "none" ? nil : source.shepherdShirtID
        )
    }
}

enum CampfireShepherdMotionRules {
    static func blanketLift(at time: TimeInterval, reduceMotion: Bool, isActive: Bool) -> Double {
        guard !reduceMotion, isActive, time.isFinite else { return 0 }
        return (1 + sin(time * 2 * .pi / 5)) * 0.9
    }
}

// The deployed social contract has no shirt slot or open-coat identifier yet.
// Keep outbound appearances valid while retaining the full private wardrobe.
extension ShepherdProfile {
    var sharedOutfitID: String {
        if outfitItemID == "shepherd_open_moss_coat" { return "shepherd_moss_coat" }
        guard let outfitItemID,
              CountingSheepPublicPresentationAllowlist.shepherdOutfitIDs.contains(outfitItemID) else { return "none" }
        return outfitItemID
    }
}
