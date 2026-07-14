import SwiftUI

/// A miniature render of a DL4 MkII, modeled on the real pedal: Line 6 green
/// enclosure, black control strip with six green-ringed knobs, and illuminated
/// footswitches (the buttons themselves glow — A red while recording, B green
/// while playing, TAP pulsing at the tempo, blue during identify).
/// Tapping the pedal runs identify on the hardware.
struct PedalView: View {
    let letter: String
    let present: Bool
    let loop: LoopPhase
    let conducting: Bool
    let bpm: Double
    let identifying: Bool
    var onTap: () -> Void = {}

    // Line 6 green, sampled from the hardware
    private var bodyTop: Color    { present ? Color(red: 0.35, green: 0.78, blue: 0.47) : Color(white: 0.30) }
    private var bodyBottom: Color { present ? Color(red: 0.22, green: 0.62, blue: 0.35) : Color(white: 0.22) }
    private let panelBlack = Color(red: 0.07, green: 0.08, blue: 0.07)
    private var ringGreen: Color  { present ? Color(red: 0.28, green: 0.72, blue: 0.42) : Color(white: 0.4) }

    private let knobLabels = ["TIME", "REPEATS", "TWEAK", "TWEEZ", "MIX"]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                // Enclosure
                RoundedRectangle(cornerRadius: w * 0.035)
                    .fill(LinearGradient(colors: [bodyTop, bodyBottom], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: w * 0.035)
                        .stroke(Color.black.opacity(0.55), lineWidth: 1))
                    .shadow(color: .black.opacity(0.6), radius: w * 0.018, y: w * 0.012)

                VStack(spacing: 0) {
                    // Logo row
                    HStack {
                        Text("LINE 6")
                            .font(.system(size: w * 0.032, weight: .heavy))
                            .tracking(w * 0.004)
                            .foregroundStyle(.white)
                            .padding(.horizontal, w * 0.016).padding(.vertical, w * 0.008)
                            .background(RoundedRectangle(cornerRadius: w * 0.012).fill(.black.opacity(0.9)))
                        Spacer()
                        Text("DL4")
                            .font(.system(size: w * 0.042, weight: .heavy)).italic()
                            .foregroundColor(.black.opacity(0.85))
                        + Text(" MkII")
                            .font(.system(size: w * 0.030, weight: .semibold))
                            .foregroundColor(.black.opacity(0.7))
                        Text(letter)
                            .font(.system(size: w * 0.036, weight: .black, design: .monospaced))
                            .foregroundStyle(bodyTop)
                            .frame(width: w * 0.062, height: w * 0.062)
                            .background(Circle().fill(.black.opacity(0.9)))
                    }
                    .padding(.horizontal, w * 0.04)
                    .padding(.top, w * 0.025)

                    // Black control strip with knobs
                    HStack(spacing: w * 0.038) {
                        knob(w: w, size: w * 0.115, label: "LOOPER", selector: true)
                        ForEach(0..<5, id: \.self) { i in
                            knob(w: w, size: w * 0.095, label: knobLabels[i], selector: false)
                        }
                    }
                    .padding(.horizontal, w * 0.035)
                    .padding(.vertical, w * 0.028)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: w * 0.02).fill(panelBlack)
                        .overlay(RoundedRectangle(cornerRadius: w * 0.02).stroke(.white.opacity(0.06), lineWidth: 1)))
                    .padding(.horizontal, w * 0.03)
                    .padding(.top, w * 0.02)

                    Spacer(minLength: 0)

                    // Footswitch row — the buttons themselves glow, like the MkII
                    HStack(spacing: 0) {
                        footswitch(w: w, name: "A",   sub: "● / DUB", glow: recGlow,  pulsing: false)
                        footswitch(w: w, name: "B",   sub: "▶ / ■",   glow: playGlow, pulsing: false)
                        footswitch(w: w, name: "C",   sub: "▶ ONCE",  glow: nil,      pulsing: false)
                        footswitch(w: w, name: "TAP", sub: "½ / ⇠",   glow: tapGlow,  pulsing: conducting && present && !identifying)
                    }
                    .padding(.horizontal, w * 0.03)
                    .padding(.bottom, w * 0.03)
                }

                if !present {
                    Text("OFFLINE")
                        .font(.system(size: w * 0.045, weight: .bold, design: .monospaced))
                        .tracking(w * 0.008)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, w * 0.025).padding(.vertical, w * 0.010)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.6)))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if present { onTap() } }
            .help(present ? "Pedal \(letter) — click to identify (TAP light turns blue)" : "Pedal \(letter) is unplugged")
        }
        .aspectRatio(1.9, contentMode: .fit)
    }

    // MARK: Glow states (mirroring the hardware's switch LEDs)

    private var recGlow: Color? {
        guard present else { return nil }
        switch loop {
        case .recording: return Color(red: 1.0, green: 0.25, blue: 0.2)
        case .overdub:   return Color(red: 1.0, green: 0.62, blue: 0.1)
        default:         return nil
        }
    }

    private var playGlow: Color? {
        guard present else { return nil }
        return loop == .playing ? Color(red: 0.3, green: 0.95, blue: 0.45) : nil
    }

    private var tapGlow: Color? {
        guard present else { return nil }
        if identifying { return Color(red: 0.25, green: 0.55, blue: 1.0) }
        return Color(red: 1.0, green: 0.22, blue: 0.18)
    }

    // MARK: Components

    private func knob(w: CGFloat, size: CGFloat, label: String, selector: Bool) -> some View {
        VStack(spacing: w * 0.012) {
            ZStack {
                Circle().stroke(ringGreen, lineWidth: max(1, size * 0.06))
                    .frame(width: size, height: size)
                Circle()
                    .fill(RadialGradient(colors: [Color(white: 0.22), Color(white: 0.05)],
                                         center: .init(x: 0.35, y: 0.3),
                                         startRadius: 0, endRadius: size * 0.7))
                    .frame(width: size * 0.86, height: size * 0.86)
                Rectangle()
                    .fill(.white.opacity(0.85))
                    .frame(width: max(1, size * 0.05), height: size * 0.3)
                    .offset(y: -size * 0.22)
                    .rotationEffect(.degrees(selector ? 30 : -40))
            }
            Text(label)
                .font(.system(size: max(3, w * 0.019), weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .opacity(present ? 1 : 0.4)
    }

    private func footswitch(w: CGFloat, name: String, sub: String, glow: Color?, pulsing: Bool) -> some View {
        VStack(spacing: w * 0.008) {
            Text(name)
                .font(.system(size: w * 0.034, weight: .bold))
                .foregroundStyle(.black.opacity(present ? 0.85 : 0.4))
            Group {
                if pulsing, let g = glow {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        let beat = context.date.timeIntervalSinceReferenceDate * (bpm / 60.0)
                        let phase = beat.truncatingRemainder(dividingBy: 1)
                        switchButton(w: w, glow: g, bright: phase < 0.2)
                    }
                } else {
                    switchButton(w: w, glow: glow, bright: glow != nil)
                }
            }
            Text(sub)
                .font(.system(size: max(3, w * 0.020), weight: .medium))
                .foregroundStyle(.black.opacity(present ? 0.65 : 0.3))
        }
        .frame(maxWidth: .infinity)
    }

    private func switchButton(w: CGFloat, glow: Color?, bright: Bool) -> some View {
        let size = w * 0.085
        let lit = glow != nil && bright
        return ZStack {
            // chrome base
            Circle()
                .fill(LinearGradient(colors: [Color(white: present ? 0.85 : 0.5), Color(white: present ? 0.55 : 0.3)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 1))
            // button cap — glows through when lit
            Circle()
                .fill(lit ? glow!.opacity(0.95) : Color(white: present ? 0.12 : 0.2))
                .frame(width: size * 0.66, height: size * 0.66)
                .shadow(color: lit ? glow! : .clear, radius: size * 0.35)
        }
    }
}

/// The 2x2 pedal board — mirrors the physical arrangement (A B / C D).
struct PedalBoardView: View {
    @EnvironmentObject var model: AppModel
    @State private var identifying = Set<Int>()

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { r in
                HStack(spacing: 12) {
                    ForEach(0..<2, id: \.self) { c in
                        let i = r * 2 + c
                        PedalView(
                            letter: Conductor.pedalLetters[i],
                            present: model.midi.isPresent(i),
                            loop: model.loopPhase(pedal: i),
                            conducting: model.isConducting,
                            bpm: model.bpm,
                            identifying: identifying.contains(i)
                        ) {
                            identifying.insert(i)
                            model.identify(pedal: i)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                                identifying.remove(i)
                            }
                        }
                    }
                }
            }
        }
    }
}
