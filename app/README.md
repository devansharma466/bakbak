# Bakbak

Personal, **fully on-device** dictation for macOS — a Wispr Flow–style hold-to-talk menubar app for Devan Sharma.

Hold **Right Option**, speak, release → polished text is pasted at the cursor in any app. English only. No accounts, no paid APIs, no cloud ASR.

| | |
| --- | --- |
| **Platform** | macOS 14+ (Apple Silicon) |
| **ASR** | [FluidAudio](https://github.com/FluidInference/FluidAudio) Parakeet TDT **v2** (English, Apache-2.0) |
| **Cleanup (Phase 2)** | On-device only: Apple Foundation Models / Apple Intelligence → local MLX → regex fillers |
| **Signing** | Ad-hoc (`codesign -s -`) — **no Apple Developer Program ($99) needed** for personal use |

Phases **0** (scaffold) and **1** (MVP dictation) are implemented in this folder. Phase 2+ is stubbed only.

---

## Build & run (on your Mac)

### Prerequisites

- MacBook Pro with **Apple Silicon**
- **macOS 14+**
- **Xcode 16+** (or current Command Line Tools with Swift 6) — needed for SwiftPM + Apple frameworks
- Network on **first** launch to download Parakeet Core ML models from Hugging Face (then cached locally)

No paid Apple Developer account. Ad-hoc signing is enough to run locally.

### Exact steps

```bash
cd /path/to/wispr-clone/app

# Resolve Swift packages (FluidAudio)
make fetch

# Build release binary + assemble Bakbak.app + ad-hoc sign
make app

# Launch
make run
# or: open dist/Bakbak.app
```

Manual equivalent:

```bash
swift build -c release --arch arm64
./Scripts/build_app.sh
open dist/Bakbak.app
```

### Permissions to grant

1. **Microphone**  
   System Settings → Privacy & Security → Microphone → enable **Bakbak**.  
   (Also prompted on first use via `NSMicrophoneUsageDescription`.)

2. **Accessibility**  
   System Settings → Privacy & Security → Accessibility → enable **Bakbak**.  
   Required for the global Right Option hotkey (CGEvent tap) and synthetic ⌘V paste.

If you rebuild or move the `.app`, macOS may treat it as a new binary:

- Remove Bakbak from Accessibility, relaunch, re-enable (or toggle off/on).
- The onboarding sheet and **Refresh permissions** menu item help with this.

### First-run model download

On first successful ASR warm-up, FluidAudio downloads Parakeet **v2** (~hundreds of MB) into its local cache (typically under `~/.cache/fluidaudio/` or the library’s default). Stay online once; afterwards dictation works offline.

---

## How to use

1. Click a text field in Notes, Slack, Cursor, etc.
2. **Hold Right Option** and speak.
3. **Release** — Bakbak transcribes locally and pastes at the cursor (clipboard is restored afterward).
4. Open the menu bar icon for status, last transcript, History, and Settings.

---

## Project layout

```
app/
  Package.swift              SwiftPM executable (macOS 14+)
  Makefile                   fetch / build / app / run
  Scripts/build_app.sh       .app bundle + ad-hoc codesign
  Resources/Info.plist       LSUIElement, NSMicrophoneUsageDescription
  Sources/Bakbak/
    BakbakApp.swift          MenuBarExtra entry
    AppState.swift           Dictation pipeline coordinator
    Models/                  Settings, dictionary, history types
    Stores/                  JSON persistence (Application Support/Bakbak/)
    Permissions/             Mic + Accessibility helpers
    Hotkey/                  CGEvent tap (Right Option = 61)
    Audio/                   AVAudioEngine → 16 kHz mono Float32
    ASR/                     FluidAudio Parakeet wrapper
    Cleanup/                 Protocol + pass-through stub (Phase 2)
    Insertion/               Pasteboard + ⌘V + restore
    UI/                      Menu, onboarding, settings, history
```

Data files (local only):

- `~/Library/Application Support/Bakbak/settings.json`
- `~/Library/Application Support/Bakbak/dictionary.json` (empty until Phase 2)
- `~/Library/Application Support/Bakbak/history.json`

---

## Design notes

### Hotkey

Default: **hold Right Option** (`keyCode` 61) via `CGEvent` tap. Configurable hotkeys are deferred. Re-grant Accessibility after resigning/moving the app.

### Text insertion

1. Snapshot all pasteboard items (not just strings).  
2. Write transcript as `.string`.  
3. Post synthetic ⌘V (`virtualKey` 9).  
4. Restore previous pasteboard after a short delay if nothing else wrote to it.

### Cleanup (Phase 2 — stub only)

`TextCleanupService` is a protocol. Phase 1 uses `PassthroughCleanupService`. Planned free path only:

1. Apple Foundation Models / Apple Intelligence (when the OS exposes it)
2. Small **local MLX** model
3. `RegexFillerCleanupService` for “um” / “uh” etc.

**No paid API keys** and no cloud cleanup services.

### Licences

- App code: personal; keep FluidAudio Apache-2.0 notices when distributing.
- FluidAudio: Apache-2.0.
- Patterns studied from MIT projects (e.g. open-wispr) — no GPL code (no VoiceInk, no linked BlackHole).

---

## Cost / accounts

| Item | Needed? |
| --- | --- |
| Apple Developer Program ($99/yr) | **No** — ad-hoc sign for personal use |
| OpenAI / Anthropic / Groq API | **No** |
| Wispr / other SaaS | **No** |
| Hugging Face (model download) | Free account may be needed only if HF rate-limits anonymous downloads; models themselves are open |

---

## What is not done yet

- Phase 2: real cleanup + dictionary biasing + snippets  
- Phase 3: languages / WhisperKit / toggle mode  
- Phase 4: meeting mode (ScreenCaptureKit)  
- Configurable hotkey UI  
- Notarisation / Developer ID (only if you later distribute outside personal use)

---

## Troubleshooting

| Symptom | Try |
| --- | --- |
| Hotkey does nothing | Accessibility for this exact `Bakbak.app`; restart app after granting |
| No paste | Accessibility; try TextEdit; some apps block synthetic events |
| Empty transcript | Speak longer; check Microphone permission; wait for model load |
| Event tap dies after rebuild | Remove & re-add Accessibility entry; `tccutil reset Accessibility dev.devansharma.bakbak` (optional) |
