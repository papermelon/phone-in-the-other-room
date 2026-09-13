import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct ProductionSheet: View {
    let shape: ShepherdHeadShape
    let dark: Bool
    private let clothes: [String?] = [nil, "shepherd_moss_coat", "shepherd_moon_coat", "shepherd_field_overalls", "shepherd_star_keeper_cloak"]
    private let labels = ["Everyday", "Moss Work Coat", "Moonlit Coat", "Field Overalls", "Star-Keeper Cloak"]
    var body: some View {
        VStack(spacing: 12) {
            Text("\(shape.title) · production avatar").font(.system(size: 24, weight: .semibold))
            HStack {
                ForEach(0..<5) { index in Text(labels[index]).font(.system(size: 14)).frame(width: 180) }
            }
            ForEach(Array(ShepherdHairStyle.allCases.enumerated()), id: \.offset) { index, hair in
                HStack {
                    ForEach(0..<5) { column in
                        VStack {
                            ShepherdStudyCanvas(appearance: appearance(index: index, hair: hair, column: column))
                                .frame(width: 150, height: 165)
                            Text(ShepherdSkinTone.allCases[index].title).font(.system(size: 12))
                        }.frame(width: 180)
                    }
                }
            }
            Text("Rows: hats off / field hat / headscarf / beanie / hats off · five saved skin tones")
                .font(.system(size: 14))
            HStack {
                ForEach(0..<5) { column in
                    ShepherdStudyCanvas(appearance: appearance(index: column, hair: .waves, column: column))
                        .frame(width: 72, height: 72)
                }
            }
            Text("Farm size · 72 pt").font(.system(size: 12))
        }
        .padding(24)
        .foregroundStyle(dark ? ShepherdStudyPalette.cream : ShepherdStudyPalette.ink)
        .background(dark ? Color(red: 0.08, green: 0.11, blue: 0.09) : ShepherdStudyPalette.masterPaper)
    }
    func appearance(index: Int, hair: ShepherdHairStyle, column: Int) -> ShepherdStudyAppearance {
        let hats: [String?] = [nil, "shepherd_wool_hat", "shepherd_clover_headscarf", "shepherd_moon_beanie", nil]
        let profile = ShepherdProfile(skinTone: ShepherdSkinTone.allCases[index], hairStyle: .long,
            outfitItemID: clothes[column], accessoryItemID: hats[index], headShapeID: shape.rawValue)
        return ShepherdStudyAppearance(profile: profile)
    }
}

struct HairViews: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Long hair · continuous silhouette behind the face").font(.system(size: 18, weight: .semibold))
            HStack {
                ForEach(ShepherdStudyDirection.allCases) { direction in
                    Text(direction.title).font(.system(size: 11)).frame(width: 110)
                }
            }
            ForEach(ShepherdHeadShape.allCases) { shape in
                Text(shape.title).font(.system(size: 14, weight: .medium))
                HStack {
                    ForEach(ShepherdStudyDirection.allCases) { direction in
                        ShepherdStudyCanvas(appearance: ShepherdStudyAppearance(profile: ShepherdProfile(
                            skinTone: .warm, hairStyle: .long, outfitItemID: "shepherd_moss_coat",
                            accessoryItemID: nil, headShapeID: shape.rawValue)), direction: direction)
                            .frame(width: 110, height: 128)
                    }
                }
            }
        }.padding(20).foregroundStyle(ShepherdStudyPalette.cream)
            .background(Color(red: 0.08, green: 0.11, blue: 0.09))
    }
}

@main struct Export {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let proof = ImageRenderer(content: HairViews())
        proof.scale = 2
        if let image = proof.cgImage {
            let url = folder.appendingPathComponent("long-hair-views.png")
            let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(output, image, nil)
            precondition(CGImageDestinationFinalize(output))
        }
        for shape in ShepherdHeadShape.allCases {
            let renderer = ImageRenderer(content: ProductionSheet(shape: shape, dark: shape == .round))
            renderer.scale = 1.5
            guard let image = renderer.cgImage else { fatalError("Rendering failed") }
            let url = folder.appendingPathComponent("\(shape.rawValue)-production.png")
            let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(output, image, nil)
            precondition(CGImageDestinationFinalize(output))
            print(url.path)
        }
    }
}
