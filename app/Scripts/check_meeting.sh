#!/usr/bin/env bash
# Compile + run meeting speaker-turn / notes-helper checks (Foundation only — no UI/FluidAudio).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/bakbak-meeting-check"
swiftc -swift-version 6 -O -o "$OUT" \
  "$ROOT/Scripts/meeting-check/main.swift" \
  "$ROOT/Sources/Bakbak/Audio/SpeakerTurns.swift" \
  "$ROOT/Sources/Bakbak/Models/Meeting.swift" \
  "$ROOT/Sources/Bakbak/Notes/MeetingNotesWriter.swift" \
  "$ROOT/Sources/Bakbak/Cleanup/TextCleanupService.swift" \
  "$ROOT/Sources/Bakbak/Models/DictionaryEntry.swift"
"$OUT"
