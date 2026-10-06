#!/usr/bin/env bash
# Compile + run heuristic cleanup regression checks (Foundation only — no UI/FluidAudio).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/bakbak-cleanup-check"
swiftc -swift-version 6 -O -o "$OUT" \
  "$ROOT/Scripts/cleanup-check/main.swift" \
  "$ROOT/Sources/Bakbak/Cleanup/TextCleanupService.swift" \
  "$ROOT/Sources/Bakbak/Models/DictionaryEntry.swift"
"$OUT"
