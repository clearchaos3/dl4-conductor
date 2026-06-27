// Renders the rig as a top-down PEDALBOARD: background-removed pedal cutouts laid directly
// on a board surface (no cards), packed tight and to real size, with the CIOKS DC7 power
// plan underneath and off-board gear below. Cutouts from docs/assets/cut/ (Vision), off-board
// cards from docs/assets/trim/. Usage: swift tools/render-pedalboard.swift out.png
import AppKit
import CoreGraphics

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "pedalboard.png"
let cutDir = "docs/assets/cut", trimDir = "docs/assets/trim"
let W: CGFloat = 1320, H: CGFloat = 1180, scale: CGFloat = 2
let PK: CGFloat = 1.15, GAP: CGFloat = 9

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
    let ang = atan2(-(y2-y1), x2-x1), L: CGFloat = 12, tip = P(x2,y2)
    ctx.move(to: tip); ctx.addLine(to: CGPoint(x: tip.x+cos(ang + .pi-0.45)*L, y: tip.y+sin(ang + .pi-0.45)*L))
    ctx.addLine(to: CGPoint(x: tip.x+cos(ang + .pi+0.45)*L, y: tip.y+sin(ang + .pi+0.45)*L)); ctx.closePath(); ctx.setFillColor(hexCG(hex)); ctx.fillPath() }
func badge(_ n: Int, _ x: CGFloat, _ y: CGFloat) {
    let r = CGRect(x: x-11, y: (H-y)-11, width: 22, height: 22); ctx.addEllipse(in: r); ctx.setFillColor(hexCG("0d0f0e",0.92)); ctx.fillPath()
    ctx.addEllipse(in: r); ctx.setStrokeColor(hexCG("7CF08A")); ctx.setLineWidth(1.8); ctx.strokePath(); text("\(n)", cx: x, top: y-7, size: 12, "7CF08A", bold: true)
}
func imgSize(_ path: String) -> CGSize? { NSImage(contentsOfFile: path).flatMap { $0.size.width > 0 ? $0.size : nil } }

/// Place a background-removed cutout directly on the board, scaled so its width = footprint × PK.
/// Bottom-aligned to `bottom` (the front/footswitch edge). Returns its drawn width.
@discardableResult
func pedal(_ file: String, cx: CGFloat, bottom: CGFloat, fw: CGFloat, label: String, num: Int? = nil, sub: String = "") -> CGFloat {
    let path = "\(cutDir)/\(file)"
    guard let img = NSImage(contentsOfFile: path), img.size.width > 0 else { return fw*PK }
    let w = fw*PK, h = w * img.size.height/img.size.width, top = bottom - h
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 2, height: -4), blur: 9, color: hexCG("000000", 0.55))
    img.draw(in: RR(cx-w/2, top, w, h), from: .zero, operation: .sourceOver, fraction: 1); ctx.restoreGState()
    if let n = num { badge(n, cx-w/2+10, top+8) }
    text(label, cx: cx, top: bottom+6, size: 11.5, "dfe6e0", bold: true)
    if !sub.isEmpty { text(sub, cx: cx, top: bottom+22, size: 10, "8a978d") }
    return w
}

// ===== background + title =====
ctx.setFillColor(hexCG("0d0f0e")); ctx.fill(CGRect(x:0,y:0,width:W,height:H))
ltext("DL4 ×4 Rig — Ideal Pedalboard Layout", x: 54, top: 26, size: 27, "7CF08A", bold: true)
ltext("loopers on the back rail (Midi-Fighter-driven) · foot pedals up front · numbers = signal order", x: 56, top: 61, size: 13.5, "9fb0a5")

// ===== board surface (Pedaltrain-style) =====
let dl4w = 235*PK
let backW = 4*dl4w + 3*GAP
let pad: CGFloat = 30
let bw = backW + 2*pad
let bx = (W - bw)/2, by: CGFloat = 130, bh: CGFloat = 400
fillRR(RR(bx, by, bw, bh), 14, hexCG("1a1a1a")); strokeRR(RR(bx, by, bw, bh), 14, hexCG("3c3c3c"), 3)
ctx.saveGState(); ctx.addPath(CGPath(roundedRect: RR(bx, by, bw, bh), cornerWidth: 14, cornerHeight: 14, transform: nil)); ctx.clip()
ctx.setStrokeColor(hexCG("000000", 0.5)); ctx.setLineWidth(1)   // rail grooves
var gy = by + 16; while gy < by + bh { ctx.move(to: P(bx, gy)); ctx.addLine(to: P(bx+bw, gy)); gy += 22 }; ctx.strokePath()
ctx.restoreGState()

// back rail: 4 DL4s, bottom-aligned
let backBottom = by + 188
var dx = bx + pad
for i in 0..<4 {
    let f = i==3 ? "dl4-25th.png" : "dl4.png"
    let w = pedal(f, cx: dx + dl4w/2, bottom: backBottom, fw: 235, label: i==3 ? "DL4 D · 25th" : "DL4 \(["A","B","C"][i])", num: i+2)
    dx += w + GAP
}

// front row: cutouts bottom-aligned at the front edge
let frontEdge = by + bh - 40
struct FP { let file: String; let label: String; let fw: CGFloat; let num: Int?; let sub: String }
let front: [FP] = [
    FP(file:"tu3w.png", label:"TU-3W", fw:73, num:1, sub:"tuner"),
    FP(file:"dookie.png", label:"Dookie", fw:64, num:6, sub:"drive"),
    FP(file:"ge7.png", label:"GE-7", fw:73, num:7, sub:"EQ"),
    FP(file:"pitchfork.png", label:"Pitch Fork", fw:70, num:8, sub:"pitch"),
    FP(file:"ph2.png", label:"PH-2", fw:73, num:9, sub:"phaser"),
    FP(file:"de7.png", label:"DE7", fw:70, num:10, sub:"delay"),
    FP(file:"dd5.png", label:"DD-5", fw:73, num:11, sub:"delay"),
    FP(file:"rv3.png", label:"RV-3", fw:73, num:12, sub:"reverb"),
    FP(file:"volumex.png", label:"Volume X", fw:70, num:nil, sub:"exp"),
    FP(file:"redremote.png", label:"Red Rmt", fw:64, num:nil, sub:"tap"),
]
let frontW = front.reduce(0) { $0 + $1.fw*PK } + CGFloat(front.count-1)*GAP
var fx = bx + bw/2 - frontW/2
for fp in front { let w = pedal(fp.file, cx: fx + fp.fw*PK/2, bottom: frontEdge, fw: fp.fw, label: fp.label, num: fp.num, sub: fp.sub); fx += w + GAP }

arrow(bx-22, frontEdge-46, bx+8, frontEdge-46); ltext("Guitar in", x: bx-26, top: frontEdge-80, size: 12, "5bbf73", bold: true)
arrow(bx+bw-8, backBottom-40, bx+bw+26, backBottom-40, "5bbf73"); ltext("out →", x: bx+bw-4, top: backBottom-74, size: 12, "5bbf73", bold: true)

// ===== CIOKS DC7 + power plan =====
ltext("signal:  guitar → 1 tuner → 2-5 DL4 A-D → 6 drive → 7 EQ → 8 pitch → 9 phaser → 10-12 delays + reverb → out", x: bx+4, top: by+bh+14, size: 12, "c8d2cc")
let cy0 = by + bh + 42
fillRR(RR(bx, cy0, bw, 44), 8, hexCG("141414")); strokeRR(RR(bx, cy0, bw, 44), 8, hexCG("555555"), 1.5)
ltext("CIOKS DC7 — mounted underneath · 7 isolated outlets @ 9V / 660 mA", x: bx+16, top: cy0+14, size: 13, "e0c08a", bold: true)
ltext("POWER PLAN:", x: bx, top: cy0+66, size: 12.5, "e8efe9", bold: true)
let plan = [
    "Out 1-4 → DL4 A / B / C / D  (one isolated 660 mA outlet each — clears the DL4's 500 mA)",
    "Out 5 → DD-5 + RV-3 + Pitch Fork  (digital, daisy-chained ~230 mA)      Out 6 → Dookie + GE-7 + PH-2 + DE7  (analog, ~70 mA)",
    "Out 7 → TU-3W tuner        Volume X & Red Remote: passive (no power)",
]
for (i, line) in plan.enumerated() { ltext(line, x: bx+6, top: cy0+90 + CGFloat(i)*22, size: 11.5, "b9c3bc") }

// ===== off-board =====
let oy = cy0 + 196
ctx.setStrokeColor(hexCG("333333")); ctx.setLineWidth(1); ctx.move(to: P(40, oy-14)); ctx.addLine(to: P(W-40, oy-14)); ctx.strokePath()
ltext("OFF-BOARD", x: 54, top: oy, size: 15, "9fb0a5", bold: true)
func dev(_ file: String, cx: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat, label: String, cut: Bool) {
    let r = RR(cx-w/2, top, w, h)
    if cut, let img = NSImage(contentsOfFile: "\(cutDir)/\(file)") {
        let s = min((w)/img.size.width, (h)/img.size.height); let dw = img.size.width*s, dh = img.size.height*s
        ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 2, height: -3), blur: 7, color: hexCG("000000",0.5))
        img.draw(in: CGRect(x: r.midX-dw/2, y: r.midY-dh/2, width: dw, height: dh), from: .zero, operation: .sourceOver, fraction: 1); ctx.restoreGState()
    } else {
        fillRR(r, 9, hexCG("f4f5f3")); strokeRR(r, 9, hexCG("5aa0e0"), 2)
        if let img = NSImage(contentsOfFile: "\(trimDir)/\(file)") { let c = r.insetBy(dx: 7, dy: 7); let s = min(c.width/img.size.width, c.height/img.size.height); let dw=img.size.width*s, dh=img.size.height*s; img.draw(in: CGRect(x:c.midX-dw/2,y:c.midY-dh/2,width:dw,height:dh), from:.zero, operation:.sourceOver, fraction:1) }
    }
    text(label, cx: cx, top: top+h+5, size: 11.5, "dfe6e0", bold: true)
}
dev("mf64.png", cx: 175, top: oy+30, w: 180, h: 120, label: "Midi Fighter 64", cut: false)
dev("macbook.png", cx: 490, top: oy+30, w: 210, h: 120, label: "MacBook · Ableton + DL4 Conductor", cut: false)
dev("apollo.png", cx: 815, top: oy+30, w: 200, h: 115, label: "Apollo Twin", cut: false)
dev("krk.png", cx: 1040, top: oy+18, w: 95, h: 145, label: "KRK 8 L", cut: true)
dev("krk.png", cx: 1160, top: oy+18, w: 95, h: 145, label: "KRK 8 R", cut: true)
arrow(268, oy+88, 380, oy+88, "5aa0e0"); ltext("USB", x: 305, top: oy+70, size: 11, "c8d2cc")
arrow(600, oy+88, 710, oy+88, "5bbf73", dashed: true); ltext("Thunderbolt", x: 612, top: oy+70, size: 11, "9fb0a5")
arrow(920, oy+84, 990, oy+84, "d98a5b"); arrow(920, oy+84, 1110, oy+84, "d98a5b")
ltext("board out → Apollo;   USB: 4× DL4 + Midi Fighter → MacBook;   Apollo → 2× KRK Rokit 8", x: 175, top: oy+182, size: 12, "9fb0a5")

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)  \(Int(W*scale))x\(Int(H*scale))")
