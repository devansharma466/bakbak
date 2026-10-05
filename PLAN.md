# Wispr Flow Clone — Build Brief (macOS)

**For:** Devan Sharma  
**Target:** MacBook Pro (Apple Silicon), macOS 14+ (Ventura/Sonoma/Sequoia)  
**Status:** Research complete — awaiting approval before coding  
**Date:** 5 Oct 2026 (Europe/London)

---

## 1. Feature list

Mapped from Wispr Flow (dictation + Notetaker) to a **personal, mostly on-device** macOS clone.

### Must-have (v1)

| Feature | Notes |
| --- | --- |
| System-wide push-to-talk | Hold global hotkey → record mic → release → insert polished text at cursor in any app |
| Near-real-time local ASR | On-device transcription; no account required for core dictation |
| AI clean-up / formatting | Strip fillers (“um”, “uh”), fix self-corrections, punctuation, light structure (lists, paragraphs) |
| Personal dictionary | Manual + auto-add from corrections; bias ASR/LLM toward names, jargon |
| Text injection | Accessibility-based paste / keystroke insert into focused field; clipboard restore |
| History | Local-only recent dictations (opt-in audio retention off by default) |
| Permissions UX | Clear onboarding for Microphone + Accessibility (+ Screen Recording later for meetings) |

### Nice-to-have (v1.5)

| Feature | Notes |
| --- | --- |
| Multiple languages | Auto-detect or manual language; English-first engine + Whisper fallback for 100-ish languages |
| Voice commands / snippets | Spoken cues expand to canned text (scheduling link, signature, FAQ) |
| Hands-free toggle mode | Press once to start, again to stop (in addition to hold-to-talk) |
| Whisper mode / quiet speech | Bias VAD + model for soft speech |
| Per-app tone (stretch) | Detect frontmost app → apply style prompt (formal / casual / code-aware) |
| Optional cloud LLM | User-supplied API key for stronger cleanup when offline LLM isn’t enough |

### Later

| Feature | Notes |
| --- | --- |
| Meeting mode | Record **system audio + mic**, live or post transcript, **speaker diarisation**, then summary + action items |
| Meeting search / Q&A | Ask questions over past meetings |
| Shared team dictionary / snippets | Out of scope for personal v1 |
| Mobile / Windows / sync | Out of scope — macOS only |
| Developer-aware code dictation | Syntax/file-name awareness beyond basic cleanup |

### macOS constraints (must design for)

- **Accessibility** — required for global hotkey observation (CGEvent tap) and inserting text into other apps.
- **Microphone** — required for dictation and meeting mic track.
- **Screen Recording** — required for **ScreenCaptureKit** system-audio capture in meeting mode (macOS 13+); no virtual driver needed if this path works.
- **Privacy** — default: audio never leaves the machine; cloud LLM only if Devan opts in with an API key.
- **Hotkeys** — Caps Lock is unreliable for hold-to-talk; prefer Globe / Right Option / custom chord (Wispr uses Fn on Mac).
- **Sandbox / notarisation** — personal unsigned or ad-hoc signed builds are fine for private use; event taps need care if code-signing identity changes.
- **BlackHole** — useful fallback for system audio but **GPL-3.0**; prefer ScreenCaptureKit so the app itself stays MIT/Apache-clean. Document BlackHole only as an optional user-installed driver, not a linked dependency.

---

## 2. Chosen foundation + licence notes

### One-sentence recommendation

**Build a thin SwiftUI menubar shell around FluidAudio (Parakeet ASR + VAD + diarisation, Apache-2.0) with WhisperKit (MIT) as multilingual fallback, ScreenCaptureKit for meetings, and a local or optional-cloud LLM for cleanup — using open-wispr / open-flow only as MIT reference for hotkeys and paste, not as a GPL fork.**

### Why this wins for personal macOS use

| Criterion | Rationale |
| --- | --- |
| Apple Silicon | FluidAudio runs on Neural Engine; WhisperKit is Core ML; both are native Swift |
| Speed | Parakeet TDT via FluidAudio is far faster than Whisper for English (~100–190× RTFx class); good push-to-talk feel |
| Languages | Parakeet covers ~25 European languages; WhisperKit `large-v3-turbo` covers ~100 languages when needed |
| Meeting path | FluidAudio already ships offline + streaming diarisation (and VAD) — avoids bolting Python pyannote into a Swift app for v1 |
| Privacy | Fully local dictation path; Wispr Flow itself requires internet for transcription |
| Licence | Apache-2.0 + MIT stack is safe for a private personal app (and for later open-sourcing if desired) |

### Licence clearance (private personal app)

| Component | Licence | OK for private personal use? |
| --- | --- | --- |
| **FluidAudio** | Apache-2.0 | Yes — retain notices |
| **WhisperKit** (argmaxinc) | MIT | Yes |
| **whisper.cpp** (fallback / reference) | MIT | Yes |
| **open-wispr** (reference patterns) | MIT | Yes — may study / adapt |
| **open-flow** (reference) | MIT | Yes — early/small; good ideas (Parakeet + Apple Intelligence cleanup) |
| **local-dictation** | MIT OR Apache-2.0 | Yes — Rust reference for cleanup prompts |
| **BlackHole** | GPL-3.0 | Do **not** link into the app; optional separate install only |
| **VoiceInk** | GPLv3 | Do **not** copy code into a closed private app if you might distribute; fine to *use* the app or study behaviour. Prefer not as code foundation |
| **whisperX** | BSD-2-Clause | OK for optional Python meeting pipeline; pyannote **models** need HF token + accept terms (CC-BY community models) |
| **faster-whisper** | MIT | OK if we ever use a Python sidecar |

**Decision:** No GPL app code in the tree. No BlackHole as a required dependency. Hugging Face token only if we later use gated pyannote weights; FluidAudio’s Core ML diarisation path is preferred to avoid that.

### Serious candidates evaluated (summary)

| Candidate | Stars / activity (approx.) | Licence | Apple Silicon | Real-time | Gaps vs our goals |
| --- | --- | --- | --- | --- | --- |
| FluidAudio | Active Swift SDK; used by several macOS dictation apps | Apache-2.0 | Excellent (ANE) | Streaming ASR + diarisation | Not a full PTT app — library only |
| WhisperKit | Mature (~Argmax OSS) | MIT | Excellent | Streaming / server modes; Pro features gated | No PTT UI; advanced custom vocab / speaker RT is Pro |
| whisper.cpp | ~50k+ ★ | MIT | Metal | Near-RT with chunking | C++ integrate or CLI; no cleanup / meetings |
| open-wispr | ~210 ★ | MIT | Yes | Hold-to-talk | No AI cleanup, no meetings, no dictionary product layer |
| open-flow | ~5 ★ (early) | MIT | Yes (Parakeet + WhisperKit) | Hold-to-talk | Small/new; good architecture sketch to learn from |
| local-dictation | Active Rust | MIT/Apache | Yes (Parakeet + Qwen) | ~150–400 ms class | Rust daemon, not SwiftUI; no meeting mode |
| VoiceInk | ~6k ★ | **GPLv3** | Yes | Strong product | Licence friction for private closed derivative |
| whisperX + pyannote | Popular Python | BSD-2 + model terms | CPU/MPS; not ANE-native | Offline batch strong | Heavy Python deps; HF token; awkward in native app |
| muesli | Tiny / early | Check before use | ScreenCaptureKit + faster-whisper | Meeting-oriented | Immature; Python stack |

---

## 3. Architecture sketch

```
┌─────────────────────────────────────────────────────────────┐
│  SwiftUI menubar app (macOS)                                │
│  Hotkey service · Permissions · Dictionary · History · UI   │
└───────────────┬─────────────────────────────┬───────────────┘
                │                             │
        Dictation path                 Meeting path (later)
                │                             │
                ▼                             ▼
        Mic (AVAudioEngine)          Mic + System audio
                                     (ScreenCaptureKit;
                                      BlackHole optional fallback)
                │                             │
                ▼                             ▼
        VAD (FluidAudio)             Mix / dual-track record
                │                             │
                ▼                             ▼
        ASR: FluidAudio Parakeet     ASR: FluidAudio / WhisperKit
        (default, EN + EU langs)     + Diarisation (FluidAudio)
                │                    (WhisperKit if language needs it)
                │                             │
                ▼                             ▼
        Cleanup LLM                  Transcript + speakers
        - Local: Apple Intelligence  → Summary / actions LLM
          and/or MLX small model
        - Optional: user API key
                │                             │
                ▼                             ▼
        Inject text at cursor        Save markdown note locally
        (AX / CGEvent paste)         (Meetings/ folder)
```

**Dictation path (MVP):** hotkey down → record → hotkey up → VAD trim → Parakeet → prompt with personal dictionary → cleanup → paste → restore clipboard.

**Meeting path:** start/stop from menubar → capture mic + system audio → post-process ASR + diarisation → LLM summary → local store. Live partial transcript is a stretch after offline meeting works.

---

## 4. Build phases

### Phase 0 — Scaffold (½–1 day)
- Xcode / SwiftPM macOS menubar app skeleton under this project (no GitHub repo unless Devan asks).
- Permission helpers (Mic, Accessibility).
- Empty settings + dictionary store (JSON/SQLite).

### Phase 1 — MVP dictation (core)
- Global hold-to-talk hotkey.
- Mic capture → FluidAudio Parakeet transcription.
- Paste into focused app; clipboard-safe restore.
- Basic local history.
- **Exit criteria:** dictate into Notes, Slack, Cursor reliably on Devan’s MacBook Pro.

### Phase 2 — Cleanup + dictionary
- Cleanup prompt (filler removal, punctuation, light formatting).
- Prefer on-device path first (Apple Foundation Models / Apple Intelligence if available on OS; else small MLX model; else optional API).
- Personal dictionary biasing (prompt injection + optional Whisper/Parakeet hotwords where supported).
- Snippets / simple voice commands.
- **Exit criteria:** “um”-heavy speech becomes sendable prose; custom names spell correctly.

### Phase 3 — Languages + polish
- Language picker + WhisperKit fallback for non-Parakeet languages.
- Toggle mode, sound feedback, model download UX.
- Optional per-app tone map (frontmost bundle ID → style).

### Phase 4 — Meeting mode
- Screen Recording permission + ScreenCaptureKit capture (mic + system).
- Offline transcript + FluidAudio diarisation.
- Summary / decisions / action items via same LLM stack.
- Local meeting library (search later).

### Phase 5 — Hardening (ongoing)
- Latency budgets, battery, thermal.
- Failure modes (no focus field → copy only).
- Privacy mode defaults; no telemetry unless explicitly added later.

---

## 5. What we need from Devan before coding

1. **Approve this plan** (or mark changes to Must / Nice / Later).
2. **macOS version** on the MacBook Pro (14 / 15 / 16?) — gates Apple Intelligence / Foundation Models and ScreenCaptureKit behaviour.
3. **Chip** (M1 / M2 / M3 / M4 and Pro/Max if known) — model size defaults.
4. **Primary languages** for dictation (e.g. English + Hindi? others?) — sets Parakeet vs WhisperKit default.
5. **Cleanup preference:** fully local only vs OK to use a personal OpenAI/Anthropic/Groq API key as optional turbo path.
6. **Hotkey preference** (Globe / Right Option / Fn-style / custom).
7. **Private repo:** confirm **no GitHub repo for now** (already the default); when ready, private repo OK? GitHub account to use?
8. **Permissions:** willing to grant Microphone, Accessibility, and later Screen Recording on the build Mac.
9. **Meeting scope for v1:** confirm meetings stay in “Later / Phase 4” so MVP ships dictation first.
10. **Name** for the app (internal codename is fine).

### Risks / unknowns

| Risk | Mitigation |
| --- | --- |
| Event-tap / Accessibility flaky after re-sign | Stable ad-hoc or Developer ID signing; document re-grant steps |
| Parakeet language coverage insufficient | Auto-fallback to WhisperKit |
| Apple Intelligence APIs unavailable / weak | Ship MLX or API cleanup path |
| ScreenCaptureKit system audio quirks with headphones / Zoom | Dual-track testing; BlackHole as documented optional fallback (not linked) |
| Diarisation quality on overlapping speech | Post-process + user speaker rename; accept imperfect v1 |
| Latency on large Whisper models | Default Parakeet; keep Whisper for multilingual / accuracy mode |

---

## Approval

Reply **yes** to proceed to Phase 0/1 scaffolding, or list edits to features / stack / phases.
