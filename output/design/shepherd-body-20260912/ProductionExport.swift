import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

private let proofDark = Color(red: 0.08, green: 0.11, blue: 0.09)

private func character(_ outfit: ShepherdStudyOutfit, head: ShepherdStudySilhouette = .pear,
                       hair: ShepherdStudyHair = .short) -> ShepherdStudyAppearance {
    ShepherdStudyAppearance(head: head, hair: hair, eyes: head == .round || head == .boxy ? .open : .calm,
                            skin: .warm, outfit: outfit)
}

struct FittingProof: View {
    let label: String
    let dark: Bool
    private let outfits: [ShepherdStudyOutfit] = [.coat, .shirt, .dress]
    private let directions: [ShepherdStudyDirection] = [.front, .threeQuarter]
    var body: some View {
        VStack(spacing: 14) {
            Text("\(label.capitalized) · body proportions").font(.system(size: 24, weight: .semibold))
            Text("Actual production Canvas · unchanged heads · 180 pt customization / 72 pt Farm")
                .font(.system(size: 14))
            HStack(spacing: 8) {
                ForEach(outfits) { outfit in
                    ForEach(directions) { direction in
                        VStack(spacing: 6) {
                            Text(outfit.title).font(.system(size: 15, weight: .medium))
                            Text(direction.title).font(.system(size: 12))
                            ShepherdStudyCanvas(appearance: character(outfit, head: outfit == .dress ? .round : .pear,
                                hair: outfit == .dress ? .long : .short), direction: direction)
                                .frame(width: 180, height: 180)
                            ShepherdStudyCanvas(appearance: character(outfit, head: outfit == .dress ? .round : .pear,
                                hair: outfit == .dress ? .long : .short), direction: direction)
                                .frame(width: 72, height: 72)
                        }.frame(width: 180)
                    }
                }
            }
        }.padding(24).foregroundStyle(dark ? ShepherdStudyPalette.cream : ShepherdStudyPalette.ink)
            .background(dark ? proofDark : ShepherdStudyPalette.masterPaper)
    }
}

struct WardrobeProof: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Wardrobe fit · four head shapes, short and long hair").font(.system(size: 22, weight: .semibold))
            HStack(spacing: 10) {
                Text("Head / hair").frame(width: 110)
                ForEach(ShepherdStudyOutfit.allCases) { outfit in
                    Text(outfit.title).frame(width: 124)
                }
            }.font(.system(size: 12))
            ForEach(ShepherdStudySilhouette.allCases) { head in
                ForEach([ShepherdStudyHair.short, .long]) { hair in
                    HStack(spacing: 10) {
                        Text("\(head.rawValue.capitalized)\n\(hair.title)").font(.system(size: 13)).frame(width: 110)
                        ForEach(ShepherdStudyOutfit.allCases) { outfit in
                            ShepherdStudyCanvas(appearance: character(outfit, head: head, hair: hair))
                                .frame(width: 124, height: 138)
                        }
                    }
                }
            }
            Text("Berry dress remains an art-study option; saved production outfit IDs are unchanged.")
                .font(.system(size: 12))
        }.padding(20).foregroundStyle(ShepherdStudyPalette.cream).background(proofDark)
    }
}

struct MotionProof: View {
    private let times = [0.0, 0.225, 0.72]
    private let labels = ["Contact · 0.00s", "Stance · 0.225s", "Recovery · 0.72s"]
    var body: some View {
        VStack(spacing: 8) {
            Text("Pose compatibility · five views").font(.system(size: 22, weight: .semibold))
            Text("Existing walk poses; each sample retains one planted foot").font(.system(size: 13))
            HStack(spacing: 6) {
                Text("Pose").frame(width: 110)
                ForEach(ShepherdStudyDirection.allCases) { direction in
                    Text(direction.title).frame(width: 140)
                }
            }.font(.system(size: 12))
            ForEach([ShepherdStudyOutfit.coat, .overalls]) { outfit in
                ForEach(0..<3) { phase in
                    HStack(spacing: 6) {
                        Text("\(outfit.title)\n\(labels[phase])").font(.system(size: 12)).frame(width: 110)
                        ForEach(ShepherdStudyDirection.allCases) { direction in
                            VStack(spacing: 0) {
                                ShepherdStudyCanvas(appearance: character(outfit), direction: direction,
                                    pose: ShepherdStudyMotionRules.pose(at: times[phase], motion: .walk))
                                    .frame(width: 140, height: 163.333)
                            }.frame(width: 140)
                        }
                    }
                }
            }
        }.padding(20).foregroundStyle(ShepherdStudyPalette.ink).background(ShepherdStudyPalette.masterPaper)
    }
}

struct CompanionProof: View {
    let project: String
    private func asset(_ path: String, size: CGFloat) -> some View {
        let image = NSImage(contentsOfFile: project + "/Assets.xcassets/" + path)!
        return Image(nsImage: image).resizable().scaledToFit().frame(width: size, height: size)
    }
    private func row(size: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 22) {
            asset("dog/dog_classic_farm_idle.imageset/dog_classic_farm_idle.png", size: size)
            asset("sheep/sheep_bramble_wool_ready.imageset/sheep_bramble_wool_ready.png", size: size)
            ShepherdStudyCanvas(appearance: character(.coat)).frame(width: size, height: size)
            ShepherdStudyCanvas(appearance: character(.shirt)).frame(width: size, height: size)
            ShepherdStudyCanvas(appearance: character(.dress, head: .round, hair: .long)).frame(width: size, height: size)
        }
    }
    var body: some View {
        VStack(spacing: 14) {
            Text("With the production Ollie and sheep art").font(.system(size: 22, weight: .semibold))
            Text("180 pt comparison").font(.system(size: 13))
            row(size: 180)
            Text("72 pt Farm frames").font(.system(size: 13))
            row(size: 72)
        }.padding(24).foregroundStyle(ShepherdStudyPalette.cream).background(proofDark)
    }
}

@main struct Export {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let label = CommandLine.arguments[2]
        let project = CommandLine.arguments[3]
        func save<V: View>(_ view: V, _ name: String, scale: CGFloat = 1.5) {
            let renderer = ImageRenderer(content: view)
            renderer.scale = scale
            guard let image = renderer.cgImage else { fatalError("Rendering failed: \(name)") }
            let url = folder.appendingPathComponent("\(label)-\(name).png")
            let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(output, image, nil)
            precondition(CGImageDestinationFinalize(output))
            print(url.path)
        }
        save(FittingProof(label: label, dark: true), "fit-dark")
        save(FittingProof(label: label, dark: false), "fit-paper")
        if label != "before" {
            save(WardrobeProof(), "wardrobe")
            save(MotionProof(), "motion")
            save(CompanionProof(project: project), "companions")
        }
    }
}
