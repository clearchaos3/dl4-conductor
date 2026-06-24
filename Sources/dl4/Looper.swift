import Foundation

/// Semantic looper commands mapped to DL4 MkII MIDI CCs, broadcast to all connected pedals.
/// (The pedal responds to these whether or not Classic Looper mode is visibly on, but you
/// only see LED feedback when it is — hence `enterLooperMode()`.)
struct LooperControl {
    let midi: DL4Midi

    func enterLooperMode() { midi.ccAll(CC.Looper.onOff, 127) }
    func exitLooperMode()  { midi.ccAll(CC.Looper.onOff, 0) }

    func record()    { midi.ccAll(CC.Looper.recordOverdub, 127) }
    func overdub()   { midi.ccAll(CC.Looper.recordOverdub, 0) }
    func play()      { midi.ccAll(CC.Looper.stopPlay, 127) }
    func stop()      { midi.ccAll(CC.Looper.stopPlay, 0) }
    func playOnce()  { midi.ccAll(CC.Looper.playOnce, 127) }
    func undo()      { midi.ccAll(CC.Looper.undoRedo, 0) }
    func redo()      { midi.ccAll(CC.Looper.undoRedo, 127) }
    func reverse()   { midi.ccAll(CC.Looper.forwardReverse, 127) }
    func forward()   { midi.ccAll(CC.Looper.forwardReverse, 0) }
    func halfSpeed() { midi.ccAll(CC.Looper.fullHalf, 127) }
    func fullSpeed() { midi.ccAll(CC.Looper.fullHalf, 0) }

    /// Perform a looper function on one pedal (-1 = all pedals).
    func perform(_ f: LooperFunction, on pedal: Int) {
        let m = f.message
        if pedal < 0 { midi.ccAll(m.cc, m.value) } else { midi.cc(m.cc, m.value, to: pedal) }
    }

    /// Route a web-button action name to the matching command. Returns false if unknown.
    func command(_ name: String) -> Bool {
        switch name {
        case "enter":   enterLooperMode()
        case "exit":    exitLooperMode()
        case "record":  record()
        case "overdub": overdub()
        case "play":    play()
        case "stop":    stop()
        case "once":    playOnce()
        case "undo":    undo()
        case "redo":    redo()
        case "reverse": reverse()
        case "forward": forward()
        case "half":    halfSpeed()
        case "full":    fullSpeed()
        default:        return false
        }
        return true
    }
}

/// A single looper action, used for controller bindings and the on-screen grid.
enum LooperFunction: String, CaseIterable, Codable, Identifiable {
    case record, overdub, play, stop, once, undo, redo, reverse, forward, half, full
    var id: String { rawValue }

    var title: String {
        switch self {
        case .record:  return "Record"
        case .overdub: return "Overdub"
        case .play:    return "Play"
        case .stop:    return "Stop"
        case .once:    return "Once"
        case .undo:    return "Undo"
        case .redo:    return "Redo"
        case .reverse: return "Reverse"
        case .forward: return "Forward"
        case .half:    return "Half"
        case .full:    return "Full"
        }
    }

    /// The DL4 looper CC + value that performs this function.
    var message: (cc: UInt8, value: UInt8) {
        switch self {
        case .record:  return (CC.Looper.recordOverdub, 127)
        case .overdub: return (CC.Looper.recordOverdub, 0)
        case .play:    return (CC.Looper.stopPlay, 127)
        case .stop:    return (CC.Looper.stopPlay, 0)
        case .once:    return (CC.Looper.playOnce, 127)
        case .undo:    return (CC.Looper.undoRedo, 0)
        case .redo:    return (CC.Looper.undoRedo, 127)
        case .reverse: return (CC.Looper.forwardReverse, 127)
        case .forward: return (CC.Looper.forwardReverse, 0)
        case .half:    return (CC.Looper.fullHalf, 127)
        case .full:    return (CC.Looper.fullHalf, 0)
        }
    }
}
