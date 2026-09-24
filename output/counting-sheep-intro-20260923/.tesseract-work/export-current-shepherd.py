from pathlib import Path
import subprocess,hashlib,json
root=Path(__file__).resolve().parents[1]; repo=root.parents[1]; work=root/'.tesseract-work/native-shepherd'; work.mkdir(exist_ok=True)
s=(repo/'Shared/FarmModels.swift').read_text();(work/'Skin.swift').write_text('import Foundation\n'+s[s.index('enum ShepherdSkinTone:'):s.index('enum ShepherdHairStyle:')]+ '\nenum ShepherdStudyHeadwear { case fieldHat, headscarf, beanie }\n')
sources=['Shared/ShepherdArtStudy.swift','PhoneInTheOtherRoomApp/Design/ShepherdStudyPalette.swift']
for n in ['ShepherdStudyMasterPaths','ShepherdStudyPainter','ShepherdStudyHeadDrawing','ShepherdStudyCanvas']:
 sources.append(f'PhoneInTheOtherRoomApp/Views/ShepherdArtStudy/{n}.swift')
# A film-only pose extension keeps the far arm relaxed while the near arm sets down the phone.
canvas=(repo/sources[-1]).read_text().replace('swing: -pose.armSwing','swing: 0')
(work/'FilmShepherdCanvas.swift').write_text(canvas)
(work/'Export.swift').write_text('''import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers
@main struct Export {
 @MainActor static func main() throws {
  let out=URL(fileURLWithPath:CommandLine.arguments[1])
  try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
  let a=ShepherdStudyAppearance(head:.pear,hair:.short,eyes:.calm,skin:.warm,outfit:.shirt)
  for i in 0...16 {
   let angle = i < 5 ? -98.0 + Double(i)*3 : -86.0 + Double(i-4)/12*86
   let pose=ShepherdStudyPose(armSwing:angle)
   let v=ShepherdStudyCanvas(appearance:a,direction:.threeQuarter,pose:pose).frame(width:720,height:840)
   let renderer=ImageRenderer(content:v); renderer.scale=1
   guard let image=renderer.cgImage,let dest=CGImageDestinationCreateWithURL(out.appendingPathComponent(String(format:"shepherd-pose-%02d.png",i)) as CFURL,UTType.png.identifier as CFString,1,nil) else {fatalError("Export failed")}
   CGImageDestinationAddImage(dest,image,nil); guard CGImageDestinationFinalize(dest) else {fatalError("Save failed")}
  }
 }
}''')
args=['xcrun','swiftc','-parse-as-library','-module-cache-path',str(work/'modules'),str(work/'Skin.swift'),*[str(repo/x) for x in sources[:-1]],str(work/'FilmShepherdCanvas.swift'),str(work/'Export.swift'),'-o',str(work/'export')]
subprocess.run(args,check=True);subprocess.run([str(work/'export'),str(root/'Assets/current-shepherd')],check=True)
(work/'source-sha256.json').write_text(json.dumps({x:hashlib.sha256((repo/x).read_bytes()).hexdigest() for x in sources},indent=2))
print('Exported 17 film poses using current production paths, palette and texture.')
