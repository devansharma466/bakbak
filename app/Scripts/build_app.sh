#!/usr/bin/env bash
# Build Bakbak as a macOS .app bundle.
# Prefer Apple Development signing when available (stable TCC / Accessibility);
# fall back to ad-hoc only if CODESIGN_IDENTITY=- or no development identity exists.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="Bakbak"
BUNDLE_ID="dev.devansharma.bakbak"
BUILD_DIR="$ROOT/.build"
APP_DIR="${APP_DIR:-$ROOT/dist/${APP_NAME}.app}"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

resolve_identity() {
  if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    echo "$CODESIGN_IDENTITY"
    return
  fi
  # Prefer an Apple Development identity for personal Mac installs (keeps TCC stable).
  local found
  found="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ {print $2; exit}')"
  if [[ -n "$found" ]]; then
    echo "$found"
  else
    echo "-"
  fi
}

IDENTITY="$(resolve_identity)"

echo "==> swift build ($CONFIGURATION, arm64)"
swift build -c "$CONFIGURATION" --arch arm64

BIN="$(swift build -c "$CONFIGURATION" --arch arm64 --show-bin-path)/${APP_NAME}"
if [[ ! -x "$BIN" ]]; then
  echo "error: built binary not found at $BIN" >&2
  exit 1
fi

echo "==> assembling ${APP_NAME}.app"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN" "$MACOS_DIR/${APP_NAME}"
chmod +x "$MACOS_DIR/${APP_NAME}"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

# Menu bar template PNGs (1x + @2x) and Dock / Finder source art
for f in \
  bakbak-menubar.png \
  bakbak-menubar@2x.png \
  bakbak-mac-light.png \
  bakbak-mac-dark.png \
  bakbak-parrot-black.png
do
  if [[ -f "$ROOT/Resources/$f" ]]; then
    cp "$ROOT/Resources/$f" "$RESOURCES_DIR/$f"
  fi
done

# App icon (.icns). Prefer prebuilt; else build from iconset via iconutil (macOS only).
if [[ -f "$ROOT/Resources/Bakbak.icns" ]]; then
  cp "$ROOT/Resources/Bakbak.icns" "$RESOURCES_DIR/Bakbak.icns"
elif [[ -d "$ROOT/Resources/Bakbak.iconset" ]]; then
  if command -v iconutil >/dev/null 2>&1; then
    echo "==> generating Bakbak.icns from Bakbak.iconset"
    TMP_ICONSET="$(mktemp -d)/Bakbak.iconset"
    mkdir -p "$TMP_ICONSET"
    for src in "$ROOT/Resources/Bakbak.iconset"/*; do
      [[ -f "$src" ]] || continue
      base="$(basename "$src")"
      case "$base" in
        *_2x.png) dest="${base%_2x.png}@2x.png" ;;
        *)        dest="$base" ;;
      esac
      cp "$src" "$TMP_ICONSET/$dest"
    done
    iconutil -c icns "$TMP_ICONSET" -o "$RESOURCES_DIR/Bakbak.icns"
    cp "$RESOURCES_DIR/Bakbak.icns" "$ROOT/Resources/Bakbak.icns"
    rm -rf "$(dirname "$TMP_ICONSET")"
  else
    echo "warning: iconutil not found — Dock icon skipped. Run Scripts/generate_icns.sh on macOS." >&2
  fi
else
  echo "warning: no Bakbak.icns / Bakbak.iconset — Dock icon missing" >&2
fi

# PkgInfo is optional but conventional.
echo -n 'APPL????' > "$CONTENTS/PkgInfo"

if [[ "$IDENTITY" == "-" ]]; then
  echo "==> ad-hoc codesign (no Apple Development identity found)"
  codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_DIR"
else
  echo "==> codesign with: $IDENTITY"
  codesign --force --deep --options runtime --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP_DIR"
fi

echo "==> verify"
codesign -dv --verbose=2 "$APP_DIR" 2>&1 | head -20
echo
echo "Built: $APP_DIR"
echo "Run with: open \"$APP_DIR\""
echo "Then grant Microphone + Accessibility (+ Screen Recording for meeting system audio)."
