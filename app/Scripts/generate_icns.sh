#!/usr/bin/env bash
# macOS only: produce Resources/Bakbak.icns for CFBundleIconFile.
# Prefers existing Resources/Bakbak.iconset (renaming *_2x.png → *@2x.png).
# Falls back to sips from bakbak-mac-light.png (or Desktop parrot icons).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="$ROOT/Resources"
SRC_PNG="${1:-$RES/bakbak-mac-light.png}"
# Optional Desktop fallback if Resources PNG missing:
if [[ ! -f "$SRC_PNG" && -f "$HOME/Desktop/bakbak-icon/bakbak-mac-light.png" ]]; then
  SRC_PNG="$HOME/Desktop/bakbak-icon/bakbak-mac-light.png"
fi

if ! command -v iconutil >/dev/null 2>&1; then
  echo "error: iconutil required (run on macOS)" >&2
  exit 1
fi

TMP="$(mktemp -d)"
ICONSET="$TMP/Bakbak.iconset"
mkdir -p "$ICONSET"

normalize_iconset() {
  local from="$1"
  for src in "$from"/*; do
    [[ -f "$src" ]] || continue
    base="$(basename "$src")"
    case "$base" in
      *_2x.png) dest="${base%_2x.png}@2x.png" ;;
      *)        dest="$base" ;;
    esac
    cp "$src" "$ICONSET/$dest"
  done
}

if [[ -d "$RES/Bakbak.iconset" ]] && ls "$RES/Bakbak.iconset"/*.png >/dev/null 2>&1; then
  echo "==> using existing Bakbak.iconset (normalizing _2x → @2x)"
  normalize_iconset "$RES/Bakbak.iconset"
elif [[ -f "$SRC_PNG" ]] && command -v sips >/dev/null 2>&1; then
  echo "==> generating iconset via sips from $SRC_PNG"
  declare -a SPECS=(
    "icon_16x16.png:16"
    "diana.k@example.org:32"
    "icon_32x32.png:32"
    "ivan.p@example.net:64"
    "icon_128x128.png:128"
    "wendy.h@example.net:256"
    "icon_256x256.png:256"
    "wendy.h@example.net:512"
    "icon_512x512.png:512"
    "walt.e@example.net:1024"
  )
  for spec in "${SPECS[@]}"; do
    name="${spec%%:*}"
    px="${spec##*:}"
    sips -z "$px" "$px" "$SRC_PNG" --out "$ICONSET/$name" >/dev/null
  done
else
  echo "error: need Resources/Bakbak.iconset or a source PNG + sips" >&2
  exit 1
fi

echo "==> iconutil → $RES/Bakbak.icns"
iconutil -c icns "$ICONSET" -o "$RES/Bakbak.icns"
rm -rf "$TMP"
ls -la "$RES/Bakbak.icns"
echo "Done. Rebuild with: make app"
