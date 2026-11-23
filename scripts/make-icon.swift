// Renders the Deskflip app icon as a 1024x1024 PNG.
//
// Usage: swift scripts/make-icon.swift <output.png>
//
// All coordinates below are in pixels with the origin at the top-left.

import AppKit

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("make-icon: \(message)\n".utf8))
    exit(1)
}

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func roundedRect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, radius: CGFloat) -> CGPath {
    CGPath(
        roundedRect: CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0),
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    )
}

func polygon(_ points: [(CGFloat, CGFloat)]) -> CGPath {
    let path = CGMutablePath()
    path.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
    path.closeSubpath()
    return path
}

func fill(_ context: CGContext, _ path: CGPath, _ fillColor: CGColor) {
    context.addPath(path)
    context.setFillColor(fillColor)
    context.fillPath()
}

guard CommandLine.arguments.count == 2 else {
    fail("usage: make-icon.swift <output.png>")
}
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])

let size = 1024
guard
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
else {
    fail("could not create a drawing context")
}

// Flip to top-left coordinates.
context.translateBy(x: 0, y: CGFloat(size))
context.scaleBy(x: 1, y: -1)

// Tile: vertical gradient with a soft drop shadow. Shadow offsets are in device
// space (y up), so a negative height moves the shadow down.
let tile = roundedRect(100, 100, 924, 924, radius: 185)
guard let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [color(0x5C9CFF), color(0x2254D6)] as CFArray,
    locations: [0, 1]
) else {
    fail("could not create the tile gradient")
}
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, alpha: 0.35))
context.beginTransparencyLayer(auxiliaryInfo: nil)
context.addPath(tile)
context.clip()
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 924), options: [])
context.endTransparencyLayer()
context.restoreGState()

let white = color(0xFFFFFF)

// Monitor: bezel and screen.
fill(context, roundedRect(232, 262, 792, 642, radius: 44), white)
fill(context, roundedRect(262, 292, 762, 612, radius: 22), color(0x163AA8))

// Stand and base.
fill(context, polygon([(462, 642), (562, 642), (582, 722), (442, 722)]), white)
fill(context, roundedRect(372, 712, 652, 752, radius: 20), white)

// Left/right arrow on the screen.
fill(context, CGPath(rect: CGRect(x: 370, y: 435, width: 654 - 370, height: 469 - 435), transform: nil), white)
fill(context, polygon([(316, 452), (404, 374), (404, 530)]), white)
fill(context, polygon([(708, 452), (620, 374), (620, 530)]), white)

guard let image = context.makeImage() else {
    fail("could not render the image")
}
let bitmap = NSBitmapImageRep(cgImage: image)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fail("could not encode the PNG")
}
do {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try png.write(to: outputURL)
} catch {
    fail("could not write \(outputURL.path): \(error.localizedDescription)")
}
