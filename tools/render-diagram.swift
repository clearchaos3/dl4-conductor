// Renders the rig signal-chain diagram as a PNG using flat-icon illustrations of the gear.
// Pure CoreGraphics + AppKit text (no external assets). Usage: swift tools/render-diagram.swift out.png
import AppKit
import CoreGraphics

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "signal-chain.png"
let W: CGFloat = 1700, H: CGFloat = 1480
let scale: CGFloat = 2

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W*scale), pixelsHigh: Int(H*scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext

// ---- helpers (top-down coordinates: y grows downward) ----
func hexCG(_ h: String, _ a: CGFloat = 1) -> CGColor {
    var s = h; if s.hasPrefix("#") { s.removeFirst() }
    let v = UInt32(s, radix: 16) ?? 0
    return CGColor(srgbRed: CGFloat((v>>16)&0xff)/255, green: CGFloat((v>>8)&0xff)/255, blue: CGFloat(v&0xff)/255, alpha: a)
}
func nsCol(_ h: String) -> NSColor {
    var s = h; if s.hasPrefix("#") { s.removeFirst() }
    let v = UInt32(s, radix: 16) ?? 0
    return NSColor(srgbRed: CGFloat((v>>16)&0xff)/255, green: CGFloat((v>>8)&0xff)/255, blue: CGFloat(v&0xff)/255, alpha: 1)
}
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: H - y) }            // point convert
func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: H - y - h, width: w, height: h) }

func fillRR(_ r: CGRect, _ rad: CGFloat, _ c: CGColor) {
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.setFillColor(c); ctx.fillPath()
}
func strokeRR(_ r: CGRect, _ rad: CGFloat, _ c: CGColor, _ lw: CGFloat) {
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.setStrokeColor(c); ctx.setLineWidth(lw); ctx.strokePath()
}
func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ rad: CGFloat, fill: CGColor, stroke: CGColor, lw: CGFloat = 2) {
    let r = R(x, y, w, h); fillRR(r, rad, fill); strokeRR(r, rad, stroke, lw)
}
func circle(_ cx: CGFloat, _ cy: CGFloat, _ rad: CGFloat, fill: CGColor, stroke: CGColor? = nil, lw: CGFloat = 1.5) {
    let r = CGRect(x: cx-rad, y: (H-cy)-rad, width: rad*2, height: rad*2)
    ctx.addEllipse(in: r); ctx.setFillColor(fill); ctx.fillPath()
    if let s = stroke { ctx.addEllipse(in: r); ctx.setStrokeColor(s); ctx.setLineWidth(lw); ctx.strokePath() }
}
func text(_ s: String, cx: CGFloat, top: CGFloat, size: CGFloat, _ hex: String = "e8efe9", bold: Bool = false) {
    let f = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    let a = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: nsCol(hex)])
    let sz = a.size()
    a.draw(at: NSPoint(x: cx - sz.width/2, y: (H - top) - sz.height))
}
func ltext(_ s: String, x: CGFloat, top: CGFloat, size: CGFloat, _ hex: String = "9fb0a5", bold: Bool = false) {
    let f = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    let a = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: nsCol(hex)])
    a.draw(at: NSPoint(x: x, y: (H - top) - a.size().height))
}
func arrow(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ hex: String = "c8d2cc", dashed: Bool = false, lw: CGFloat = 2.2) {
    ctx.saveGState()
    ctx.setStrokeColor(hexCG(hex)); ctx.setLineWidth(lw)
    if dashed { ctx.setLineDash(phase: 0, lengths: [7, 5]) }
    ctx.move(to: P(x1, y1)); ctx.addLine(to: P(x2, y2)); ctx.strokePath()
    ctx.restoreGState()
    // arrowhead
    let ang = atan2(-(y2 - y1), x2 - x1) // screen-y inverted
    let a1 = ang + .pi - 0.45, a2 = ang + .pi + 0.45, len: CGFloat = 13
    let tip = P(x2, y2)
    ctx.move(to: tip)
    ctx.addLine(to: CGPoint(x: tip.x + cos(a1)*len, y: tip.y + sin(a1)*len))
    ctx.addLine(to: CGPoint(x: tip.x + cos(a2)*len, y: tip.y + sin(a2)*len))
    ctx.closePath(); ctx.setFillColor(hexCG(hex)); ctx.fillPath()
}

// ---- gear icons ----
func pedal(cx: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat, color: String, knobs: Int, name: String, knobHex: String = "2b2b2b") {
    let x = cx - w/2
    box(x, top, w, h, 10, fill: hexCG(color), stroke: hexCG("000000", 0.5), lw: 1.5)
    box(x+8, top+10, w-16, h*0.34, 6, fill: hexCG("000000", 0.18), stroke: hexCG("000000", 0.12), lw: 1) // control strip
    let n = max(knobs, 1)
    for i in 0..<n {
        let kx = x + w*(CGFloat(i)+0.5)/CGFloat(n)
        circle(kx, top+10+h*0.17, 7, fill: hexCG(knobHex), stroke: hexCG("d8d8d8", 0.7), lw: 1.2)
    }
    circle(cx, top+h-24, 15, fill: hexCG("cfcfcf"), stroke: hexCG("777777"), lw: 1.5) // footswitch
    text(name, cx: cx, top: top+h+6, size: 12.5, "c8d2cc", bold: true)
}
func dl4(cx: CGFloat, top: CGFloat, name: String) {
    let w: CGFloat = 168, h: CGFloat = 100, x = cx - w/2
    box(x, top, w, h, 12, fill: hexCG("2f7d3f"), stroke: hexCG("7CF08A"), lw: 2.5)
    for i in 0..<6 { circle(x + w*(CGFloat(i)+0.5)/6, top+28, 8, fill: hexCG("12351c"), stroke: hexCG("bfeccb"), lw: 1.2) }
    for i in 0..<4 { circle(x + w*(CGFloat(i)+0.5)/4, top+h-22, 12, fill: hexCG("cfcfcf"), stroke: hexCG("5aa05f"), lw: 1.5) }
    text(name, cx: cx, top: top+h+7, size: 13, "e8efe9", bold: true)
}
func laptop(cx: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat, label: String) {
    let x = cx - w/2, sh = h*0.7
    box(x, top, w, sh, 10, fill: hexCG("11131a"), stroke: hexCG("888888"), lw: 2)      // screen
    box(x+10, top+10, w-20, sh-20, 6, fill: hexCG("0e1622"), stroke: hexCG("2b3a4a"), lw: 1)
    // base
    let baseY = top + sh + 4
    fillRR(R(x-14, baseY, w+28, 14), 6, hexCG("2a2e36")); strokeRR(R(x-14, baseY, w+28, 14), 6, hexCG("888888"), 1.5)
    text(label, cx: cx, top: top + sh*0.42, size: 16, "9fb0a5", bold: true)
}
func interfaceBox(cx: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat) {
    let x = cx - w/2
    box(x, top, w, h, 12, fill: hexCG("16211b"), stroke: hexCG("5bbf73"), lw: 2)
    circle(x + w - 46, top + h/2, 26, fill: hexCG("0e1712"), stroke: hexCG("9fe0ad"), lw: 2)   // big knob
    circle(x + w - 46, top + h/2, 4, fill: hexCG("9fe0ad"))
    for i in 0..<2 { box(x+20, top+18+CGFloat(i)*26, 110, 12, 4, fill: hexCG("0e1712"), stroke: hexCG("3c6b48"), lw: 1) } // meters
    text("APOLLO TWIN", cx: cx-24, top: top+h-30, size: 14, "e8efe9", bold: true)
}
func grid64(cx: CGFloat, top: CGFloat, size: CGFloat) {
    let x = cx - size/2
    box(x, top, size, size, 12, fill: hexCG("15212b"), stroke: hexCG("5aa0e0"), lw: 2)
    let pad = (size - 18) / 8
    let accent = [(0,0),(1,0),(0,1),(7,7),(6,7),(7,6)]   // a few lit corners
    for r in 0..<8 { for c in 0..<8 {
        let px = x + 9 + CGFloat(c)*pad, py = top + 9 + CGFloat(r)*pad
        let lit = accent.contains { $0.0 == c && $0.1 == r }
        let topLeft = (c < 4 && r < 4)
        let fill = lit ? hexCG("e0a94a") : (topLeft ? hexCG("2a6b3a") : hexCG("223240"))
        let rr = R(px, py, pad-5, pad-5); fillRR(rr, 3, fill); strokeRR(rr, 3, hexCG("000000", 0.3), 0.8)
    }}
}
func hub(cx: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat) {
    let x = cx - w/2
    box(x, top, w, h, 9, fill: hexCG("15212b"), stroke: hexCG("5aa0e0"), lw: 2)
    for i in 0..<4 { box(x+18+CGFloat(i)*((w-36)/4), top+h-16, (w-36)/4-8, 9, 2, fill: hexCG("0c1118"), stroke: hexCG("3a5876"), lw: 1) }
    text("POWERED USB HUB", cx: cx, top: top+10, size: 13, "e8efe9", bold: true)
}
func amp(cx: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat) {
    let x = cx - w/2
    box(x, top, w, h, 12, fill: hexCG("241a16"), stroke: hexCG("d98a5b"), lw: 2)
    let g = R(x+18, top+34, w-36, h-50); fillRR(g, 6, hexCG("1a120e"))
    ctx.saveGState(); ctx.addPath(CGPath(roundedRect: g, cornerWidth: 6, cornerHeight: 6, transform: nil)); ctx.clip()
    ctx.setStrokeColor(hexCG("3a2a20")); ctx.setLineWidth(1)
    var gx = g.minX; while gx < g.maxX { ctx.move(to: CGPoint(x: gx, y: g.minY)); ctx.addLine(to: CGPoint(x: gx, y: g.maxY)); gx += 6 }; ctx.strokePath()
    ctx.restoreGState()
    text("AMP / SPEAKERS", cx: cx, top: top+10, size: 13, "e8efe9", bold: true)
}
func guitar(cx: CGFloat, top: CGFloat) {
    // simple electric guitar
    circle(cx-6, top+58, 30, fill: hexCG("16211b"), stroke: hexCG("5bbf73"), lw: 2)
    circle(cx+18, top+50, 22, fill: hexCG("16211b"), stroke: hexCG("5bbf73"), lw: 2)
    fillRR(R(cx+30, top+18, 70, 12), 4, hexCG("3a2a1c")); strokeRR(R(cx+30, top+18, 70, 12), 4, hexCG("5bbf73"), 1.5) // neck
    fillRR(R(cx+96, top+10, 22, 22), 3, hexCG("3a2a1c")); strokeRR(R(cx+96, top+10, 22, 22), 3, hexCG("5bbf73"), 1.5) // head
    text("GUITAR", cx: cx+6, top: top+96, size: 12.5, "c8d2cc", bold: true)
}
func mic(cx: CGFloat, top: CGFloat) {
    box(cx-16, top, 32, 50, 16, fill: hexCG("1b1b1b"), stroke: hexCG("5bbf73"), lw: 2)        // capsule
    for i in 0..<3 { let yy = top+12+CGFloat(i)*10; ctx.setStrokeColor(hexCG("5bbf73",0.7)); ctx.setLineWidth(1.2); ctx.move(to: P(cx-12, yy)); ctx.addLine(to: P(cx+12, yy)); ctx.strokePath() }
    fillRR(R(cx-6, top+50, 12, 34), 3, hexCG("2a2a2a")); strokeRR(R(cx-6, top+50, 12, 34), 3, hexCG("5bbf73"), 1.2)  // handle
    text("MIC", cx: cx, top: top+92, size: 12.5, "c8d2cc", bold: true)
}
func treadle(cx: CGFloat, top: CGFloat, label: String) {
    let path = CGMutablePath()
    path.move(to: P(cx-30, top+40)); path.addLine(to: P(cx+30, top+16)); path.addLine(to: P(cx+30, top+44)); path.addLine(to: P(cx-30, top+44)); path.closeSubpath()
    ctx.addPath(path); ctx.setFillColor(hexCG("2b2b2b")); ctx.fillPath()
    ctx.addPath(path); ctx.setStrokeColor(hexCG("888888")); ctx.setLineWidth(1.5); ctx.strokePath()
    text(label, cx: cx, top: top+50, size: 11, "9fb0a5")
}
func redRemote(cx: CGFloat, top: CGFloat, label: String) {
    box(cx-26, top, 52, 46, 8, fill: hexCG("c0392b"), stroke: hexCG("7a241b"), lw: 1.5)
    circle(cx, top+24, 12, fill: hexCG("cfcfcf"), stroke: hexCG("7a241b"), lw: 1.5)
    text(label, cx: cx, top: top+50, size: 11, "9fb0a5")
}

// =================== BACKGROUND + TITLE ===================
ctx.setFillColor(hexCG("0d0f0e")); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
ltext("DL4 ×4  ·  Loop + Lofi-Beat Rig — Signal Chain", x: 56, top: 30, size: 28, "7CF08A", bold: true)

// legend
box(1300, 84, 360, 150, 10, fill: hexCG("11141a"), stroke: hexCG("444444"), lw: 1.5)
ltext("Legend", x: 1322, top: 100, size: 16, "e8efe9", bold: true)
arrow(1322, 142, 1372, 142, "5bbf73"); ltext("audio signal", x: 1388, top: 134, size: 13)
arrow(1322, 176, 1372, 176, "5aa0e0"); ltext("MIDI control", x: 1388, top: 168, size: 13)
arrow(1322, 210, 1372, 210, "e0a94a", dashed: true); ltext("MIDI clock (tempo)", x: 1388, top: 202, size: 13)

// =================== PANEL A: AUDIO ===================
ltext("AUDIO PATH   ·   DL4s record samples · FX tweak them live", x: 56, top: 92, size: 21, "9fb0a5", bold: true)

guitar(cx: 110, top: 150)
mic(cx: 110, top: 300)
pedal(cx: 300, top: 170, w: 96, h: 116, color: "1d1d1d", knobs: 1, name: "TU-3W tuner", knobHex: "111111")

let dl4xs: [CGFloat] = [470, 690, 910, 1130]
let dl4names = ["DL4 MkII A", "DL4 MkII B", "DL4 MkII C", "DL4 MkII D"]
for (i, x) in dl4xs.enumerated() { dl4(cx: x, top: 168, name: dl4names[i]) }

arrow(160, 196, 246, 210)                 // guitar -> tuner-ish (into DL4 A via tuner)
arrow(348, 210, 388, 214)                 // tuner -> DL4 A
ltext("1/4\"", x: 352, top: 186, size: 12, "c8d2cc")
arrow(150, 338, 388, 250)                 // mic -> DL4 A (XLR)
ltext("XLR (mic)", x: 200, top: 330, size: 12, "c8d2cc")
arrow(556, 218, 604, 218); arrow(776, 218, 824, 218); arrow(996, 218, 1044, 218)  // A->B->C->D
ltext("guitar + mic reach every DL4 → record a sample into any of the four", x: 380, top: 300, size: 13, "9fb0a5")

arrow(1130, 270, 1130, 326)               // DL4 D down
arrow(1130, 326, 250, 326, "c8d2cc")      // wrap left
arrow(250, 326, 250, 392, "c8d2cc")       // down into FX row

// FX row
let fx: [(CGFloat, String, String, Int)] = [
    (250, "Dookie Drive", "3fae54", 3), (430, "GE-7 EQ", "cfcfcf", 2), (610, "Pitch Fork", "efefef", 2),
    (790, "PH-2 Phaser", "7ec46a", 3), (970, "DE7 delay", "9a9a9a", 2), (1150, "DD-5 delay", "e6e6e6", 4), (1330, "RV-3 reverb", "ededed", 3)
]
for (cx, name, color, k) in fx { pedal(cx: cx, top: 396, w: 108, h: 120, color: color, knobs: k, name: name) }
for i in 0..<6 { arrow(fx[i].0+54, 452, fx[i+1].0-54, 452) }
treadle(cx: 610, top: 540, label: "Vol X → exp")
redRemote(cx: 1150, top: 540, label: "Red Remote → tap")

arrow(1384, 456, 1470, 456); arrow(1470, 456, 1470, 640, "c8d2cc"); arrow(1470, 640, 980, 640, "c8d2cc")  // RV3 -> Apollo

interfaceBox(cx: 820, top: 612, w: 320, h: 96)
arrow(820, 708, 820, 752)
amp(cx: 820, top: 756, w: 280, h: 96)
laptop(cx: 1320, top: 600, w: 230, h: 150, label: "MAC")
arrow(980, 650, 1206, 660, "c8d2cc", dashed: true); ltext("Thunderbolt", x: 1020, top: 628, size: 12, "9fb0a5")

// divider
ctx.setStrokeColor(hexCG("333333")); ctx.setLineWidth(1); ctx.move(to: P(40, 880)); ctx.addLine(to: P(1660, 880)); ctx.strokePath()

// =================== PANEL B: MIDI / USB ===================
ltext("MIDI / USB   ·   one Midi Fighter drives both Ableton drums and the DL4 loopers", x: 56, top: 912, size: 21, "9fb0a5", bold: true)

grid64(cx: 200, top: 960, size: 190)
ltext("MIDI FIGHTER 64", x: 120, top: 1160, size: 14, "e8efe9", bold: true)
ltext("finger-drum beat + DL4 pads", x: 120, top: 1182, size: 12, "9fb0a5")

laptop(cx: 640, top: 980, w: 250, h: 160, label: "MAC")
box(560, 1050, 300, 40, 8, fill: hexCG("16263a"), stroke: hexCG("5aa0e0"), lw: 1.5); text("ABLETON — drum loop · master clock", cx: 710, top: 1060, size: 12.5, "cfe0f2")
box(560, 1098, 300, 40, 8, fill: hexCG("16263a"), stroke: hexCG("5aa0e0"), lw: 1.5); text("DL4 CONDUCTOR — control · quantize", cx: 710, top: 1108, size: 12, "cfe0f2")

arrow(300, 1010, 512, 1050, "5aa0e0"); ltext("drum pads (~48)", x: 330, top: 1000, size: 12, "c8d2cc")
arrow(300, 1060, 552, 1118, "5aa0e0"); ltext("DL4 pads (16)", x: 330, top: 1110, size: 12, "c8d2cc")

hub(cx: 1080, top: 1150, w: 230, h: 60)
arrow(862, 1118, 970, 1170, "5aa0e0"); ltext("control + LEDs", x: 880, top: 1132, size: 12, "c8d2cc")
arrow(862, 1066, 985, 1168, "e0a94a", dashed: true); ltext("MIDI clock", x: 1000, top: 1066, size: 12, "e0a94a")

let bxs: [CGFloat] = [840, 990, 1140, 1290]
for (i, x) in bxs.enumerated() { box(x-58, 1290, 116, 56, 8, fill: hexCG("16291d"), stroke: hexCG("7CF08A"), lw: 2); text("DL4 \(["A","B","C","D"][i])", cx: x, top: 1310, size: 14, "e8efe9", bold: true) }
for x in bxs { arrow(1080, 1210, x, 1288, "c8d2cc") }
ltext("the same 4 DL4s as above · each powered by its own 9V brick", x: 840, top: 1360, size: 12, "9fb0a5")

// ---- save ----
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)  \(Int(W*scale))x\(Int(H*scale))")
