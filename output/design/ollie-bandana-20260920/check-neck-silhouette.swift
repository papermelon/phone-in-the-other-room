import AppKit
let base = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))!
let dressed = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))!
let scale = Double(dressed.pixelsWide) / Double(base.pixelsWide)
var strayPixels = 0
// Right-neck area of the deepest tilt. The knot is on the opposite side.
for y in 220..<280 {
    for x in 340..<380 {
        let source = base.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
        let pixel = dressed.colorAt(x: Int(Double(x) * scale), y: Int(Double(y) * scale))!.usingColorSpace(.deviceRGB)!
        if source.alphaComponent < 0.02 && pixel.greenComponent > pixel.redComponent * 1.02 && pixel.greenComponent > pixel.blueComponent * 1.2 && pixel.greenComponent > 0.1 {
            strayPixels += 1
        }
    }
}
print("Green fabric pixels outside the right-neck silhouette: \(strayPixels)")
if CommandLine.arguments.contains("--assert-clean") { precondition(strayPixels == 0) }
