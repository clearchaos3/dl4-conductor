import Foundation
import SwiftUI

/// Grid for quantized looper triggers — fire on the next beat or the next bar.
enum QuantizeGrid: String, CaseIterable, Identifiable {
    case beat = "Beat", bar = "Bar"
    var id: String { rawValue }
}

/// Observable state bridging the SwiftUI view to the MIDI engine.
final class AppModel: ObservableObject {
    let midi = DL4Midi()
    let midiIn = MidiInput()
    private lazy var looper = LooperControl(midi: midi)

    struct LearnTarget: Equatable { var pedal: Int; var action: PadAction }

    @Published var pedalNames: [String] = []
    @Published var status = ""

    @Published var bpm: Double = 132 { didSet { conductor?.setBPM(bpm); quantizeClock?.bpm = bpm; if !syncExternal { reconfigureClock() } } }
    @Published var isConducting = false
    @Published var conductorLine = ""
    @Published var currentBar = -1

    /// Per-bar subdivision patterns (one per pedal, A…D), editable live.
    @Published var sequences: [[Subdivision]] = Conductor.defaultSequences {
        didSet { conductor?.sequences = sequences }
    }
    /// Phase-offset the feedback LFO per pedal so sweeps ripple across pedals instead
    /// of breathing in unison. Off by default to keep the classic 2-pedal behavior.
    @Published var lfoStaggered = false {
        didSet { conductor?.lfoStaggered = lfoStaggered }
    }

    @Published var looperModeOn = false
    @Published var remoteOn = false
    @Published var remoteURL = ""

    // Grid controller (Midi Fighter etc.)
    let led = ControllerLED()
    @Published var gridEnabled = true
    @Published var ledEnabled = true { didSet { refreshLEDs() } }
    @Published var bindings: [PadBinding] = [] { didSet { saveBindings(); refreshLEDs() } }
    @Published var learnTarget: LearnTarget?
    @Published var lastTrigger = ""
    @Published var midiSources: [String] = []

    @Published private(set) var pedalStates = Array(repeating: PedalState(), count: 4)

    /// Looper phase the app believes a pedal is in (for the pedal renders).
    func loopPhase(pedal: Int) -> LoopPhase {
        pedalStates.indices.contains(pedal) ? pedalStates[pedal].loop : .empty
    }
    @Published private(set) var heldTriggers = Set<MidiTrigger>()
    private var litTriggers = Set<MidiTrigger>()

    // Quantize: hold looper triggers and fire them on the next grid boundary.
    @Published var quantizeEnabled = false { didSet { reconfigureClock() } }
    @Published var quantizeGrid: QuantizeGrid = .bar
    @Published var quantizeBeatsPerBar = 4
    @Published var pendingCount = 0
    // Sync + retrigger
    @Published var syncExternal = false { didSet { reconfigureClock() } }   // follow Ableton's MIDI clock
    @Published var retriggerEnabled = false { didSet { reconfigureClock() } } // re-fire loops each cycle
    @Published var loopBars = 4
    @Published var activePedals: Set<Int> = []                              // loops being kept in sync
    @Published var clockStatus = "off"
    private var quantizeClock: MidiClock?
    private var externalPulse = 0
    private var pendingActions: [(action: PadAction, pedal: Int)] = []
    private var pendingTriggers = Set<MidiTrigger>()

    private var conductor: Conductor?
    private var server: WebServer?
    private let bindingsKey = "gridBindings"

    var pedalCount: Int { pedalNames.count }
    /// How many pedals the grid lets you address individually (A…D), at least 2 so you can
    /// pre-map before the others arrive, capped at 4.
    var addressablePedals: Int { min(max(pedalCount, 2), 4) }
    var midiSourceSummary: String { midiSources.isEmpty ? "no sources" : midiSources.joined(separator: ", ") }

    /// Turn one pedal's TAP footswitch LED BLUE for a few seconds so you can tell
    /// identical DL4s apart. Per the manual, the TAP LED goes blue while synced to
    /// MIDI Clock — which requires a clock START; bare ticks are ignored.
    /// Side effect: clock sync nudges that pedal's delay tempo; re-tap if needed.
    func identify(pedal: Int) {
        guard midi.isPresent(pedal) else { return }
        let midi = self.midi
        DispatchQueue.global().async {
            midi.sendRaw([0xFA], to: pedal)          // start → LED blue
            let interval = 60.0 / 120.0 / 24.0
            for _ in 0..<Int(4.0 / interval) {
                midi.sendRaw([0xF8], to: pedal)
                usleep(UInt32(interval * 1_000_000))
            }
            midi.sendRaw([0xFC], to: pedal)          // stop → LED back to red
        }
    }

    init() {
        rescan()
        loadBindings()
        midiSources = midiIn.sourceNames()
        // MIDI callbacks arrive on CoreMIDI's thread; published state must
        // mutate on the main thread for SwiftUI.
        midiIn.onTrigger = { [weak self] t, pressed, vel in
            DispatchQueue.main.async { self?.handleTrigger(t, pressed: pressed, velocity: vel) }
        }
        midiIn.onClock = { [weak self] m in self?.handleClock(m) }
        // Hot-plug: refresh state (and reconnect input sources) whenever
        // CoreMIDI's device list changes — no manual Rescan needed.
        midi.onSetupChanged = { [weak self] in
            self?.rescan()
            self?.rescanMidiSources()
        }
    }

    /// Pedals that are actually reachable right now (slots can be unplugged).
    var presentPedals: Int { midi.presentCount }

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
        if pressed { heldTriggers.insert(t) } else { heldTriggers.remove(t) }
        for b in bindings where b.trigger == t {
            if pressed, quantizeEnabled, b.action.isLooperTiming {
                pendingActions.append((b.action, b.pedal))   // fire on the next grid boundary
                pendingTriggers.insert(t)
                pendingCount = pendingActions.count
            } else {
                perform(b.action, pedal: b.pedal, pressed: pressed, velocity: velocity)
                updateState(b.action, pedal: b.pedal, pressed: pressed)
            }
        }
        refreshLEDs()
    }

    // MARK: - Quantize clock

    /// Decide which clock (external Ableton vs internal) drives the grid, and reflect status.
    private func reconfigureClock() {
        let need = quantizeEnabled || retriggerEnabled
        if syncExternal {
            quantizeClock?.stop(); quantizeClock = nil
            clockStatus = need ? "waiting for Ableton clock…" : "external (idle)"
        } else if need {
            if quantizeClock == nil {
                let c = MidiClock(midi: midi, bpm: bpm, sendsClock: false)
                c.onPulse = { [weak self] pulse in DispatchQueue.main.async { self?.gridPulse(pulse) } }
                c.start(); quantizeClock = c
            } else { quantizeClock?.bpm = bpm }
            clockStatus = "internal \(Int(bpm)) BPM"
        } else {
            quantizeClock?.stop(); quantizeClock = nil
            DispatchQueue.main.async { [weak self] in self?.flushPending() }
            clockStatus = "off"
        }
    }

    /// Incoming Ableton clock (main thread).
    private func handleClock(_ m: MidiInput.ClockMsg) {
        switch m {
        case .start, .cont:
            externalPulse = 0
            if syncExternal { clockStatus = "Ableton clock ▶" }
        case .stop:
            if syncExternal { clockStatus = "Ableton clock ■" }
        case .tick:
            guard syncExternal else { return }
            gridPulse(externalPulse)
            externalPulse += 1
        }
    }

    /// One 24-PPQN pulse of whichever clock is active: flush quantized hits + retrigger loops.
    private func gridPulse(_ pulse: Int) {
        let ppb = 24 * max(quantizeBeatsPerBar, 1)
        if quantizeEnabled {
            let unit = quantizeGrid == .beat ? 24 : ppb
            if pulse % unit == 0 { flushPending() }
        }
        if retriggerEnabled, !activePedals.isEmpty {
            let cycle = max(loopBars, 1) * ppb
            if pulse % cycle == 0 { for p in activePedals { looper.perform(.once, on: p) } }  // re-fire from bar 1
        }
    }

    private func flushPending() {
        guard !pendingActions.isEmpty else { return }
        let items = pendingActions
        pendingActions.removeAll()
        pendingTriggers.removeAll()
        pendingCount = 0
        for item in items {
            perform(item.action, pedal: item.pedal, pressed: true, velocity: 127)
            updateState(item.action, pedal: item.pedal, pressed: true)
        }
        refreshLEDs()
    }

    /// Track inferred state so LEDs can reflect it (DL4 sends nothing back).
    private func updateState(_ a: PadAction, pedal: Int, pressed: Bool) {
        guard pressed else { return }
        let targets = pedal < 0 ? Array(pedalStates.indices) : [pedal]
        for p in targets where pedalStates.indices.contains(p) {
            switch a.kind {
            case .looper:
                switch a.looper {
                case .record:  pedalStates[p].loop = .recording; activePedals.insert(p)
                case .overdub: pedalStates[p].loop = .overdub;   activePedals.insert(p)
                case .play, .once: pedalStates[p].loop = .playing; activePedals.insert(p)
                case .stop:    pedalStates[p].loop = .stopped;    activePedals.remove(p)
                case .reverse: pedalStates[p].reverse = true
                case .forward: pedalStates[p].reverse = false
                case .half:    pedalStates[p].halfSpeed = true
                case .full:    pedalStates[p].halfSpeed = false
                case .undo, .redo: break
                }
            case .delayModel:  pedalStates[p].delayModel = a.arg
            case .subdivision: pedalStates[p].subdivision = a.arg
            default: break
            }
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
        refreshLEDs()
    }

    // MARK: - LED feedback

    func refreshLEDs() {
        var current = Set<MidiTrigger>()
        if ledEnabled {
            for b in bindings where b.trigger.kind == .note {
                current.insert(b.trigger)
                led.setColor(note: b.trigger.data1, channel: b.trigger.channel,
                             velocity: ledColor(for: b))
            }
        }
        // Turn off pads that are no longer lit (unmapped, or LEDs disabled).
        for old in litTriggers.subtracting(current) {
            led.setColor(note: old.data1, channel: old.channel, velocity: LEDColor.off)
        }
        litTriggers = current
    }

    private func ledColor(for b: PadBinding) -> UInt8 {
        if pendingTriggers.contains(b.trigger) { return LEDColor.amber }   // armed, waiting for the grid
        let st = pedalStates[b.pedal < 0 ? 0 : min(b.pedal, pedalStates.count - 1)]
        let held = heldTriggers.contains(b.trigger)
        switch b.action.kind {
        case .looper:
            switch b.action.looper {
            case .record:  return st.loop == .recording ? LEDColor.red : LEDColor.dimRed
            case .overdub: return st.loop == .overdub ? LEDColor.amber : LEDColor.dim
            case .play, .once: return st.loop == .playing ? LEDColor.green : LEDColor.dimGreen
            case .stop:    return st.loop == .stopped ? LEDColor.green : LEDColor.dim
            case .reverse: return st.reverse ? LEDColor.amber : LEDColor.dim
            case .forward: return st.reverse ? LEDColor.dim : LEDColor.amber
            case .half:    return st.halfSpeed ? LEDColor.blue : LEDColor.dim
            case .full:    return st.halfSpeed ? LEDColor.dim : LEDColor.blue
            case .undo, .redo: return LEDColor.dim
            }
        case .delayModel:  return st.delayModel == b.action.arg ? LEDColor.green : LEDColor.dimBlue
        case .reverbModel: return LEDColor.dimBlue
        case .subdivision: return st.subdivision == b.action.arg ? LEDColor.green : LEDColor.dimBlue
        case .preset:      return LEDColor.purple
        case .tap:         return LEDColor.amber
        case .squeal, .kill, .fullWet: return held ? LEDColor.red : LEDColor.dimRed
        case .drop, .build: return LEDColor.purple
        case .feedbackVel, .mixVel: return LEDColor.blue
        case .reverseToggle: return st.reverse ? LEDColor.amber : LEDColor.dim
        case .halfToggle:    return st.halfSpeed ? LEDColor.blue : LEDColor.dim
        }
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
        case .looper:
            if pressed {
                // "Once" is a choke group: only one DL4 speaks at a time
                if a.looper == .once && pedal >= 0 { choke(except: pedal) }
                looper.perform(a.looper, on: pedal)
            }
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
        case .reverseToggle: if pressed { toggle(\.reverse, cc: CC.Looper.forwardReverse, pedal: pedal) }
        case .halfToggle:    if pressed { toggle(\.halfSpeed, cc: CC.Looper.fullHalf, pedal: pedal) }
        }
    }

    /// Choke group: stop every other pedal's loop so only the chosen one plays.
    /// Stops are sent to all present pedals (not just the ones we believe are
    /// playing) because the DL4 reports nothing back — belief can be stale if
    /// footswitches were used directly.
    private func choke(except pedal: Int) {
        for p in midi.pedals.indices where p != pedal && midi.isPresent(p) {
            looper.perform(.stop, on: p)
            if pedalStates.indices.contains(p), pedalStates[p].loop != .empty {
                pedalStates[p].loop = .stopped
            }
            activePedals.remove(p)
        }
        refreshLEDs()
    }

    /// Flip a per-pedal boolean state and send the matching CC (64-127 on, 0 off).
    private func toggle(_ key: WritableKeyPath<PedalState, Bool>, cc: UInt8, pedal: Int) {
        let targets = pedal < 0 ? Array(midi.pedals.indices) : [pedal]
        for p in targets where pedalStates.indices.contains(p) {
            let on = !pedalStates[p][keyPath: key]
            midi.cc(cc, on ? 127 : 0, to: p)
            pedalStates[p][keyPath: key] = on
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
        if midi.presentCount == 0 {
            status = "No DL4 detected — connect USB-C and power the pedal on."
        } else {
            status = pedalNames.enumerated().map { i, n in
                let letter = i < Conductor.pedalLetters.count ? Conductor.pedalLetters[i] : "\(i + 1)"
                return "\(letter) \(n == "(unplugged)" ? "✕" : "✓")"
            }.joined(separator: "   ")
        }
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
        c.sequences = sequences
        c.lfoStaggered = lfoStaggered
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
    func addStep(pedal: Int) {
        guard sequences.indices.contains(pedal), sequences[pedal].count < 8 else { return }
        sequences[pedal].append(.quarter)
    }
    func removeStep(pedal: Int) {
        guard sequences.indices.contains(pedal), sequences[pedal].count > 1 else { return }
        sequences[pedal].removeLast()
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
