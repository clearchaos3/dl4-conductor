import SwiftUI

/// One hue as this specific Midi Fighter 64 renders it. Calibrated from photos
/// of velocity sweeps (IMG_7172 + IMG_7173): the unit's palette is a hue wheel
/// over velocity 1-64. `idle` is the verified LED velocity; `screen` matches
/// the photographed color.
struct PadHue {
    let idle: UInt8
    let screen: Color
}

/// Row-color system. The grid is two 4x8 decks (looper left, performance
/// right); the same row does different things on each side, so color must
/// distinguish the halves, not just the rows. Each deck gets all eight hues,
/// but the performance deck's palette is rotated four steps against the
/// looper deck's — so within any row the left four pads and the right four
/// pads are always different colors, and no two vertically-adjacent pads
/// share a hue either.
enum MF64Palette {
    /// Universal "lit" color for an active or held pad: full white, verified
    /// to pop against every idle hue below.
    static let lit: UInt8 = 64

    static let green   = PadHue(idle: 19, screen: Color(red: 0.25, green: 0.90, blue: 0.35))
    static let red     = PadHue(idle: 9,  screen: Color(red: 1.00, green: 0.24, blue: 0.18))
    static let orange  = PadHue(idle: 62, screen: Color(red: 1.00, green: 0.58, blue: 0.12))
    static let yellow  = PadHue(idle: 14, screen: Color(red: 0.96, green: 0.88, blue: 0.35))
    static let cyan    = PadHue(idle: 33, screen: Color(red: 0.22, green: 0.85, blue: 0.85))
    static let blue    = PadHue(idle: 41, screen: Color(red: 0.30, green: 0.48, blue: 1.00))
    static let magenta = PadHue(idle: 56, screen: Color(red: 1.00, green: 0.30, blue: 0.65))
    static let pale    = PadHue(idle: 1,  screen: Color(red: 0.80, green: 0.80, blue: 0.92))

    /// Quantize-armed pads: violet, which no row uses.
    static let armed = PadHue(idle: 47, screen: Color(red: 0.62, green: 0.40, blue: 1.00))

    /// Looper deck (left), rows top to bottom. Performance deck reuses these
    /// rotated by four (see `perf`).
    private static let looper: [PadHue] = [green, red, orange, yellow, cyan, blue, magenta, pale]
    private static func perf(_ row: Int) -> PadHue { looper[(row + 4) % 8] }

    /// The row hue for a pad function. Looper-deck functions map straight to
    /// the looper palette; performance-deck functions map to the rotated one,
    /// so paired rows (once/squeal, record/kill, ...) never match.
    static func hue(for a: PadAction) -> PadHue {
        switch a.kind {
        case .looper:
            switch a.looper {
            case .once:              return looper[0]
            case .record:            return looper[1]
            case .overdub:           return looper[2]
            case .play:              return looper[3]
            case .stop:              return looper[4]
            case .undo, .redo:       return looper[5]
            case .reverse, .forward: return looper[6]
            case .half, .full:       return looper[7]
            }
        case .reverseToggle: return looper[6]
        case .halfToggle:    return looper[7]
        case .squeal:        return perf(0)
        case .kill:          return perf(1)
        case .fullWet:       return perf(2)
        case .drop:          return perf(3)
        case .build:         return perf(4)
        case .tap:           return perf(5)
        case .preset:        return perf(a.arg == 0 ? 6 : 7)
        case .delayModel, .reverbModel, .subdivision: return perf(3)
        case .feedbackVel, .mixVel: return perf(2)
        }
    }
}
