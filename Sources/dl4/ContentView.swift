import SwiftUI

enum ActionCategory: String, CaseIterable, Identifiable {
    case looper = "Looper", delay = "Delay Model", reverb = "Reverb Model",
         subdiv = "Subdivision", preset = "Preset", fx = "FX"
    var id: String { rawValue }
}

enum FXKind: String, CaseIterable, Identifiable {
    case squeal = "Squeal (hold)", kill = "Kill (hold)", fullWet = "100% Wet (hold)",
         tap = "Tap Tempo", drop = "Drop", build = "Build",
         feedbackVel = "Feedback (vel)", mixVel = "Mix (vel)"
    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    private let accent = Color(red: 0.36, green: 0.75, blue: 0.45)

    // Grid action composer
    @State private var cPedal = 0           // 0 = A, 1 = B, -1 = Both
    @State private var cCategory: ActionCategory = .looper
    @State private var cLooper: LooperFunction = .record
    @State private var cModel = 0
    @State private var cReverb = 0
    @State private var cSubdiv: Subdivision = .dottedEighth
    @State private var cPreset = 0
    @State private var cFX: FXKind = .squeal

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                Divider()
                conductorSection
                Divider()
                gridSection
                Divider()
                looperSection
            }
            .padding(22)
            .frame(width: 460)
        }
        .frame(width: 460, height: 820)
        .background(Color(red: 0.05, green: 0.06, blue: 0.055))
    }

    private var gridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                Text("Grid Controller").font(.headline)
                Spacer()
                Toggle("LEDs", isOn: $model.ledEnabled).toggleStyle(.switch)
                Toggle("Active", isOn: $model.gridEnabled).toggleStyle(.switch)
            }
            Text("MIDI in: \(model.midiSourceSummary)")
                .font(.system(size: 11)).foregroundStyle(.secondary)

            if model.pedalCount > 0 {
                HStack(spacing: 6) {
                    Text("Identify:").font(.system(size: 11)).foregroundStyle(.secondary)
                    ForEach(0..<model.pedalCount, id: \.self) { i in
                        Button("⚡ \(pedalLetter(i))") { model.identify(pedal: i) }
                            .font(.system(size: 11))
                    }
                }
            }

            composer

            Text(model.learnTarget == nil
                 ? "Last in: \(model.lastTrigger.isEmpty ? "—" : model.lastTrigger)"
                 : "Press the pad to assign…")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(model.learnTarget == nil ? .secondary : accent)

            bindingsList

            HStack {
                Button("Rescan MIDI") { model.rescanMidiSources() }
                if !model.bindings.isEmpty { Button("Clear all") { model.clearAllBindings() } }
            }
            .font(.system(size: 11))
            Text("Turn on Looper mode below so looper pads show their state on the pedal.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("", selection: $cPedal) {
                    ForEach(0..<model.addressablePedals, id: \.self) { i in
                        Text(pedalLetter(i)).tag(i)
                    }
                    Text("All").tag(-1)
                }
                .pickerStyle(.segmented)
                .frame(width: min(CGFloat((model.addressablePedals + 1) * 44), 240))
                .labelsHidden()
                Picker("", selection: $cCategory) {
                    ForEach(ActionCategory.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().frame(width: 140)
                Spacer()
            }
            HStack {
                detailPicker
                Spacer()
                Button(model.learnTarget == nil ? "Learn pad" : "Waiting…") {
                    model.startLearn(pedal: cPedal, action: composedAction())
                }
                .disabled(model.learnTarget != nil)
                if model.learnTarget != nil { Button("Cancel") { model.cancelLearn() } }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
    }

    @ViewBuilder private var detailPicker: some View {
        switch cCategory {
        case .looper:
            Picker("", selection: $cLooper) {
                ForEach(LooperFunction.allCases) { Text($0.title).tag($0) }
            }.labelsHidden().frame(width: 180)
        case .delay:
            Picker("", selection: $cModel) {
                ForEach(Array(DelayModel.names.enumerated()), id: \.offset) { Text($1).tag($0) }
            }.labelsHidden().frame(width: 220)
        case .reverb:
            Picker("", selection: $cReverb) {
                ForEach(Array(ReverbModel.names.enumerated()), id: \.offset) { Text($1).tag($0) }
            }.labelsHidden().frame(width: 220)
        case .subdiv:
            Picker("", selection: $cSubdiv) {
                ForEach(Subdivision.allCases, id: \.self) { Text($0.label).tag($0) }
            }.labelsHidden().frame(width: 140)
        case .preset:
            Stepper("Preset · PC\(cPreset)", value: $cPreset, in: 0...127).frame(width: 200)
        case .fx:
            Picker("", selection: $cFX) {
                ForEach(FXKind.allCases) { Text($0.rawValue).tag($0) }
            }.labelsHidden().frame(width: 220)
        }
    }

    private var bindingsList: some View {
        Group {
            if model.bindings.isEmpty {
                Text("No pads mapped yet.").font(.system(size: 11)).foregroundStyle(.secondary)
            } else {
                ForEach(model.bindings) { b in
                    HStack(spacing: 8) {
                        Text(b.trigger.shortLabel)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 46, alignment: .leading).foregroundStyle(accent)
                        Text(pedalLabel(b.pedal)).font(.system(size: 11))
                            .frame(width: 40, alignment: .leading)
                        Text(b.action.title).font(.system(size: 12))
                        Spacer()
                        Button { model.removeBinding(b.id) } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func pedalLabel(_ p: Int) -> String { p < 0 ? "All" : pedalLetter(p) }
    private func pedalLetter(_ i: Int) -> String {
        i < 0 ? "All" : String(UnicodeScalar(65 + min(max(i, 0), 25))!)
    }

    private func composedAction() -> PadAction {
        switch cCategory {
        case .looper: return PadAction(kind: .looper, looper: cLooper)
        case .delay:  return PadAction(kind: .delayModel, arg: cModel)
        case .reverb: return PadAction(kind: .reverbModel, arg: cReverb)
        case .subdiv: return PadAction(kind: .subdivision, arg: Int(cSubdiv.rawValue))
        case .preset: return PadAction(kind: .preset, arg: cPreset)
        case .fx:
            switch cFX {
            case .squeal:      return PadAction(kind: .squeal)
            case .kill:        return PadAction(kind: .kill)
            case .fullWet:     return PadAction(kind: .fullWet)
            case .tap:         return PadAction(kind: .tap)
            case .drop:        return PadAction(kind: .drop)
            case .build:       return PadAction(kind: .build)
            case .feedbackVel: return PadAction(kind: .feedbackVel)
            case .mixVel:      return PadAction(kind: .mixVel)
            }
        }
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

            patternRow(label: model.pedalCount > 1 ? "Pattern — pedal A" : "Pattern (per bar)",
                       steps: $model.sequenceA, isB: false)
            if model.pedalCount > 1 {
                patternRow(label: "Pattern — pedal B", steps: $model.sequenceB, isB: true)
            }
        }
    }

    private func patternRow(label: String, steps: Binding<[Subdivision]>, isB: Bool) -> some View {
        let highlight = model.currentBar >= 0 ? model.currentBar % steps.wrappedValue.count : -1
        return VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(Array(steps.wrappedValue.indices), id: \.self) { i in
                    Menu(steps.wrappedValue[i].label) {
                        ForEach(Subdivision.allCases, id: \.rawValue) { s in
                            Button(s.label) { steps.wrappedValue[i] = s }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 50)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .fill(i == highlight ? accent.opacity(0.35) : Color.white.opacity(0.06)))
                }
                Button { model.removeStep(fromB: isB) } label: { Image(systemName: "minus") }
                    .buttonStyle(.borderless).disabled(steps.wrappedValue.count <= 1)
                Button { model.addStep(toB: isB) } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderless).disabled(steps.wrappedValue.count >= 8)
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
