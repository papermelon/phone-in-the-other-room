import SwiftUI

/// Authored logical coordinates: one 240×280 canvas and a common foot baseline at 264.
/// Side silhouettes are drawings, not horizontal compression of the front view.
enum ShepherdStudyMasterPaths {
    static func head(_ shape: ShepherdStudySilhouette, direction: ShepherdStudyDirection) -> Path {
        if direction == .side { return profile(shape) }
        switch shape {
        case .pear: return pear
        case .round: return Path(ellipseIn: CGRect(x: 44, y: 40, width: 151, height: 119))
        case .boxy: return Path(roundedRect: CGRect(x: 48, y: 40, width: 148, height: 118), cornerRadius: 29)
        case .triangular: return triangle
        }
    }

    /// One continuous scalp-to-shoulder silhouette behind the face, never cheek-mounted locks.
    static func longHair(_ shape: ShepherdStudySilhouette, direction: ShepherdStudyDirection) -> Path {
        let bounds = head(shape, direction: direction).boundingRect
        let frame = direction == .side
            ? CGRect(x: 55, y: 33, width: 89, height: 164)
            : CGRect(x: bounds.minX - 9, y: bounds.minY - 3,
                     width: bounds.width + 18, height: 198 - bounds.minY)
        return Path(roundedRect: frame, cornerRadius: direction == .side ? 35 : 42)
    }

    static let pear = Path { p in
        p.move(to: CGPoint(x: 66, y: 90))
        p.addCurve(to: CGPoint(x: 122, y: 32), control1: CGPoint(x: 66, y: 54), control2: CGPoint(x: 87, y: 31))
        p.addCurve(to: CGPoint(x: 177, y: 92), control1: CGPoint(x: 157, y: 31), control2: CGPoint(x: 171, y: 60))
        p.addCurve(to: CGPoint(x: 119, y: 158), control1: CGPoint(x: 195, y: 133), control2: CGPoint(x: 164, y: 162))
        p.addCurve(to: CGPoint(x: 66, y: 90), control1: CGPoint(x: 75, y: 159), control2: CGPoint(x: 52, y: 128))
        p.closeSubpath()
    }

    static let triangle = Path { p in
        p.move(to: CGPoint(x: 49, y: 74))
        p.addCurve(to: CGPoint(x: 190, y: 72), control1: CGPoint(x: 44, y: 26), control2: CGPoint(x: 194, y: 22))
        p.addCurve(to: CGPoint(x: 127, y: 160), control1: CGPoint(x: 192, y: 107), control2: CGPoint(x: 151, y: 153))
        p.addQuadCurve(to: CGPoint(x: 105, y: 151), control: CGPoint(x: 119, y: 165))
        p.addCurve(to: CGPoint(x: 49, y: 74), control1: CGPoint(x: 75, y: 129), control2: CGPoint(x: 47, y: 102))
        p.closeSubpath()
    }

    static func profile(_ shape: ShepherdStudySilhouette) -> Path {
        let angular = shape == .boxy || shape == .triangular
        return Path { p in
            p.move(to: CGPoint(x: 64, y: 91))
            p.addCurve(to: CGPoint(x: 123, y: 35), control1: CGPoint(x: 61, y: 51), control2: CGPoint(x: 90, y: 34))
            p.addCurve(to: CGPoint(x: 174, y: 91), control1: CGPoint(x: 157, y: 33), control2: CGPoint(x: 178, y: 59))
            p.addLine(to: CGPoint(x: 174, y: 108))
            if shape == .pear || shape == .triangular {
                p.addQuadCurve(to: CGPoint(x: 190, y: 117), control: CGPoint(x: 193, y: 109))
                p.addQuadCurve(to: CGPoint(x: 174, y: 123), control: CGPoint(x: 188, y: 126))
            } else {
                p.addQuadCurve(to: CGPoint(x: 175, y: 124), control: CGPoint(x: 194, y: 116))
            }
            p.addCurve(to: CGPoint(x: angular ? 121 : 128, y: 157), control1: CGPoint(x: 174, y: 149), control2: CGPoint(x: 145, y: 160))
            p.addCurve(to: CGPoint(x: 64, y: 91), control1: CGPoint(x: 82, y: 159), control2: CGPoint(x: 60, y: 130))
            p.closeSubpath()
        }
    }

    static let sweptHair = Path { p in
        p.move(to: CGPoint(x: 20, y: 0)); p.addLine(to: CGPoint(x: 217, y: 0))
        p.addLine(to: CGPoint(x: 217, y: 85))
        p.addQuadCurve(to: CGPoint(x: 152, y: 53), control: CGPoint(x: 167, y: 84))
        p.addQuadCurve(to: CGPoint(x: 67, y: 100), control: CGPoint(x: 123, y: 85))
        p.addLine(to: CGPoint(x: 20, y: 125)); p.closeSubpath()
    }

    static let scallopedHair = Path { p in
        p.move(to: CGPoint(x: 20, y: 0)); p.addLine(to: CGPoint(x: 218, y: 0))
        p.addLine(to: CGPoint(x: 218, y: 101))
        p.addQuadCurve(to: CGPoint(x: 172, y: 73), control: CGPoint(x: 186, y: 93))
        p.addQuadCurve(to: CGPoint(x: 140, y: 76), control: CGPoint(x: 158, y: 93))
        p.addQuadCurve(to: CGPoint(x: 107, y: 76), control: CGPoint(x: 125, y: 94))
        p.addQuadCurve(to: CGPoint(x: 75, y: 80), control: CGPoint(x: 94, y: 95))
        p.addLine(to: CGPoint(x: 20, y: 122)); p.closeSubpath()
    }

    static let profileHair = Path { p in
        p.move(to: CGPoint(x: 25, y: 0)); p.addLine(to: CGPoint(x: 220, y: 0))
        p.addLine(to: CGPoint(x: 220, y: 78))
        p.addQuadCurve(to: CGPoint(x: 153, y: 61), control: CGPoint(x: 181, y: 83))
        p.addQuadCurve(to: CGPoint(x: 95, y: 99), control: CGPoint(x: 134, y: 89))
        p.addLine(to: CGPoint(x: 94, y: 161)); p.addLine(to: CGPoint(x: 24, y: 170)); p.closeSubpath()
    }

    static let tuft = Path { p in
        p.move(to: CGPoint(x: 147, y: 45))
        p.addQuadCurve(to: CGPoint(x: 158, y: 28), control: CGPoint(x: 146, y: 18))
        p.addQuadCurve(to: CGPoint(x: 170, y: 33), control: CGPoint(x: 169, y: 16))
        p.addQuadCurve(to: CGPoint(x: 157, y: 52), control: CGPoint(x: 181, y: 45))
        p.closeSubpath()
    }

    /// Soft shoulders and authored hems keep clothes readable below the oversized head.
    static func garment(_ outfit: ShepherdStudyOutfit, side: Bool) -> Path {
        let short = outfit == .shirt || outfit == .overalls
        let hem: CGFloat = short ? 222 : outfit == .cloak ? 239 : 234
        let left: CGFloat = side ? 101 : outfit == .dress ? 80 : outfit == .cloak ? 74 : 85
        let right: CGFloat = side ? 154 : outfit == .dress ? 166 : outfit == .cloak ? 172 : 163
        return Path { p in
            p.move(to: CGPoint(x: side ? 117 : 110, y: 161))
            p.addQuadCurve(to: CGPoint(x: side ? 142 : 143, y: 166), control: CGPoint(x: 135, y: 157))
            p.addCurve(to: CGPoint(x: side ? 149 : 153, y: 195),
                       control1: CGPoint(x: 152, y: 171), control2: CGPoint(x: 150, y: 185))
            p.addQuadCurve(to: CGPoint(x: right, y: hem - 2), control: CGPoint(x: right - 3, y: hem - 14))
            p.addCurve(to: CGPoint(x: left, y: hem - 1),
                       control1: CGPoint(x: right - 17, y: hem + 2), control2: CGPoint(x: left + 22, y: hem + 3))
            p.addQuadCurve(to: CGPoint(x: side ? 103 : 94, y: 192), control: CGPoint(x: left + 3, y: hem - 19))
            p.addCurve(to: CGPoint(x: side ? 117 : 110, y: 161),
                       control1: CGPoint(x: side ? 103 : 96, y: 174), control2: CGPoint(x: side ? 108 : 100, y: 165))
            p.closeSubpath()
        }
    }

    /// Local coordinates point out from the left shoulder; the other sleeve is mirrored.
    static func sleeve(short: Bool, side: Bool) -> Path {
        let cuff: CGFloat = short ? 25 : 44
        let reach: CGFloat = side ? 6 : 20
        return Path { p in
            p.move(to: CGPoint(x: 4, y: -6))
            p.addCurve(to: CGPoint(x: -10, y: 4), control1: CGPoint(x: -2, y: -9), control2: CGPoint(x: -7, y: -3))
            p.addQuadCurve(to: CGPoint(x: -reach - 6, y: cuff - 2), control: CGPoint(x: -reach - 1, y: 20))
            p.addQuadCurve(to: CGPoint(x: -reach + 12, y: cuff + 3), control: CGPoint(x: -reach + 3, y: cuff + 2))
            p.addQuadCurve(to: CGPoint(x: 9, y: 11), control: CGPoint(x: 5, y: cuff - 12))
            p.addQuadCurve(to: CGPoint(x: 4, y: -6), control: CGPoint(x: 11, y: -1))
            p.closeSubpath()
        }
    }

    static func hand(shortSleeve: Bool, side: Bool) -> Path {
        let reach: CGFloat = side ? 6 : 20
        let cuff: CGFloat = shortSleeve ? 25 : 44
        let wrist: CGFloat = shortSleeve ? 16 : 3
        return Path { p in
            p.move(to: CGPoint(x: -reach - 4, y: cuff - 4))
            p.addQuadCurve(to: CGPoint(x: -reach - 6, y: cuff + wrist + 5), control: CGPoint(x: -reach - 5, y: cuff + wrist))
            p.addCurve(to: CGPoint(x: -reach + 2, y: cuff + wrist + 14),
                       control1: CGPoint(x: -reach - 7, y: cuff + wrist + 11), control2: CGPoint(x: -reach - 2, y: cuff + wrist + 15))
            p.addQuadCurve(to: CGPoint(x: -reach + 10, y: cuff + wrist + 8), control: CGPoint(x: -reach + 10, y: cuff + wrist + 15))
            p.addQuadCurve(to: CGPoint(x: -reach + 12, y: cuff + wrist + 2), control: CGPoint(x: -reach + 16, y: cuff + wrist + 5))
            p.addQuadCurve(to: CGPoint(x: -reach + 10, y: cuff - 1), control: CGPoint(x: -reach + 9, y: cuff + wrist - 1))
            p.closeSubpath()
        }
    }

    static func boot(x: CGFloat, ankle: CGFloat, toeRight: Bool) -> Path {
        let direction: CGFloat = toeRight ? 1 : -1
        func point(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: x + dx * direction, y: ankle + dy) }
        return Path { p in
            p.move(to: point(-10, -4))
            p.addQuadCurve(to: point(9, -4), control: point(0, -2))
            p.addLine(to: point(9, 5))
            p.addCurve(to: point(18, 12), control1: point(14, 5), control2: point(19, 7))
            p.addQuadCurve(to: point(12, 15), control: point(19, 15))
            p.addQuadCurve(to: point(-10, 14), control: point(-1, 16))
            p.addQuadCurve(to: point(-12, 8), control: point(-13, 14))
            p.closeSubpath()
        }
    }

    static func collar(side: Bool) -> Path {
        return Path { p in
            if side {
                p.move(to: CGPoint(x: 116, y: 159))
                p.addQuadCurve(to: CGPoint(x: 148, y: 165), control: CGPoint(x: 136, y: 154))
                p.addQuadCurve(to: CGPoint(x: 145, y: 177), control: CGPoint(x: 153, y: 183))
                p.addQuadCurve(to: CGPoint(x: 115, y: 169), control: CGPoint(x: 127, y: 168))
            } else {
                p.move(to: CGPoint(x: 103, y: 160))
                p.addQuadCurve(to: CGPoint(x: 144, y: 160), control: CGPoint(x: 123, y: 156))
                p.addCurve(to: CGPoint(x: 124, y: 167), control1: CGPoint(x: 149, y: 184), control2: CGPoint(x: 129, y: 185))
                p.addCurve(to: CGPoint(x: 103, y: 160), control1: CGPoint(x: 118, y: 187), control2: CGPoint(x: 98, y: 180))
            }
            p.closeSubpath()
        }
    }

    static func pocket(x: CGFloat, y: CGFloat, width: CGFloat = 18) -> Path {
        Path { p in
            p.move(to: CGPoint(x: x + 1, y: y))
            p.addQuadCurve(to: CGPoint(x: x + width, y: y - 1), control: CGPoint(x: x + width / 2, y: y + 1))
            p.addLine(to: CGPoint(x: x + width + 1, y: y + 14))
            p.addCurve(to: CGPoint(x: x, y: y + 14), control1: CGPoint(x: x + width, y: y + 19), control2: CGPoint(x: x - 1, y: y + 18))
            p.closeSubpath()
        }
    }
}
