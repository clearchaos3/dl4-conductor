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
                let letters = Conductor.pedalLetters
                let saved = DL4Midi.savedOrder()
                for (i, n) in pedals.enumerated() {
                    let uid = midi.pedalUIDs[i]
                    let label = i < saved.count && i < letters.count ? " (\(letters[i]))" : ""
                    print("  pedal[\(i)]\(label) -> \(n)  uid=\(uid)")
                }
            }

        case "test":
            guard !midi.pedals.isEmpty else { print("No DL4 found. Run `dl4 list`."); exit(1) }
            // The MkII has no LED rings on its knobs — the visible MIDI-reachable
            // indicator is the TAP footswitch LED, which blinks at the current
            // tempo and follows MIDI clock.
            print("Watch the TAP footswitch LEDs on \(midi.pedals.count) pedal(s):")
            print("  they turn BLUE (clock sync), flutter fast, pulse slow, then go red again.")
            midi.clockStart()   // required — pedals ignore bare ticks without a start
            for _ in 0..<2 {
                for (bpm, secs) in [(240.0, 4.0), (75.0, 4.0)] {
                    let interval = 60.0 / bpm / 24.0
                    for _ in 0..<Int(secs / interval) {
                        midi.clockTick()
                        usleep(UInt32(interval * 1_000_000))
                    }
                }
            }
            midi.clockStop()
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

        case "identify":
            // Sequential roll call: exactly one pedal's TAP LED races at a time
            // (fast clock to that pedal only), then a slow burst calms it back
            // down before the next pedal starts. Delay-mode friendly.
            guard !midi.pedals.isEmpty else { print("No DL4 found. Run `dl4 list`."); exit(1) }
            // Per the manual: the TAP LED turns BLUE only once the pedal receives
            // a MIDI Clock START and syncs; bare ticks are ignored. So identify =
            // start + clock to ONE pedal (its TAP goes blue), then stop (back to red).
            print("Identify: the target pedal's TAP LED turns BLUE while it's synced.")
            func syncBlue(pedal: Int, seconds: Double, bpm: Double = 120) {
                midi.sendRaw([0xFA], to: pedal)          // clock start → LED goes blue
                let interval = 60.0 / bpm / 24.0
                for _ in 0..<Int(seconds / interval) {
                    midi.sendRaw([0xF8], to: pedal)
                    usleep(UInt32(interval * 1_000_000))
                }
                midi.sendRaw([0xFC], to: pedal)          // clock stop → back to red
            }
            if let idxStr = argValue("--pedal"), let idx = Int(idxStr) {
                guard midi.pedals.indices.contains(idx) else { print("No pedal[\(idx)]."); exit(1) }
                print("  pedal[\(idx)] BLUE for 20s…")
                syncBlue(pedal: idx, seconds: 20)
            } else {
                for i in midi.pedals.indices {
                    guard midi.isPresent(i) else { print("  pedal[\(i)] unplugged — skipping"); continue }
                    print("  pedal[\(i)] BLUE now…")
                    syncBlue(pedal: i, seconds: 6)
                    sleep(2)
                }
            }
            print("\nDone. (Clock sync nudges tempo — re-tap to taste.)")

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

        case "zero":
            guard !midi.pedals.isEmpty else { print("No DL4 found. Run `dl4 list`."); exit(1) }
            let present = midi.pedals.indices.filter { midi.isPresent($0) }
            midi.zeroAll()
            let letters = present.map { Conductor.pedalLetters[$0] }.joined(separator: ", ")
            print("Zeroed \(present.count) pedal(s): \(letters)")
            print("""

            Sent to each: bypass OFF, mix 50%, repeats moderate, forward, full speed.
            This clears stuck performance-pad states (a lost Kill release leaves a
            pedal bypassed, and a bypassed DL4 ignores looper record entirely).

            Note: these values now override the physical knobs. Wiggle any knob to
            hand that parameter back to the hardware.
            """)

        case "doctor":
            // Interactive per-pedal looper checkup, entirely user-paced (press
            // Enter to advance; no timed windows). Separates MIDI-path failures
            // (record LED never lights) from audio-path failures (LED lights but
            // no loop heard).
            guard !midi.pedals.isEmpty else { print("No DL4 found. Run `dl4 list`."); exit(1) }
            let positions = ["bottom-right", "bottom-left", "top-right (silver)", "top-left (silver)"]
            func ask(_ q: String) -> Bool {
                while true {
                    print("\(q) [y/n] ", terminator: "")
                    guard let a = readLine()?.lowercased() else { return false }
                    if a.hasPrefix("y") { return true }
                    if a.hasPrefix("n") { return false }
                }
            }
            func pause(_ msg: String) {
                print(msg, terminator: "")
                _ = readLine()
            }
            print("""
            DL4 doctor: checks each pedal one at a time, at your pace.
            Signal chain: guitar -> A (bottom-right) -> B (bottom-left) -> C (top-right) -> D (top-left) -> out.
            Each pedal is zeroed and put in looper mode first, so stuck bypass/mix states get cleared as we go.
            """)
            var results: [(String, Bool, Bool, Bool)] = []   // letter, present, midiOK, audioOK
            for i in midi.pedals.indices {
                let letter = Conductor.pedalLetters[i]
                guard midi.isPresent(i) else {
                    print("\nPedal \(letter) (\(positions[i])): unplugged, skipping.")
                    results.append((letter, false, false, false))
                    continue
                }
                print("\n=== Pedal \(letter) (\(positions[i])) ===")
                midi.zero(pedal: i)
                midi.cc(CC.Looper.onOff, 127, to: i)
                usleep(150_000)
                pause("Zeroed and set to looper mode. Watch pedal \(letter), then press Enter to send RECORD... ")
                midi.cc(CC.Looper.recordOverdub, 127, to: i)
                let midiOK = ask("Did its A footswitch light turn RED (recording)?")
                var audioOK = false
                if midiOK {
                    pause("Play a riff now, then press Enter to stop recording and loop it back... ")
                    midi.cc(CC.Looper.stopPlay, 127, to: i)   // ends record, starts playback
                    audioOK = ask("Do you hear the loop playing back?")
                    midi.cc(CC.Looper.stopPlay, 0, to: i)     // stop
                    midi.cc(CC.Looper.undoRedo, 0, to: i)     // undo: leave no loop behind
                } else {
                    midi.cc(CC.Looper.stopPlay, 0, to: i)     // in case it recorded without a visible LED
                    midi.cc(CC.Looper.undoRedo, 0, to: i)
                }
                results.append((letter, true, midiOK, audioOK))
            }
            print("\n=== Results ===")
            for (letter, present, midiOK, audioOK) in results {
                let status = !present ? "unplugged"
                    : !midiOK ? "MIDI NOT REACHING PEDAL"
                    : !audioOK ? "MIDI ok, NO AUDIO"
                    : "ok"
                print("  \(letter): \(status)")
            }
            print("")
            if results.contains(where: { $0.1 && !$0.2 }) {
                print("MIDI failures: replug that pedal's USB, run `dl4 list`, and if it still")
                print("shows but won't respond, run `sudo killall MIDIServer` and rescan.")
            }
            if results.contains(where: { $0.2 && !$0.3 }) {
                print("Audio failures: MIDI reached the pedal, so it's the audio path. The chain")
                print("is series, so check the patch cable INTO that pedal, its output cable,")
                print("and wiggle its MIX knob (a MIDI override may have parked it full wet).")
            }
            if results.allSatisfy({ !$0.1 || $0.3 }) && results.contains(where: { $0.1 }) {
                print("Everything checks out. All pedals are zeroed and in looper mode.")
            }

        case "firmware":
            // Standard MIDI identity request (SysEx F0 7E 7F 06 01 F7), sent to
            // one pedal at a time so each reply is unambiguous.
            guard !midi.pedals.isEmpty else { print("No DL4 found. Run `dl4 list`."); exit(1) }
            let input = MidiInput()
            let sem = DispatchSemaphore(value: 0)
            var reply: [UInt8]?
            input.onSysEx = { bytes in
                // Identity reply: F0 7E <dev> 06 02 <mfr...> ... F7
                if bytes.count >= 6, bytes[1] == 0x7E, bytes[3] == 0x06, bytes[4] == 0x02 {
                    reply = bytes
                    sem.signal()
                }
            }
            print("Querying each pedal's firmware over USB MIDI…\n")
            for i in midi.pedals.indices {
                let letter = Conductor.pedalLetters[i]
                guard midi.isPresent(i) else { print("  \(letter): unplugged"); continue }
                reply = nil
                midi.sendRaw([0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7], to: i)
                if sem.wait(timeout: .now() + 1.5) == .success, let r = reply {
                    print("  \(letter): \(decodeIdentity(r))")
                    if CommandLine.arguments.contains("--raw") {
                        print("     full reply: \(r.map { String(format: "%02X", $0) }.joined(separator: " "))")
                    }
                } else {
                    print("  \(letter): no reply (try `sudo killall MIDIServer` and rerun if others answered)")
                }
            }
            withExtendedLifetime(input) {}

        case "lag":
            // Times the software half of a pad press: USB driver timestamp →
            // handler entry → a real MIDISend back out. The outbound message is
            // a bare 0xF8 clock tick, which the pedal ignores without a clock
            // start, so the test has zero audible side effects.
            guard !midi.pedals.isEmpty else { print("No DL4 found. Run `dl4 list`."); exit(1) }
            var tb = mach_timebase_info_data_t()
            mach_timebase_info(&tb)
            func toUs(_ delta: UInt64) -> Double {
                Double(delta) * Double(tb.numer) / Double(tb.denom) / 1000.0
            }
            let input = MidiInput()
            var samples: [Double] = []
            print("Latency probe: tap Midi Fighter pads. Ctrl-C for stats.\n")
            input.onTrigger = { t, pressed, _ in
                guard pressed else { return }
                let arrived = mach_absolute_time()
                let stamped = input.currentPacketTime
                midi.sendRaw([0xF8], to: 0)
                let sent = mach_absolute_time()
                let inUs = (stamped > 0 && stamped <= arrived) ? toUs(arrived - stamped) : Double.nan
                let outUs = toUs(sent - arrived)
                let total = inUs.isNaN ? outUs : inUs + outUs
                samples.append(total)
                let inStr = inUs.isNaN ? "  n/a" : String(format: "%5.0f", inUs)
                print(String(format: "  %-6@ driver→app %@ µs   send %5.0f µs   total %5.0f µs",
                             t.shortLabel as NSString, inStr, outUs, total))
            }
            signal(SIGINT, SIG_IGN)
            let sig = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
            sig.setEventHandler {
                let s = samples.sorted()
                if s.isEmpty {
                    print("\nNo presses seen.")
                } else {
                    print(String(format: "\n%d presses: min %.0f µs · median %.0f µs · max %.0f µs",
                                 s.count, s[0], s[s.count / 2], s[s.count - 1]))
                    print("(software path only; USB adds roughly a millisecond each direction)")
                }
                exit(0)
            }
            sig.resume()
            withExtendedLifetime((input, midi)) { RunLoop.main.run() }

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
          dl4 firmware            Read each pedal's firmware version over USB MIDI
          dl4 zero                Reset all pedals to a clean baseline (clears stuck bypass/mix/repeats)
          dl4 doctor              Interactive per-pedal looper checkup (you confirm lights and audio)
          dl4 lag                 Measure pad-press latency (tap pads, Ctrl-C for stats)
          dl4 conduct [--bpm N]   Run the tempo-locked delay conductor (default 132)
          dl4 loop [--port N]     Looper mode + phone remote (default 8888)

        For `conduct`: set DL4 Global Settings ▸ Receive MIDI Clock to Auto or On (Auto is the factory default).
        """)
    }

    /// Newest DL4 MkII firmware, per Line 6's release notes (checked 2026-07-19).
    private static let latestDL4Firmware = "1.10"

    /// Decode a MIDI identity reply. Line 6's manufacturer ID is 00 01 0C; the
    /// four bytes before the trailing F7 are the software revision.
    private static func decodeIdentity(_ b: [UInt8]) -> String {
        let isLine6 = b.count >= 8 && b[5] == 0x00 && b[6] == 0x01 && b[7] == 0x0C
        let mfr = isLine6 ? "Line 6" : "mfr \(b.dropFirst(5).prefix(3).map { String(format: "%02X", $0) }.joined(separator: " "))"
        guard b.count >= 6, b.last == 0xF7 else {
            return "\(mfr), malformed reply (\(b.count) bytes)"
        }
        // Revision is four bytes, least-significant first: [build, patch, minor,
        // major]. A DL4 MkII on 1.01.0 replies 00 00 01 01 (verified against
        // what Line 6 Updater displays for the same pedal).
        let ver = Array(b.suffix(5).prefix(4))
        let dotted = String(format: "%d.%02d", ver[3], ver[2])
        let note = dotted == Self.latestDL4Firmware
            ? "(latest)"
            : "** UPDATE AVAILABLE: \(Self.latestDL4Firmware) **"
        return "\(mfr) firmware \(dotted) \(note)"
    }

    private static func argValue(_ name: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}
