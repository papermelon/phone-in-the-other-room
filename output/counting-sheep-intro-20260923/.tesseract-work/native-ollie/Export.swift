import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers
@main struct Export {
 @MainActor static func main() throws {
  let out=URL(fileURLWithPath:CommandLine.arguments[2])
  try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
  for i in 1...6 {
   let view=OllieDressedSprite(assetName:"dog/dog_classic_run_frame_0\(i)",accessoryItemID:"ollie_moss_bandana").frame(width:512,height:512)
   let renderer=ImageRenderer(content:view); renderer.scale=1
   guard let image=renderer.cgImage,let dest=CGImageDestinationCreateWithURL(out.appendingPathComponent(String(format:"ollie-bandana-run-%02d.png",i)) as CFURL,UTType.png.identifier as CFString,1,nil) else { fatalError("Export failed") }
   CGImageDestinationAddImage(dest,image,nil); guard CGImageDestinationFinalize(dest) else { fatalError("Save failed") }
  }
 }
}
