import Foundation
import CoreMIDI

/// A controller event we can bind to a looper action — a note or CC on a channel.
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

/// A learned mapping: controller trigger → looper function on a given pedal (-1 = all).
struct PadBinding: Codable, Identifiable, Hashable {
    var id = UUID()
    var trigger: MidiTrigger
    var pedal: Int
    var function: LooperFunction
}

/// Listens to every MIDI source and reports note/CC presses. Used to route a controller
/// (e.g. a Midi Fighter 64) into DL4 looper commands.
final class MidiInput {
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var connected = Set<MIDIEndpointRef>()

    /// Called on the main thread for each incoming press.
    var onTrigger: ((MidiTrigger) -> Void)?

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
                    let hi = status & 0xF0
                    let ch = status & 0x0F
                    switch hi {
                    case 0x90 where i + 2 < length:           // Note On
                        let note = raw[i + 1], vel = raw[i + 2]
                        if vel > 0 { emit(MidiTrigger(kind: .note, channel: ch, data1: note)) }
                        i += 3
                    case 0x80 where i + 2 < length:           // Note Off — ignore
                        i += 3
                    case 0xB0 where i + 2 < length:           // CC
                        let cc = raw[i + 1], val = raw[i + 2]
                        if val >= 64 { emit(MidiTrigger(kind: .cc, channel: ch, data1: cc)) }
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

    private func emit(_ t: MidiTrigger) {
        DispatchQueue.main.async { [weak self] in self?.onTrigger?(t) }
    }
}

private func midiReadProc(_ pktList: UnsafePointer<MIDIPacketList>,
                          _ readRefCon: UnsafeMutableRawPointer?,
                          _ srcConnRefCon: UnsafeMutableRawPointer?) {
    guard let refCon = readRefCon else { return }
    Unmanaged<MidiInput>.fromOpaque(refCon).takeUnretainedValue().handle(pktList)
}
