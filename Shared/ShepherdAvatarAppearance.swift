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
        switch profile.outfitItemID {
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
