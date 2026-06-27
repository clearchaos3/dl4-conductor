# dl4-conductor

Turn your Mac into the brain for one or two **Line 6 DL4 MkII** pedals over USB-C MIDI.

Two modes:

- **`conduct`** — a tempo-locked *delay conductor*. The Mac is the clock master, so the
  pedal's repeats lock to your tempo. It sequences delay subdivisions per bar (dotted-8th,
  quarter-triplet, …) and continuously sweeps feedback with a tempo-synced LFO — evolving
  rhythmic delays you can't get from a static patch. Plug in a second DL4 and it
  automatically plays a complementary subdivision against the first.
- **Grid controller** — route a USB MIDI controller (e.g. a Midi Fighter 64) into the DL4
  loopers. The Mac is the hub: it reads pad presses and translates each into a looper command
  on a chosen pedal, so you can drive two DL4 loopers independently from one grid. Mappings
  are **MIDI-learn** (tap a pad to assign) and persist across launches. Set up in the app's
  Grid Controller section.
- **`loop`** — a *phone looper remote*. Puts the pedal in Classic Looper mode and serves a
  small web page on your LAN so you can conduct the looper from your phone. (Note: for looping
  while you play, the DL4's own footswitches are easier — this is mainly for desk use.)

> The DL4 MkII's USB-C port is **MIDI + firmware only — not a USB audio interface**. Audio
> still runs through the 1/4"/XLR jacks. This app only sends MIDI; it's the brain, the pedal
> is the voice.

## Requirements

- macOS 13+, Swift 6 toolchain
- DL4 MkII connected by USB-C (it appears as a class-compliant MIDI device — no driver)
- For `conduct`: DL4 **Global Settings ▸ Receive MIDI Clock** = `Auto` or `On` (Auto is the
  factory default, so this usually just works)

## Install the app

```sh
./make-app.sh           # builds release + installs "DL4 Conductor.app" to /Applications
```

Then launch **DL4 Conductor** from Spotlight/Launchpad. The window shows detected pedals,
a BPM slider + Start/Stop for the conductor, looper transport buttons, and a phone-remote
toggle (prints the URL to open on your phone). It's ad-hoc signed for local use — not
notarized — so it runs because you built it yourself.

## CLI (handy for quick testing)

The same binary is a CLI when given a subcommand:

```sh
swift run dl4 list                 # show MIDI destinations and detected pedals
swift run dl4 test                 # sweep the Mix knob to confirm MIDI is getting through
swift run dl4 conduct --bpm 132    # run the delay conductor
swift run dl4 loop --port 8888     # looper mode + phone remote (open the printed URL on your phone)
```

## How it maps to the pedal

All control is on MIDI channel 1 (the DL4 factory default). Highlights from the manual's
MIDI implementation, encoded in [`CC.swift`](Sources/dl4/CC.swift):

| What | Message |
|------|---------|
| Tempo | MIDI Clock (24 PPQN) → repeats follow it |
| Subdivision | CC12 (0=1/8T … 2=1/8. … 8=1/2.) |
| Feedback / Repeats | CC13 (0–127) |
| Mix | CC16 |
| Delay / reverb model | CC1 / CC2 |
| Looper transport | CC60–66, CC9 (enter/exit looper) |

## Layout

| File | Role |
|------|------|
| `main.swift` | Entry point: CLI on a subcommand, else launches the GUI |
| `DL4App.swift` / `ContentView.swift` / `AppModel.swift` | SwiftUI app |
| `CLI.swift` | Terminal interface (`list` / `test` / `conduct` / `loop`) |
| `DL4Midi.swift` | CoreMIDI: find DL4 endpoints, send CC / PC / clock |
| `MidiClock.swift` | Low-jitter 24-PPQN clock on a dedicated thread |
| `Conductor.swift` | Subdivision sequencing + feedback LFO |
| `Looper.swift` | Semantic looper commands → CCs; `LooperFunction` |
| `MidiInput.swift` | CoreMIDI input: read a controller, learn/route pad presses |
| `WebServer.swift` + `LooperPage.swift` | Dependency-free phone remote |
| `CC.swift` | The DL4 MkII MIDI map |
| `make-app.sh` | Bundle the binary into `/Applications/DL4 Conductor.app` |

## Roadmap

- [x] Live per-bar subdivision editor in the app
- [x] App icon
- [x] Grid controller: MIDI-learn routing of a controller into the loopers
- [x] Grid LED feedback (Midi Fighter pads colored by state; app tracks state since the DL4
      reports nothing back). Color velocities in `ControllerLED.swift` may need calibration on
      real hardware.
- [x] Up to 4 DL4s addressed individually (A–D) + Identify flash
- [x] Reverse/Half toggle pads
- [x] Quantized looper triggers (the DL4 looper ignores MIDI clock, so the app holds hits
      and fires them on the next beat/bar; queued pads glow amber)
- [ ] More DL4s (arriving) — verify 4-pedal addressing + Identify on real hardware
- [ ] Dynamics-responsive delay (audio envelope → CC3) — uses the Apollo for audio in
- [ ] Optional shared-secret auth on the web remote (Swarm-style)
