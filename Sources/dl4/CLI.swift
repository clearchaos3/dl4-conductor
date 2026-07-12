import Foundation

/// Terminal interface — handy for quick testing without the GUI.
enum CLI {
    static func run(_ command: String) {
        let midi = DL4Midi()

        switch command {
        case "list":
            let dests = midi.allDestinationNames()
            print("MIDI destinations (\(dests.count)):")
            for (i, n) in dests.enumerated() { print("  [\(i)] \(n)") }
            let pedals = midi.rescan()
            print("\nDetected DL4 pedals (\(pedals.count)):")
            if pedals.isEmpty {
                print("  none — is the USB-C cable connected and the pedal powered?")
            } else {
                for (i, n) in pedals.enumerated() { print("  pedal[\(i)] -> \(n)") }
            }

        case "test":
            guard !midi.pedals.isEmpty else { print("No DL4 found. Run `dl4 list`."); exit(1) }
            // The MkII has no LED rings on its knobs — the visible MIDI-reachable
            // indicator is the TAP footswitch LED, which blinks at the current
            // tempo and follows MIDI clock.
            print("Watch the TAP footswitch LED on \(midi.pedals.count) pedal(s):")
            print("  ~4s FAST flutter (240 BPM) then ~4s slow pulse (75 BPM), twice.")
            for _ in 0..<2 {
                for (bpm, secs) in [(240.0, 4.0), (75.0, 4.0)] {
                    let interval = 60.0 / bpm / 24.0
                    for _ in 0..<Int(secs / interval) {
                        midi.clockTick()
                        usleep(UInt32(interval * 1_000_000))
                    }
                }
            }
            print("Done. (MIDI clock nudges the pedals' delay tempo — re-tap if you had one set.)")

        case "blink":
            // Visibility test for pedals sitting in Looper mode (where the TAP LED
            // doesn't track MIDI clock): pulse Record red 3x, undoing each blip.
            guard !midi.pedals.isEmpty else { print("No DL4 found. Run `dl4 list`."); exit(1) }
            let looper = LooperControl(midi: midi)
            print("Blinking the looper RECORD LED 3x on \(midi.pedals.count) pedal(s)… watch for red.")
            for _ in 0..<3 {
                looper.record()
                usleep(500_000)
                looper.stop()
                usleep(150_000)
                looper.undo()
                usleep(350_000)
            }
            print("Done. (Each blip was stopped and undone — no loop left behind.)")

        case "conduct":
            guard !midi.pedals.isEmpty else { print("No DL4 found. Run `dl4 list`."); exit(1) }
            let bpm = Double(argValue("--bpm") ?? "") ?? 132
            print("Conducting \(midi.pedals.count) pedal(s) at \(Int(bpm)) BPM. Ctrl-C to stop.\n")
            let conductor = Conductor(midi: midi, bpm: bpm)
            signal(SIGINT) { _ in
                print("\nStopping clock.")
                exit(0)
            }
            conductor.run()
            RunLoop.main.run()

        case "loop":
            guard !midi.pedals.isEmpty else { print("No DL4 found. Run `dl4 list`."); exit(1) }
            let port = UInt16(argValue("--port") ?? "") ?? 8888
            let looper = LooperControl(midi: midi)
            looper.enterLooperMode()
            do {
                let server = try WebServer(port: port, html: LooperPage.html) { looper.command($0) }
                server.start()
                let ip = LocalNetwork.primaryIPv4() ?? "<your-mac-ip>"
                print("Looper mode on for \(midi.pedals.count) pedal(s).")
                print("On your phone (same Wi-Fi), open:  http://\(ip):\(port)")
                print("Ctrl-C to stop.")
                RunLoop.main.run()
            } catch {
                print("Could not start web server on port \(port): \(error)")
                exit(1)
            }

        default:
            usage()
        }
    }

    private static func usage() {
        print("""
        dl4 — DL4 MkII conductor & looper remote

        USAGE:
          dl4                     Launch the app (also happens when double-clicked)
          dl4 list                Show MIDI destinations and detected pedals
          dl4 test                Flutter the TAP LED to confirm MIDI reaches the pedal
          dl4 blink               Pulse the looper RECORD LED 3x (for pedals in Looper mode)
          dl4 conduct [--bpm N]   Run the tempo-locked delay conductor (default 132)
          dl4 loop [--port N]     Looper mode + phone remote (default 8888)

        For `conduct`: set DL4 Global Settings ▸ Receive MIDI Clock to Auto or On (Auto is the factory default).
        """)
    }

    private static func argValue(_ name: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
