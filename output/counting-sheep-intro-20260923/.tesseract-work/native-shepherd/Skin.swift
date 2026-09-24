import Foundation
enum ShepherdSkinTone: String, Codable, CaseIterable, Identifiable {
    case porcelain, warm, olive, brown, deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .porcelain: return "Porcelain"
        case .warm: return "Warm"
        case .olive: return "Olive"
        case .brown: return "Brown"
        case .deep: return "Deep"
        }
    }
}


enum ShepherdStudyHeadwear { case fieldHat, headscarf, beanie }
