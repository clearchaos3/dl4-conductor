import Foundation
import Darwin

/// A low-jitter MIDI clock. Sends 24 PPQN (pulses per quarter note) on a dedicated
/// high-priority thread using `mach_wait_until`, and fires `onPulse` every pulse so
/// callers can sequence on musical boundaries.
final class MidiClock {
    private let midi: DL4Midi
    var bpm: Double
    /// Called on the clock thread once per pulse, with a monotonically increasing count.
    var onPulse: ((Int) -> Void)?

    private var thread: Thread?
    private var running = false
    private var timebase = mach_timebase_info_data_t()

    init(midi: DL4Midi, bpm: Double) {
        self.midi = midi
        self.bpm = bpm
        mach_timebase_info(&timebase)
    }

    func start() {
        guard !running else { return }
        running = true
        midi.clockStart()
        let t = Thread { [weak self] in self?.run() }
        t.name = "dl4.midiclock"
        t.qualityOfService = .userInteractive
        thread = t
        t.start()
    }

    func stop() {
        running = false
        midi.clockStop()
    }

    /// Nanoseconds between pulses — a quarter note is 24 pulses.
    private var pulseNanos: UInt64 { UInt64(60_000_000_000.0 / bpm / 24.0) }

    private func nanosToMach(_ nanos: UInt64) -> UInt64 {
        nanos * UInt64(timebase.denom) / UInt64(timebase.numer)
    }

    private func run() {
        var pulse = 0
        var deadline = mach_absolute_time()
        while running {
            midi.clockTick()
            onPulse?(pulse)
            pulse += 1
            deadline &+= nanosToMach(pulseNanos)   // re-read bpm each loop, so tempo can change live
            mach_wait_until(deadline)
        }
    }
}
