import SwiftUI
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
}