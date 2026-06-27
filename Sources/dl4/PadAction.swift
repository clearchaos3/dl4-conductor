import Foundation

/// What a controller pad does when pressed. Covers the full DL4 MkII MIDI surface, not
/// just the looper: model/preset launching, rhythm, momentary FX, velocity hits, macros.
struct PadAction: Codable, Hashable {
    enum Kind: String, Codable {
        case looper        // a LooperFunction
        case delayModel    // CC1 = arg
        case reverbModel   // CC2 = arg
        case subdivision   // CC12 = arg
        case preset        // Program Change = arg
        case tap           // CC64 tap tempo
        case squeal        // momentary: feedback to max while held
        case kill          // momentary: bypass (mute) while held
        case fullWet       // momentary: mix to 100% while held
        case drop          // one-shot macro: reverse + half speed
        case build         // one-shot macro: ramp feedback + mix up
        case feedbackVel   // CC13 set from pad velocity
        case mixVel        // CC16 set from pad velocity
        case reverseToggle // one pad flips reverse on/off (like the pedal's double-tap)
        case halfToggle    // one pad flips half-speed on/off (like the pedal's tap)
    }

    var kind: Kind
    var arg: Int = 0                       // model index / subdivision / preset PC
    var looper: LooperFunction = .record   // for .looper

    /// Momentary actions also fire on pad release (to revert).
    var isMomentary: Bool { kind == .squeal || kind == .kill || kind == .fullWet }

    /// Actions that affect loop timing — these are the ones worth quantizing to the grid.
    var isLooperTiming: Bool {
        switch kind {
        case .looper, .reverseToggle, .halfToggle, .drop: return true
        default: return false
        }
    }

    var title: String {
        switch kind {
        case .looper:      return looper.title
        case .delayModel:  return "Delay: \(DelayModel.names[safe: arg] ?? "\(arg)")"
        case .reverbModel: return "Reverb: \(ReverbModel.names[safe: arg] ?? "\(arg)")"
        case .subdivision: return "Subdiv: \(Subdivision(rawValue: UInt8(arg))?.label ?? "\(arg)")"
        case .preset:      return "Preset · PC\(arg)"
        case .tap:         return "Tap Tempo"
        case .squeal:      return "Squeal (hold)"
        case .kill:        return "Kill (hold)"
        case .fullWet:     return "100% Wet (hold)"
        case .drop:        return "Drop"
        case .build:       return "Build"
        case .feedbackVel: return "Feedback (vel)"
        case .mixVel:      return "Mix (vel)"
        case .reverseToggle: return "Reverse (toggle)"
        case .halfToggle:    return "Half (toggle)"
        }
    }
}
