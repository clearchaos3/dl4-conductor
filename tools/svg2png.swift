import AppKit
let svgPath = CommandLine.arguments[1], pngPath = CommandLine.arguments[2]
let scale: CGFloat = 2
guard let img = NSImage(contentsOfFile: svgPath) else { fatalError("load fail") }
let base = img.size
let w = Int(base.width * scale), h = Int(base.height * scale)
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { fatalError("rep fail") }
rep.size = base
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
img.draw(in: NSRect(origin: .zero, size: base))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: pngPath))
print("wrote \(pngPath)  \(w)x\(h)")
