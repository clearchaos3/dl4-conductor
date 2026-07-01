import Foundation
import CoreMIDI

/// A controller event we can bind to an action — a note or CC on a channel.
struct MidiTrigger: Hashable, Codable {
    enum Kind: String, Codable { case note, cc }
    var kind: Kind
    var channel: UInt8   // 0-based (0 = MIDI channel 1)
    var data1: UInt8     // note number, or CC number

    var label: String {
        switch kind {
        case .note: return "Note \(data1) · ch\(channel + 1)"
        case .cc:   return "CC \(data1) · ch\(channel + 1)"
        }
    }
    var shortLabel: String {
        switch kind {
        case .note: return "n\(data1)"
        case .cc:   return "cc\(data1)"
        }
    }
}

/// A learned mapping: controller trigger → action on a given pedal (-1 = all).
struct PadBinding: Codable, Identifiable, Hashable {
    var id = UUID()
    var trigger: MidiTrigger
    var pedal: Int
    var action: PadAction
}

/// Listens to every MIDI source and reports presses/releases with velocity. Used to route a
/// controller (e.g. a Midi Fighter 64) into DL4 actions.
final class MidiInput {
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var connected = Set<MIDIEndpointRef>()

    /// Called on the main thread for each event: (trigger, pressed, velocity).
    var onTrigger: ((MidiTrigger, Bool, UInt8) -> Void)?

    /// System-realtime clock messages (e.g. from Ableton), delivered on the main thread.
    enum ClockMsg { case tick, start, stop, cont }
    var onClock: ((ClockMsg) -> Void)?

    init() {
        MIDIClientCreate("dl4-conductor-in" as CFString, nil, nil, &client)
        let refCon = Unmanaged.passUnretained(self).toOpaque()
        MIDIInputPortCreate(client, "dl4-in" as CFString, midiReadProc, refCon, &port)
        connectAllSources()
    }

    /// Connect to any sources we're not already listening to.
    func connectAllSources() {
        for i in 0..<MIDIGetNumberOfSources() {
            let src = MIDIGetSource(i)
            if !connected.contains(src) {
                if MIDIPortConnectSource(port, src, nil) == noErr { connected.insert(src) }
            }
        }
    }

    func sourceNames() -> [String] {
        (0..<MIDIGetNumberOfSources()).map { i in
            let s = MIDIGetSource(i)
            var nameRef: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(s, kMIDIPropertyDisplayName, &nameRef)
            return (nameRef?.takeRetainedValue() as String?) ?? "(unknown)"
        }
    }

    fileprivate func handle(_ pktList: UnsafePointer<MIDIPacketList>) {
        var packet = pktList.pointee.packet
        for _ in 0..<pktList.pointee.numPackets {
            let length = Int(packet.length)
            withUnsafeBytes(of: packet.data) { raw in
                var i = 0
                while i < length {
                    let status = raw[i]
                    guard status & 0x80 != 0 else { i += 1; continue }
                    if status >= 0xF8 {            // system realtime — single byte, may interleave
                        switch status {
                        case 0xF8: emitClock(.tick)
                        case 0xFA: emitClock(.start)
                        case 0xFB: emitClock(.cont)
                        case 0xFC: emitClock(.stop)
                        default: break
                        }
                        i += 1; continue
                    }
                    let hi = status & 0xF0
                    let ch = status & 0x0F
                    switch hi {
                    case 0x90 where i + 2 < length:           // Note On (vel 0 = release)
                        let note = raw[i + 1], vel = raw[i + 2]
                        emit(MidiTrigger(kind: .note, channel: ch, data1: note), pressed: vel > 0, velocity: vel)
                        i += 3
                    case 0x80 where i + 2 < length:           // Note Off
                        let note = raw[i + 1]
                        emit(MidiTrigger(kind: .note, channel: ch, data1: note), pressed: false, velocity: 0)
                        i += 3
                    case 0xB0 where i + 2 < length:           // CC (>=64 press, <64 release)
                        let cc = raw[i + 1], val = raw[i + 2]
                        emit(MidiTrigger(kind: .cc, channel: ch, data1: cc), pressed: val >= 64, velocity: val)
                        i += 3
                    case 0xC0, 0xD0:                          // Program Change / Channel Pressure
                        i += 2
                    default:
                        i += 1
                    }
                }
            }
            packet = MIDIPacketNext(&packet).pointee
        }
    }

    private func emit(_ t: MidiTrigger, pressed: Bool, velocity: UInt8) {
        DispatchQueue.main.async { [weak self] in self?.onTrigger?(t, pressed, velocity) }
    }
    private func emitClock(_ m: ClockMsg) {
        DispatchQueue.main.async { [weak self] in self?.onClock?(m) }
    }
}

private func midiReadProc(_ pktList: UnsafePointer<MIDIPacketList>,
                          _ readRefCon: UnsafeMutableRawPointer?,
                          _ srcConnRefCon: UnsafeMutableRawPointer?) {
    guard let refCon = readRefCon else { return }
    Unmanaged<MidiInput>.fromOpaque(refCon).takeUnretainedValue().handle(pktList)
}
