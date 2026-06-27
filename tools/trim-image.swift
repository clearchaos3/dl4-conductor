// Trims near-white and transparent margins from an image so it can be scaled to real size.
// Usage: swift tools/trim-image.swift in.png out.png [pad]
// (If no foreground is found — e.g. a black-background photo — the original is copied through.)
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: trim in out [pad]"); exit(1) }
let inPath = args[1], outPath = args[2]
let pad = args.count > 3 ? (Int(args[3]) ?? 6) : 6

guard let img = NSImage(contentsOfFile: inPath),
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("load fail: \(inPath)"); exit(1) }
let w = cg.width, h = cg.height, bpr = w * 4
var data = [UInt8](repeating: 0, count: bpr * h)
let cs = CGColorSpaceCreateDeviceRGB()
guard let rc = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: bpr,
    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { print("ctx fail"); exit(1) }
rc.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))   // bottom-up buffer

func fg(_ x: Int, _ y: Int) -> Bool {
    let i = y*bpr + x*4
    if data[i+3] < 16 { return false }                                  // transparent
    if data[i] > 244 && data[i+1] > 244 && data[i+2] > 244 { return false } // near-white
    return true
}
var minX = w, minY = h, maxX = -1, maxY = -1
for y in 0..<h { for x in 0..<w where fg(x, y) {
    if x < minX { minX = x }; if x > maxX { maxX = x }
    if y < minY { minY = y }; if y > maxY { maxY = y }
}}
if maxX < minX || maxY < minY {
    try? FileManager.default.removeItem(atPath: outPath)
    try? FileManager.default.copyItem(atPath: inPath, toPath: outPath)
    print("no-trim (kept) \(outPath)"); exit(0)
}
minX = max(0, minX-pad); minY = max(0, minY-pad); maxX = min(w-1, maxX+pad); maxY = min(h-1, maxY+pad)
let cw = maxX-minX+1, ch = maxY-minY+1
let out = CGContext(data: nil, width: cw, height: ch, bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
out.draw(cg, in: CGRect(x: -CGFloat(minX), y: -CGFloat(minY), width: CGFloat(w), height: CGFloat(h)))
let cropped = out.makeImage()!
try! NSBitmapImageRep(cgImage: cropped).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("trimmed \(outPath)  \(w)x\(h) -> \(cw)x\(ch)")
