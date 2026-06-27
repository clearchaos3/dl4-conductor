// Renders the rig as a top-down PEDALBOARD layout (ideal formation) with real-size pedals,
// the CIOKS DC7 power plan underneath, and the off-board computer/interface/monitors.
// Reads trimmed photos from docs/assets/trim/. Usage: swift tools/render-pedalboard.swift out.png
import AppKit
import CoreGraphics

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "pedalboard.png"
let dir = "docs/assets/trim"
let W: CGFloat = 1520, H: CGFloat = 1420, scale: CGFloat = 2
let PK: CGFloat = 1.15

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
    let r = CGRect(x: x-13, y: (H-y)-13, width: 26, height: 26); ctx.addEllipse(in: r); ctx.setFillColor(hexCG("0d0f0e")); ctx.fillPath()
    ctx.addEllipse(in: r); ctx.setStrokeColor(hexCG("7CF08A")); ctx.setLineWidth(2); ctx.strokePath()
    text("\(n)", cx: x, top: y-9, size: 14, "7CF08A", bold: true)
}

// pedal placed by its FRONT edge (bottom). returns (left,right,topX center unchanged)
func pedalB(_ file: String, cx: CGFloat, bottom: CGFloat, fw: CGFloat, fh: CGFloat, label: String, num: Int? = nil, sub: String = "", accent: String = "7CF08A") {
    let w = fw*PK, h = fh*PK, top = bottom - h, r = RR(cx-w/2, top, w, h)
    fillRR(r, 9, hexCG("f4f5f3")); strokeRR(r, 9, hexCG(accent), 2.2)
    drawImage(file, in: r.insetBy(dx: 7, dy: 7))
    text(label, cx: cx, top: bottom+6, size: 12.5, "e8efe9", bold: true)
    if !sub.isEmpty { text(sub, cx: cx, top: bottom+24, size: 10.5, "9fb0a5") }
    if let n = num { badge(n, cx - w/2 + 2, top + 2) }
}
func pedalC(_ file: String, cx: CGFloat, cy: CGFloat, fw: CGFloat, fh: CGFloat, label: String, num: Int? = nil, accent: String = "7CF08A") {
    pedalB(file, cx: cx, bottom: cy + fh*PK/2, fw: fw, fh: fh, label: label, num: num, accent: accent)
}
func devCard(_ file: String, cx: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat, label: String, accent: String = "5aa0e0") {
    let r = RR(cx-w/2, top, w, h); fillRR(r, 10, hexCG("f4f5f3")); strokeRR(r, 10, hexCG(accent), 2.2)
    drawImage(file, in: r.insetBy(dx: 8, dy: 8)); text(label, cx: cx, top: top+h+6, size: 12, "e8efe9", bold: true)
}

// ===== background + title =====
ctx.setFillColor(hexCG("0d0f0e")); ctx.fill(CGRect(x:0,y:0,width:W,height:H))
ltext("DL4 ×4 Rig — Ideal Pedalboard Layout", x: 56, top: 30, size: 28, "7CF08A", bold: true)
ltext("loopers on the back riser (driven by the Midi Fighter) · foot pedals up front · numbers = signal order", x: 58, top: 66, size: 14, "9fb0a5")

// ===== board surface =====
let bx: CGFloat = 70, by: CGFloat = 150, bw: CGFloat = 1380, bh: CGFloat = 700
fillRR(RR(bx, by, bw, bh), 16, hexCG("17191a")); strokeRR(RR(bx, by, bw, bh), 16, hexCG("3a3f3b"), 2)
fillRR(RR(bx+12, by+12, bw-24, 224), 12, hexCG("1d2620"))   // back riser
ltext("BACK RISER — 4× DL4 MkII loopers (controlled over USB-MIDI by the Midi Fighter)", x: bx+28, top: by+30, size: 13, "7fae8c", bold: true)
ltext("FRONT ROW — tuner, drives & time FX you stomp, expression + tap", x: bx+28, top: by+392, size: 13, "9fb0a5", bold: true)

// back riser: 4 DL4s
let dl4cx: [CGFloat] = [310, 610, 910, 1210]
for (i, cx) in dl4cx.enumerated() {
    pedalC(i==3 ? "dl4-25th.png" : "dl4.png", cx: cx, cy: by+128, fw: 235, fh: 114,
           label: i==3 ? "DL4 D (25th)" : "DL4 \(["A","B","C"][i])", num: i+2)
}

// front row: bottom-aligned at the front edge
let frontEdge = by + bh - 80
struct FP { let file: String; let label: String; let fw: CGFloat; let fh: CGFloat; let num: Int?; let sub: String; let acc: String }
let front: [FP] = [
    FP(file:"tu3w.png", label:"TU-3W", fw:73, fh:129, num:1, sub:"tuner", acc:"9fb0a5"),
    FP(file:"dookie.png", label:"Dookie Drive", fw:64, fh:111, num:6, sub:"", acc:"5bbf73"),
    FP(file:"ge7.png", label:"GE-7 EQ", fw:73, fh:129, num:7, sub:"", acc:"5bbf73"),
    FP(file:"pitchfork.png", label:"Pitch Fork", fw:70, fh:92, num:8, sub:"", acc:"5bbf73"),
    FP(file:"ph2.png", label:"PH-2", fw:73, fh:129, num:9, sub:"", acc:"5bbf73"),
    FP(file:"de7.png", label:"DE7", fw:70, fh:125, num:10, sub:"", acc:"5bbf73"),
    FP(file:"dd5.png", label:"DD-5", fw:73, fh:129, num:11, sub:"", acc:"5bbf73"),
    FP(file:"rv3.png", label:"RV-3", fw:73, fh:129, num:12, sub:"", acc:"5bbf73"),
    FP(file:"volumex.png", label:"Volume X", fw:70, fh:100, num:nil, sub:"exp → Pitch Fork", acc:"d98a5b"),
    FP(file:"redremote.png", label:"Red Remote", fw:64, fh:64, num:nil, sub:"tap → DD-5", acc:"d98a5b"),
]
let totalW = front.reduce(0) { $0 + $1.fw*PK }
let gap = (bw - 80 - totalW) / CGFloat(front.count - 1)
var cursor = bx + 40
for fp in front {
    let w = fp.fw*PK; let cx = cursor + w/2
    pedalB(fp.file, cx: cx, bottom: frontEdge, fw: fp.fw, fh: fp.fh, label: fp.label, num: fp.num, sub: fp.sub, accent: fp.acc)
    cursor += w + gap
}

// IN / OUT jacks
arrow(bx-26, frontEdge-50, bx+8, frontEdge-50); ltext("Guitar in", x: bx-30, top: frontEdge-86, size: 12, "5bbf73", bold: true)
arrow(bx+bw-8, by+128, bx+bw+30, by+128, "5bbf73"); ltext("out →", x: bx+bw-4, top: by+92, size: 12, "5bbf73", bold: true)
ltext("signal: guitar → 1 tuner → 2-5 DL4 A-D → 6 drive → 7 EQ → 8 pitch → 9 phaser → 10-12 delays + reverb → out", x: bx+20, top: by+bh-26, size: 12, "c8d2cc")

// ===== CIOKS DC7 underneath =====
let cy0 = by + bh + 24
fillRR(RR(bx, cy0, bw, 50), 8, hexCG("141414")); strokeRR(RR(bx, cy0, bw, 50), 8, hexCG("555555"), 1.5)
ltext("CIOKS DC7 — mounted underneath · 7 isolated outlets @ 9V / 660 mA", x: bx+20, top: cy0+17, size: 14, "e0c08a", bold: true)

ltext("POWER PLAN (7 outlets):", x: bx, top: cy0+78, size: 13, "e8efe9", bold: true)
let plan = [
    "Outlet 1-4  →  DL4 MkII A / B / C / D     (one isolated 660 mA outlet each; clears the DL4's 500 mA)",
    "Outlet 5    →  DD-5 + RV-3 + Pitch Fork   (digital — daisy-chained, ~230 mA total)",
    "Outlet 6    →  Dookie + GE-7 + PH-2 + DE7 (analog — daisy-chained, ~70 mA total)",
    "Outlet 7    →  TU-3W tuner",
    "(no power)  →  Volume X & Red Remote are passive",
]
for (i, line) in plan.enumerated() { ltext(line, x: bx+8, top: cy0+104 + CGFloat(i)*24, size: 12.5, i < 1 ? "7CF08A" : "b9c3bc") }

// ===== off-board: computer / interface / monitors =====
let oy: CGFloat = cy0 + 250
ctx.setStrokeColor(hexCG("333333")); ctx.setLineWidth(1); ctx.move(to: P(40, oy-16)); ctx.addLine(to: P(W-40, oy-16)); ctx.strokePath()
ltext("OFF-BOARD", x: 56, top: oy, size: 16, "9fb0a5", bold: true)
devCard("mf64.png", cx: 200, top: oy+34, w: 200, h: 135, label: "Midi Fighter 64")
devCard("macbook.png", cx: 560, top: oy+34, w: 230, h: 135, label: "MacBook (Ableton + DL4 Conductor)")
devCard("apollo.png", cx: 950, top: oy+34, w: 250, h: 130, label: "Apollo Twin")
devCard("krk.png", cx: 1210, top: oy+24, w: 105, h: 150, label: "KRK 8 L", accent: "d98a5b")
devCard("krk.png", cx: 1340, top: oy+24, w: 105, h: 150, label: "KRK 8 R", accent: "d98a5b")
arrow(300, oy+100, 448, oy+100, "5aa0e0"); ltext("USB", x: 350, top: oy+82, size: 11, "c8d2cc")
arrow(675, oy+100, 828, oy+100, "5bbf73", dashed: true); ltext("Thunderbolt", x: 690, top: oy+82, size: 11, "9fb0a5")
arrow(1075, oy+92, 1155, oy+92, "d98a5b"); arrow(1075, oy+92, 1285, oy+92, "d98a5b")
ltext("board out → Apollo;   USB: 4× DL4 + Midi Fighter → MacBook;   Apollo → 2× KRK Rokit 8", x: 200, top: oy+196, size: 12, "9fb0a5")

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)  \(Int(W*scale))x\(Int(H*scale))")
