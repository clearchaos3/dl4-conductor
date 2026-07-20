import Foundation
import CoreMIDI

/// MF64 color velocities (from the Midi Fighter 64 user guide — velocity selects color,
/// 0 disables color control). These are best-effort anchors on the device's color wheel;
/// if a color looks off on real hardware, tweak the number here — that's the only change.
enum LEDColor {
    static let off: UInt8 = 0
    static let dim: UInt8 = 1
    static let red: UInt8 = 5
    static let dimRed: UInt8 = 3
    static let amber: UInt8 = 11
    static let green: UInt8 = 37
    static let dimGreen: UInt8 = 35
    static let blue: UInt8 = 50
    static let dimBlue: UInt8 = 48
    static let purple: UInt8 = 58
}

/// Sends LED color messages to a grid controller (e.g. Midi Fighter 64) by writing Note On
/// back to it on the pad's own note + channel.
final class ControllerLED {
    private var client = MIDIClientRef()
    private var outPort = MIDIPortRef()
    /// Case-insensitive substring used to find the controller's destination endpoint.
    var nameMatch = "fighter"

    init() {
        MIDIClientCreate("dl4-led" as CFString, nil, nil, &client)
        MIDIOutputPortCreate(client, "dl4-led-out" as CFString, &outPort)
    }

    var isPresent: Bool { destination() != nil }

    private func destination() -> MIDIEndpointRef? {
        for i in 0..<MIDIGetNumberOfDestinations() {
            let ep = MIDIGetDestination(i)
            var nameRef: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(ep, kMIDIPropertyDisplayName, &nameRef)
            let name = (nameRef?.takeRetainedValue() as String?)?.lowercased() ?? ""
            if name.contains(nameMatch) { return ep }
        }
        return nil
    }

    /// Set one pad's color. `channel` is 0-based (matches the trigger we captured).
    func setColor(note: UInt8, channel: UInt8, velocity: UInt8) {
        guard let dest = destination() else { return }
        send([0x90 | (channel & 0x0F), note, velocity], to: dest)
    }

    private func send(_ bytes: [UInt8], to dest: MIDIEndpointRef) {
        let bufSize = 256
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buffer.deallocate() }
        let packetList = UnsafeMutableRawPointer(buffer).assumingMemoryBound(to: MIDIPacketList.self)
        var packet = MIDIPacketListInit(packetList)
        packet = MIDIPacketListAdd(packetList, bufSize, packet, 0, bytes.count, bytes)
        MIDISend(outPort, dest, packetList)
    }
}

/// What the app believes each pedal's looper/effect state is (the DL4 reports nothing back,
/// so we infer it from the commands we send).
enum LoopPhase { case empty, recording, overdub, playing, stopped }

struct PedalState {
    var loop: LoopPhase = .empty
    var reverse = false
    var halfSpeed = false
    var delayModel: Int?
    var subdivision: Int?
    // Inferred loop timing, measured from our own record/play sends. The pedal
    // reports nothing, so this exists only for pad-initiated loops.
    var loopLength: Double?
    var cycleAnchor: Date?
    var recordStart: Date?

    /// One playback pass, accounting for half-speed doubling the period.
    var effectiveLength: Double? {
        loopLength.map { $0 * (halfSpeed ? 2 : 1) }
    }
}
