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
            print("Sweeping the Mix knob (CC16) on \(midi.pedals.count) pedal(s)… watch the knob ring light.")
            for v in stride(from: 0, through: 127, by: 1) {
                midi.ccAll(CC.mix, UInt8(v))
                usleep(15_000)
            }
            midi.ccAll(CC.mix, 64)
            print("Done.")

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
          dl4 test                Sweep the Mix knob to confirm MIDI reaches the pedal
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
