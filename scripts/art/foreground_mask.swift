import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Vision

guard CommandLine.arguments.count == 3 else {
    fputs("usage: foreground_mask.swift input.png output-mask.png\n", stderr)
    exit(64)
}

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = NSImage(contentsOf: input), let image = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("could not read input image\n", stderr)
    exit(65)
}

let request = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(cgImage: image, options: [:])
do {
    try handler.perform([request])
    guard let observation = request.results?.first else { throw NSError(domain: "OllieMask", code: 1) }
    let maskBuffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
    let maskImage = CIImage(cvPixelBuffer: maskBuffer)
    let context = CIContext(options: [.useSoftwareRenderer: false])
    guard let cgMask = context.createCGImage(maskImage, from: maskImage.extent),
          let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "OllieMask", code: 2)
    }
    CGImageDestinationAddImage(destination, cgMask, nil)
    guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "OllieMask", code: 3) }
} catch {
    fputs("foreground segmentation failed: \(error)\n", stderr)
    exit(1)
}
