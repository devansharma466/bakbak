# Bakbak

Personal, **fully on-device** dictation and meeting notes for macOS — Wispr Flow–style hold-to-talk plus Granola-style meeting notes, in one menubar app for Devan Sharma.

Hold **Right Option**, speak, release → polished text is pasted at the cursor in any app. English only. No accounts, no paid APIs, no cloud ASR.

| | |
| --- | --- |
| **Platform** | macOS 14+ (Apple Silicon) |
| **ASR** | [FluidAudio](https://github.com/FluidInference/FluidAudio) Parakeet TDT **v2** (English, Apache-2.0) |
| **Cleanup (Phase 2)** | Free + local only: Apple Foundation Models / Apple Intelligence when available → built-in heuristic rules. No paid API keys. |
| **Meeting notes** | Apple Intelligence on-device model (macOS 26+, Apple Intelligence on). Summary, decisions, action items. |
| **Signing** | Apple Development identity when available (stable TCC); ad-hoc fallback |

Phases **0–2** (dictation + cleanup + dictionary) and **4** (meeting mode, mic-first + optional ScreenCaptureKit system audio) are implemented. Phase 3 (languages / WhisperKit) is not started.

---

## Build & run (on your Mac)

### Prerequisites

- MacBook Pro with **Apple Silicon**
- **macOS 14+** (Apple Intelligence cleanup needs a Mac that exposes Foundation Models — typically recent macOS with Apple Intelligence enabled; heuristics always work)
- **Xcode 16+** (or current Command Line Tools with Swift 6) — needed for SwiftPM + Apple frameworks
- Network on **first** launch to download Parakeet Core ML models from Hugging Face (then cached locally)

No paid Apple Developer account. Ad-hoc signing is enough to run locally.

### Exact steps

```bash
cd /path/to/wispr-clone/app

# Resolve Swift packages (FluidAudio)
make fetch

# Optional: fast heuristic cleanup regression checks (no app bundle)
make check-cleanup

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
   Required for dictation and meeting mic capture.

2. **Accessibility**  
   System Settings → Privacy & Security → Accessibility → enable **Bakbak**.  
   Required for the global Right Option hotkey (CGEvent tap) and synthetic ⌘V paste.

3. **Screen Recording** (meetings — system audio)  
   System Settings → Privacy & Security → Screen Recording → enable **Bakbak**.  
   Used only so ScreenCaptureKit can capture **system audio** during meetings (Zoom / Meet / etc.). Screen frames are not saved. Without this, meetings still work **mic-only**.

If you rebuild or move the `.app`, macOS may treat it as a new binary:

- Remove Bakbak from Accessibility / Screen Recording, relaunch, re-enable (or toggle off/on).
- The onboarding sheet and **Refresh permissions** menu item help with this.

### First-run model download

On first successful ASR warm-up, FluidAudio downloads Parakeet **v2** (~hundreds of MB) into its local cache (typically under `~/.cache/fluidaudio/` or the library’s default). Stay online once; afterwards dictation works offline.

---

## How to use

1. Click a text field in Notes, Slack, Cursor, etc.
2. **Hold Right Option** and speak.
3. **Release** — Bakbak transcribes locally, runs free on-device cleanup (if enabled), and pastes at the cursor (clipboard is restored afterward).
4. Open the menu bar icon for status, last transcript, History, Dictionary, Meetings, and Settings.

### Meeting mode (Phase 4)

1. Menu bar → **Start meeting** (parrot / status becomes a red record icon while live).
2. Speak into the mic; if Screen Recording is granted, system audio is captured too.
3. **Stop meeting** → on-device Parakeet transcription (chunked for long audio) → optional cleanup → saved to the Meetings library.
4. Bakbak then writes **notes** in the background: a short summary, decisions, and action items with an owner ("You: send the draft by Friday").
5. Menu → **Meetings…** to browse, copy (transcript or notes), rename, rewrite notes, or delete.

**You / Them labels.** With system audio, the mic is *you* and system audio is *them*. Every 100 ms Bakbak checks which track is louder (on laptop speakers the mic hears the call too, but much more quietly than the system feed), groups that into speaker turns, and transcribes each turn separately. Mic-only meetings get a plain transcript. Headphones give the cleanest split. Logic: `Sources/Bakbak/Audio/SpeakerTurns.swift`.

**Notes.** `Sources/Bakbak/Notes/MeetingNotesWriter.swift` uses Apple's on-device model with structured output. Long transcripts are noted in parts that fit the model's context (~1,200 words each), action items are owned per part (the model quotes the line where someone takes the task on), and the summaries and decisions are merged. A 20-minute meeting takes ~30 s. Needs Apple Intelligence turned on (System Settings → Apple Intelligence & Siri); without it, meetings still save with transcripts.

**Retention:** transcripts and notes auto-delete after **30 days** (on launch and when saving). Audio is not retained.  
**Files:** `~/Library/Application Support/Bakbak/meetings.json` (older files load fine; new fields are optional)  
**Checks:** `make check-meeting` (speaker turns, transcript formatting, notes helpers; no models needed)  
**Deferred:** live rolling transcript, auto-start when a call begins, search across meetings.

---

## Phase 2 — Cleanup + personal dictionary

### What cleanup does

When **Clean-up** is on (Settings / menu checkbox; default on):

1. **Apple Intelligence** (optional, when the Mac exposes Foundation Models and the toggle is on) — short on-device rewrite with your dictionary injected into the instructions. Rejects odd / too-long output and falls back.
2. **Heuristic rules** (always available, free, no network) — used when Apple Intelligence is off, unavailable, slow, or rejected:
   - Strip fillers: `um` / `uh` / `erm` / `hmm`, pause-delimited `you know`, hedge `like` (`, like,` / leading `Like,`)
   - Stutter collapse: `I I think` → `I think`
   - Self-corrections: `Tuesday, I mean Wednesday` → `Wednesday`; `John, sorry, Jane` (proper nouns); `three no wait four`; `scratch that`
   - Punctuation + sentence capitals; `i` / `i'm` → `I`; terminal `.` or `?` when it looks like a question
   - Personal dictionary spellings (and “heard as” aliases)

When cleanup is **off**, the raw ASR text is pasted, but dictionary spellings still apply.

### What cleanup does **not** do yet

- Full LLM rewriting / tone / list formatting
- MLX local models (intentionally not linked — heavy deps; stub falls through to heuristics)
- Paid cloud APIs (OpenAI / Anthropic / Groq etc. — dropped by design)
- Non-English
- Voice snippets / commands (deferred)
- WhisperKit / multilingual (Phase 3)

### Personal dictionary

- Menu → **Dictionary…** or Settings → **Edit dictionary…**
- Each entry: preferred **Spelling** + optional **Heard as** aliases (comma-separated)
- Stored at `~/Library/Application Support/Bakbak/dictionary.json`
- CamelCase terms also match spaced ASR (`fluid audio` → `FluidAudio`)
- Old Phase 0/1 JSON that used `replacement` migrates automatically (`term` spoken → `replacement` written becomes `term` + alias)

### Settings

| Setting | Default | Notes |
| --- | --- | --- |
| Clean up transcripts | On | Master switch |
| Use Apple Intelligence when available | **Off** | Falls back to heuristics; status string shown in Settings |
| Edit dictionary… | — | Add / edit / delete |

---

## Project layout

```
app/
  Package.swift              SwiftPM executable (macOS 14+)
  Makefile                   fetch / build / app / run / check-cleanup
  Scripts/build_app.sh       .app bundle + ad-hoc codesign
  Scripts/check_cleanup.sh   Heuristic cleanup regression checks
  Resources/Info.plist       LSUIElement, NSMicrophoneUsageDescription, CFBundleIconFile
  Resources/bakbak-menubar*.png  Menu bar template (black silhouette)
  Resources/Bakbak.iconset/  Pre-sized Dock icon PNGs (*_2x → @2x on Mac)
  Scripts/generate_icns.sh   macOS: iconutil → Resources/Bakbak.icns
  Sources/Bakbak/
    BakbakApp.swift          MenuBarExtra entry
    AppState.swift           Dictation pipeline coordinator
    Models/                  Settings, dictionary, history types
    Stores/                  JSON persistence (Application Support/Bakbak/)
    Permissions/             Mic + Accessibility helpers
    Hotkey/                  CGEvent tap (Right Option = 61)
    Audio/                   Mic (AVAudioEngine) + MeetingRecorder + ScreenCaptureKit system audio
    ASR/                     FluidAudio Parakeet wrapper (chunked for meetings)
    Cleanup/                 BakbakCleanupService (Apple Intelligence → heuristics)
    Insertion/               Pasteboard + ⌘V + restore
    Stores/                  History + MeetingStore (30-day retention)
    UI/                      Menu, onboarding, settings, history, dictionary, meetings
```

Data files (local only):

- `~/Library/Application Support/Bakbak/settings.json`
- `~/Library/Application Support/Bakbak/dictionary.json`
- `~/Library/Application Support/Bakbak/history.json`
- `~/Library/Application Support/Bakbak/meetings.json`

---

## Design notes

### Hotkey

Default: **hold Right Option** (`keyCode` 61) via `CGEvent` tap. Configurable hotkeys are deferred. Re-grant Accessibility after resigning/moving the app.

### Text insertion

1. Snapshot all pasteboard items (not just strings).  
2. Write transcript as `.string`.  
3. Post synthetic ⌘V (`virtualKey` 9).  
4. Restore previous pasteboard after a short delay if nothing else wrote to it.

### Cleanup (Phase 2 — implemented)

`TextCleanupService` protocol. Default: `BakbakCleanupService`.

1. Apple Foundation Models / Apple Intelligence when `#available` + model `.available` (no network, no API key)
2. `HeuristicCleanupService` for fillers / self-corrections / punctuation / dictionary
3. `LocalMLXCleanupService` remains a stub (no MLX dependency)

**No paid API keys** and no cloud cleanup services.

### Licences

- App code: personal; keep FluidAudio Apache-2.0 notices when distributing.
- FluidAudio: Apache-2.0.
- Patterns studied from MIT projects (e.g. open-wispr) — no GPL code (no VoiceInk, no linked BlackHole).

---

## Cost / accounts

| Item | Needed? |
| --- | --- |
| Apple Developer Program ($99/yr) | **No** for personal use — free Apple Development identity preferred for stable permissions |
| OpenAI / Anthropic / Groq API | **No** |
| Wispr / other SaaS | **No** |
| Hugging Face (model download) | Free account may be needed only if HF rate-limits anonymous downloads; models themselves are open |

---

## What is not done yet

- Phase 3: languages / WhisperKit / toggle mode  
- Meeting niceties: live transcript, diarisation, summary / action items  
- Configurable hotkey UI  
- Snippets / voice commands  
- MLX local cleanup model (optional; heuristics cover the free path for now)  
- Notarisation / Developer ID (only if you later distribute outside personal use)

---

## Troubleshooting

| Symptom | Try |
| --- | --- |
| Hotkey does nothing | Accessibility for this exact `Bakbak.app`; restart app after granting |
| No paste | Accessibility; try TextEdit; some apps block synthetic events |
| Empty transcript | Speak longer; check Microphone permission; wait for model load |
| Cleanup too aggressive | Turn off **Clean up transcripts**, or add dictionary entries for names it “corrects” |
| Apple Intelligence unused | Check Settings status; heuristics still run. Needs a Mac/OS that exposes Foundation Models |
| Event tap dies after rebuild | Remove & re-add Accessibility entry; `tccutil reset Accessibility dev.devansharma.bakbak` (optional) |
