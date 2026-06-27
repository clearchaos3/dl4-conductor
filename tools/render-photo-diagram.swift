// Composites trimmed product photos into the rig signal-chain diagram.
// Pedals are sized to their REAL footprint (so a DL4 visibly dwarfs a BOSS compact); each
// photo sits in a white card (neutralizes mismatched backgrounds) with label + dims.
// Reads trimmed images from docs/assets/trim/. Usage: swift tools/render-photo-diagram.swift out.png
import AppKit
import CoreGraphics

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "signal-chain.png"
let dir = "docs/assets/trim"
let W: CGFloat = 1860, H: CGFloat = 1680, scale: CGFloat = 2
let PK: CGFloat = 1.2   // pedal px-per-mm (real-size scaling among pedals)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W*scale), pixelsHigh: Int(H*scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext

func hexCG(_ h: String, _ a: CGFloat = 1) -> CGColor { var s=h; if s.hasPrefix("#"){s.removeFirst()}; let v=UInt32(s,radix:16) ?? 0
    return CGColor(srgbRed: CGFloat((v>>16)&0xff)/255, green: CGFloat((v>>8)&0xff)/255, blue: CGFloat(v&0xff)/255, alpha: a) }
func nsCol(_ h: String) -> NSColor { var s=h; if s.hasPrefix("#"){s.removeFirst()}; let v=UInt32(s,radix:16) ?? 0
    return NSColor(srgbRed: CGFloat((v>>16)&0xff)/255, green: CGFloat((v>>8)&0xff)/255, blue: CGFloat(v&0xff)/255, alpha: 1) }
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: H - y) }
func RR(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: H-y-h, width: w, height: h) }
func fillRR(_ r: CGRect, _ rad: CGFloat, _ c: CGColor) { ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.setFillColor(c); ctx.fillPath() }
func strokeRR(_ r: CGRect, _ rad: CGFloat, _ c: CGColor, _ lw: CGFloat) { ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.setStrokeColor(c); ctx.setLineWidth(lw); ctx.strokePath() }
func text(_ s: String, cx: CGFloat, top: CGFloat, size: CGFloat, _ hex: String = "e8efe9", bold: Bool = false) {
    let a = NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular), .foregroundColor: nsCol(hex)])
    a.draw(at: NSPoint(x: cx - a.size().width/2, y: (H-top) - a.size().height)) }
func ltext(_ s: String, x: CGFloat, top: CGFloat, size: CGFloat, _ hex: String = "9fb0a5", bold: Bool = false) {
    let f = NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: nsCol(hex)]).draw(at: NSPoint(x: x, y: (H-top) - f.ascender - 2)) }
func arrow(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ hex: String = "c8d2cc", dashed: Bool = false, lw: CGFloat = 2.2) {
    ctx.saveGState(); ctx.setStrokeColor(hexCG(hex)); ctx.setLineWidth(lw); if dashed { ctx.setLineDash(phase: 0, lengths: [7,5]) }
    ctx.move(to: P(x1,y1)); ctx.addLine(to: P(x2,y2)); ctx.strokePath(); ctx.restoreGState()
    let ang = atan2(-(y2-y1), x2-x1), L: CGFloat = 13, tip = P(x2,y2)
    ctx.move(to: tip); ctx.addLine(to: CGPoint(x: tip.x+cos(ang + .pi-0.45)*L, y: tip.y+sin(ang + .pi-0.45)*L))
    ctx.addLine(to: CGPoint(x: tip.x+cos(ang + .pi+0.45)*L, y: tip.y+sin(ang + .pi+0.45)*L)); ctx.closePath(); ctx.setFillColor(hexCG(hex)); ctx.fillPath() }

func drawImage(_ file: String, in content: CGRect) {
    if let img = NSImage(contentsOfFile: "\(dir)/\(file)"), img.size.width > 0 {
        let s = min(content.width/img.size.width, content.height/img.size.height)
        let dw = img.size.width*s, dh = img.size.height*s
        img.draw(in: CGRect(x: content.midX-dw/2, y: content.midY-dh/2, width: dw, height: dh), from: .zero, operation: .sourceOver, fraction: 1)
    } else { ctx.setFillColor(hexCG("dddddd")); ctx.fill(content) }
}
/// Generic white card with a fitted photo and label/sub below.
func card(_ file: String, cx: CGFloat, top: CGFloat, w: CGFloat, h: CGFloat, label: String, sub: String = "", accent: String = "5bbf73") {
    let r = RR(cx-w/2, top, w, h); fillRR(r, 11, hexCG("f4f5f3")); strokeRR(r, 11, hexCG(accent), 2.4)
    drawImage(file, in: r.insetBy(dx: 10, dy: 10))
    text(label, cx: cx, top: top+h+6, size: 13, "e8efe9", bold: true)
    if !sub.isEmpty { text(sub, cx: cx, top: top+h+25, size: 11, "9fb0a5") }
}
/// Pedal card sized to real footprint (mm) × PK, vertically centered on `cy`.
func pedal(_ file: String, cx: CGFloat, cy: CGFloat, fw: CGFloat, fh: CGFloat, label: String, accent: String = "7CF08A") -> CGFloat {
    let w = fw*PK, h = fh*PK, top = cy - h/2
    card(file, cx: cx, top: top, w: w, h: h, label: label, sub: "\(Int(fw))×\(Int(fh)) mm", accent: accent)
    return w
}

// ===== background + title =====
ctx.setFillColor(hexCG("0d0f0e")); ctx.fill(CGRect(x:0,y:0,width:W,height:H))
ltext("DL4 ×4  ·  Loop + Lofi-Beat Rig — Signal Chain", x: 56, top: 30, size: 28, "7CF08A", bold: true)
ltext("pedals drawn to real relative size", x: 58, top: 64, size: 14, "9fb0a5")

let lr = RR(1470, 86, 350, 150); fillRR(lr, 10, hexCG("11141a")); strokeRR(lr, 10, hexCG("444444"), 1.5)
ltext("Legend", x: 1492, top: 104, size: 16, "e8efe9", bold: true)
arrow(1492,146,1542,146,"5bbf73"); ltext("audio signal", x: 1558, top: 139, size: 13)
arrow(1492,180,1542,180,"5aa0e0"); ltext("MIDI control", x: 1558, top: 173, size: 13)
arrow(1492,214,1542,214,"e0a94a",dashed:true); ltext("MIDI clock (tempo)", x: 1558, top: 207, size: 13)

// ===== PANEL A: AUDIO =====
ltext("AUDIO PATH   ·   guitar + mic record into the 4 DL4s (in series) · FX after, tweaked live", x: 56, top: 110, size: 20, "9fb0a5", bold: true)

card("guitar.png", cx: 120, top: 165, w: 120, h: 250, label: "Electric Guitar")
card("mic.png", cx: 130, top: 470, w: 170, h: 110, label: "Shure SM58")

let dRow: CGFloat = 235
_ = pedal("tu3w.png", cx: 320, cy: dRow, fw: 73, fh: 129, label: "TU-3W tuner", accent: "9fb0a5")
let dl4cx: [CGFloat] = [560, 860, 1160, 1460]
for (i, cx) in dl4cx.enumerated() {
    _ = pedal(i==3 ? "dl4-25th.png" : "dl4.png", cx: cx, cy: dRow, fw: 235, fh: 114, label: i==3 ? "DL4 MkII D (25th)" : "DL4 MkII \(["A","B","C"][i])")
}
arrow(175, 220, 280, 232); arrow(360, 232, 420, 232); ltext("guitar 1/4\"", x: 365, top: 205, size: 11, "c8d2cc")
arrow(190, 470, 430, 250, "c8d2cc"); ltext("mic XLR", x: 235, top: 430, size: 11, "c8d2cc")
arrow(700, 235, 718, 235); arrow(1000, 235, 1018, 235); arrow(1300, 235, 1318, 235)
ltext("guitar + mic reach every DL4 → record a sample into any of the four", x: 470, top: 320, size: 13, "9fb0a5")

arrow(1460, 320, 1460, 360, "c8d2cc"); arrow(1460, 360, 250, 360, "c8d2cc"); arrow(250, 360, 250, 470, "c8d2cc")

// FX row (real footprint sizes), vertically centered on fRow
let fRow: CGFloat = 560
let fx: [(CGFloat, String, String, CGFloat, CGFloat)] = [
    (250,"dookie.png","Dookie Drive",64,111), (450,"ge7.png","GE-7 EQ",73,129), (650,"pitchfork.png","Pitch Fork",70,92),
    (850,"ph2.png","PH-2 Phaser",73,129), (1050,"de7.png","DE7 delay",70,125), (1250,"dd5.png","DD-5 delay",73,129), (1470,"rv3.png","RV-3 reverb",73,129)
]
var edges: [(CGFloat,CGFloat)] = []   // (leftX, rightX) per pedal
for (cx,file,label,fw,fh) in fx { let w = pedal(file, cx: cx, cy: fRow, fw: fw, fh: fh, label: label, accent: "5bbf73"); edges.append((cx-w/2, cx+w/2)) }
for i in 0..<fx.count-1 { arrow(edges[i].1, fRow, edges[i+1].0, fRow) }
card("volumex.png", cx: 650, top: 660, w: 96, h: 96, label: "Volume X → exp")
card("redremote.png", cx: 1250, top: 665, w: 86, h: 92, label: "Red Remote → tap")

arrow(edges[6].1, fRow, 1620, fRow); arrow(1620, fRow, 1620, 800, "c8d2cc"); arrow(1620, 800, 1075, 800, "c8d2cc")

card("apollo.png", cx: 930, top: 740, w: 300, h: 150, label: "Apollo Twin", sub: "interface · monitoring", accent: "5bbf73")
card("krk.png", cx: 800, top: 940, w: 120, h: 185, label: "KRK Rokit 8 (L)", accent: "d98a5b")
card("krk.png", cx: 1010, top: 940, w: 120, h: 185, label: "KRK Rokit 8 (R)", accent: "d98a5b")
arrow(905, 890, 820, 938, "c8d2cc"); arrow(955, 890, 1000, 938, "c8d2cc")
card("macbook.png", cx: 1470, top: 745, w: 280, h: 165, label: "MacBook Pro", accent: "9fb0a5")
arrow(1085, 815, 1335, 820, "c8d2cc", dashed: true); ltext("Thunderbolt", x: 1135, top: 798, size: 12, "9fb0a5")

ctx.setStrokeColor(hexCG("333333")); ctx.setLineWidth(1); ctx.move(to: P(40,1190)); ctx.addLine(to: P(1820,1190)); ctx.strokePath()

// ===== PANEL B: MIDI / USB =====
ltext("MIDI / USB   ·   one Midi Fighter drives both Ableton drums and the DL4 loopers", x: 56, top: 1222, size: 20, "9fb0a5", bold: true)
card("mf64.png", cx: 250, top: 1270, w: 250, h: 175, label: "Midi Fighter 64", sub: "finger-drum beat + DL4 pads", accent: "5aa0e0")
card("macbook.png", cx: 760, top: 1280, w: 280, h: 165, label: "MacBook (Ableton + DL4 Conductor)", accent: "5aa0e0")
card("hub.png", cx: 1240, top: 1300, w: 200, h: 140, label: "Powered USB hub", accent: "5aa0e0")

arrow(380, 1300, 615, 1330, "5aa0e0"); ltext("drum pads (~48)", x: 400, top: 1288, size: 12, "c8d2cc")
arrow(380, 1370, 615, 1400, "5aa0e0"); ltext("DL4 pads (16)", x: 400, top: 1402, size: 12, "c8d2cc")
arrow(905, 1340, 1140, 1350, "5aa0e0"); ltext("control + LEDs", x: 930, top: 1326, size: 12, "c8d2cc")
arrow(905, 1380, 1140, 1388, "e0a94a", dashed: true); ltext("MIDI clock → delays", x: 930, top: 1392, size: 12, "e0a94a")

let bxs: [CGFloat] = [1000, 1150, 1300, 1450]
for (i, cx) in bxs.enumerated() { let r = RR(cx-58, 1480, 116, 56); fillRR(r, 8, hexCG("16291d")); strokeRR(r, 8, hexCG("7CF08A"), 2); text("DL4 \(["A","B","C","D"][i])", cx: cx, top: 1500, size: 14, "e8efe9", bold: true) }
for cx in bxs { arrow(1240, 1440, cx, 1478, "c8d2cc") }
ltext("the same 4 DL4s as above · each powered by its own 9V brick", x: 1000, top: 1552, size: 12, "9fb0a5")

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)  \(Int(W*scale))x\(Int(H*scale))")
