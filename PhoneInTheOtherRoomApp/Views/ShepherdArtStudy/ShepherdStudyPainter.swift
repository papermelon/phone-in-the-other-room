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
        surface.opacity *= 0.13
        surface.draw(Image(decorative: grain, scale: 1), in: CGRect(x: 0, y: 0, width: 240, height: 280))
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

    /// One cached texture, fixed seed and coordinates: paper must not crawl on every frame.
    private static let grain: CGImage? = {
        let size = 128
        var seed: UInt32 = 813
        var pixels = [UInt8](repeating: 0, count: size * size)
        for index in pixels.indices {
            seed = 1_664_525 &* seed &+ 1_013_904_223
            pixels[index] = 110 + UInt8((seed >> 24) % 145)
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8,
                       bytesPerRow: size, space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: 0), provider: provider,
                       decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }()
}
