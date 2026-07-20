import Foundation
import Combine

/// Pad-press visuals, isolated from AppModel so a flurry of presses only
/// re-renders the views that watch pads instead of invalidating the whole
/// window. Guarantees every press stays lit for a minimum flash: fast
/// beat-mashing presses can be shorter than one display frame and would
/// otherwise be inserted and removed before SwiftUI ever draws them.
/// Main thread only.
final class PadActivity: ObservableObject {
    @Published private(set) var lit = Set<MidiTrigger>()
    @Published private(set) var lastLabel = ""

    private var pressedAt: [MidiTrigger: DispatchTime] = [:]
    private var generation: [MidiTrigger: Int] = [:]
    private let minFlash = 0.12

    func press(_ t: MidiTrigger) {
        pressedAt[t] = .now()
        generation[t, default: 0] += 1
        lit.insert(t)
        lastLabel = t.label
    }

    func release(_ t: MidiTrigger) {
        let gen = generation[t, default: 0]
        let held = pressedAt[t].map {
            Double(DispatchTime.now().uptimeNanoseconds - $0.uptimeNanoseconds) / 1e9
        } ?? minFlash
        let remaining = minFlash - held
        if remaining <= 0 {
            lit.remove(t)
        } else {
            // Keep the flash visible; a newer press on the same pad (higher
            // generation) cancels this scheduled removal.
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
                guard let self, self.generation[t, default: 0] == gen else { return }
                self.lit.remove(t)
            }
        }
    }
}
