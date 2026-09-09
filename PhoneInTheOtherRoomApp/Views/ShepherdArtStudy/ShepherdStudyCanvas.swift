import SwiftUI

struct ShepherdStudyCanvas: View {
    var appearance: ShepherdStudyAppearance
    var direction: ShepherdStudyDirection = .threeQuarter
    var pose: ShepherdStudyPose = .still
    var paperTexture = true

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

    private func draw(in p: ShepherdStudyPainter) {
        let side = direction == .side
        let skin = ShepherdStudyPalette.skin(appearance.skin)
        if appearance.hair == .long {
            var hair = p
            hair.context.translateBy(x: 0, y: -pose.bodyLift)
            hair = hair.rotated(pose.headTilt, around: CGPoint(x: 123, y: 157))
            hair.fill(ShepherdStudyMasterPaths.longHair(appearance.head, direction: direction), ShepherdStudyPalette.hair)
        }
        leg(in: p, x: side ? 115 : 104, foot: pose.leftFoot)
        leg(in: p, x: side ? 129 : 139, foot: pose.rightFoot)
        var upper = p
        upper.context.translateBy(x: 0, y: -pose.bodyLift)
        upper.rounded(112, 149, 22, 24, 5, skin)
        if side { arm(in: upper, x: 118, swing: -pose.armSwing) }
        upper.fill(ShepherdStudyMasterPaths.garment(appearance.outfit, side: side), garmentColor)
        if !direction.hidesFace { frontDetails(in: upper, side: side) }
        if !side { arm(in: upper, x: 89, swing: -pose.armSwing) }
        arm(in: upper, x: side ? 131 : 151, swing: pose.armSwing)
        ShepherdStudyHeadDrawing.draw(in: upper, appearance: appearance, direction: direction, pose: pose)
    }

    private var garmentColor: Color {
        switch appearance.outfit {
        case .shirt: return ShepherdStudyPalette.cream
        case .coat: return ShepherdStudyPalette.moss
        case .dress: return ShepherdStudyPalette.berry
        case .moonCoat: return ShepherdStudyPalette.moon
        case .overalls: return ShepherdStudyPalette.cream
        case .cloak: return ShepherdStudyPalette.midnight
        }
    }

    private func leg(in p: ShepherdStudyPainter, x: CGFloat, foot: ShepherdStudyFoot) {
        let side = direction == .side
        let travel = CGFloat(foot.travel) * (side ? 1 : 0.28)
        let footX = x + travel
        let ankleY = 251 - CGFloat(foot.lift)
        let path = Path { path in
            path.move(to: CGPoint(x: x - 8, y: 213 - pose.bodyLift))
            path.addLine(to: CGPoint(x: x + 9, y: 213 - pose.bodyLift))
            path.addLine(to: CGPoint(x: footX + 9, y: ankleY))
            path.addQuadCurve(to: CGPoint(x: footX - 8, y: ankleY), control: CGPoint(x: footX, y: ankleY + 3))
            path.closeSubpath()
        }
        p.fill(path, appearance.outfit == .dress ? ShepherdStudyPalette.skin(appearance.skin) : appearance.outfit == .overalls ? ShepherdStudyPalette.denim : ShepherdStudyPalette.trousers)
        p.rounded(footX - 9, ankleY - 5, side ? 29 : 23, 17, 5, ShepherdStudyPalette.boots)
    }

    private func arm(in p: ShepherdStudyPainter, x: CGFloat, swing: Double) {
        let arm = p.rotated(swing, around: CGPoint(x: x, y: 174))
        let sleeveHeight: CGFloat = appearance.outfit == .shirt || appearance.outfit == .overalls ? 23 : 38
        arm.rounded(x - 10, 171, 20, sleeveHeight, 7, garmentColor)
        arm.rounded(x - 7, 170 + sleeveHeight, 16, 221 - 170 - sleeveHeight, 8, ShepherdStudyPalette.skin(appearance.skin))
    }

    private func frontDetails(in p: ShepherdStudyPainter, side: Bool) {
        p.ellipse(side ? 120 : 103, 162, 18, 17, ShepherdStudyPalette.cream)
        if !side { p.ellipse(123, 162, 18, 17, ShepherdStudyPalette.cream) }
        if appearance.outfit == .overalls {
            p.rounded(side ? 118 : 100, 174, side ? 27 : 40, 37, 4, ShepherdStudyPalette.denim)
            p.rounded(side ? 120 : 100, 164, 8, 29, 3, ShepherdStudyPalette.denim)
            if !side { p.rounded(132, 164, 8, 29, 3, ShepherdStudyPalette.denim) }
            p.rounded(side ? 128 : 109, 192, 21, 12, 3, ShepherdStudyPalette.pocket)
            p.ellipse(side ? 122 : 101, 179, 5, 5, ShepherdStudyPalette.hat)
            if !side { p.ellipse(134, 179, 5, 5, ShepherdStudyPalette.hat) }
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
        guard appearance.outfit != .shirt else { return }
        let x: CGFloat = side ? 143 : 120
        p.ellipse(x, 188, 7, 8, appearance.outfit == .coat ? ShepherdStudyPalette.hat : ShepherdStudyPalette.cream)
        guard appearance.outfit == .coat || appearance.outfit == .moonCoat else { return }
        p.ellipse(x, 209, 7, 8, ShepherdStudyPalette.hat)
        if side {
            p.rounded(135, 207, 15, 17, 3, garmentColor.opacity(0.8))
        } else {
            p.rounded(87, 207, 21, 17, 3, garmentColor.opacity(0.8))
            p.rounded(138, 207, 17, 17, 3, garmentColor.opacity(0.8))
        }
    }
}
