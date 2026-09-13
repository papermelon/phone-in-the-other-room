import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct ExportSheet: View {
    var heads: [ShepherdStudySilhouette]
    var body: some View {
        VStack(spacing: 18) {
            Text("Shepherd · native geometry masters").font(.system(size: 22, weight: .medium, design: .rounded))
            HStack(spacing: 12) {
                ForEach(ShepherdStudyDirection.allCases) { Text($0.title).font(.system(size: 13)).frame(width: 180) }
            }
            ForEach(heads) { head in
                Text(head.title).font(.system(size: 15, weight: .medium, design: .rounded))
                HStack(spacing: 12) {
                    ForEach(ShepherdStudyDirection.allCases) { direction in
                        ShepherdStudyCanvas(appearance: appearance(head), direction: direction).frame(width: 180, height: 210)
                    }
                }
            }
        }
        .padding(28)
        .foregroundStyle(ShepherdStudyPalette.ink)
        .background(ShepherdStudyPalette.masterPaper)
    }
    func appearance(_ head: ShepherdStudySilhouette) -> ShepherdStudyAppearance {
        var appearance: ShepherdStudyAppearance = head == .round ? .round : .init()
        appearance.head = head
        return appearance
    }
}

@main
struct Export {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        for (name, heads) in [("bc-native-masters", [ShepherdStudySilhouette.pear, .round]), ("head-shape-explorations", [.boxy, .triangular])] {
            let renderer = ImageRenderer(content: ExportSheet(heads: heads).environment(\.colorScheme, .light))
            renderer.scale = 2
            guard let image = renderer.cgImage else { fatalError("Native image rendering failed") }
            let url = folder.appendingPathComponent(name + ".png")
            let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(output, image, nil)
            precondition(CGImageDestinationFinalize(output))
            print("Exported \(url.path) (\(image.width)×\(image.height))")
        }
    }
}
