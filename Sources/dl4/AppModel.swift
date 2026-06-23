import Foundation
import SwiftUI

/// Observable state bridging the SwiftUI view to the MIDI engine.
final class AppModel: ObservableObject {
    let midi = DL4Midi()
    private lazy var looper = LooperControl(midi: midi)

    @Published var pedalNames: [String] = []
    @Published var status = ""

    @Published var bpm: Double = 132 { didSet { conductor?.setBPM(bpm) } }
    @Published var isConducting = false
    @Published var conductorLine = ""

    @Published var looperModeOn = false
    @Published var remoteOn = false
    @Published var remoteURL = ""

    private var conductor: Conductor?
    private var server: WebServer?

    var pedalCount: Int { pedalNames.count }

    init() { rescan() }

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
        c.onBar = { [weak self] _, line in
            DispatchQueue.main.async { self?.conductorLine = line }
        }
        c.run()
        conductor = c
        isConducting = true
    }

    func stopConducting() {
        conductor?.stop(); conductor = nil
        isConducting = false
        conductorLine = ""
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
