import SwiftUI

enum ShepherdStudyHeadDrawing {
    private typealias Pigment = ShepherdStudyPalette

    static func draw(
        in painter: ShepherdStudyPainter, appearance a: ShepherdStudyAppearance,
        direction: ShepherdStudyDirection, pose: ShepherdStudyPose
    ) {
        let p = painter.rotated(pose.headTilt, around: CGPoint(x: 123, y: 157))
        let side = direction == .side, rear = direction == .rearThreeQuarter
        let head = ShepherdStudyMasterPaths.head(a.head, direction: direction)
        let cap = side ? ShepherdStudyMasterPaths.profileHair
            : a.hair == .short ? ShepherdStudyMasterPaths.sweptHair : ShepherdStudyMasterPaths.scallopedHair
        if a.hair == .long {
            if !direction.hidesFace {
                // Keep skin out of the hair region so antialiasing cannot reveal a scalp outline.
                var face = p
                var visibleSkin = Path(CGRect(x: -100, y: -100, width: 500, height: 500))
                visibleSkin.addPath(cap)
                face.context.clip(to: visibleSkin, style: FillStyle(eoFill: true))
                face.fill(head, Pigment.skin(a.skin))
            }
        } else {
            p.fill(head, Pigment.skin(a.skin))
        }
        if !direction.hidesFace {
            p.ellipse(side ? 80 : 47, 95, side ? 22 : 25, 32, Pigment.skin(a.skin))
            if direction == .front {
                p.ellipse(a.head == .pear ? 169 : 181, 96, 24, 30, Pigment.skin(a.skin))
            }
        }

        var hair = p
        hair.context.clip(to: head)
        if direction.hidesFace {
            hair.fill(head, Pigment.hair)
        } else {
            hair.fill(cap, Pigment.hair)
        }
        if a.hair == .curls || a.hair == .coils {
            let count = a.hair == .coils ? 11 : 7
            let diameter: CGFloat = a.hair == .coils ? 20 : 29
            let left: CGFloat = side ? 72 : a.head == .pear ? 64 : 48
            let span: CGFloat = side ? 92 : a.head == .pear ? 113 : 140
            for index in 0..<count {
                let phase = CGFloat(index) / CGFloat(count - 1)
                let x = left + phase * span
                let y = 63 - sin(phase * .pi) * 22
                p.ellipse(x - diameter / 2, y - diameter / 2, diameter, diameter, Pigment.hair)
            }
            if !side { p.ellipse(left - 8, 72, diameter, diameter, Pigment.hair) }
        }
        if rear { p.ellipse(166, 104, 20, 28, Pigment.skin(a.skin)) }

        if !direction.hidesFace {
            face(in: p, appearance: a, direction: direction, pose: pose)
        }
        if a.head == .pear && a.hair == .short && !a.hat {
            p.fill(ShepherdStudyMasterPaths.tuft, Pigment.hair)
        }
        if a.hat { hat(in: p, head: a.head, side: side, style: a.headwear) }
    }

    private static func face(
        in p: ShepherdStudyPainter, appearance a: ShepherdStudyAppearance,
        direction: ShepherdStudyDirection, pose: ShepherdStudyPose
    ) {
        let side = direction == .side, quarter = direction == .threeQuarter
        let centers: [CGFloat] = side ? [157] : quarter ? [128, 163] : [99, 145]
        for center in centers {
            if pose.eyesClosed {
                p.line([CGPoint(x: center - 9, y: 106), CGPoint(x: center + 9, y: 106)])
            } else {
                p.ellipse(center - 11, 88, 22, 36, Pigment.cream)
                p.ellipse(center + (quarter || side ? 1 : -4), 98, 10, 19, Pigment.ink)
                if a.eyes == .calm {
                    p.line([CGPoint(x: center - 13, y: 96), CGPoint(x: center + 13, y: 96)], width: 2.5)
                }
            }
        }
        if !side {
            let x: CGFloat = quarter ? 150 : 121
            if a.head == .pear || a.head == .triangular {
                p.line([CGPoint(x: x, y: 121), CGPoint(x: x + 5, y: 125), CGPoint(x: x, y: 128)], width: 2)
            } else {
                p.context.stroke(Path(ellipseIn: CGRect(x: x - 6, y: 119, width: 13, height: 12)),
                                 with: .color(Pigment.ink), lineWidth: 2)
            }
        }
        let x: CGFloat = side ? 164 : quarter ? 140 : 116
        let smile = Path { path in
            path.move(to: CGPoint(x: x, y: 141))
            path.addQuadCurve(to: CGPoint(x: x + 12, y: 141), control: CGPoint(x: x + 6, y: 146))
        }
        p.context.stroke(smile, with: .color(Pigment.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private static func hat(in p: ShepherdStudyPainter, head: ShepherdStudySilhouette, side: Bool, style: ShepherdStudyHeadwear) {
        let x: CGFloat = side ? 59 : head == .pear ? 60 : 41
        let width: CGFloat = side ? 122 : head == .pear ? 126 : 158
        let crown = Path { path in
            path.move(to: CGPoint(x: x, y: 73))
            path.addCurve(to: CGPoint(x: x + width, y: 73),
                          control1: CGPoint(x: x + 4, y: 9), control2: CGPoint(x: x + width - 5, y: 8))
            path.closeSubpath()
        }
        switch style {
        case .fieldHat:
            p.fill(crown, Pigment.hat)
            p.rounded(x - 15, 70, width + 30, 12, 6, Pigment.hat)
            p.rounded(x, 60, width, 12, 4, Pigment.hatBand)
        case .beanie:
            p.fill(crown, Pigment.moon)
            p.rounded(x - 3, 66, width + 6, 18, 6, Pigment.midnight)
            p.ellipse(x + width / 2 - 11, 13, 22, 22, Pigment.moon)
        case .headscarf:
            p.fill(crown, Pigment.moss)
            p.rounded(x - 4, 66, width + 8, 14, 5, Pigment.pocket)
            p.ellipse(x - 10, 70, 20, 17, Pigment.moss)
            p.fill(Path { path in
                path.move(to: CGPoint(x: x - 3, y: 76))
                path.addQuadCurve(to: CGPoint(x: x - 16, y: 114), control: CGPoint(x: x - 29, y: 90))
                path.addLine(to: CGPoint(x: x + 5, y: 89))
                path.closeSubpath()
            }, Pigment.moss)
        }
    }
}
