import Foundation

/// DL4 MkII MIDI implementation, transcribed from the Owner's Manual (MIDI chapter).
/// All control is on MIDI channel 1 by default, so CC status is 0xB0.
enum CC {
    // Models / global
    static let delayModel: UInt8 = 1      // value = model index (see DelayModel)
    static let reverbModel: UInt8 = 2
    static let expression: UInt8 = 3      // emulates the EXP pedal (0-127)
    static let bypass: UInt8 = 4          // <=63 active, >=64 bypassed
    static let looperMode: UInt8 = 9      // <=63 off, >=64 Classic Looper on

    // Delay parameters (respond in Preset and Classic Looper modes)
    static let delayTime: UInt8 = 11      // 0-127
    static let subdivision: UInt8 = 12    // see Subdivision
    static let feedback: UInt8 = 13       // "Repeats" 0-127
    static let tweak: UInt8 = 14
    static let tweez: UInt8 = 15
    static let mix: UInt8 = 16

    // Reverb parameters
    static let reverbDecay: UInt8 = 17
    static let reverbPredelay: UInt8 = 18
    static let reverbRouting: UInt8 = 19  // 0 before, 1 parallel, 2 after delay
    static let reverbMix: UInt8 = 20

    static let tapTempo: UInt8 = 64       // 64-127 triggers a tap

    /// Classic Looper CCs. Each picks one of a pair by value: <=63 vs >=64.
    enum Looper {
        static let onOff: UInt8 = 9            // shares CC9 (<=63 off / >=64 on)
        static let recordOverdub: UInt8 = 60   // >=64 Record, <=63 Overdub
        static let stopPlay: UInt8 = 61        // >=64 Play, <=63 Stop
        static let playOnce: UInt8 = 62        // 64-127
        static let undoRedo: UInt8 = 63        // >=64 Redo, <=63 Undo
        static let forwardReverse: UInt8 = 65  // >=64 Reverse, <=63 Forward
        static let fullHalf: UInt8 = 66        // >=64 Half speed, <=63 Full speed
    }
}

/// CC12 time-subdivision values.
enum Subdivision: UInt8, CaseIterable {
    case eighthTriplet = 0
    case eighth = 1
    case dottedEighth = 2
    case quarterTriplet = 3
    case quarter = 4
    case dottedQuarter = 5
    case halfTriplet = 6
    case half = 7
    case dottedHalf = 8

    var label: String {
        switch self {
        case .eighthTriplet:  return "1/8T"
        case .eighth:         return "1/8"
        case .dottedEighth:   return "1/8."
        case .quarterTriplet: return "1/4T"
        case .quarter:        return "1/4"
        case .dottedQuarter:  return "1/4."
        case .halfTriplet:    return "1/2T"
        case .half:           return "1/2"
        case .dottedHalf:     return "1/2."
        }
    }
}

/// CC1 MkII delay model indices.
enum DelayModel: UInt8 {
    case vintageDigital = 0, crisscross, euclidean, dualDelay, pitchEcho,
         adt, ducked, harmony, heliosphere, transistor, cosmos,
         multiPass, adriatic, elephantMan, glitch
}
