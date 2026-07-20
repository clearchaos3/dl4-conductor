import SwiftUI

enum ActionCategory: String, CaseIterable, Identifiable {
    case looper = "Looper", delay = "Delay Model", reverb = "Reverb Model",
         subdiv = "Subdivision", preset = "Preset", fx = "FX"
    var id: String { rawValue }
}

enum FXKind: String, CaseIterable, Identifiable {
    case reverseToggle = "Reverse (toggle)", halfToggle = "Half (toggle)",
         squeal = "Squeal (hold)", kill = "Kill (hold)", fullWet = "100% Wet (hold)",
         tap = "Tap Tempo", drop = "Drop", build = "Build",
         feedbackVel = "Feedback (vel)", mixVel = "Mix (vel)"
    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    private let accent = Color(red: 0.36, green: 0.75, blue: 0.45)

    @State private var editMode = false

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
        // Stage layout, orientation-aware: three columns on a landscape
        // display; on a portrait (rotated) display everything stacks in
        // glance-priority order — pedals, pad map, controls.
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width
            VStack(spacing: 14) {
                toolbar
                if portrait { portraitLayout } else { landscapeLayout }
            }
            .padding(18)
        }
        .frame(minWidth: 960, minHeight: 720)
        .background(Color(red: 0.043, green: 0.051, blue: 0.047))
        .onAppear {
            // Dedicated rig display: claim the whole screen on launch so the
            // portrait dashboard gets its full 1080x1920.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let w = NSApp.windows.first(where: { $0.isVisible }),
                   let screen = w.screen ?? NSScreen.main {
                    w.setFrame(screen.visibleFrame, display: true, animate: false)
                }
            }
        }
    }

    private var gridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
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

            if model.learnTarget == nil {
                LastInText(activity: model.activity)
            } else {
                Text("Press the pad to assign…")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(accent)
            }

            quantizeRow

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

    private var quantizeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Toggle("Quantize", isOn: $model.quantizeEnabled).toggleStyle(.switch)
                if model.quantizeEnabled {
                    Picker("", selection: $model.quantizeGrid) {
                        ForEach(QuantizeGrid.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 120)
                    Stepper("\(model.quantizeBeatsPerBar)/bar", value: $model.quantizeBeatsPerBar, in: 2...12)
                        .frame(width: 110)
                }
                Spacer()
                if model.pendingCount > 0 {
                    Text("\(model.pendingCount) queued")
                        .font(.system(size: 11)).foregroundStyle(accent)
                }
            }
            if model.quantizeEnabled {
                Text("Looper hits fire on the next \(model.quantizeGrid == .beat ? "beat" : "bar"). Queued pads glow amber.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }

            Divider().padding(.vertical, 2)

            HStack(spacing: 12) {
                Toggle("Sync to Ableton clock", isOn: $model.syncExternal).toggleStyle(.switch)
                Spacer()
                Text(model.clockStatus)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(model.clockStatus.contains("▶") ? accent : .secondary)
            }
            if model.syncExternal {
                Text("Set up an IAC bus (Audio MIDI Setup) and enable Ableton's Sync output to it. The app follows that clock.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Toggle("Re-sync loops (retrigger)", isOn: $model.retriggerEnabled).toggleStyle(.switch)
                if model.retriggerEnabled {
                    Stepper("\(model.loopBars) bars", value: $model.loopBars, in: 1...32).frame(width: 110)
                }
                Spacer()
                if !model.activePedals.isEmpty {
                    Text("loops: " + model.activePedals.sorted().map { pedalLetter($0) }.joined(separator: " "))
                        .font(.system(size: 11)).foregroundStyle(accent)
                }
            }
            if model.retriggerEnabled {
                Text("Each active loop re-fires from bar 1 every \(model.loopBars) bars on the clock, so drift never builds up. Record loops to \(model.loopBars)-bar lengths.")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
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
            case .reverseToggle: return PadAction(kind: .reverseToggle)
            case .halfToggle:    return PadAction(kind: .halfToggle)
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

    private var landscapeLayout: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 14) {
                panel("PEDALBOARD") { PedalBoardView() }
                Spacer(minLength: 0)
            }
            .frame(width: 470)

            panel("MIDI FIGHTER 64") { GridMapView(activity: model.activity) }
                .frame(maxWidth: .infinity)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    panel("CONDUCTOR") { conductorSection }
                    panel("GRID CONTROLLER") { gridSection }
                    panel("LOOPER") { looperSection }
                }
            }
            .frame(width: 430)
        }
    }

    /// Portrait (rotated 1080x1920) stage dashboard: fixed no-scroll zones in
    /// glance-priority order — loop lanes, pedal renders, pad map, performance
    /// strip. Edit mode swaps the middle for the config panels.
    private var portraitLayout: some View {
        GeometryReader { geo in
            VStack(spacing: 12) {
                if editMode {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            panel("CONDUCTOR") { conductorSection }
                            panel("GRID CONTROLLER") { gridSection }
                            panel("LOOPER") { looperSection }
                        }
                    }
                } else {
                    LoopLanesView()
                        .frame(minHeight: geo.size.height * 0.185,
                               maxHeight: geo.size.height * 0.235)
                    panel("PEDALBOARD") { PedalBoardView() }
                        .frame(maxHeight: geo.size.height * 0.28)
                    panel("MIDI FIGHTER 64") { GridMapView(activity: model.activity) }
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                performStrip
            }
        }
    }

    /// Always-visible bottom strip in portrait: the numbers and switches that
    /// matter mid-jam, plus the door into Edit mode.
    private var performStrip: some View {
        HStack(spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(model.bpm))")
                    .font(.system(size: 46, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                Text("BPM")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            if model.isConducting {
                Text(model.conductorLine)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Toggle("Looper", isOn: Binding(
                get: { model.looperModeOn },
                set: { model.setLooperMode($0) }))
                .toggleStyle(.switch)
            Toggle("Quantize", isOn: $model.quantizeEnabled)
                .toggleStyle(.switch)
            Button(editMode ? "Perform" : "Edit") { editMode.toggle() }
                .font(.system(size: 14, weight: .semibold))
        }
        .font(.system(size: 13))
        .padding(.horizontal, 6)
    }

    /// Slim top bar: wordmark, one presence chip per pedal slot, live bar
    /// readout while conducting, utilities on the right.
    private var toolbar: some View {
        HStack(spacing: 16) {
            Text("DL4 CONDUCTOR")
                .font(.system(size: 15, weight: .bold)).tracking(4).foregroundStyle(accent)
            HStack(spacing: 8) {
                ForEach(0..<max(model.pedalCount, 4), id: \.self) { i in
                    let present = model.midi.isPresent(i)
                    HStack(spacing: 4) {
                        Circle().fill(present ? accent : Color(red: 0.75, green: 0.25, blue: 0.22))
                            .frame(width: 7, height: 7)
                        Text(i < Conductor.pedalLetters.count ? Conductor.pedalLetters[i] : "\(i + 1)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(present ? .primary : .secondary)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                }
            }
            Spacer()
            if model.isConducting {
                Text(model.conductorLine)
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Button("Rescan") { model.rescan() }
            Button("Zero") { model.zeroAll() }.disabled(model.presentPedals == 0)
                .help("Reset all pedals to a clean baseline: un-bypass, 50% mix, moderate repeats, forward, full speed")
            Button("Test") { model.testSweep() }.disabled(model.presentPedals == 0)
        }
    }

    /// Observes PadActivity alone so per-press label updates don't re-render
    /// the whole ContentView.
    private struct LastInText: View {
        @ObservedObject var activity: PadActivity
        var body: some View {
            Text("Last in: \(activity.lastLabel.isEmpty ? "—" : activity.lastLabel)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    /// Section card: silkscreen-style tracked title over a quiet panel.
    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .bold)).tracking(2.4)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: Conductor

    private var conductorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            // One pattern row per connected pedal (A…D)
            ForEach(0..<max(1, min(model.pedalCount, 4)), id: \.self) { p in
                patternRow(pedal: p)
            }
            if model.pedalCount > 1 {
                Toggle("Stagger feedback LFO across pedals", isOn: $model.lfoStaggered)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func patternRow(pedal: Int) -> some View {
        let steps = model.sequences[pedal]
        let label = model.pedalCount > 1
            ? "Pattern — pedal \(Conductor.pedalLetters[pedal])"
            : "Pattern (per bar)"
        let highlight = model.currentBar >= 0 && !steps.isEmpty ? model.currentBar % steps.count : -1
        return VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(Array(steps.indices), id: \.self) { i in
                    Menu(steps[i].label) {
                        ForEach(Subdivision.allCases, id: \.rawValue) { s in
                            Button(s.label) { model.sequences[pedal][i] = s }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 50)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .fill(i == highlight ? accent.opacity(0.35) : Color.white.opacity(0.06)))
                }
                Button { model.removeStep(pedal: pedal) } label: { Image(systemName: "minus") }
                    .buttonStyle(.borderless).disabled(steps.count <= 1)
                Button { model.addStep(pedal: pedal) } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderless).disabled(steps.count >= 8)
            }
        }
    }

    // MARK: Looper

    private var looperSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Toggle("Looper mode", isOn: Binding(
                    get: { model.looperModeOn },
                    set: { model.setLooperMode($0) }))
                    .toggleStyle(.switch).disabled(model.presentPedals == 0)
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
