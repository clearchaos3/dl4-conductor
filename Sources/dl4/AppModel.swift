import Foundation
import SwiftUI

/// Observable state bridging the SwiftUI view to the MIDI engine.
final class AppModel: ObservableObject {
    let midi = DL4Midi()
    let midiIn = MidiInput()
    private lazy var looper = LooperControl(midi: midi)

    struct LearnTarget: Equatable { var pedal: Int; var action: PadAction }

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
        midiIn.onTrigger = { [weak self] t, pressed, vel in
            self?.handleTrigger(t, pressed: pressed, velocity: vel)
        }
    }

    // MARK: - Grid controller

    private func handleTrigger(_ t: MidiTrigger, pressed: Bool, velocity: UInt8) {
        if pressed { lastTrigger = t.label }
        if pressed, let target = learnTarget {
            bindings.removeAll { $0.trigger == t }          // one trigger → one binding
            bindings.append(PadBinding(trigger: t, pedal: target.pedal, action: target.action))
            learnTarget = nil
            return
        }
        guard gridEnabled else { return }
        for b in bindings where b.trigger == t {
            perform(b.action, pedal: b.pedal, pressed: pressed, velocity: velocity)
        }
    }

    func startLearn(pedal: Int, action: PadAction) {
        learnTarget = LearnTarget(pedal: pedal, action: action)
    }
    func cancelLearn() { learnTarget = nil }
    func removeBinding(_ id: UUID) { bindings.removeAll { $0.id == id } }
    func clearAllBindings() { bindings.removeAll() }
    func rescanMidiSources() {
        midiIn.connectAllSources()
        midiSources = midiIn.sourceNames()
    }

    /// Execute a pad action. Momentary actions also fire on release.
    private func perform(_ a: PadAction, pedal: Int, pressed: Bool, velocity: UInt8) {
        func cc(_ c: UInt8, _ v: UInt8) {
            if pedal < 0 { midi.ccAll(c, v) } else { midi.cc(c, v, to: pedal) }
        }
        func pc(_ p: UInt8) {
            if pedal < 0 { for i in midi.pedals.indices { midi.programChange(p, to: i) } }
            else { midi.programChange(p, to: pedal) }
        }
        let arg = UInt8(min(max(a.arg, 0), 127))
        switch a.kind {
        case .looper:      if pressed { looper.perform(a.looper, on: pedal) }
        case .delayModel:  if pressed { cc(CC.delayModel, arg) }
        case .reverbModel: if pressed { cc(CC.reverbModel, arg) }
        case .subdivision: if pressed { cc(CC.subdivision, arg) }
        case .preset:      if pressed { pc(arg) }
        case .tap:         if pressed { cc(CC.tapTempo, 127) }
        case .squeal:      cc(CC.feedback, pressed ? 127 : 55)
        case .kill:        cc(CC.bypass, pressed ? 127 : 0)
        case .fullWet:     cc(CC.mix, pressed ? 127 : 64)
        case .drop:        if pressed { looper.perform(.reverse, on: pedal); looper.perform(.half, on: pedal) }
        case .build:       if pressed { rampUp(pedal: pedal) }
        case .feedbackVel: if pressed { cc(CC.feedback, velocity) }
        case .mixVel:      if pressed { cc(CC.mix, velocity) }
        }
    }

    /// "Build": ramp feedback + mix up over ~2.5s.
    private func rampUp(pedal: Int) {
        let steps = 25
        for s in 0...steps {
            let v = UInt8(Double(s) / Double(steps) * 127)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(s) * 0.1) { [weak self] in
                guard let self else { return }
                if pedal < 0 { self.midi.ccAll(CC.feedback, v); self.midi.ccAll(CC.mix, v) }
                else { self.midi.cc(CC.feedback, v, to: pedal); self.midi.cc(CC.mix, v, to: pedal) }
            }
        }
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
