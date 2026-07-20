import SwiftUI

/// Four full-width state lanes, one per pedal in signal-chain order. Sized to
/// be readable from a playing position across the room: giant letter, colored
/// state word, badges for reverse/half-speed. The pedal renders are the
/// pretty picture; these are the glanceable truth.
struct LoopLanesView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                lane(i)
            }
        }
    }

    @ViewBuilder
    private func lane(_ i: Int) -> some View {
        let present = model.midi.isPresent(i)
        let st = model.pedalStates.indices.contains(i) ? model.pedalStates[i] : PedalState()
        let (word, color) = stateWord(st.loop, present: present)

        HStack(spacing: 18) {
            Text(Conductor.pedalLetters[i])
                .font(.system(size: 40, weight: .black, design: .monospaced))
                .foregroundStyle(present ? Color.primary : Color.secondary)
                .frame(width: 52)
            Text(word)
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(color)
            Spacer()
            if present {
                if st.reverse { badge("REV") }
                if st.halfSpeed { badge("½ SPEED") }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(st.loop == .empty || !present ? 0.05 : 0.14))
        )
        .overlay(
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 5)
                    .padding(.vertical, 6)
                Spacer()
            }
            .padding(.leading, 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func stateWord(_ phase: LoopPhase, present: Bool) -> (String, Color) {
        guard present else { return ("OFFLINE", Color(white: 0.45)) }
        switch phase {
        case .empty:     return ("EMPTY", Color(white: 0.5))
        case .recording: return ("REC", Color(red: 1.0, green: 0.28, blue: 0.22))
        case .overdub:   return ("OVERDUB", Color(red: 1.0, green: 0.62, blue: 0.1))
        case .playing:   return ("PLAYING", Color(red: 0.3, green: 0.9, blue: 0.45))
        case .stopped:   return ("STOPPED", Color(white: 0.75))
        }
    }

    private func badge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Color.teal.opacity(0.25)))
            .foregroundStyle(.teal)
    }
}
