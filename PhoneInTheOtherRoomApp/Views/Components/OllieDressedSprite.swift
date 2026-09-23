import SwiftUI

/// A garment is drawn against the pose's neck, never as an inventory cutout.
/// Home, Farm, previews and the journey all use this composition.
struct OllieDressedSprite: View {
    let assetName: String
    let accessoryItemID: String?
    @Environment(\.ollieCoat) private var coat

    var body: some View {
        Group {
            if let baseImage = UIImage(named: resolvedAsset) {
                Canvas { context, size in
                    // A single fitted canvas keeps the fur mask and clothing registered,
                    // including callers that offer a non-square layout proposal.
                    let scale = min(size.width, size.height) / 512
                    context.translateBy(x: (size.width - 512 * scale) / 2, y: (size.height - 512 * scale) / 2)
                    context.scaleBy(x: scale, y: scale)
                    let image = Image(uiImage: baseImage)
                    let bounds = CGRect(x: 0, y: usesFullerCoat ? OllieFullerCoatRegistration.groundOffset(for: assetName) : 0, width: 512, height: 512)
                    let garment = OllieGarment(itemID: accessoryItemID)
                    let pose = usesFullerCoat ? OllieFullerCoatRegistration.neckwear(for: assetName) : OllieNeckwearPose.forAsset(assetName)
                    if garment == .starKeeperCape, let pose {
                        drawCapeBehindOllie(pose, in: context)
                    }
                    context.draw(image, in: bounds)
                    if let garment, let pose {
                        drawGarment(garment, pose: pose, base: image, bounds: bounds, in: context)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable().scaledToFit().foregroundStyle(AppColors.grass)
                    .padding(AppSpacing.sm)
            }
        }
        .accessibilityHidden(true)
    }

    private var usesFullerCoat: Bool {
        coat == .fuller && OllieCoatAvailability.fuller
            && OllieCoatStyle.fullerAsset(for: assetName) != nil
    }

    private var resolvedAsset: String {
        usesFullerCoat ? OllieCoatStyle.fullerAsset(for: assetName)! : assetName
    }

    private func drawCapeBehindOllie(_ pose: OllieNeckwearPose, in context: GraphicsContext) {
        var cape = context
        cape.concatenate(placement(for: pose))
        OllieGarmentPainter(painter: .init(context: cape, texture: true)).capeBack()
    }

    private func drawGarment(_ garment: OllieGarment, pose: OllieNeckwearPose, base: Image, bounds: CGRect, in context: GraphicsContext) {
        let placement = placement(for: pose)
        if garment.hasTie, pose.showsTie {
            var tie = context
            tie.concatenate(placement)
            OllieGarmentPainter(painter: .init(context: tie, texture: true)).tie(for: garment)
        }
        // Tucked fabric stays inside Ollie's painted silhouette. Cape fabric is
        // drawn behind the base above, so it is naturally hidden by fur and paws.
        var cloth = context
        cloth.clipToLayer { silhouette in
            silhouette.draw(base, in: bounds)
        }
        cloth.concatenate(placement)
        OllieGarmentPainter(painter: .init(context: cloth, texture: true)).fitted(garment, pose: pose)

        // Restore the textured chin/ruff over the neckline after clothing is drawn.
        var fur = context
        fur.clip(to: ruff(for: placement))
        fur.draw(base, in: bounds)
    }

    private func placement(for pose: OllieNeckwearPose) -> CGAffineTransform {
        let left = pose.neckLeft, right = pose.neckRight, tip = pose.bibTip
        return CGAffineTransform(
            a: (right.x - left.x) / 100, b: (right.y - left.y) / 100,
            c: (tip.x - (left.x + right.x) / 2) / 70,
            d: (tip.y - (left.y + right.y) / 2) / 70,
            tx: left.x, ty: left.y)
    }

    private func ruff(for placement: CGAffineTransform) -> Path {
        Path { p in
            p.move(to: CGPoint(x: -30, y: -400))
            p.addLine(to: CGPoint(x: 130, y: -400))
            p.addLine(to: CGPoint(x: 130, y: -3))
            p.addLine(to: CGPoint(x: 100, y: 5))
            p.addQuadCurve(to: CGPoint(x: 0, y: 5), control: CGPoint(x: 50, y: 30))
            p.addLine(to: CGPoint(x: -30, y: -3))
            p.closeSubpath()
        }.applying(placement)
    }
}

private extension OllieGarment {
    var hasTie: Bool { self == .mossBandana || self == .moonKerchief }
}

private struct OllieGarmentPainter {
    let painter: ShepherdStudyPainter
    private typealias Pigment = ShepherdStudyPalette

    func fitted(_ garment: OllieGarment, pose: OllieNeckwearPose) {
        switch garment {
        case .mossBandana:
            fittedKerchief(color: Pigment.moss, pose: pose) { sheep(x: 44, y: 38) }
        case .moonKerchief:
            fittedKerchief(color: Pigment.heather, pose: pose) { moon(x: 44, y: 35, color: Pigment.heather) }
        case .brassBell:
            collar(Pigment.trousers)
            if pose.showsFrontDetail { bell() }
        case .cloverCollar:
            collar(Pigment.moss)
            if pose.showsFrontDetail { clover() }
        case .sunriseScarf:
            collar(Pigment.hat)
            if pose.showsFrontDetail { scarfTail() }
        case .starKeeperCape:
            if pose.showsFrontDetail { capeShoulder() }
            collar(Pigment.midnight)
            if pose.showsFrontDetail { painter.ellipse(48, 14, 9, 9, Pigment.hat) }
        }
    }

    func tie(for garment: OllieGarment) {
        knot(garment == .moonKerchief ? Pigment.heather : Pigment.moss)
    }

    func capeBack() {
        painter.fill(Path { p in
            p.move(to: CGPoint(x: 3, y: 2))
            p.addQuadCurve(to: CGPoint(x: -46, y: 75), control: CGPoint(x: -39, y: 22))
            p.addQuadCurve(to: CGPoint(x: 38, y: 82), control: CGPoint(x: -10, y: 98))
            p.addQuadCurve(to: CGPoint(x: 41, y: 11), control: CGPoint(x: 25, y: 40))
            p.closeSubpath()
        }, Pigment.midnight)
        painter.fill(polygon([(-8, 40), (-4, 49), (6, 50), (-2, 56), (0, 66),
                              (-8, 60), (-16, 66), (-14, 56), (-22, 50), (-12, 49)]), Pigment.cream)
    }

    private func fittedKerchief(color: Color, pose: OllieNeckwearPose, motif: () -> Void) {
        painter.fill(Path { p in
            p.move(to: CGPoint(x: 0, y: -5))
            p.addQuadCurve(to: CGPoint(x: 100, y: -5), control: CGPoint(x: 50, y: 14))
            p.addCurve(to: CGPoint(x: 50, y: 70), control1: CGPoint(x: 97, y: 25), control2: CGPoint(x: 69, y: 61))
            p.addCurve(to: CGPoint(x: 0, y: -5), control1: CGPoint(x: 30, y: 60), control2: CGPoint(x: 3, y: 27))
            p.closeSubpath()
        }, color)
        painter.fill(Path { p in
            p.move(to: CGPoint(x: 1, y: 5))
            p.addQuadCurve(to: CGPoint(x: 99, y: 5), control: CGPoint(x: 50, y: 30))
            p.addQuadCurve(to: CGPoint(x: 4, y: 13), control: CGPoint(x: 51, y: 39))
            p.closeSubpath()
        }, Pigment.pocket.opacity(0.35))
        if pose.showsFrontDetail { motif() }
    }

    private func bell() {
        painter.rounded(48, 17, 7, 9, 3, Pigment.hatBand)
        painter.fill(polygon([(45, 26), (58, 26), (63, 41), (40, 41)]), Pigment.hat)
        painter.ellipse(48, 40, 7, 5, Pigment.hatBand)
        painter.rounded(41, 38, 21, 3, 1, Pigment.cream)
    }

    private func clover() {
        for (x, y) in [(45.0, 26.0), (52, 26), (45, 33), (52, 33)] {
            painter.ellipse(x, y, 9, 9, Pigment.cream)
        }
    }

    private func scarfTail() {
        painter.fill(polygon([(6, 7), (29, 15), (16, 63), (0, 58)]), Pigment.hat)
        painter.fill(polygon([(11, 8), (29, 12), (43, 46), (25, 53)]), Pigment.hatBand)
        painter.rounded(4, 49, 13, 3, 1, Pigment.cream)
    }

    private func capeShoulder() {
        painter.fill(Path { p in
            p.move(to: CGPoint(x: 3, y: 2))
            p.addQuadCurve(to: CGPoint(x: 19, y: 61), control: CGPoint(x: -12, y: 28))
            p.addQuadCurve(to: CGPoint(x: 43, y: 13), control: CGPoint(x: 40, y: 48))
            p.addQuadCurve(to: CGPoint(x: 3, y: 2), control: CGPoint(x: 28, y: 6))
            p.closeSubpath()
        }, Pigment.midnight)
        painter.fill(polygon([(18, 28), (21, 35), (28, 37), (22, 41), (23, 49),
                              (18, 44), (13, 49), (14, 41), (8, 37), (15, 35)]), Pigment.cream)
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

    func knot(_ color: Color) {
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


private struct OllieCoatEnvironmentKey: EnvironmentKey {
    static let defaultValue = OllieCoatStyle.classic
}

extension EnvironmentValues {
    var ollieCoat: OllieCoatStyle {
        get { self[OllieCoatEnvironmentKey.self] }
        set { self[OllieCoatEnvironmentKey.self] = newValue }
    }
}

enum OllieCoatAvailability {
    static let fuller = OllieCoatStyle.hasCompletePack(available: Set(
        OllieCoatStyle.baseAssets.compactMap(OllieCoatStyle.fullerAsset).filter { UIImage(named: $0) != nil }
    ))
}
