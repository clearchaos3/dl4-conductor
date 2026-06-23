import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    private let accent = Color(red: 0.36, green: 0.75, blue: 0.45)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            conductorSection
            Divider()
            looperSection
        }
        .padding(22)
        .frame(width: 430)
        .background(Color(red: 0.05, green: 0.06, blue: 0.055))
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DL4 CONDUCTOR")
                .font(.system(size: 15, weight: .bold)).tracking(3).foregroundStyle(accent)
            HStack(spacing: 8) {
                Circle().fill(model.pedalCount > 0 ? accent : .gray).frame(width: 9, height: 9)
                Text(model.status).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("Rescan") { model.rescan() }
                Button("Test") { model.testSweep() }.disabled(model.pedalCount == 0)
            }
        }
    }

    // MARK: Conductor

    private var conductorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delay Conductor").font(.headline)
            HStack {
                Text("\(Int(model.bpm)) BPM")
                    .font(.system(size: 14, design: .monospaced)).frame(width: 78, alignment: .leading)
                Slider(value: $model.bpm, in: 60...200, step: 1)
            }
            HStack(spacing: 12) {
                Button(model.isConducting ? "Stop" : "Start") { model.toggleConducting() }
                    .buttonStyle(.borderedProminent)
                    .tint(model.isConducting ? .red : accent)
                    .disabled(model.pedalCount == 0)
                Text(model.isConducting ? model.conductorLine : "Mac is the clock master.")
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    // MARK: Looper

    private var looperSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Looper").font(.headline)
                Spacer()
                Toggle("Looper mode", isOn: Binding(
                    get: { model.looperModeOn },
                    set: { model.setLooperMode($0) }))
                    .toggleStyle(.switch).disabled(model.pedalCount == 0)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                looperButton("● Record", "record", .red)
                looperButton("⊕ Overdub", "overdub", nil)
                looperButton("▶ Play", "play", accent)
                looperButton("■ Stop", "stop", nil)
                looperButton("▶| Once", "once", nil)
                looperButton("↶ Undo", "undo", nil)
                looperButton("◀ Reverse", "reverse", nil)
                looperButton("½× Half", "half", nil)
                looperButton("1× Full", "full", nil)
            }
            HStack {
                Toggle("Phone remote", isOn: Binding(
                    get: { model.remoteOn },
                    set: { model.setRemote($0) }))
                    .toggleStyle(.switch).disabled(model.pedalCount == 0)
                Spacer()
                if model.remoteOn {
                    Text(model.remoteURL)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(accent).textSelection(.enabled)
                }
            }
        }
    }

    private func looperButton(_ title: String, _ cmd: String, _ color: Color?) -> some View {
        Button(title) { model.looperCommand(cmd) }
            .frame(maxWidth: .infinity)
            .tint(color)
            .disabled(model.pedalCount == 0)
    }
}
