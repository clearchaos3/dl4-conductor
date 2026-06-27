// Composites real product photos into the rig signal-chain diagram.
// Each photo sits in a white rounded "card" (neutralizes mismatched backgrounds) with a
// label + dimensions below. Photos live in docs/assets/<file>. Missing files render as a
// labeled placeholder so partial sets still produce a diagram.
// Usage: swift tools/render-photo-diagram.swift docs/signal-chain.png
import AppKit
import CoreGraphics

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "signal-chain.png"
let assetsDir = "docs/assets"
let W: CGFloat = 1800, H: CGFloat = 1600
let scale: CGFloat = 2

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W*scale), pixelsHigh: Int(H*scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext

func hexCG(_ h: String, _ a: CGFloat = 1) -> CGColor {
    var s = h; if s.hasPrefix("#") { s.removeFirst() }; let v = UInt32(s, radix: 16) ?? 0
    return CGColor(srgbRed: CGFloat((v>>16)&0xff)/255, green: CGFloat((v>>8)&0xff)/255, blue: CGFloat(v&0xff)/255, alpha: a)
}
func nsCol(_ h: String) -> NSColor {
    var s = h; if s.hasPrefix("#") { s.removeFirst() }; let v = UInt32(s, radix: 16) ?? 0
    return NSColor(srgbRed: CGFloat((v>>16)&0xff)/255, green: CGFloat((v>>8)&0xff)/255, blue: CGFloat(v&0xff)/255, alpha: 1)
}
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: H - y) }
func RR(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: H - y - h, width: w, height: h) }
func fillRR(_ r: CGRect, _ rad: CGFloat, _ c: CGColor) { ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.setFillColor(c); ctx.fillPath() }
func strokeRR(_ r: CGRect, _ rad: CGFloat, _ c: CGColor, _ lw: CGFloat) { ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.setStrokeColor(c); ctx.setLineWidth(lw); ctx.strokePath() }
func text(_ s: String, cx: CGFloat, top: CGFloat, size: CGFloat, _ hex: String = "e8efe9", bold: Bool = false) {
    let f = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    let a = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: nsCol(hex)])
    a.draw(at: NSPoint(x: cx - a.size().width/2, y: (H - top) - a.size().height))
}
func ltext(_ s: String, x: CGFloat, top: CGFloat, size: CGFloat, _ hex: String = "9fb0a5", bold: Bool = false) {
    let f = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: nsCol(hex)]).draw(at: NSPoint(x: x, y: (H - top) - f.ascender - 2))
}
func arrow(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ hex: String = "c8d2cc", dashed: Bool = false, lw: CGFloat = 2.2) {
    ctx.saveGState(); ctx.setStrokeColor(hexCG(hex)); ctx.setLineWidth(lw)
    if dashed { ctx.setLineDash(phase: 0, lengths: [7, 5]) }
    ctx.move(to: P(x1, y1)); ctx.addLine(to: P(x2, y2)); ctx.strokePath(); ctx.restoreGState()
    let ang = atan2(-(y2 - y1), x2 - x1), len: CGFloat = 13
    let tip = P(x2, y2)
    ctx.move(to: tip)
    ctx.addLine(to: CGPoint(x: tip.x + cos(ang + .pi - 0.45)*len, y: tip.y + sin(ang + .pi - 0.45)*len))
    ctx.addLine(to: CGPoint(x: tip.x + cos(ang + .pi + 0.45)*len, y: tip.y + sin(ang + .pi + 0.45)*len))
    ctx.closePath(); ctx.setFillColor(hexCG(hex)); ctx.fillPath()
}

/// White card holding a photo (aspect-fit) with label + dims below it.
func card(_ file: String, cx: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat, label: String, dims: String, accent: String = "5bbf73") {
    let r = RR(cx - w/2, top, w, h)
    fillRR(r, 12, hexCG("f4f5f3")); strokeRR(r, 12, hexCG(accent), 2.5)
    let pad: CGFloat = 12
    let content = r.insetBy(dx: pad, dy: pad)
    if let img = NSImage(contentsOfFile: "\(assetsDir)/\(file)"), img.size.width > 0 {
        let s = min(content.width / img.size.width, content.height / img.size.height)
        let dw = img.size.width * s, dh = img.size.height * s
        let dr = CGRect(x: content.midX - dw/2, y: content.midY - dh/2, width: dw, height: dh)
        img.draw(in: dr, from: .zero, operation: .sourceOver, fraction: 1)
    } else {
        text("(\(file))", cx: cx, top: top + h/2 - 6, size: 11, "999999")
    }
    text(label, cx: cx, top: top + h + 6, size: 13, "e8efe9", bold: true)
    if !dims.isEmpty { text(dims + " mm", cx: cx, top: top + h + 26, size: 11, "9fb0a5") }
}

// ===== background + title =====
ctx.setFillColor(hexCG("0d0f0e")); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
ltext("DL4 ×4  ·  Loop + Lofi-Beat Rig — Signal Chain", x: 56, top: 30, size: 28, "7CF08A", bold: true)

box: do {
    let r = RR(1410, 86, 350, 150); fillRR(r, 10, hexCG("11141a")); strokeRR(r, 10, hexCG("444444"), 1.5)
}
ltext("Legend", x: 1432, top: 104, size: 16, "e8efe9", bold: true)
arrow(1432, 146, 1482, 146, "5bbf73"); ltext("audio signal", x: 1498, top: 139, size: 13)
arrow(1432, 180, 1482, 180, "5aa0e0"); ltext("MIDI control", x: 1498, top: 173, size: 13)
arrow(1432, 214, 1482, 214, "e0a94a", dashed: true); ltext("MIDI clock (tempo)", x: 1498, top: 207, size: 13)

// ===== PANEL A: AUDIO =====
ltext("AUDIO PATH   ·   DL4s record samples · FX tweak them live", x: 56, top: 92, size: 21, "9fb0a5", bold: true)

card("guitar.png",  cx: 140, top: 150, w: 150, h: 130, label: "Electric Guitar", dims: "")
card("mic.png",     cx: 140, top: 330, w: 130, h: 130, label: "Microphone", dims: "")
card("tu3w.png",    cx: 330, top: 175, w: 130, h: 150, label: "TU-3W tuner", dims: "73×129")

let dl4cx: [CGFloat] = [560, 820, 1080, 1340]
let dl4nm = ["DL4 MkII A", "DL4 MkII B", "DL4 MkII C", "DL4 MkII D"]
for (i, cx) in dl4cx.enumerated() {
    let file = i == 3 ? "dl4-25th.png" : "dl4.png"
    card(file, cx: cx, top: 165, w: 210, h: 150, label: dl4nm[i], dims: "152×89", accent: "7CF08A")
}
arrow(160, 200, 263, 215); arrow(396, 235, 452, 235); ltext("1/4\"", x: 402, top: 205, size: 12, "c8d2cc")
arrow(160, 380, 452, 290, "c8d2cc"); ltext("XLR (mic)", x: 215, top: 360, size: 12, "c8d2cc")
arrow(666, 240, 712, 240); arrow(926, 240, 972, 240); arrow(1186, 240, 1232, 240)
ltext("guitar + mic reach every DL4 → record a sample into any of the four", x: 470, top: 340, size: 13, "9fb0a5")

arrow(1340, 345, 1340, 400, "c8d2cc"); arrow(1340, 400, 250, 400, "c8d2cc"); arrow(250, 400, 250, 470, "c8d2cc")

let fx: [(CGFloat, String, String, String)] = [
    (235, "Dookie Drive", "dookie.png", "MXR"), (470, "GE-7 EQ", "ge7.png", "73×129"),
    (705, "Pitch Fork", "pitchfork.png", "70×115"), (940, "PH-2 Phaser", "ph2.png", "73×129"),
    (1175, "DE7 delay", "de7.png", "Ibanez"), (1410, "DD-5 delay", "dd5.png", "73×129"),
    (1645, "RV-3 reverb", "rv3.png", "73×129")
]
for (cx, label, file, dims) in fx { card(file, cx: cx, top: 474, w: 150, h: 150, label: label, dims: dims) }
for i in 0..<6 { arrow(fx[i].0 + 75, 549, fx[i+1].0 - 75, 549) }
card("volumex.png", cx: 705, top: 690, w: 120, h: 110, label: "Volume X → exp", dims: "")
card("redremote.png", cx: 1410, top: 690, w: 110, h: 100, label: "Red Remote → tap", dims: "")

arrow(1720, 555, 1760, 555); arrow(1760, 555, 1760, 760, "c8d2cc"); arrow(1760, 760, 1075, 760, "c8d2cc")

card("apollo.png", cx: 930, top: 770, w: 300, h: 150, label: "Apollo Twin", dims: "interface", accent: "5bbf73")
arrow(930, 968, 930, 1012)
card("amp.png", cx: 930, top: 1016, w: 280, h: 140, label: "Amp / Speakers", dims: "", accent: "d98a5b")
card("macbook.png", cx: 1460, top: 760, w: 260, h: 170, label: "MacBook", dims: "")
arrow(1090, 845, 1330, 850, "c8d2cc", dashed: true); ltext("Thunderbolt", x: 1140, top: 825, size: 12, "9fb0a5")

ctx.setStrokeColor(hexCG("333333")); ctx.setLineWidth(1); ctx.move(to: P(40, 1140)); ctx.addLine(to: P(1760, 1140)); ctx.strokePath()

// ===== PANEL B: MIDI / USB =====
ltext("MIDI / USB   ·   one Midi Fighter drives both Ableton drums and the DL4 loopers", x: 56, top: 1172, size: 21, "9fb0a5", bold: true)

card("mf64.png", cx: 240, top: 1220, w: 220, h: 200, label: "Midi Fighter 64", dims: "263×263", accent: "5aa0e0")
card("macbook.png", cx: 720, top: 1230, w: 250, h: 170, label: "MacBook (Ableton + DL4 Conductor)", dims: "", accent: "5aa0e0")
card("hub.png", cx: 1200, top: 1250, w: 200, h: 130, label: "Powered USB hub", dims: "", accent: "5aa0e0")

arrow(360, 1260, 585, 1290, "5aa0e0"); ltext("drum pads (~48)", x: 380, top: 1248, size: 12, "c8d2cc")
arrow(360, 1320, 585, 1360, "5aa0e0"); ltext("DL4 pads (16)", x: 380, top: 1360, size: 12, "c8d2cc")
arrow(855, 1300, 1100, 1310, "5aa0e0"); ltext("control + LEDs", x: 880, top: 1285, size: 12, "c8d2cc")
arrow(855, 1340, 1100, 1345, "e0a94a", dashed: true); ltext("MIDI clock → delays", x: 880, top: 1352, size: 12, "e0a94a")

let bxs: [CGFloat] = [960, 1110, 1260, 1410]
for (i, cx) in bxs.enumerated() {
    let r = RR(cx - 58, 1430, 116, 56); fillRR(r, 8, hexCG("16291d")); strokeRR(r, 8, hexCG("7CF08A"), 2)
    text("DL4 \(["A","B","C","D"][i])", cx: cx, top: 1450, size: 14, "e8efe9", bold: true)
}
for cx in bxs { arrow(1200, 1380, cx, 1428, "c8d2cc") }
ltext("the same 4 DL4s as above · each powered by its own 9V brick", x: 960, top: 1500, size: 12, "9fb0a5")

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)  \(Int(W*scale))x\(Int(H*scale))")
