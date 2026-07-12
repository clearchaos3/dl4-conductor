import Foundation

/// The "delay conductor": runs a tempo clock and sequences delay subdivisions per bar
/// while continuously modulating feedback with a tempo-locked triangle LFO. Built for
/// rhythmic, Minus-the-Bear-style delays.
///
/// Drives up to four DL4s. Each connected pedal gets its own per-bar subdivision
/// sequence, chosen so they interlock rhythmically out of the box.
final class Conductor {
    private let midi: DL4Midi
    private let clock: MidiClock
    private let beatsPerBar: Int

    static let pedalLetters = ["A", "B", "C", "D"]

    /// Interlocking defaults: dotted-vs-triplet on A/B, straighter counterlines on C/D.
    static let defaultSequences: [[Subdivision]] = [
        [.dottedEighth, .dottedEighth, .quarterTriplet, .eighth],
        [.quarterTriplet, .eighth, .dottedEighth, .dottedEighth],
        [.quarter, .quarterTriplet, .eighth, .dottedEighth],
        [.eighth, .dottedQuarter, .quarter, .quarterTriplet],
    ]

    /// One subdivision sequence per pedal (index-aligned with midi.pedals, max 4),
    /// advanced one step per bar (loops).
    var sequences: [[Subdivision]] = Conductor.defaultSequences

    /// Feedback LFO range, within the CC13 0-127 scale.
    var feedbackLow: UInt8 = 45
    var feedbackHigh: UInt8 = 105
    /// LFO period in bars (one full up-and-back sweep).
    var lfoBars: Double = 4
    /// When true, each pedal's LFO is phase-offset (i/n of the period) so the feedback
    /// sweeps ripple across the pedals instead of breathing in unison.
    var lfoStaggered = false

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
            let pedalCount = min(self.midi.pedals.count, self.sequences.count)

            // On each downbeat, set every pedal's subdivision.
            if bar != lastBar {
                lastBar = bar
                var parts: [String] = []
                for i in 0..<pedalCount {
                    let seq = self.sequences[i]
                    guard !seq.isEmpty else { continue }
                    let s = seq[bar % seq.count]
                    self.midi.cc(CC.subdivision, s.rawValue, to: i)
                    parts.append("\(Conductor.pedalLetters[i])=\(s.label)")
                }
                let line = "bar \(bar): " + parts.joined(separator: "  ")
                print(line)
                self.onBar?(bar, line)
            }

            // Continuous feedback LFO, updated every 16th note (every 6 pulses).
            if pulse % 6 == 0 {
                let pulsesPerLfo = Double(pulsesPerBar) * self.lfoBars
                let span = Double(self.feedbackHigh) - Double(self.feedbackLow)
                let basePhase = Double(pulse).truncatingRemainder(dividingBy: pulsesPerLfo) / pulsesPerLfo

                if self.lfoStaggered && pedalCount > 1 {
                    for i in 0..<pedalCount {
                        let phase = (basePhase + Double(i) / Double(pedalCount))
                            .truncatingRemainder(dividingBy: 1)
                        let triangle = phase < 0.5 ? phase * 2 : (1 - phase) * 2   // 0→1→0
                        self.midi.cc(CC.feedback,
                                     UInt8(Double(self.feedbackLow) + triangle * span),
                                     to: i)
                    }
                } else {
                    let triangle = basePhase < 0.5 ? basePhase * 2 : (1 - basePhase) * 2
                    self.midi.ccAll(CC.feedback, UInt8(Double(self.feedbackLow) + triangle * span))
                }
            }
        }
        clock.start()
    }

    func stop() { clock.stop() }

    /// Change tempo while running.
    func setBPM(_ value: Double) { clock.bpm = value }
}
