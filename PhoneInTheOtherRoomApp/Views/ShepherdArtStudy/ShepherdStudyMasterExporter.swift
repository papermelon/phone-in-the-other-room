#if DEBUG
import SwiftUI

@MainActor
enum ShepherdStudyMasterExporter {
    static func export() throws -> URL {
        let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                     appropriateFor: nil, create: true)
            .appendingPathComponent("ShepherdArtStudy", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, heads) in [("bc-masters", [ShepherdStudySilhouette.pear, .round]),
                              ("head-explorations", [.boxy, .triangular])] {
            let renderer = ImageRenderer(content: ShepherdStudyMasterSheet(heads: heads).environment(\.colorScheme, .light))
            renderer.scale = 2
            guard let data = renderer.uiImage?.pngData() else { throw ExportError.noImage }
            try data.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
        }
        return directory
    }

    private enum ExportError: Error { case noImage }
}

struct ShepherdStudyMasterSheet: View {
    let heads: [ShepherdStudySilhouette]

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text("Shepherd · native geometry masters").font(pixelFont(.headline))
            HStack(spacing: AppSpacing.sm) {
                ForEach(ShepherdStudyDirection.allCases) { direction in
                    Text(direction.title).font(AppTypography.caption).frame(width: 180)
                }
            }
            ForEach(heads) { head in
                Text(head.title).font(AppTypography.caption)
                HStack(spacing: AppSpacing.sm) {
                    ForEach(ShepherdStudyDirection.allCases) { direction in
                        ShepherdStudyCanvas(appearance: appearance(for: head), direction: direction)
                            .frame(width: 180, height: 210)
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(ShepherdStudyPalette.masterPaper)
        .foregroundStyle(ShepherdStudyPalette.ink)
    }

    private func appearance(for head: ShepherdStudySilhouette) -> ShepherdStudyAppearance {
        var result: ShepherdStudyAppearance = head == .round ? .round : .init()
        result.head = head
        return result
    }
}
#endif
