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
/// lighting cells live as pads are pressed.
struct GridMapView: View {
    @EnvironmentObject var model: AppModel

    private func binding(forNote n: UInt8) -> PadBinding? {
        model.bindings.first { $0.trigger.kind == .note && $0.trigger.data1 == n }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<8, id: \.self) { col in
                        cell(row: row, col: col)
                    }
                }
            }
            Text("As you face the Midi Fighter · columns pair with pedals A–D · pads light while pressed")
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func cell(row: Int, col: Int) -> some View {
        let n = MF64Grid.note(displayRow: row, col: col)
        if let b = binding(forNote: n) {
            let held = model.heldTriggers.contains(b.trigger)
            let color = categoryColor(b.action)
            VStack(spacing: 1) {
                Text(pedalLetter(b.pedal))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(shortLabel(b.action))
                    .font(.system(size: 8, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(width: 46, height: 30)
            .background(RoundedRectangle(cornerRadius: 5)
                .fill(held ? color.opacity(0.95) : color.opacity(0.28)))
            .overlay(RoundedRectangle(cornerRadius: 5)
                .stroke(held ? Color.white : color.opacity(0.5), lineWidth: held ? 1.5 : 0.5))
            .help("\(pedalLetter(b.pedal)) — \(b.action.title)")
        } else {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.04))
                .frame(width: 46, height: 30)
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
