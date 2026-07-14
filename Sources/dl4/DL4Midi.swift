import Foundation
import CoreMIDI

/// A thin CoreMIDI wrapper that finds DL4 MkII output endpoints and sends to them.
/// Each USB-connected pedal shows up as its own destination, so `pedals[0]` is the
/// first pedal and `pedals[1]` the second once it's plugged in.
final class DL4Midi {
    private var client = MIDIClientRef()
    private var outPort = MIDIPortRef()

    /// Discovered DL4 endpoints, ordered by the saved pedal-order file (physical
    /// A…D layout) when present, falling back to CoreMIDI order for unknown uids.
    private(set) var pedals: [MIDIEndpointRef] = []
    /// CoreMIDI unique IDs, index-aligned with `pedals`. UIDs persist per device
    /// across replugs and reboots — that's what keeps the A…D labels stable.
    private(set) var pedalUIDs: [Int32] = []

    /// Physical-order file shared by the CLI and the app (their UserDefaults
    /// domains differ, so a plain file it is).
    static let orderURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/dl4-conductor/pedal-order.json")

    /// Fired on the main thread whenever CoreMIDI's device list changes
    /// (pedal plugged/unplugged) — after an automatic rescan.
    var onSetupChanged: (() -> Void)?

    init() {
        MIDIClientCreateWithBlock("dl4-conductor" as CFString, &client) { [weak self] notification in
            guard notification.pointee.messageID == .msgSetupChanged else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                self.rescan()
                self.onSetupChanged?()
            }
        }
        MIDIOutputPortCreate(client, "dl4-out" as CFString, &outPort)
        rescan()
    }

    /// Pedals currently reachable (slots with a live endpoint).
    var presentCount: Int { pedals.filter { $0 != 0 }.count }
    func isPresent(_ index: Int) -> Bool { pedals.indices.contains(index) && pedals[index] != 0 }

    static func savedOrder() -> [Int32] {
        (try? JSONDecoder().decode([Int32].self, from: Data(contentsOf: orderURL))) ?? []
    }

    static func savePedalOrder(_ uids: [Int32]) {
        try? FileManager.default.createDirectory(
            at: orderURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(uids).write(to: orderURL)
    }

    /// (Re)discover destinations whose name mentions "DL4". Returns their names.
    @discardableResult
    func rescan() -> [String] {
        var found: [(name: String, ref: MIDIEndpointRef, uid: Int32)] = []
        for i in 0..<MIDIGetNumberOfDestinations() {
            let ep = MIDIGetDestination(i)
            let name = Self.displayName(ep)
            if name.uppercased().contains("DL4") {
                var uid: Int32 = 0
                MIDIObjectGetIntegerProperty(ep, kMIDIPropertyUniqueID, &uid)
                found.append((name, ep, uid))
            }
        }
        let order = Self.savedOrder()
        if order.isEmpty {
            pedals = found.map(\.ref)
            pedalUIDs = found.map(\.uid)
            return found.map(\.name)
        }
        // Slot model: each saved uid owns a fixed slot (A…D). A missing pedal
        // leaves an EMPTY slot (ref 0) rather than compacting — otherwise the
        // letters shift and the grid starts controlling the wrong pedal.
        var refs: [MIDIEndpointRef] = []
        var uids: [Int32] = []
        var names: [String] = []
        var claimed = Set<Int32>()
        for uid in order {
            if let f = found.first(where: { $0.uid == uid }) {
                refs.append(f.ref); uids.append(uid); names.append(f.name)
                claimed.insert(uid)
            } else {
                refs.append(0); uids.append(uid); names.append("(unplugged)")
            }
        }
        // New pedals that aren't in the saved order go after the fixed slots.
        for f in found where !claimed.contains(f.uid) {
            refs.append(f.ref); uids.append(f.uid); names.append(f.name)
        }
        pedals = refs
        pedalUIDs = uids
        return names
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
        guard pedals.indices.contains(index), pedals[index] != 0 else { return }
        send(bytes, to: pedals[index])
    }

    /// Send raw bytes to every connected pedal.
    func sendRawAll(_ bytes: [UInt8]) {
        for ep in pedals where ep != 0 { send(bytes, to: ep) }
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
