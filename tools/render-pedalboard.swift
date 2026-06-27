// Renders the rig as a top-down PEDALBOARD layout (ideal formation, TIGHTLY packed like a
// real board) with real-size pedals, the CIOKS DC7 power plan underneath, and the off-board
// computer/interface/monitors. Reads trimmed photos from docs/assets/trim/.
// Usage: swift tools/render-pedalboard.swift out.png
import AppKit
import CoreGraphics

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "pedalboard.png"
let dir = "docs/assets/trim"
let W: CGFloat = 1320, H: CGFloat = 1230, scale: CGFloat = 2
let PK: CGFloat = 1.15
let GAP: CGFloat = 11        // tight inter-pedal gap (~9-10 mm), like a real board

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W*scale), pixelsHigh: Int(H*scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
let gctx = NSGraphicsContext(bitmapImageRep: rep)!; NSGraphicsContext.current = gctx
let ctx = gctx.cgContext

func hexCG(_ h: String, _ a: CGFloat = 1) -> CGColor { var s=h; if s.hasPrefix("#"){s.removeFirst()}; let v=UInt32(s,radix:16) ?? 0
    return CGColor(srgbRed: CGFloat((v>>16)&0xff)/255, green: CGFloat((v>>8)&0xff)/255, blue: CGFloat(v&0xff)/255, alpha: a) }
func nsCol(_ h: String) -> NSColor { var s=h; if s.hasPrefix("#"){s.removeFirst()}; let v=UInt32(s,radix:16) ?? 0
    return NSColor(srgbRed: CGFloat((v>>16)&0xff)/255, green: CGFloat((v>>8)&0xff)/255, blue: CGFloat(v&0xff)/255, alpha: 1) }
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: H-y) }
func RR(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: H-y-h, width: w, height: h) }
func fillRR(_ r: CGRect, _ rad: CGFloat, _ c: CGColor) { ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.setFillColor(c); ctx.fillPath() }
func strokeRR(_ r: CGRect, _ rad: CGFloat, _ c: CGColor, _ lw: CGFloat) { ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.setStrokeColor(c); ctx.setLineWidth(lw); ctx.strokePath() }
func text(_ s: String, cx: CGFloat, top: CGFloat, size: CGFloat, _ hex: String = "e8efe9", bold: Bool = false) {
    let a = NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular), .foregroundColor: nsCol(hex)])
    a.draw(at: NSPoint(x: cx - a.size().width/2, y: (H-top) - a.size().height)) }
func ltext(_ s: String, x: CGFloat, top: CGFloat, size: CGFloat, _ hex: String = "9fb0a5", bold: Bool = false) {
    let f = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: nsCol(hex)]).draw(at: NSPoint(x: x, y: (H-top) - f.ascender - 2)) }
func arrow(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ hex: String = "5bbf73", dashed: Bool = false, lw: CGFloat = 2.4) {
    ctx.saveGState(); ctx.setStrokeColor(hexCG(hex)); ctx.setLineWidth(lw); if dashed { ctx.setLineDash(phase: 0, lengths: [7,5]) }
    ctx.move(to: P(x1,y1)); ctx.addLine(to: P(x2,y2)); ctx.strokePath(); ctx.restoreGState()
    let ang = atan2(-(y2-y1), x2-x1), L: CGFloat = 13, tip = P(x2,y2)
    ctx.move(to: tip); ctx.addLine(to: CGPoint(x: tip.x+cos(ang + .pi-0.45)*L, y: tip.y+sin(ang + .pi-0.45)*L))
    ctx.addLine(to: CGPoint(x: tip.x+cos(ang + .pi+0.45)*L, y: tip.y+sin(ang + .pi+0.45)*L)); ctx.closePath(); ctx.setFillColor(hexCG(hex)); ctx.fillPath() }
func drawImage(_ file: String, in c: CGRect) {
    if let img = NSImage(contentsOfFile: "\(dir)/\(file)"), img.size.width > 0 {
        let s = min(c.width/img.size.width, c.height/img.size.height); let dw = img.size.width*s, dh = img.size.height*s
        img.draw(in: CGRect(x: c.midX-dw/2, y: c.midY-dh/2, width: dw, height: dh), from: .zero, operation: .sourceOver, fraction: 1)
    } else { ctx.setFillColor(hexCG("dddddd")); ctx.fill(c) }
}
func badge(_ n: Int, _ x: CGFloat, _ y: CGFloat) {
    let r = CGRect(x: x-12, y: (H-y)-12, width: 24, height: 24); ctx.addEllipse(in: r); ctx.setFillColor(hexCG("0d0f0e")); ctx.fillPath()
    ctx.addEllipse(in: r); ctx.setStrokeColor(hexCG("7CF08A")); ctx.setLineWidth(2); ctx.strokePath()
    text("\(n)", cx: x, top: y-8, size: 13, "7CF08A", bold: true)
}
func pedalB(_ file: String, cx: CGFloat, bottom: CGFloat, fw: CGFloat, fh: CGFloat, label: String, num: Int? = nil, sub: String = "", accent: String = "7CF08A") {
    let w = fw*PK, h = fh*PK, top = bottom - h, r = RR(cx-w/2, top, w, h)
    fillRR(r, 8, hexCG("f4f5f3")); strokeRR(r, 8, hexCG(accent), 2)
    drawImage(file, in: r.insetBy(dx: 6, dy: 6))
    text(label, cx: cx, top: bottom+5, size: 12, "e8efe9", bold: true)
    if !sub.isEmpty { text(sub, cx: cx, top: bottom+22, size: 10, "9fb0a5") }
    if let n = num { badge(n, cx-w/2+1, top+1) }
}
func pedalC(_ file: String, cx: CGFloat, cy: CGFloat, fw: CGFloat, fh: CGFloat, label: String, num: Int? = nil) {
    pedalB(file, cx: cx, bottom: cy + fh*PK/2, fw: fw, fh: fh, label: label, num: num)
}
func devCard(_ file: String, cx: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat, label: String, accent: String = "5aa0e0") {
    let r = RR(cx-w/2, top, w, h); fillRR(r, 9, hexCG("f4f5f3")); strokeRR(r, 9, hexCG(accent), 2)
    drawImage(file, in: r.insetBy(dx: 7, dy: 7)); text(label, cx: cx, top: top+h+5, size: 11.5, "e8efe9", bold: true)
}

// ===== background + title =====
ctx.setFillColor(hexCG("0d0f0e")); ctx.fill(CGRect(x:0,y:0,width:W,height:H))
ltext("DL4 ×4 Rig — Ideal Pedalboard Layout", x: 54, top: 28, size: 27, "7CF08A", bold: true)
ltext("packed tight · loopers on the back riser (Midi-Fighter-driven) · foot pedals up front · numbers = signal order", x: 56, top: 63, size: 13.5, "9fb0a5")

// ===== board (snug, tightly packed) =====
let dl4w = 235*PK, dl4h = 114*PK
let backW = 4*dl4w + 3*GAP
let pad: CGFloat = 26
let bw = backW + 2*pad
let bx = (W - bw)/2, by: CGFloat = 150, bh: CGFloat = 430
let frontEdge = by + 360
fillRR(RR(bx, by, bw, bh), 16, hexCG("17191a")); strokeRR(RR(bx, by, bw, bh), 16, hexCG("3a3f3b"), 2)
fillRR(RR(bx+10, by+10, bw-20, 178), 12, hexCG("1d2620"))
ltext("BACK RISER — 4× DL4 MkII (driven over USB-MIDI by the Midi Fighter)", x: bx+22, top: by+26, size: 12.5, "7fae8c", bold: true)

let innerLeft = bx + pad
let dl4cy = by + 48 + dl4h/2
var dx = innerLeft + dl4w/2
for i in 0..<4 {
    pedalC(i==3 ? "dl4-25th.png" : "dl4.png", cx: dx, cy: dl4cy, fw: 235, fh: 114,
           label: i==3 ? "DL4 D (25th)" : "DL4 \(["A","B","C"][i])", num: i+2)
    dx += dl4w + GAP
}

struct FP { let file: String; let label: String; let fw: CGFloat; let fh: CGFloat; let num: Int?; let sub: String; let acc: String }
let front: [FP] = [
    FP(file:"tu3w.png", label:"TU-3W", fw:73, fh:129, num:1, sub:"tuner", acc:"9fb0a5"),
    FP(file:"dookie.png", label:"Dookie", fw:64, fh:111, num:6, sub:"drive", acc:"5bbf73"),
    FP(file:"ge7.png", label:"GE-7", fw:73, fh:129, num:7, sub:"EQ", acc:"5bbf73"),
    FP(file:"pitchfork.png", label:"Pitch Fork", fw:70, fh:92, num:8, sub:"", acc:"5bbf73"),
    FP(file:"ph2.png", label:"PH-2", fw:73, fh:129, num:9, sub:"phaser", acc:"5bbf73"),
    FP(file:"de7.png", label:"DE7", fw:70, fh:125, num:10, sub:"delay", acc:"5bbf73"),
    FP(file:"dd5.png", label:"DD-5", fw:73, fh:129, num:11, sub:"delay", acc:"5bbf73"),
    FP(file:"rv3.png", label:"RV-3", fw:73, fh:129, num:12, sub:"reverb", acc:"5bbf73"),
    FP(file:"volumex.png", label:"Volume X", fw:70, fh:100, num:nil, sub:"exp", acc:"d98a5b"),
    FP(file:"redremote.png", label:"Red Remote", fw:64, fh:64, num:nil, sub:"tap", acc:"d98a5b"),
]
let frontW = front.reduce(0) { $0 + $1.fw*PK } + CGFloat(front.count-1)*GAP
var cursor = bx + bw/2 - frontW/2
for fp in front {
    let w = fp.fw*PK; let cx = cursor + w/2
    pedalB(fp.file, cx: cx, bottom: frontEdge, fw: fp.fw, fh: fp.fh, label: fp.label, num: fp.num, sub: fp.sub, accent: fp.acc)
    cursor += w + GAP
}

arrow(bx-24, frontEdge-46, bx+6, frontEdge-46); ltext("Guitar in", x: bx-28, top: frontEdge-82, size: 12, "5bbf73", bold: true)
arrow(bx+bw-6, dl4cy, bx+bw+28, dl4cy, "5bbf73"); ltext("out →", x: bx+bw-2, top: dl4cy-34, size: 12, "5bbf73", bold: true)
ltext("signal:  guitar → 1 tuner → 2-5 DL4 A-D → 6 drive → 7 EQ → 8 pitch → 9 phaser → 10-12 delays + reverb → out", x: bx+18, top: by+bh-24, size: 12, "c8d2cc")

// ===== CIOKS DC7 underneath =====
let cy0 = by + bh + 22
fillRR(RR(bx, cy0, bw, 46), 8, hexCG("141414")); strokeRR(RR(bx, cy0, bw, 46), 8, hexCG("555555"), 1.5)
ltext("CIOKS DC7 — mounted underneath · 7 isolated outlets @ 9V / 660 mA", x: bx+18, top: cy0+15, size: 13.5, "e0c08a", bold: true)
ltext("POWER PLAN:", x: bx, top: cy0+72, size: 13, "e8efe9", bold: true)
let plan = [
    "Out 1-4 → DL4 A / B / C / D   (one isolated 660 mA outlet each — clears the DL4's 500 mA)",
    "Out 5   → DD-5 + RV-3 + Pitch Fork   (digital, daisy-chained ~230 mA)",
    "Out 6   → Dookie + GE-7 + PH-2 + DE7   (analog, daisy-chained ~70 mA)",
    "Out 7   → TU-3W tuner          Volume X & Red Remote: passive (no power)",
]
for (i, line) in plan.enumerated() { ltext(line, x: bx+6, top: cy0+98 + CGFloat(i)*23, size: 12, "b9c3bc") }

// ===== off-board =====
let oy = cy0 + 232
ctx.setStrokeColor(hexCG("333333")); ctx.setLineWidth(1); ctx.move(to: P(40, oy-14)); ctx.addLine(to: P(W-40, oy-14)); ctx.strokePath()
ltext("OFF-BOARD", x: 54, top: oy, size: 15, "9fb0a5", bold: true)
devCard("mf64.png", cx: 175, top: oy+30, w: 180, h: 120, label: "Midi Fighter 64")
devCard("macbook.png", cx: 490, top: oy+30, w: 210, h: 120, label: "MacBook · Ableton + DL4 Conductor")
devCard("apollo.png", cx: 830, top: oy+32, w: 220, h: 115, label: "Apollo Twin")
devCard("krk.png", cx: 1065, top: oy+22, w: 95, h: 135, label: "KRK 8 L", accent: "d98a5b")
devCard("krk.png", cx: 1180, top: oy+22, w: 95, h: 135, label: "KRK 8 R", accent: "d98a5b")
arrow(268, oy+90, 382, oy+90, "5aa0e0"); ltext("USB", x: 305, top: oy+72, size: 11, "c8d2cc")
arrow(598, oy+90, 718, oy+90, "5bbf73", dashed: true); ltext("Thunderbolt", x: 612, top: oy+72, size: 11, "9fb0a5")
arrow(942, oy+86, 1015, oy+86, "d98a5b"); arrow(942, oy+86, 1130, oy+86, "d98a5b")
ltext("board out → Apollo;   USB: 4× DL4 + Midi Fighter → MacBook;   Apollo → 2× KRK Rokit 8", x: 175, top: oy+182, size: 12, "9fb0a5")

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)  \(Int(W*scale))x\(Int(H*scale))")
