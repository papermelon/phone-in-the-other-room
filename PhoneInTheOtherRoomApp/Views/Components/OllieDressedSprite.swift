import SwiftUI

/// A garment is drawn against the pose's neck, never as an inventory cutout.
/// Home, Farm, previews and the journey all use this composition.
struct OllieDressedSprite: View {
    let assetName: String
    let accessoryItemID: String?

    var body: some View {
        Group {
            if let baseImage = UIImage(named: assetName) {
                ZStack {
                    Image(uiImage: baseImage)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                    if let garment = OllieGarment(itemID: accessoryItemID),
                       let fit = OllieGarmentFit.forAsset(assetName) {
                        Canvas { context, size in
                            context.scaleBy(x: size.width / 512, y: size.height / 512)
                            if garment == .starKeeperCape, fit.drape < 0.5 {
                                var shoulder = context
                                shoulder.translateBy(x: 150, y: 303)
                                OllieGarmentPainter(painter: .init(context: shoulder, texture: true)).restingCape()
                            }
                            context.translateBy(x: fit.x, y: fit.y)
                            context.rotate(by: .degrees(fit.angle))
                            context.scaleBy(x: fit.width / 100, y: fit.width / 100)
                            OllieGarmentPainter(painter: .init(context: context, texture: true))
                                .draw(garment, drape: fit.drape)
                        }
                    }
                }
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable().scaledToFit().foregroundStyle(AppColors.grass)
                    .padding(AppSpacing.sm)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct OllieGarmentPainter {
    let painter: ShepherdStudyPainter
    private typealias Pigment = ShepherdStudyPalette

    func restingCape() {
        painter.fill(Path { path in
            path.move(to: CGPoint(x: 30, y: 0))
            path.addQuadCurve(to: CGPoint(x: 91, y: 22), control: CGPoint(x: 65, y: -9))
            path.addQuadCurve(to: CGPoint(x: 111, y: 68), control: CGPoint(x: 97, y: 42))
            path.addQuadCurve(to: CGPoint(x: -7, y: 62), control: CGPoint(x: 52, y: 110))
            path.addQuadCurve(to: CGPoint(x: 30, y: 0), control: CGPoint(x: -1, y: 20))
        }, Pigment.midnight)
        painter.fill(polygon([(47, 25), (52, 36), (64, 38), (55, 46), (57, 58),
                              (47, 52), (36, 58), (38, 46), (29, 38), (41, 36)]), Pigment.cream)
    }

    func draw(_ garment: OllieGarment, drape: Double) {
        let color: Color
        switch garment {
        case .mossBandana, .cloverCollar: color = Pigment.moss
        case .moonKerchief: color = Pigment.heather
        case .brassBell: color = Pigment.trousers
        case .sunriseScarf: color = Pigment.hat
        case .starKeeperCape: color = Pigment.midnight
        }
        let depth = 50 * drape
        switch garment {
        case .mossBandana, .moonKerchief:
            // The top edge hugs the white ruff; there is no hollow inventory rim.
            painter.fill(Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: 100, y: 0), control: CGPoint(x: 53, y: 24))
                p.addQuadCurve(to: CGPoint(x: 53, y: 17 + depth), control: CGPoint(x: 95, y: 25 + depth * 0.45))
                p.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: 4, y: 21 + depth * 0.45))
            }, color)
            fold(color)
            if drape > 0.5 {
                knot(color)
                if garment == .mossBandana { sheep(x: 45, y: 30) }
                else { moon(x: 44, y: 28, color: color) }
            }
        case .brassBell, .cloverCollar:
            collar(color)
            if drape > 0.5 {
                if garment == .brassBell {
                    painter.rounded(48, 17, 7, 9, 3, Pigment.hatBand)
                    painter.fill(polygon([(45, 26), (58, 26), (63, 41), (40, 41)]), Pigment.hat)
                    painter.ellipse(48, 40, 7, 5, Pigment.hatBand)
                    painter.rounded(41, 38, 21, 3, 1, Pigment.cream)
                } else {
                    for (x, y) in [(45.0, 26.0), (52, 26), (45, 33), (52, 33)] {
                        painter.ellipse(x, y, 9, 9, Pigment.cream)
                    }
                }
            }
        case .sunriseScarf:
            if drape > 0.5 {
                painter.fill(polygon([(6, 7), (29, 15), (16, 63 * drape), (0, 58 * drape)]), color)
                painter.fill(polygon([(11, 8), (29, 12), (43, 46 * drape), (25, 53 * drape)]), Pigment.hatBand)
                painter.rounded(4, 49 * drape, 13, 3, 1, Pigment.cream)
            }
            collar(color)
        case .starKeeperCape:
            if drape > 0.5 {
                painter.fill(Path { p in
                    p.move(to: CGPoint(x: 3, y: 2))
                    p.addQuadCurve(to: CGPoint(x: -46, y: 75 * drape), control: CGPoint(x: -39, y: 22))
                    p.addQuadCurve(to: CGPoint(x: 38, y: 82 * drape), control: CGPoint(x: -10, y: 98 * drape))
                    p.addQuadCurve(to: CGPoint(x: 41, y: 11), control: CGPoint(x: 25, y: 40))
                    p.closeSubpath()
                }, color)
                painter.fill(polygon([(-8, 40), (-4, 49), (6, 50), (-2, 56), (0, 66), (-8, 60), (-16, 66), (-14, 56), (-22, 50), (-12, 49)]), Pigment.cream)
            }
            collar(color)
            painter.ellipse(48, 14, 9, 9, Pigment.hat)
        }
    }

    private func collar(_ color: Color) {
        painter.fill(Path { p in
            p.move(to: .zero)
            p.addQuadCurve(to: CGPoint(x: 100, y: 0), control: CGPoint(x: 52, y: 23))
            p.addLine(to: CGPoint(x: 98, y: 12))
            p.addQuadCurve(to: CGPoint(x: 3, y: 13), control: CGPoint(x: 52, y: 32))
            p.closeSubpath()
        }, color)
    }

    private func fold(_ color: Color) {
        painter.fill(Path { p in
            p.move(to: CGPoint(x: 2, y: 1))
            p.addQuadCurve(to: CGPoint(x: 98, y: 1), control: CGPoint(x: 53, y: 25))
            p.addQuadCurve(to: CGPoint(x: 5, y: 9), control: CGPoint(x: 46, y: 33))
            p.closeSubpath()
        }, color.opacity(0.65))
    }

    private func knot(_ color: Color) {
        painter.fill(polygon([(4, 6), (-19, -3), (-13, 13), (3, 17), (-13, 26), (0, 27), (12, 14)]), color)
        painter.ellipse(0, 8, 13, 13, color)
    }

    private func sheep(x: Double, y: Double) {
        painter.ellipse(x, y, 16, 11, Pigment.cream)
        painter.ellipse(x - 4, y + 3, 7, 7, Pigment.boots)
        painter.rounded(x + 3, y + 9, 3, 5, 1, Pigment.cream)
        painter.rounded(x + 11, y + 9, 3, 5, 1, Pigment.cream)
    }

    private func moon(x: Double, y: Double, color: Color) {
        painter.ellipse(x, y, 17, 17, Pigment.cream)
        painter.ellipse(x + 6, y - 3, 15, 16, color)
        painter.ellipse(x + 25, y + 4, 4, 4, Pigment.cream)
    }

    private func polygon(_ points: [(Double, Double)]) -> Path {
        Path { p in
            guard let first = points.first else { return }
            p.move(to: CGPoint(x: first.0, y: first.1))
            for point in points.dropFirst() { p.addLine(to: CGPoint(x: point.0, y: point.1)) }
            p.closeSubpath()
        }
    }
}

#Preview("Fitted bandana · chase") {
    OllieDressedSprite(assetName: NightJourneyAssets.ollieRunFrames[0], accessoryItemID: "ollie_moss_bandana")
        .frame(width: 230, height: 230).background(AppColors.paper)
}

#Preview("Curled cape · missing item fallback") {
    HStack {
        OllieDressedSprite(assetName: "dog/dog_ollie_motion_pose_09", accessoryItemID: "ollie_star_keeper_cape")
        OllieDressedSprite(assetName: NightJourneyAssets.ollieHomeIdleFrames[0], accessoryItemID: "future_item")
    }.frame(height: 170).background(AppColors.paper)
}
