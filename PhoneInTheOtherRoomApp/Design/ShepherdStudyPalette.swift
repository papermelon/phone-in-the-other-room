import SwiftUI

/// Illustration pigments stay consistent across appearance modes, like the approved animal art.
enum ShepherdStudyPalette {
    static let hair = Color(red: 0.36, green: 0.19, blue: 0.29)
    static let ink = Color(red: 0.32, green: 0.18, blue: 0.27)
    static let cream = Color(red: 0.96, green: 0.90, blue: 0.74)
    static let moon = Color(red: 0.39, green: 0.47, blue: 0.59)
    static let midnight = Color(red: 0.28, green: 0.33, blue: 0.47)
    static let denim = Color(red: 0.48, green: 0.52, blue: 0.43)
    static let moss = Color(red: 0.45, green: 0.49, blue: 0.28)
    static let pocket = Color(red: 0.39, green: 0.43, blue: 0.23)
    static let berry = Color(red: 0.65, green: 0.32, blue: 0.38)
    static let trousers = Color(red: 0.68, green: 0.37, blue: 0.29)
    static let boots = Color(red: 0.34, green: 0.20, blue: 0.28)
    static let hat = Color(red: 0.82, green: 0.63, blue: 0.30)
    static let hatBand = Color(red: 0.73, green: 0.54, blue: 0.24)
    static let masterPaper = Color(red: 0.98, green: 0.96, blue: 0.90)

    static func skin(_ tone: ShepherdSkinTone) -> Color {
        switch tone {
        case .porcelain: return Color(red: 0.94, green: 0.76, blue: 0.61)
        case .warm: return Color(red: 0.87, green: 0.63, blue: 0.39)
        case .olive: return Color(red: 0.72, green: 0.51, blue: 0.32)
        case .brown: return Color(red: 0.57, green: 0.36, blue: 0.23)
        case .deep: return Color(red: 0.38, green: 0.23, blue: 0.16)
        }
    }
}
