import Foundation
import CoreMIDI

/// A thin CoreMIDI wrapper that finds DL4 MkII output endpoints and sends to them.
/// Each USB-connected pedal shows up as its own destination, so `pedals[0]` is the
/// first pedal and `pedals[1]` the second once it's plugged in.
final class DL4Midi {
    private var client = MIDIClientRef()
    private var outPort = MIDIPortRef()

    /// Discovered DL4 endpoints, in CoreMIDI order.
    private(set) var pedals: [MIDIEndpointRef] = []

    init() {
        MIDIClientCreate("dl4-conductor" as CFString, nil, nil, &client)
        MIDIOutputPortCreate(client, "dl4-out" as CFString, &outPort)
        rescan()
    }

    /// (Re)discover destinations whose name mentions "DL4". Returns their names.
    @discardableResult
    func rescan() -> [String] {
        var found: [(name: String, ref: MIDIEndpointRef)] = []
        for i in 0..<MIDIGetNumberOfDestinations() {
            let ep = MIDIGetDestination(i)
            let name = Self.displayName(ep)
            if name.uppercased().contains("DL4") {
                found.append((name, ep))
            }
        }
        pedals = found.map(\.ref)
        return found.map(\.name)
    }

    /// Every MIDI destination name (for `list` / troubleshooting).
    func allDestinationNames() -> [String] {
        (0..<MIDIGetNumberOfDestinations()).map { Self.displayName(MIDIGetDestination($0)) }
    }

    private static func displayName(_ ep: MIDIEndpointRef) -> String {
        var nameRef: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(ep, kMIDIPropertyDisplayName, &nameRef) == noErr,
              let name = nameRef?.takeRetainedValue() else { return "(unknown)" }
        return name as String
    }

    // MARK: - Sending

    /// Send raw bytes to one pedal index (no-op if that pedal isn't present).
    func sendRaw(_ bytes: [UInt8], to index: Int) {
        guard pedals.indices.contains(index) else { return }
        send(bytes, to: pedals[index])
    }

    /// Send raw bytes to every connected pedal.
    func sendRawAll(_ bytes: [UInt8]) {
        for ep in pedals { send(bytes, to: ep) }
    }

    /// Control Change on channel 1 (status 0xB0).
    func cc(_ controller: UInt8, _ value: UInt8, to index: Int) {
        sendRaw([0xB0, controller, min(value, 127)], to: index)
    }

    func ccAll(_ controller: UInt8, _ value: UInt8) {
        sendRawAll([0xB0, controller, min(value, 127)])
    }

    /// Program Change on channel 1 (status 0xC0). 0 = preset A … 127 = preset 128.
    func programChange(_ program: UInt8, to index: Int) {
        sendRaw([0xC0, min(program, 127)], to: index)
    }

    // MARK: - MIDI realtime clock (single status bytes, broadcast to all pedals)

    func clockTick()  { sendRawAll([0xF8]) }
    func clockStart() { sendRawAll([0xFA]) }
    func clockStop()  { sendRawAll([0xFC]) }

    private func send(_ bytes: [UInt8], to dest: MIDIEndpointRef) {
        let bufSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buffer.deallocate() }
        let packetList = UnsafeMutableRawPointer(buffer).assumingMemoryBound(to: MIDIPacketList.self)
        var packet = MIDIPacketListInit(packetList)
        packet = MIDIPacketListAdd(packetList, bufSize, packet, 0, bytes.count, bytes)
        MIDISend(outPort, dest, packetList)
    }
}
