import SwiftUI

/// One hue as this specific Midi Fighter 64 renders it. Calibrated from two
/// photos of velocity sweeps (IMG_7172 + IMG_7173, both rotated 90° and
/// cross-checked): the unit's palette is a hue wheel over velocity 1-64,
/// roughly 5-11 red, 12-15 yellow, 17-27 green, 28-35 cyan, 36-44 blue,
/// 45-48 violet, 49-56 magenta, 57-62 pink->orange, 1 pale lavender.
/// `idle` is the verified row color; `lit` is the active/held color (white,
/// unmistakable against every row hue). `screen` matches the photos.
struct PadHue {
    let idle: UInt8
    let lit: UInt8
    let screen: Color
}

/// Row-color system: every grid row gets one hue on both halves, ordered so
/// adjacent rows never share a color family. Top to bottom: green, red,
/// yellow, cyan, white, orange, blue, magenta. Active or held pads light
/// white; quantize-armed pads go violet.
enum MF64Palette {
    static let white: UInt8 = 64          // full white: the universal "lit" color

    static let green   = PadHue(idle: 19, lit: white, screen: Color(red: 0.25, green: 0.90, blue: 0.35))
    static let red     = PadHue(idle: 9,  lit: white, screen: Color(red: 1.00, green: 0.24, blue: 0.18))
    static let yellow  = PadHue(idle: 14, lit: white, screen: Color(red: 0.96, green: 0.88, blue: 0.35))
    static let cyan    = PadHue(idle: 33, lit: white, screen: Color(red: 0.22, green: 0.85, blue: 0.85))
    static let pale    = PadHue(idle: 1,  lit: white, screen: Color(red: 0.80, green: 0.80, blue: 0.92))
    static let orange  = PadHue(idle: 62, lit: white, screen: Color(red: 1.00, green: 0.58, blue: 0.12))
    static let blue    = PadHue(idle: 41, lit: white, screen: Color(red: 0.30, green: 0.48, blue: 1.00))
    static let magenta = PadHue(idle: 56, lit: white, screen: Color(red: 1.00, green: 0.30, blue: 0.65))

    /// Quantize-armed pads: violet, which no row uses.
    static let armed = PadHue(idle: 47, lit: 47, screen: Color(red: 0.62, green: 0.40, blue: 1.00))

    /// The row hue for a pad function. Row pairs (left looper / right perf):
    /// once/squeal, record/kill, overdub/wet, play/drop, stop/build,
    /// undo/tap, reverse/preset A, half/preset B.
    static func hue(for a: PadAction) -> PadHue {
        switch a.kind {
        case .looper:
            switch a.looper {
            case .once:              return green
            case .record:            return red
            case .overdub:           return yellow
            case .play:              return cyan
            case .stop:              return pale
            case .undo, .redo:       return orange
            case .reverse, .forward: return blue
            case .half, .full:       return magenta
            }
        case .reverseToggle: return blue
        case .halfToggle:    return magenta
        case .squeal:        return green
        case .kill:          return red
        case .fullWet:       return yellow
        case .drop:          return cyan
        case .build:         return pale
        case .tap:           return orange
        case .preset:        return a.arg == 0 ? blue : magenta
        case .delayModel, .reverbModel, .subdivision: return cyan
        case .feedbackVel, .mixVel: return magenta
        }
    }
}
