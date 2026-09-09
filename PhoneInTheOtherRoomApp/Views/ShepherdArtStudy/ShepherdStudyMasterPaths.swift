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

    static func garment(_ outfit: ShepherdStudyOutfit, side: Bool) -> Path {
        let left: CGFloat = side ? 104 : 94, right: CGFloat = side ? 142 : 145
        let hem: CGFloat = outfit == .shirt || outfit == .overalls ? 207 : outfit == .cloak ? 239 : 234
        let flare: CGFloat = outfit == .cloak ? 30 : outfit == .dress ? 17 : 10
        return Path { p in
            p.move(to: CGPoint(x: left, y: 166))
            p.addQuadCurve(to: CGPoint(x: right, y: 166), control: CGPoint(x: 122, y: 158))
            p.addLine(to: CGPoint(x: right + flare, y: hem))
            p.addQuadCurve(to: CGPoint(x: left - flare, y: hem), control: CGPoint(x: 121, y: hem + 7))
            p.closeSubpath()
        }
    }
}
