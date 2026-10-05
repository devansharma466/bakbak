# Research notes — Wispr Flow clone (macOS)

Raw notes backing `PLAN.md`. Target: Devan Sharma, MacBook Pro, Apple Silicon. No app code yet; no GitHub repo.

---

## A. What Wispr Flow offers (as of research, Oct 2026)

Sources: [wisprflow.ai](https://wisprflow.ai/), [Features](https://wisprflow.ai/features), [Help: What is Flow](https://docs.wisprflow.ai/articles/2772472373-what-is-flow), Notetaker blog posts.

### Dictation (core “Flow”)
- System-wide voice → polished text in any text field (Notion, Gmail, Docs, WhatsApp, Cursor, etc.).
- Hold shortcut, speak, release → insert (desktop defaults: **Fn** on Mac, Ctrl+Win on Windows). Hands-free mode available.
- AI edits while / after speaking: remove fillers, lists, punctuation, understand mid-sentence corrections.
- Personal dictionary (auto from corrections + manual); snippets; **Styles** (per-context tone — English desktop only).
- 100+ languages; whisper-quiet speech; context-aware name spelling.
- Dev-aware formatting (syntax, file names) marketed for coding workflows.
- **Requires internet** for transcription (cloud). Account required. Privacy Mode / Private Cloud Sync marketed; SOC2 / ISO / HIPAA claimed.
- Platforms: Mac, Windows, iPhone, Android. Hub for history, dictionary, snippets, style, settings.

### Notetaker (meetings — newer product)
- Local-ish meeting capture on Mac/Windows; speaker labeling; summaries; decisions / action items; search across history.
- Carries personal dictionary into meetings; calendar / Slack context; MCP export to Claude/ChatGPT.
- Transcription in multiple languages (Notetaker posts cite ~21 languages for that product).

### Implications for our clone
- We want **local-first** (opposite of Flow’s cloud ASR dependency) for privacy and offline use.
- Feature parity target is dictation polish + optional meeting mode, not team dashboards / mobile sync.

---

## B. Open-source foundations — detail

### ASR engines

#### WhisperKit (argmaxinc/WhisperKit) — MIT
- On-device Whisper via Core ML; macOS 14+, Xcode 16+.
- Models from tiny → large-v3-turbo; multilingual.
- Streaming / OpenAI-compatible local server in OSS; advanced real-time speakers / custom vocab pushed to **Argmax Pro** (proprietary).
- Best as **Swift-native Whisper** fallback for languages Parakeet misses.

#### FluidAudio (FluidInference/FluidAudio) — Apache-2.0
- Swift SDK: ASR (Parakeet Ultra / TDT v2–v3 / Redux), VAD (Silero), diarisation (offline VBx, LS-EEND streaming, Sortformer), enhancement (beta), TTS (beta).
- ANE-first; streaming ASR via `SlidingWindowAsrManager`.
- Parakeet: very fast on M-series; ~25 European languages on multilingual variants; v2 English-only higher recall.
- Offline mode flag for air-gapped / bundled models.
- Points to AudioCap for system-audio reference patterns.
- **Primary library pick** for dictation + meeting diarisation in one native stack.

#### whisper.cpp (ggml-org/whisper.cpp) — MIT
- Industry standard C++ Whisper; Metal on Apple Silicon.
- Used by open-wispr. Excellent CLI/embed option; less “Swift-native” than WhisperKit/FluidAudio.

#### faster-whisper — MIT
- CTranslate2 Python; strong for batch / whisperX pipelines. Heavier to ship inside a native Mac app (sidecar possible).

### Dictation app references (not all suitable to fork)

| Project | Licence | Takeaway |
| --- | --- | --- |
| human37/open-wispr (~210★) | MIT | Clean PTT + whisper.cpp + menubar; **no AI cleanup**. Best MIT reference for hotkeys/paste. |
| Robj1925/open-flow (~5★) | MIT | Parakeet (FluidAudio) + WhisperKit + Apple Intelligence cleanup — architecture closest to our plan; still early. |
| tristan-mcinnis/local-dictation | MIT/Apache | Rust + Parakeet + Qwen cleanup; proves local LLM cleanup latency can be low. |
| hasso5703/talkink | MIT | MLX ASR (Qwen3-ASR etc.); interesting engine diversity; newer. |
| vitalii-zinchenko/dictara | (check) | Tauri + Whisper local/cloud; hybrid model. |
| Beingpax/VoiceInk (~6k★) | **GPLv3** | Most polished OSS product alternative; **avoid as code base** for a private closed app. Study UX only. |

### Meeting / diarisation / system audio

| Piece | Notes |
| --- | --- |
| ScreenCaptureKit | macOS 13+ system audio + display; needs **Screen Recording** permission. Preferred over virtual drivers. |
| BlackHole | ExistentialAudio; **GPL-3.0**. Optional user install + Multi-Output Device; do not link into app. |
| AVAudioEngine | Mic capture for dictation. |
| FluidAudio diarisation | Prefer over Python pyannote for native app. |
| whisperX | BSD-2; word timestamps + pyannote diarisation; needs HF token for models; CPU on Mac. Optional research sidecar only. |
| muesli | Menubar meeting app pattern (SCK + faster-whisper + pyannote); immature star count — pattern reference. |
| AudioCap (insidegui) | Referenced by FluidAudio for system audio capture examples. |

### Global hotkey / paste on macOS
- CGEvent tap for global hold-to-talk; Accessibility permission (`PostEvent` / trusted process).
- Insert via transient clipboard + synthetic ⌘V, or AX APIs where available; restore previous pasteboard.
- Caps Lock poor for hold-to-talk (toggle behaviour). Globe (keyCode 63) / Right Option common in open-wispr.
- Code-signing changes can silently disable event taps — document re-grant.

---

## C. Recommendation rationale (expanded)

**Combo:** SwiftUI shell + **FluidAudio** + **WhisperKit** + **ScreenCaptureKit** + cleanup LLM (Apple Intelligence / MLX / optional API).

Rejected as primary:
- **Fork VoiceInk** — GPLv3 viral for distribution; overkill if we only need libraries.
- **whisper.cpp-only** — works but slower UX than Parakeet for English PTT; no diarisation bundle.
- **Python-first (whisperX)** — poor fit for a snappy menubar dictation app; keep as optional later experiment.
- **Cloud-only ASR** — contradicts privacy goal; Wispr already does that.

Phasing: dictation MVP → cleanup/dictionary → languages/tone → meetings. Matches product risk (PTT reliability first).

---

## D. Sources (non-exhaustive)

- https://wisprflow.ai/features
- https://docs.wisprflow.ai/articles/2772472373-what-is-flow
- https://wisprflow.ai/post/wispr-flow-notetaker
- https://github.com/argmaxinc/WhisperKit
- https://github.com/FluidInference/FluidAudio
- https://github.com/human37/open-wispr
- https://github.com/Robj1925/open-flow
- https://github.com/tristan-mcinnis/local-dictation
- https://github.com/Beingpax/VoiceInk
- https://github.com/ExistentialAudio/BlackHole
- https://github.com/m-bain/whisperX
- https://github.com/scottscotthendo/muesli

---

## E. Out of scope for this research package

- Creating a GitHub repository
- Writing application source beyond empty workspace
- Purchasing API keys or installing models on Devan’s Mac
