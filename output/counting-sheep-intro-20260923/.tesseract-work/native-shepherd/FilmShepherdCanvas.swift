import SwiftUI

struct ShepherdStudyCanvas: View {
    var appearance: ShepherdStudyAppearance
    var direction: ShepherdStudyDirection = .threeQuarter
    var pose: ShepherdStudyPose = .still
    var paperTexture = true
    var seated = false

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            var p = ShepherdStudyPainter(context: context, texture: paperTexture)
            let scale = min(size.width / 240, size.height / 280)
            p.context.translateBy(x: (size.width - 240 * scale) / 2, y: (size.height - 280 * scale) / 2)
            p.context.scaleBy(x: scale, y: scale)
            if appearance.faceLeft {
                p.context.translateBy(x: 240, y: 0)
                p.context.scaleBy(x: -1, y: 1)
            }
            draw(in: p)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Shepherd, \(appearance.head.title), \(appearance.hair.title) hair, \(appearance.outfit.title), \(direction.title), hat \(appearance.hat ? "on" : "off")")
    }

    func draw(in p: ShepherdStudyPainter) {
        let side = direction == .side
        let skin = ShepherdStudyPalette.skin(appearance.skin)
        if appearance.hair == .long {
            var hair = p
            hair.context.translateBy(x: 0, y: -pose.bodyLift)
            hair = hair.rotated(pose.headTilt, around: CGPoint(x: 123, y: 157))
            hair.fill(ShepherdStudyMasterPaths.longHair(appearance.head, direction: direction), ShepherdStudyPalette.hair)
        }
        // The waist overlaps both legs and the shirt hem, including during a lifted step.
        if appearance.outfit == .shirt || appearance.outfit == .overalls || appearance.outfit == .openCoat {
            p.rounded(side ? 106 : 94, 208 - pose.bodyLift, side ? 40 : 60, 24, 6, trouserColor)
        }
        if seated {
            let left = p.rotated(18, around: CGPoint(x: 123, y: 229))
            let right = p.rotated(-18, around: CGPoint(x: 123, y: 229))
            left.rounded(77, 218, 91, 25, 12, trouserColor)
            right.rounded(78, 218, 91, 25, 12, trouserColor)
            left.rounded(145, 218, 27, 19, 7, ShepherdStudyPalette.boots)
            right.rounded(73, 218, 27, 19, 7, ShepherdStudyPalette.boots)
        } else {
            leg(in: p, x: side ? 115 : 104, foot: pose.leftFoot, near: false)
            leg(in: p, x: side ? 131 : 142, foot: pose.rightFoot, near: true)
        }
        var upper = p
        upper.context.translateBy(x: 0, y: -pose.bodyLift)
        upper.rounded(112, 149, 22, 24, 5, skin)
        if side { arm(in: upper, right: false, swing: 0) }
        upper.fill(ShepherdStudyMasterPaths.garment(appearance.outfit, side: side), garmentColor)
        if appearance.outfit == .openCoat && !direction.hidesFace { openCoatFront(in: upper, side: side) }
        if appearance.outfit == .overalls { overallBody(in: upper, side: side) }
        if !direction.hidesFace { frontDetails(in: upper, side: side) }
        if !side { arm(in: upper, right: false, swing: 0) }
        arm(in: upper, right: true, swing: pose.armSwing)
        if !direction.hidesFace && appearance.outfit != .shirt && appearance.outfit != .overalls && appearance.outfit != .openCoat {
            upper.fill(ShepherdStudyMasterPaths.collar(side: side), ShepherdStudyPalette.cream)
        }
        ShepherdStudyHeadDrawing.draw(in: upper, appearance: appearance, direction: direction, pose: pose)
    }

    private var garmentColor: Color {
        switch appearance.outfit {
        case .shirt: return shirtColor
        case .coat, .openCoat: return ShepherdStudyPalette.moss
        case .dress: return ShepherdStudyPalette.berry
        case .moonCoat: return ShepherdStudyPalette.moon
        case .overalls: return shirtColor
        case .cloak: return ShepherdStudyPalette.midnight
        }
    }

    private var shirtColor: Color {
        switch appearance.shirt {
        case .cream: return ShepherdStudyPalette.cream
        case .berry: return ShepherdStudyPalette.berry
        case .dusk: return ShepherdStudyPalette.moon
        case .amber: return ShepherdStudyPalette.hat
        }
    }

    private func openCoatFront(in p: ShepherdStudyPainter, side: Bool) {
        // The opening is cut into the long coat silhouette; the shirt stops at
        // its own hem, exposing trousers below rather than becoming a dress.
        let opening = Path { path in
            path.move(to: CGPoint(x: side ? 137 : 115, y: 161))
            path.addQuadCurve(to: CGPoint(x: side ? 153 : 146, y: 243),
                              control: CGPoint(x: side ? 140 : 132, y: 203))
            path.addLine(to: CGPoint(x: side ? 136 : 106, y: 243))
            path.addQuadCurve(to: CGPoint(x: side ? 129 : 126, y: 161),
                              control: CGPoint(x: side ? 128 : 118, y: 200))
            path.closeSubpath()
        }
        var front = p
        front.context.clip(to: ShepherdStudyMasterPaths.garment(.openCoat, side: side))
        front.context.clip(to: opening)
        front.fill(opening, trouserColor)
        front.fill(ShepherdStudyMasterPaths.garment(.shirt, side: side), shirtColor)
        p.fill(ShepherdStudyMasterPaths.collar(side: side), ShepherdStudyPalette.cream)
        p.fill(ShepherdStudyMasterPaths.pocket(x: side ? 113 : 91, y: 209, width: 15),
               ShepherdStudyPalette.pocket.opacity(0.5))
    }

    private var trouserColor: Color {
        appearance.outfit == .dress ? ShepherdStudyPalette.skin(appearance.skin)
            : appearance.outfit == .overalls ? ShepherdStudyPalette.denim : ShepherdStudyPalette.trousers
    }

    private func leg(in p: ShepherdStudyPainter, x: CGFloat, foot: ShepherdStudyFoot, near: Bool) {
        let side = direction == .side
        let footX = x + CGFloat(foot.travel) * (side ? 1 : 0.28)
        let ankleY = 249 - CGFloat(foot.lift)
        let path = Path { path in
            path.move(to: CGPoint(x: x - 11, y: 214 - pose.bodyLift))
            path.addQuadCurve(to: CGPoint(x: x + 11, y: 214 - pose.bodyLift), control: CGPoint(x: x, y: 211 - pose.bodyLift))
            path.addQuadCurve(to: CGPoint(x: footX + 10, y: ankleY), control: CGPoint(x: x + 12, y: 234))
            path.addQuadCurve(to: CGPoint(x: footX - 10, y: ankleY), control: CGPoint(x: footX, y: ankleY + 2))
            path.addQuadCurve(to: CGPoint(x: x - 11, y: 214 - pose.bodyLift), control: CGPoint(x: x - 12, y: 234))
            path.closeSubpath()
        }
        p.fill(path, trouserColor)
        p.fill(ShepherdStudyMasterPaths.boot(x: footX, ankle: ankleY, toeRight: side || near), ShepherdStudyPalette.boots)
    }

    private func arm(in p: ShepherdStudyPainter, right: Bool, swing: Double) {
        let side = direction == .side
        let short = appearance.outfit == .shirt || appearance.outfit == .overalls
        let anchor = CGPoint(x: side ? (right ? 122 : 137) : (right ? 147 : 99), y: 171)
        let arm = p.rotated(swing, around: anchor)
        // Keep the resting sleeve and torso on the same paper coordinates, avoiding a seam.
        let placement = CGAffineTransform(a: right && !side ? -1 : 1, b: 0, c: 0, d: 1,
                                          tx: anchor.x, ty: anchor.y)
        arm.fill(ShepherdStudyMasterPaths.hand(shortSleeve: short, side: side).applying(placement), ShepherdStudyPalette.skin(appearance.skin))
        arm.fill(ShepherdStudyMasterPaths.sleeve(short: short, side: side).applying(placement), garmentColor)
    }

    private func overallBody(in p: ShepherdStudyPainter, side: Bool) {
        var bib = p
        bib.context.clip(to: ShepherdStudyMasterPaths.garment(.overalls, side: side))
        let path = Path { path in
            path.move(to: CGPoint(x: side ? 126 : 105, y: 179))
            path.addLine(to: CGPoint(x: side ? 150 : 142, y: 179))
            path.addLine(to: CGPoint(x: side ? 150 : 146, y: 202))
            path.addLine(to: CGPoint(x: 174, y: 209))
            path.addLine(to: CGPoint(x: 174, y: 228))
            path.addLine(to: CGPoint(x: 80, y: 228))
            path.addLine(to: CGPoint(x: 80, y: 208))
            path.addLine(to: CGPoint(x: side ? 121 : 101, y: 202))
            path.closeSubpath()
        }
        bib.fill(path, ShepherdStudyPalette.denim)
        bib.rounded(side ? 126 : 104, 161, 7, 30, 2, ShepherdStudyPalette.denim)
        if !side { bib.rounded(135, 162, 7, 29, 2, ShepherdStudyPalette.denim) }
    }

    private func frontDetails(in p: ShepherdStudyPainter, side: Bool) {
        if appearance.outfit == .overalls {
            p.fill(ShepherdStudyMasterPaths.pocket(x: side ? 132 : 113, y: 192, width: side ? 15 : 22), ShepherdStudyPalette.pocket.opacity(0.45))
            p.ellipse(side ? 127 : 105, 180, 5, 5, ShepherdStudyPalette.hat)
            if !side { p.ellipse(136, 180, 5, 5, ShepherdStudyPalette.hat) }
            return
        }
        if appearance.outfit == .cloak {
            p.ellipse(side ? 139 : 118, 181, 7, 7, ShepherdStudyPalette.hat)
            for point in [CGPoint(x: 102, y: 204), CGPoint(x: 139, y: 219), CGPoint(x: 113, y: 233)] {
                if side && point.x < 113 { continue }
                let star = Path { path in
                    path.move(to: CGPoint(x: point.x, y: point.y - 4))
                    path.addLine(to: CGPoint(x: point.x + 2, y: point.y - 1))
                    path.addLine(to: CGPoint(x: point.x + 5, y: point.y))
                    path.addLine(to: CGPoint(x: point.x + 2, y: point.y + 2))
                    path.addLine(to: CGPoint(x: point.x, y: point.y + 5))
                    path.addLine(to: CGPoint(x: point.x - 2, y: point.y + 2))
                    path.addLine(to: CGPoint(x: point.x - 4, y: point.y))
                    path.addLine(to: CGPoint(x: point.x - 1, y: point.y - 1))
                    path.closeSubpath()
                }
                p.fill(star, ShepherdStudyPalette.cream)
            }
            return
        }
        guard appearance.outfit != .shirt && appearance.outfit != .openCoat else { return }
        let x: CGFloat = side ? 143 : 120
        p.ellipse(x, 187, 8, 9, appearance.outfit == .dress ? ShepherdStudyPalette.cream : ShepherdStudyPalette.hat)
        guard appearance.outfit == .coat || appearance.outfit == .moonCoat else { return }
        p.ellipse(x, 208, 8, 9, ShepherdStudyPalette.hat)
        let pocketColor = appearance.outfit == .coat ? ShepherdStudyPalette.pocket.opacity(0.5) : ShepherdStudyPalette.ink.opacity(0.13)
        if side {
            p.fill(ShepherdStudyMasterPaths.pocket(x: 134, y: 209, width: 16), pocketColor)
        } else {
            p.fill(ShepherdStudyMasterPaths.pocket(x: 92, y: 209), pocketColor)
            p.fill(ShepherdStudyMasterPaths.pocket(x: 138, y: 208), pocketColor)
        }
    }
}
