#!/usr/bin/env bash
# Build Bakbak as a macOS .app bundle with ad-hoc signing (no Apple Developer account).
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

# Placeholder icon-less; SF Symbols used in menu bar.
# PkgInfo is optional but conventional.
echo -n 'APPL????' > "$CONTENTS/PkgInfo"

echo "==> ad-hoc codesign (personal use — no Developer ID / $99 account needed)"
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_DIR"

echo "==> verify"
codesign -dv --verbose=2 "$APP_DIR" 2>&1 | head -20
echo
echo "Built: $APP_DIR"
echo "Run with: open \"$APP_DIR\""
echo "Then grant Microphone + Accessibility for this exact binary path."
