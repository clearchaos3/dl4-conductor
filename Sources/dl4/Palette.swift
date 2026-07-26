import SwiftUI

/// One hue as this specific Midi Fighter 64 actually renders it, calibrated
/// from a photo of a velocity sweep (IMG_7172, 2026-07-26): `bright`/`dim`
/// are LED velocities verified on the unit, `screen` is the matching on-screen
/// color sampled from the same photo. Screen and pads draw from this one
/// table, so they cannot drift apart again.
struct PadHue {
    let bright: UInt8
    let dim: UInt8
    let screen: Color
}

/// Row-color system: every grid row gets one unmistakable hue, shared by the
/// looper half (bright) and the performance half (dim). Top to bottom:
/// green, red, amber, cyan, white, yellow, blue, purple.
enum MF64Palette {
    static let green  = PadHue(bright: 59, dim: 19, screen: Color(red: 0.25, green: 0.90, blue: 0.35))
    static let red    = PadHue(bright: 17, dim: 9,  screen: Color(red: 1.00, green: 0.22, blue: 0.16))
    static let amber  = PadHue(bright: 24, dim: 10, screen: Color(red: 1.00, green: 0.58, blue: 0.10))
    static let cyan   = PadHue(bright: 61, dim: 45, screen: Color(red: 0.20, green: 0.85, blue: 0.85))
    static let white  = PadHue(bright: 35, dim: 1,  screen: Color(red: 0.92, green: 0.94, blue: 0.90))
    static let yellow = PadHue(bright: 26, dim: 18, screen: Color(red: 0.95, green: 0.85, blue: 0.20))
    static let blue   = PadHue(bright: 62, dim: 13, screen: Color(red: 0.30, green: 0.48, blue: 1.00))
    static let purple = PadHue(bright: 30, dim: 15, screen: Color(red: 0.68, green: 0.32, blue: 1.00))
    static let magenta = PadHue(bright: 64, dim: 7, screen: Color(red: 1.00, green: 0.30, blue: 0.70))

    /// Quantize-armed pads flash a hue no row uses.
    static let armed = magenta

    /// The row hue for a pad function, and whether this function sits on the
    /// dim (performance) half. Row pairs: once/squeal, record/kill,
    /// overdub/wet, play/drop, stop/build, undo/tap, reverse/preset A,
    /// half/preset B.
    static func hue(for a: PadAction) -> (hue: PadHue, isDim: Bool) {
        switch a.kind {
        case .looper:
            switch a.looper {
            case .once:              return (green, false)
            case .record:            return (red, false)
            case .overdub:           return (amber, false)
            case .play:              return (cyan, false)
            case .stop:              return (white, false)
            case .undo, .redo:       return (yellow, false)
            case .reverse, .forward: return (blue, false)
            case .half, .full:       return (purple, false)
            }
        case .reverseToggle: return (blue, false)
        case .halfToggle:    return (purple, false)
        case .squeal:        return (green, true)
        case .kill:          return (red, true)
        case .fullWet:       return (amber, true)
        case .drop:          return (cyan, true)
        case .build:         return (white, true)
        case .tap:           return (yellow, true)
        case .preset:        return (a.arg == 0 ? blue : purple, true)
        case .delayModel, .reverbModel, .subdivision: return (cyan, true)
        case .feedbackVel, .mixVel: return (magenta, true)
        }
    }
}
