import Foundation

/// Named Midi Fighter 64 pad layouts, installable via `dl4 layout <name>`.
/// Writes the same gridBindings the app persists, so install with the app
/// closed (a running app saves its in-memory bindings over ours on quit).
enum GridLayouts {
    static let names = ["function-rows"]

    static func make(_ name: String) -> [PadBinding]? {
        switch name {
        case "function-rows": return functionRows()
        default: return nil
        }
    }

    /// Every row is one function across pedals A-D. Left half is the looper
    /// with Play Once as the entire top row (most-used function, easiest row
    /// to find); right half is performance. Columns follow the signal chain:
    /// A B C D on each half.
    private static func functionRows() -> [PadBinding] {
        let looperRows: [PadAction] = [
            PadAction(kind: .looper, looper: .once),
            PadAction(kind: .looper, looper: .record),
            PadAction(kind: .looper, looper: .overdub),
            PadAction(kind: .looper, looper: .play),
            PadAction(kind: .looper, looper: .stop),
            PadAction(kind: .looper, looper: .undo),
            PadAction(kind: .reverseToggle),
            PadAction(kind: .halfToggle),
        ]
        let perfRows: [PadAction] = [
            PadAction(kind: .squeal),
            PadAction(kind: .kill),
            PadAction(kind: .fullWet),
            PadAction(kind: .drop),
            PadAction(kind: .build),
            PadAction(kind: .tap),
            PadAction(kind: .preset, arg: 0),
            PadAction(kind: .preset, arg: 1),
        ]
        var out: [PadBinding] = []
        for row in 0..<8 {
            for pedal in 0..<4 {
                out.append(bind(row: row, col: pedal, pedal: pedal, action: looperRows[row]))
                out.append(bind(row: row, col: pedal + 4, pedal: pedal, action: perfRows[row]))
            }
        }
        return out
    }

    private static func bind(row: Int, col: Int, pedal: Int, action: PadAction) -> PadBinding {
        PadBinding(
            trigger: MidiTrigger(kind: .note, channel: MF64Grid.channel,
                                 data1: MF64Grid.note(displayRow: row, col: col)),
            pedal: pedal,
            action: action)
    }
}
