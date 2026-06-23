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
