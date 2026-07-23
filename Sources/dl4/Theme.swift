import SwiftUI

/// Design tokens: "backline at night". The app is the fifth piece of gear in
/// the chain, so it borrows the rig's language: near-black stage, silkscreen
/// caps like a pedal's enclosure printing, and LED light as the only color —
/// anything colored on screen should read as a lit control.
enum Theme {
    // Surfaces
    static let stage = Color(red: 0.032, green: 0.038, blue: 0.035)
    static let panelTop = Color(white: 0.115)
    static let panelBottom = Color(white: 0.072)
    static let inset = Color.black.opacity(0.55)          // LCD-style wells

    // Silkscreen ink
    static let silk = Color(red: 0.92, green: 0.93, blue: 0.90)
    static let silkDim = Color(red: 0.60, green: 0.63, blue: 0.60)

    // LEDs
    static let green = Color(red: 0.36, green: 0.78, blue: 0.46)   // Line 6 green
    static let ledRed = Color(red: 1.0, green: 0.27, blue: 0.20)
    static let ledAmber = Color(red: 1.0, green: 0.64, blue: 0.12)
    static let ledBlue = Color(red: 0.30, green: 0.58, blue: 1.0)

    /// Machined-enclosure card: gradient face, edge highlight on top fading
    /// out, drop shadow below.
    static func enclosure(cornerRadius: CGFloat = 12) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(LinearGradient(colors: [panelTop, panelBottom],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(LinearGradient(colors: [.white.opacity(0.13), .white.opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
    }
}

/// Flat silkscreen capsule — the app's button, styled like enclosure printing
/// rather than macOS chrome.
struct SilkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(Theme.silk)
            .padding(.horizontal, 13).padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0.07)))
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == SilkButtonStyle {
    static var silk: SilkButtonStyle { SilkButtonStyle() }
}
