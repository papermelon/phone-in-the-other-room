import SwiftUI

struct ShepherdStudyPainter {
    var context: GraphicsContext
    var texture: Bool

    func fill(_ path: Path, _ color: Color) {
        context.fill(path, with: .color(color))
        guard texture, let grain = Self.grain else { return }
        var surface = context
        surface.clip(to: path)
        surface.blendMode = .multiply
        surface.opacity *= 0.11
        let canvas = CGRect(x: 0, y: 0, width: 240, height: 280)
        surface.draw(Image(decorative: grain, scale: 1), in: canvas)
        if let wash = Self.wash {
            surface.draw(Image(decorative: wash, scale: 1), in: canvas)
        }
    }

    func ellipse(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ color: Color) {
        fill(Path(ellipseIn: CGRect(x: x, y: y, width: width, height: height)), color)
    }

    func rounded(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat, _ color: Color) {
        fill(Path(roundedRect: CGRect(x: x, y: y, width: width, height: height), cornerRadius: radius), color)
    }

    func line(_ points: [CGPoint], width: CGFloat = 2.2) {
        let path = Path { p in
            guard let first = points.first else { return }
            p.move(to: first)
            points.dropFirst().forEach { p.addLine(to: $0) }
        }
        context.stroke(path, with: .color(ShepherdStudyPalette.ink), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    func rotated(_ degrees: Double, around anchor: CGPoint) -> Self {
        var result = self
        result.context.translateBy(x: anchor.x, y: anchor.y)
        result.context.rotate(by: .degrees(degrees))
        result.context.translateBy(x: -anchor.x, y: -anchor.y)
        return result
    }

    /// Broad pigment variation complements the fine grain. Both stay attached to each part.
    private static let wash: CGImage? = {
        let size = 96
        var seed: UInt32 = 481
        var lattice = [Double](repeating: 0, count: 9 * 9)
        for index in lattice.indices {
            seed = 1_664_525 &* seed &+ 1_013_904_223
            lattice[index] = Double(seed >> 24) / 255
        }
        var pixels = [UInt8](repeating: 0, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                let gx = Double(x) / Double(size) * 8, gy = Double(y) / Double(size) * 8
                let ix = Int(gx), iy = Int(gy)
                let fx = gx - Double(ix), fy = gy - Double(iy)
                let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
                let top = lattice[iy * 9 + ix] * (1 - sx) + lattice[iy * 9 + ix + 1] * sx
                let bottom = lattice[(iy + 1) * 9 + ix] * (1 - sx) + lattice[(iy + 1) * 9 + ix + 1] * sx
                pixels[y * size + x] = UInt8(65 + 190 * (top * (1 - sy) + bottom * sy))
            }
        }
        return paperImage(pixels, size: size)
    }()

    /// One cached texture, fixed seed and coordinates: paper must not crawl on every frame.
    private static let grain: CGImage? = {
        let size = 128
        var seed: UInt32 = 813
        var pixels = [UInt8](repeating: 0, count: size * size)
        for index in pixels.indices {
            seed = 1_664_525 &* seed &+ 1_013_904_223
            pixels[index] = 110 + UInt8((seed >> 24) % 145)
        }
        return paperImage(pixels, size: size)
    }()

    private static func paperImage(_ pixels: [UInt8], size: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8,
                       bytesPerRow: size, space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: 0), provider: provider,
                       decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
