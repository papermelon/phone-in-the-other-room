from pathlib import Path
import subprocess, json, hashlib

root=Path(__file__).resolve().parents[1]; repo=root.parents[1]
work=root/'.tesseract-work/native-ollie'; work.mkdir(exist_ok=True)
source='PhoneInTheOtherRoomApp/Views/Components/OllieDressedSprite.swift'
s=(repo/source).read_text().split('#Preview')[0]
s=s.replace('import SwiftUI','import SwiftUI\nimport AppKit')
s=s.replace('    @Environment(\\.ollieCoat) private var coat\n','')
s=s.replace('UIImage(named: resolvedAsset)','NSImage(contentsOfFile: Self.assetPath(assetName))')
s=s.replace('Image(uiImage: baseImage)','Image(nsImage: baseImage)')
s=s.replace('usesFullerCoat ? OllieFullerCoatRegistration.groundOffset(for: assetName) : 0','0')
s=s.replace('usesFullerCoat ? OllieFullerCoatRegistration.neckwear(for: assetName) : OllieNeckwearPose.forAsset(assetName)','OllieNeckwearPose.forAsset(assetName)')
s=s.replace('.foregroundStyle(AppColors.grass)','.foregroundStyle(Color.green)').replace('.padding(AppSpacing.sm)','.padding(8)')
a=s.index('    private var usesFullerCoat:'); b=s.index('    private func drawCapeBehindOllie',a)
replacement='''    private static func assetPath(_ name: String) -> String {
        CommandLine.arguments[1] + "/Assets.xcassets/" + name + ".imageset/" + String(name.split(separator: "/").last!) + ".png"
    }

'''
s=s[:a]+replacement+s[b:]
(work/'OllieExportView.swift').write_text(s)
wardrobe=(repo/'Shared/OllieWardrobe.swift').read_text().split('/// Coat artwork')[0]
(work/'Wardrobe.swift').write_text(wardrobe)
(work/'Assets.swift').write_text('''import Foundation
enum NightJourneyAssets {
 static let ollieHomeIdleFrames = (1...6).map { "dog/dog_classic_home_idle_frame_0\\($0)" }
 static let ollieRunFrames = (1...6).map { "dog/dog_classic_run_frame_0\\($0)" }
}
''')
(work/'Export.swift').write_text('''import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers
@main struct Export {
 @MainActor static func main() throws {
  let out=URL(fileURLWithPath:CommandLine.arguments[2])
  try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
  for i in 1...6 {
   let view=OllieDressedSprite(assetName:"dog/dog_classic_run_frame_0\\(i)",accessoryItemID:"ollie_moss_bandana").frame(width:512,height:512)
   let renderer=ImageRenderer(content:view); renderer.scale=1
   guard let image=renderer.cgImage,let dest=CGImageDestinationCreateWithURL(out.appendingPathComponent(String(format:"ollie-bandana-run-%02d.png",i)) as CFURL,UTType.png.identifier as CFString,1,nil) else { fatalError("Export failed") }
   CGImageDestinationAddImage(dest,image,nil); guard CGImageDestinationFinalize(dest) else { fatalError("Save failed") }
  }
 }
}
''')
originals=[source,'Shared/OllieWardrobe.swift','PhoneInTheOtherRoomApp/Design/ShepherdStudyPalette.swift','PhoneInTheOtherRoomApp/Views/ShepherdArtStudy/ShepherdStudyPainter.swift']
args=['xcrun','swiftc','-parse-as-library','-module-cache-path',str(work/'modules'),str(root/'.tesseract-work/native-shepherd/Skin.swift'),*[str(work/f) for f in ['OllieExportView.swift','Wardrobe.swift','Assets.swift','Export.swift']],*[str(repo/f) for f in originals[2:]],'-o',str(work/'export')]
subprocess.run(args,check=True)
subprocess.run([str(work/'export'),str(repo),str(root/'Assets/current-ollie')],check=True)
(work/'source-sha256.json').write_text(json.dumps({f:hashlib.sha256((repo/f).read_bytes()).hexdigest() for f in originals},indent=2))
print('Exported original Classic Ollie with exact production moss bandana for all six run frames.')
