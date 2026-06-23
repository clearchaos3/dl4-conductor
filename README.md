# dl4-conductor

Turn your Mac into the brain for one or two **Line 6 DL4 MkII** pedals over USB-C MIDI.

Two modes:

- **`conduct`** — a tempo-locked *delay conductor*. The Mac is the clock master, so the
  pedal's repeats lock to your tempo. It sequences delay subdivisions per bar (dotted-8th,
  quarter-triplet, …) and continuously sweeps feedback with a tempo-synced LFO — evolving
  rhythmic delays you can't get from a static patch. Plug in a second DL4 and it
  automatically plays a complementary subdivision against the first.
- **`loop`** — a *phone looper remote*. Puts the pedal in Classic Looper mode and serves a
  small web page on your LAN so you can conduct the looper (record / overdub / play / stop /
  reverse / half-speed) from your phone.

> The DL4 MkII's USB-C port is **MIDI + firmware only — not a USB audio interface**. Audio
> still runs through the 1/4"/XLR jacks. This app only sends MIDI; it's the brain, the pedal
> is the voice.

## Requirements

- macOS 13+, Swift 6 toolchain
- DL4 MkII connected by USB-C (it appears as a class-compliant MIDI device — no driver)
- For `conduct`: DL4 **Global Settings ▸ Receive MIDI Clock** = `Auto` or `On` (Auto is the
  factory default, so this usually just works)

## Usage

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
| `DL4Midi.swift` | CoreMIDI: find DL4 endpoints, send CC / PC / clock |
| `MidiClock.swift` | Low-jitter 24-PPQN clock on a dedicated thread |
| `Conductor.swift` | Subdivision sequencing + feedback LFO |
| `Looper.swift` | Semantic looper commands → CCs |
| `WebServer.swift` + `LooperPage.swift` | Dependency-free phone remote |
| `CC.swift` | The DL4 MkII MIDI map |

## Roadmap

- [ ] Second DL4 (arriving) — verify the dotted-vs-triplet stereo interplay
- [ ] Live tempo / subdivision editing from the web UI
- [ ] Dynamics-responsive delay (audio envelope → CC3) — needs an audio interface
- [ ] Optional shared-secret auth on the web remote (Swarm-style)
