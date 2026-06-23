import Foundation

/// The "delay conductor": runs a tempo clock and sequences delay subdivisions per bar
/// while continuously modulating feedback with a tempo-locked triangle LFO. Built for
/// rhythmic, Minus-the-Bear-style delays.
///
/// Works with one pedal today. When a second DL4 is connected it automatically plays a
/// complementary subdivision against the first, for stereo dotted-vs-triplet interplay.
final class Conductor {
    private let midi: DL4Midi
    private let clock: MidiClock
    private let beatsPerBar: Int

    /// Subdivision sequence for pedal 0, advanced one step per bar (loops).
    var sequenceA: [Subdivision] = [.dottedEighth, .dottedEighth, .quarterTriplet, .eighth]
    /// Pedal 1's sequence — offset so the two pedals interlock rhythmically.
    var sequenceB: [Subdivision] = [.quarterTriplet, .eighth, .dottedEighth, .dottedEighth]

    /// Feedback LFO range, within the CC13 0-127 scale.
    var feedbackLow: UInt8 = 45
    var feedbackHigh: UInt8 = 105
    /// LFO period in bars (one full up-and-back sweep).
    var lfoBars: Double = 4

    /// Called on each new bar with (barNumber, humanReadableLine) — for UI display.
    var onBar: ((Int, String) -> Void)?

    init(midi: DL4Midi, bpm: Double, beatsPerBar: Int = 4) {
        self.midi = midi
        self.beatsPerBar = beatsPerBar
        self.clock = MidiClock(midi: midi, bpm: bpm)
    }

    func run() {
        let pulsesPerBar = 24 * beatsPerBar
        var lastBar = -1

        clock.onPulse = { [weak self] pulse in
            guard let self else { return }
            let bar = pulse / pulsesPerBar

            // On each downbeat, set every pedal's subdivision.
            if bar != lastBar {
                lastBar = bar
                let a = self.sequenceA[bar % self.sequenceA.count]
                self.midi.cc(CC.subdivision, a.rawValue, to: 0)
                var line = "bar \(bar): A=\(a.label)"
                if self.midi.pedals.count > 1 {
                    let b = self.sequenceB[bar % self.sequenceB.count]
                    self.midi.cc(CC.subdivision, b.rawValue, to: 1)
                    line += "  B=\(b.label)"
                }
                print(line)
                self.onBar?(bar, line)
            }

            // Continuous feedback LFO, updated every 16th note (every 6 pulses).
            if pulse % 6 == 0 {
                let pulsesPerLfo = Double(pulsesPerBar) * self.lfoBars
                let phase = Double(pulse).truncatingRemainder(dividingBy: pulsesPerLfo) / pulsesPerLfo
                let triangle = phase < 0.5 ? phase * 2 : (1 - phase) * 2   // 0→1→0
                let span = Double(self.feedbackHigh) - Double(self.feedbackLow)
                self.midi.ccAll(CC.feedback, UInt8(Double(self.feedbackLow) + triangle * span))
            }
        }
        clock.start()
    }

    func stop() { clock.stop() }

    /// Change tempo while running.
    func setBPM(_ value: Double) { clock.bpm = value }
}
