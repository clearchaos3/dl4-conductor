import Foundation
import SwiftUI

/// Observable state bridging the SwiftUI view to the MIDI engine.
final class AppModel: ObservableObject {
    let midi = DL4Midi()
    let midiIn = MidiInput()
    private lazy var looper = LooperControl(midi: midi)

    struct LearnTarget: Equatable { var pedal: Int; var function: LooperFunction }

    @Published var pedalNames: [String] = []
    @Published var status = ""

    @Published var bpm: Double = 132 { didSet { conductor?.setBPM(bpm) } }
    @Published var isConducting = false
    @Published var conductorLine = ""
    @Published var currentBar = -1

    /// Per-bar subdivision patterns, editable live.
    @Published var sequenceA: [Subdivision] = [.dottedEighth, .dottedEighth, .quarterTriplet, .eighth] {
        didSet { conductor?.sequenceA = sequenceA }
    }
    @Published var sequenceB: [Subdivision] = [.quarterTriplet, .eighth, .dottedEighth, .dottedEighth] {
        didSet { conductor?.sequenceB = sequenceB }
    }

    @Published var looperModeOn = false
    @Published var remoteOn = false
    @Published var remoteURL = ""

    // Grid controller (Midi Fighter etc.)
    @Published var gridEnabled = true
    @Published var bindings: [PadBinding] = [] { didSet { saveBindings() } }
    @Published var learnTarget: LearnTarget?
    @Published var lastTrigger = ""
    @Published var midiSources: [String] = []

    private var conductor: Conductor?
    private var server: WebServer?
    private let bindingsKey = "gridBindings"

    var pedalCount: Int { pedalNames.count }
    var midiSourceSummary: String { midiSources.isEmpty ? "no sources" : midiSources.joined(separator: ", ") }

    init() {
        rescan()
        loadBindings()
        midiSources = midiIn.sourceNames()
        midiIn.onTrigger = { [weak self] trigger in self?.handleTrigger(trigger) }
    }

    // MARK: - Grid controller

    private func handleTrigger(_ t: MidiTrigger) {
        lastTrigger = t.label
        if let target = learnTarget {
            // Assign: replace any existing binding for this cell or this trigger.
            bindings.removeAll { ($0.pedal == target.pedal && $0.function == target.function) || $0.trigger == t }
            bindings.append(PadBinding(trigger: t, pedal: target.pedal, function: target.function))
            learnTarget = nil
            return
        }
        guard gridEnabled, let b = bindings.first(where: { $0.trigger == t }) else { return }
        looper.perform(b.function, on: b.pedal)
    }

    func arm(pedal: Int, function: LooperFunction) {
        learnTarget = LearnTarget(pedal: pedal, function: function)
    }
    func cancelLearn() { learnTarget = nil }
    func isArming(pedal: Int, function: LooperFunction) -> Bool {
        learnTarget == LearnTarget(pedal: pedal, function: function)
    }
    func binding(pedal: Int, function: LooperFunction) -> PadBinding? {
        bindings.first { $0.pedal == pedal && $0.function == function }
    }
    func clearBinding(pedal: Int, function: LooperFunction) {
        bindings.removeAll { $0.pedal == pedal && $0.function == function }
    }
    func rescanMidiSources() {
        midiIn.connectAllSources()
        midiSources = midiIn.sourceNames()
    }

    private func saveBindings() {
        if let data = try? JSONEncoder().encode(bindings) {
            UserDefaults.standard.set(data, forKey: bindingsKey)
        }
    }
    private func loadBindings() {
        if let data = UserDefaults.standard.data(forKey: bindingsKey),
           let decoded = try? JSONDecoder().decode([PadBinding].self, from: data) {
            bindings = decoded
        }
    }

    func rescan() {
        pedalNames = midi.rescan()
        status = pedalNames.isEmpty
            ? "No DL4 detected — connect USB-C and power the pedal on."
            : "Connected: \(pedalNames.joined(separator: ", "))"
    }

    // MARK: - Test

    func testSweep() {
        guard !midi.pedals.isEmpty else { return }
        let midi = self.midi
        DispatchQueue.global().async {
            for v in stride(from: 0, through: 127, by: 1) {
                midi.ccAll(CC.mix, UInt8(v)); usleep(12_000)
            }
            midi.ccAll(CC.mix, 64)
        }
    }

    // MARK: - Conductor

    func toggleConducting() { isConducting ? stopConducting() : startConducting() }

    func startConducting() {
        guard !midi.pedals.isEmpty else { return }
        if remoteOn { stopRemote() }
        if looperModeOn { looper.exitLooperMode(); looperModeOn = false }
        let c = Conductor(midi: midi, bpm: bpm)
        c.sequenceA = sequenceA
        c.sequenceB = sequenceB
        c.onBar = { [weak self] bar, line in
            DispatchQueue.main.async {
                self?.conductorLine = line
                self?.currentBar = bar
            }
        }
        c.run()
        conductor = c
        isConducting = true
    }

    func stopConducting() {
        conductor?.stop(); conductor = nil
        isConducting = false
        conductorLine = ""
        currentBar = -1
    }

    // Edit the patterns (clamped to 1...8 steps).
    func addStep(toB: Bool) {
        if toB { if sequenceB.count < 8 { sequenceB.append(.quarter) } }
        else   { if sequenceA.count < 8 { sequenceA.append(.quarter) } }
    }
    func removeStep(fromB: Bool) {
        if fromB { if sequenceB.count > 1 { sequenceB.removeLast() } }
        else     { if sequenceA.count > 1 { sequenceA.removeLast() } }
    }

    // MARK: - Looper

    func setLooperMode(_ on: Bool) {
        looperModeOn = on
        if on {
            if isConducting { stopConducting() }
            looper.enterLooperMode()
        } else {
            looper.exitLooperMode()
            if remoteOn { stopRemote() }
        }
    }

    func looperCommand(_ name: String) { _ = looper.command(name) }

    // MARK: - Phone remote

    func setRemote(_ on: Bool) { on ? startRemote() : stopRemote() }

    private func startRemote() {
        guard !midi.pedals.isEmpty else { return }
        if isConducting { stopConducting() }
        if !looperModeOn { setLooperMode(true) }
        do {
            let s = try WebServer(port: 8888, html: LooperPage.html) { [weak self] action in
                self?.looper.command(action) ?? false
            }
            s.start()
            server = s
            let ip = LocalNetwork.primaryIPv4() ?? "<your-mac-ip>"
            remoteURL = "http://\(ip):8888"
            remoteOn = true
        } catch {
            status = "Couldn't start remote: \(error.localizedDescription)"
            remoteOn = false
        }
    }

    private func stopRemote() {
        server?.stop(); server = nil
        remoteOn = false
        remoteURL = ""
    }
}
