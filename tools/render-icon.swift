// Renders a 1024×1024 app-icon master PNG with CoreGraphics (no design tools needed).
// Concept: decaying "echo tap" bars on a dark-green squircle — reads as a delay pedal.
// Usage: swift tools/render-icon.swift [out.png]
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size,
                          bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("could not create context")
}
let S = CGFloat(size)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

// MARK: Squircle background
let inset: CGFloat = 100
let rect = CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
let radius = rect.width * 0.2237
let bgPath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

ctx.saveGState()
ctx.addPath(bgPath); ctx.clip()
let bgGrad = CGGradient(colorsSpace: cs,
                        colors: [color(0.05, 0.11, 0.07), color(0.02, 0.04, 0.03)] as CFArray,
                        locations: [0, 1])!
ctx.drawLinearGradient(bgGrad, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
ctx.restoreGState()

// Hairline border
ctx.saveGState()
ctx.addPath(bgPath)
ctx.setLineWidth(4)
ctx.setStrokeColor(color(1, 1, 1, 0.06))
ctx.strokePath()
ctx.restoreGState()

// MARK: Decaying echo bars
let heights: [CGFloat] = [540, 430, 330, 240, 165]
let barW: CGFloat = 86
let gap: CGFloat = 58
let totalW = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
var x = (S - totalW) / 2
let baseY: CGFloat = 330

let barGrad = CGGradient(colorsSpace: cs,
                         colors: [color(0.55, 0.95, 0.60), color(0.18, 0.62, 0.30)] as CFArray,
                         locations: [0, 1])!

for h in heights {
    let r = CGRect(x: x, y: baseY, width: barW, height: h)
    let p = CGPath(roundedRect: r, cornerWidth: barW * 0.5, cornerHeight: barW * 0.5, transform: nil)

    // Glow pass: solid fill casts a green shadow.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 36, color: color(0.36, 0.85, 0.45, 0.6))
    ctx.addPath(p)
    ctx.setFillColor(color(0.30, 0.70, 0.40))
    ctx.fillPath()
    ctx.restoreGState()

    // Gradient pass on top.
    ctx.saveGState()
    ctx.addPath(p); ctx.clip()
    ctx.drawLinearGradient(barGrad,
                           start: CGPoint(x: 0, y: baseY + h),
                           end: CGPoint(x: 0, y: baseY), options: [])
    ctx.restoreGState()

    x += barW + gap
}

guard let image = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil) else {
    fatalError("could not write image")
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("Wrote \(outPath)")
