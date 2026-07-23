import SwiftUI

/// The Midi Fighter 64's factory pad-to-note geometry, verified against this unit
/// by corner presses: four 4x4 quadrant banks, notes on channel 3 (0-based 2).
/// note = base + 4*(rowFromBottom % 4) + (col % 4); bases BL=36 TL=52 BR=68 TR=84.
enum MF64Grid {
    static let channel: UInt8 = 2   // 0-based (MIDI channel 3)

    /// Note for a display cell — row 0 = TOP row (as you face the unit), col 0 = left.
    static func note(displayRow: Int, col: Int) -> UInt8 {
        let r = 7 - displayRow   // physical row from bottom
        let base: Int
        switch (r / 4, col / 4) {
        case (0, 0): base = 36
        case (1, 0): base = 52
        case (0, 1): base = 68
        default:     base = 84
        }
        return UInt8(base + 4 * (r % 4) + (col % 4))
    }
}

/// On-screen mirror of the Midi Fighter: an 8x8 map showing what every pad does,
/// lighting cells live as pads are pressed. Drawn as a single Canvas — one draw
/// pass per change instead of 64 diffed views, which is what keeps it responsive
/// under fast pad mashing.
struct GridMapView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var activity: PadActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Canvas(rendersAsynchronously: false) { context, size in
                let byNote = Dictionary(
                    model.bindings.compactMap { b in
                        b.trigger.kind == .note ? (b.trigger.data1, b) : nil
                    },
                    uniquingKeysWith: { a, _ in a })
                let lit = activity.lit
                let spacing = max(4, size.width * 0.008)
                let cw = (size.width - spacing * 7) / 8
                let ch = (size.height - spacing * 7) / 8
                let corner = max(5, ch * 0.14)

                _ = corner
                for row in 0..<8 {
                    for col in 0..<8 {
                        let rect = CGRect(x: CGFloat(col) * (cw + spacing),
                                          y: CGFloat(row) * (ch + spacing),
                                          width: cw, height: ch)
                        let d = min(cw, ch) * 0.94
                        let circle = Path(ellipseIn: CGRect(x: rect.midX - d / 2,
                                                            y: rect.midY - d / 2,
                                                            width: d, height: d))
                        guard let b = byNote[MF64Grid.note(displayRow: row, col: col)] else {
                            // Empty socket: dark well, faint rim
                            context.fill(circle, with: .color(.black.opacity(0.35)))
                            context.stroke(circle, with: .color(.white.opacity(0.05)), lineWidth: 1)
                            continue
                        }
                        let held = lit.contains(b.trigger)
                        let color = categoryColor(b.action)

                        if held {
                            // LED bloom: glow filter behind a fully lit pad
                            var glow = context
                            glow.addFilter(.shadow(color: color.opacity(0.9), radius: d * 0.18))
                            glow.fill(circle, with: .color(color))
                            context.stroke(circle, with: .color(.white.opacity(0.9)), lineWidth: 2)
                        } else {
                            // Unlit arcade button: dark dome, colored rim,
                            // faint top highlight like a plastic cap
                            context.fill(circle, with: .color(.black.opacity(0.32)))
                            context.fill(circle, with: .color(color.opacity(0.12)))
                            context.stroke(circle, with: .color(color.opacity(0.55)), lineWidth: 2)
                            let hl = CGRect(x: rect.midX - d * 0.28, y: rect.midY - d * 0.40,
                                            width: d * 0.56, height: d * 0.2)
                            context.fill(Path(ellipseIn: hl), with: .color(.white.opacity(0.045)))
                        }

                        let ink: Color = held ? .black.opacity(0.82) : color.opacity(0.95)
                        let letter = context.resolve(
                            Text(pedalLetter(b.pedal))
                                .font(.system(size: max(8, d * 0.17), weight: .bold, design: .monospaced))
                                .foregroundColor(held ? .black.opacity(0.6) : Theme.silkDim))
                        context.draw(letter, at: CGPoint(x: rect.midX, y: rect.midY - d * 0.17))

                        let text = shortLabel(b.action)
                        let fit = min(max(8, d * 0.20), d / CGFloat(max(3, text.count)) * 1.5)
                        let label = context.resolve(
                            Text(text)
                                .font(.system(size: fit, weight: .heavy))
                                .foregroundColor(ink))
                        context.draw(label, at: CGPoint(x: rect.midX, y: rect.midY + d * 0.13))
                    }
                }
            }
            Text("As you face the Midi Fighter · columns pair with pedals A–D · pads light while pressed")
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    private func pedalLetter(_ p: Int) -> String {
        if p < 0 { return "ALL" }
        return p < Conductor.pedalLetters.count ? Conductor.pedalLetters[p] : "\(p)"
    }

    private func shortLabel(_ a: PadAction) -> String {
        switch a.kind {
        case .looper:
            switch a.looper {
            case .record: return "REC"
            case .overdub: return "OVR"
            case .play: return "PLAY"
            case .stop: return "STOP"
            case .once: return "ONCE"
            case .undo: return "UNDO"
            case .redo: return "REDO"
            case .reverse: return "REV"
            case .forward: return "FWD"
            case .half: return "HALF"
            case .full: return "FULL"
            }
        case .delayModel: return "DLY \(a.arg)"
        case .reverbModel: return "RVB \(a.arg)"
        case .subdivision: return Subdivision(rawValue: UInt8(a.arg))?.label ?? "SUB"
        case .preset: return "PST \(["A","B","C","D","E","F"][safe: a.arg] ?? "\(a.arg)")"
        case .tap: return "TAP"
        case .squeal: return "SQUEAL"
        case .kill: return "KILL"
        case .fullWet: return "WET"
        case .drop: return "DROP"
        case .build: return "BUILD"
        case .feedbackVel: return "FB·vel"
        case .mixVel: return "MIX·vel"
        case .reverseToggle: return "REV⇄"
        case .halfToggle: return "½⇄"
        }
    }

    private func categoryColor(_ a: PadAction) -> Color {
        switch a.kind {
        case .looper:
            switch a.looper {
            case .record, .overdub: return .red
            case .play, .once: return .green
            case .stop: return .gray
            case .undo, .redo: return .orange
            case .reverse, .forward, .half, .full: return .teal
            }
        case .reverseToggle, .halfToggle: return .teal
        case .squeal, .kill, .fullWet: return .pink
        case .drop, .build: return .purple
        case .tap: return .yellow
        case .preset: return .indigo
        case .delayModel, .reverbModel, .subdivision: return .blue
        case .feedbackVel, .mixVel: return .cyan
        }
    }
}
