import SwiftUI

/// The same paper illustration is used in the Shop, placed scene and shelf.
/// Geometry is authored in the Shepherd painter's 240 × 280 art coordinates.
struct PaperFarmObjectView: View {
    let itemID: String
    var anchoredToGround = false

    static let supportedIDs: Set<String> = [
        "barn_paddock_24", "barn_paddock_36", "barn_paddock_48", "barn_paddock_60",
        "farm_flower_patch", "farm_lanterns", "farm_moon_gate", "farm_twilight_banner",
        "farm_story_bench", "farm_sheep_trough", "farm_dusk_pond", "farm_old_oak",
        "collectible_trail_pin", "collectible_story_bell", "collectible_hoofprint_tile",
        "collectible_wool_almanac", "collectible_sunrise_compass", "collectible_high_moor_star"
    ]

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 240, size.height / 240)
            let baseline: CGFloat = ["farm_flower_patch": 227, "farm_lanterns": 211,
                "farm_moon_gate": 218, "farm_twilight_banner": 220, "farm_story_bench": 218,
                "farm_sheep_trough": 212, "farm_dusk_pond": 210, "farm_old_oak": 220][itemID] ?? 220
            context.translateBy(x: (size.width - 240 * scale) / 2,
                                y: anchoredToGround ? size.height - baseline * scale : (size.height - 240 * scale) / 2 - 20 * scale)
            context.scaleBy(x: scale, y: scale)
            PaperFarmObjectPainter(p: .init(context: context, texture: true)).draw(itemID)
        }
        .accessibilityHidden(true)
    }
}

private struct PaperFarmObjectPainter {
    let p: ShepherdStudyPainter
    private typealias C = ShepherdStudyPalette

    func draw(_ id: String) {
        switch id {
        case "farm_flower_patch": cloverPatch()
        case "farm_lanterns": lantern(x: 38, y: 62, scale: 1); lantern(x: 135, y: 107, scale: 0.7)
        case "farm_moon_gate": gate()
        case "farm_twilight_banner": banner()
        case "farm_story_bench": bench()
        case "farm_sheep_trough": trough()
        case "farm_dusk_pond": pond()
        case "farm_old_oak": oak()
        case "collectible_trail_pin": pin()
        case "collectible_story_bell": storyBell()
        case "collectible_hoofprint_tile": hoofprint()
        case "collectible_wool_almanac": book()
        case "collectible_sunrise_compass": compass()
        case "collectible_high_moor_star": starKeepsake()
        case "barn_paddock_24", "barn_paddock_36", "barn_paddock_48", "barn_paddock_60": pasture(id)
        default: break
        }
    }

    private func shape(_ points: [(Double, Double)], _ color: Color) {
        p.fill(Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: first.0, y: first.1))
            points.dropFirst().forEach { path.addLine(to: CGPoint(x: $0.0, y: $0.1)) }
            path.closeSubpath()
        }, color)
    }

    private func stem(_ x: Double, _ y: Double, _ height: Double) {
        p.rounded(x, y, 4, height, 2, C.pocket)
        p.ellipse(x - 17, y + height * 0.36, 19, 11, C.moss)
        p.ellipse(x + 3, y + height * 0.58, 20, 12, C.moss)
    }

    private func flower(_ x: Double, _ y: Double, petal: Color = C.cream) {
        for (dx, dy) in [(-7.0, 0.0), (7, 0), (0, -7), (0, 7)] { p.ellipse(x + dx - 5, y + dy - 5, 10, 10, petal) }
        p.ellipse(x - 4, y - 4, 8, 8, C.hat)
    }

    private func cloverPatch() {
        p.ellipse(27, 172, 185, 55, C.moss)
        for (x, y, h) in [(52.0, 119.0, 72.0), (90, 87, 114), (139, 109, 89), (178, 140, 62)] {
            stem(x, y, h); flower(x + 2, y)
        }
        for (x, y) in [(61.0, 176.0), (115, 167), (155, 192)] {
            for (dx, dy) in [(-9.0, 0.0), (9, 0), (0, -10)] { p.ellipse(x + dx - 9, y + dy - 9, 18, 18, C.pocket) }
        }
    }

    private func lantern(x: Double, y: Double, scale: Double) {
        var context = p.context
        context.translateBy(x: x, y: y); context.scaleBy(x: scale, y: scale)
        let brush = ShepherdStudyPainter(context: context, texture: true)
        brush.context.stroke(Path(ellipseIn: CGRect(x: 23, y: 0, width: 35, height: 36)), with: .color(C.hatBand), lineWidth: 6)
        brush.rounded(4, 39, 74, 108, 12, C.hatBand)
        brush.rounded(13, 49, 55, 84, 6, C.cream)
        brush.rounded(35, 85, 13, 47, 3, C.masterPaper)
        brush.ellipse(38, 70, 8, 16, C.hat)
        brush.rounded(7, 37, 69, 12, 5, C.hat)
        brush.rounded(3, 135, 77, 14, 5, C.hat)
        brush.rounded(37, 49, 5, 21, 2, C.hatBand)
    }

    private func gate() {
        p.rounded(34, 102, 16, 116, 5, C.moon)
        p.rounded(192, 102, 16, 116, 5, C.moon)
        for x in stride(from: 62.0, through: 170, by: 27) { p.rounded(x, 126, 12, 79, 3, C.cream) }
        p.rounded(48, 116, 145, 12, 4, C.cream)
        p.rounded(48, 199, 145, 12, 4, C.cream)
        shape([(57, 194), (181, 130), (186, 139), (62, 204)], C.moon)
        // A crescent is drawn as a concave path so no background-colored disc leaks into the scene.
        p.fill(Path { path in
            path.move(to: CGPoint(x: 132, y: 62))
            path.addCurve(to: CGPoint(x: 137, y: 93), control1: CGPoint(x: 111, y: 64), control2: CGPoint(x: 115, y: 93))
            path.addCurve(to: CGPoint(x: 132, y: 62), control1: CGPoint(x: 102, y: 112), control2: CGPoint(x: 91, y: 65))
        }, C.hat)
        p.rounded(177, 152, 16, 7, 3, C.hatBand)
    }

    private func banner() {
        p.rounded(27, 69, 13, 151, 5, C.trousers); p.rounded(199, 69, 13, 151, 5, C.trousers)
        shape([(38, 97), (202, 97), (190, 173), (121, 193), (50, 173)], C.cream)
        p.rounded(40, 93, 159, 8, 3, C.hatBand)
        for x in stride(from: 68.0, through: 172, by: 26) { p.ellipse(x, 177, 7, 14, C.hat) }
        stem(120, 124, 43); flower(122, 127, petal: C.heather)
        p.ellipse(84, 141, 22, 12, C.moss); p.ellipse(140, 141, 22, 12, C.moss)
    }

    private func bench() {
        p.rounded(44, 151, 12, 67, 4, C.trousers); p.rounded(183, 151, 12, 67, 4, C.trousers)
        p.rounded(39, 94, 162, 31, 7, C.hatBand); p.rounded(40, 132, 160, 21, 5, C.hat)
        p.rounded(28, 159, 183, 17, 5, C.hatBand)
        p.rounded(54, 113, 8, 47, 3, C.trousers); p.rounded(179, 113, 8, 47, 3, C.trousers)
        p.rounded(126, 146, 52, 17, 5, C.berry)
    }

    private func trough() {
        p.rounded(48, 177, 15, 35, 4, C.trousers); p.rounded(179, 177, 15, 35, 4, C.trousers)
        shape([(28, 122), (215, 122), (196, 193), (46, 193)], C.hatBand)
        p.ellipse(27, 100, 188, 47, C.trousers); p.ellipse(40, 108, 162, 30, C.moon)
        p.ellipse(61, 114, 103, 8, C.cream.opacity(0.55))
        for x in [65.0, 117, 169] { p.rounded(x, 148, 5, 37, 2, C.trousers) }
    }

    private func pond() {
        p.ellipse(21, 119, 198, 91, C.moss); p.ellipse(34, 130, 166, 62, C.moon)
        p.ellipse(66, 149, 106, 8, C.cream.opacity(0.5)); p.ellipse(102, 171, 55, 5, C.cream.opacity(0.5))
        p.ellipse(45, 139, 30, 15, C.pocket); flower(60, 141)
        for (x, y) in [(183.0, 99.0), (199, 113), (37, 110)] {
            p.rounded(x, y, 4, 45, 2, C.pocket); p.rounded(x - 2, y - 8, 8, 23, 4, C.trousers)
        }
    }

    private func oak() {
        shape([(104, 124), (137, 125), (141, 207), (154, 220), (91, 220), (103, 204)], C.trousers)
        shape([(116, 165), (70, 126), (76, 118), (125, 147), (164, 110), (173, 120), (132, 170)], C.trousers)
        for (x, y, w, h) in [(32.0, 75.0, 99.0, 77.0), (79, 36, 100, 104), (122, 77, 88, 78)] {
            p.ellipse(x, y, w, h, C.moss)
        }
        p.ellipse(52, 65, 82, 70, C.denim); p.ellipse(119, 64, 76, 76, C.moss)
    }

    private func pin() {
        p.ellipse(47, 68, 148, 148, C.hatBand); p.ellipse(56, 77, 130, 130, C.cream)
        p.fill(Path { path in
            path.move(to: CGPoint(x: 111, y: 193))
            path.addCurve(to: CGPoint(x: 136, y: 91), control1: CGPoint(x: 182, y: 151), control2: CGPoint(x: 65, y: 134))
            path.addCurve(to: CGPoint(x: 134, y: 199), control1: CGPoint(x: 102, y: 135), control2: CGPoint(x: 213, y: 151))
            path.closeSubpath()
        }, C.hat)
        p.ellipse(74, 127, 20, 33, C.moss); p.ellipse(149, 156, 19, 28, C.moss)
    }

    private func storyBell() {
        p.rounded(60, 188, 128, 16, 5, C.trousers)
        p.rounded(66, 187, 116, 8, 3, C.cream)
        p.context.stroke(Path(ellipseIn: CGRect(x: 104, y: 67, width: 31, height: 32)), with: .color(C.hatBand), lineWidth: 7)
        p.fill(Path { path in
            path.move(to: CGPoint(x: 99, y: 104))
            path.addQuadCurve(to: CGPoint(x: 80, y: 164), control: CGPoint(x: 101, y: 148))
            path.addQuadCurve(to: CGPoint(x: 164, y: 164), control: CGPoint(x: 122, y: 179))
            path.addQuadCurve(to: CGPoint(x: 143, y: 104), control: CGPoint(x: 141, y: 146))
            path.closeSubpath()
        }, C.hat)
        p.ellipse(113, 167, 17, 16, C.hatBand)
        p.rounded(96, 145, 51, 5, 2, C.cream)
    }

    private func hoofprint() {
        p.rounded(44, 70, 155, 147, 19, C.trousers)
        p.rounded(50, 74, 140, 133, 17, C.hatBand)
        // A sheep leaves a split hoof, not the old generic dog paw symbol.
        p.ellipse(87, 111, 29, 61, C.trousers); p.ellipse(125, 111, 29, 61, C.trousers)
        p.ellipse(103, 177, 8, 10, C.trousers); p.ellipse(131, 177, 8, 10, C.trousers)
    }

    private func book() {
        p.rounded(53, 66, 140, 154, 12, C.pocket)
        p.rounded(58, 73, 128, 138, 8, C.cream)
        p.rounded(49, 62, 137, 143, 10, C.moss)
        p.rounded(61, 68, 7, 133, 3, C.pocket)
        p.rounded(87, 88, 71, 6, 3, C.cream)
        p.ellipse(101, 124, 43, 27, C.cream); p.ellipse(137, 130, 14, 16, C.trousers)
        p.rounded(107, 146, 5, 11, 2, C.cream); p.rounded(133, 146, 5, 11, 2, C.cream)
        shape([(153, 197), (166, 197), (166, 227), (159, 221), (153, 227)], C.berry)
    }

    private func compass() {
        p.context.stroke(Path(ellipseIn: CGRect(x: 104, y: 48, width: 32, height: 33)), with: .color(C.hatBand), lineWidth: 8)
        p.ellipse(48, 74, 147, 147, C.hat); p.ellipse(61, 87, 121, 121, C.cream)
        for (x, y, w, h) in [(119.0, 94.0, 4.0, 13.0), (119, 186, 4, 13), (68, 146, 13, 4), (160, 146, 13, 4)] { p.rounded(x, y, w, h, 2, C.hatBand) }
        shape([(122, 108), (138, 151), (121, 185), (106, 146)], C.moon)
        shape([(122, 108), (138, 151), (121, 147)], C.berry)
        p.ellipse(116, 142, 11, 11, C.hatBand)
    }

    private func starKeepsake() {
        p.rounded(75, 198, 93, 13, 5, C.midnight)
        shape([(121, 65), (143, 111), (194, 119), (157, 155), (167, 204), (121, 181), (74, 204), (83, 154), (47, 120), (98, 111)], C.moon)
        shape([(121, 77), (134, 121), (181, 124), (132, 135), (121, 173), (111, 135), (61, 124), (108, 121)], C.cream)
    }

    private func pasture(_ id: String) {
        p.ellipse(19, 139, 202, 88, C.moss)
        if id == "barn_paddock_36" || id == "barn_paddock_60" {
            p.ellipse(23, 96, 130, 84, C.denim); p.ellipse(102, 109, 110, 69, C.moss)
        }
        p.rounded(80, 115, 73, 71, 5, C.trousers)
        shape([(67, 116), (116, 75), (165, 116)], C.midnight)
        p.rounded(104, 145, 25, 41, 3, C.cream)
        for x in stride(from: 32.0, through: 204, by: 43) { p.rounded(x, 180, 8, 41, 3, C.hatBand) }
        p.rounded(32, 190, 179, 7, 3, C.cream)
        if id == "barn_paddock_48" { p.ellipse(170, 63, 29, 29, C.cream) }
        if id == "barn_paddock_60" { p.ellipse(167, 59, 34, 34, C.hat); stem(46, 124, 38); flower(48, 125) }
    }
}

#Preview("Paper collection") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
        ForEach(["farm_lanterns", "farm_moon_gate", "collectible_hoofprint_tile", "collectible_wool_almanac"], id: \.self) { id in
            PaperFarmObjectView(itemID: id).frame(height: 150)
        }
    }.background(AppColors.paper)
}
