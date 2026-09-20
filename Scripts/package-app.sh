#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" ]]; then
  echo "error: Silenzio targets Apple Silicon (arm64) only. Current arch: $ARCH" >&2
  exit 1
fi

# Prefer full Xcode when installed (SDKs / macros); fall back to active toolchain.
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
fi

CONFIGURATION="${1:-release}"
APP_DIR="$ROOT/dist/Silenzio.app"
CONTENTS="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"

echo "Building Silenzio (${CONFIGURATION}, arm64) with ${DEVELOPER_DIR:-$(xcode-select -p)}..."
xcrun swift build -c "$CONFIGURATION" --arch arm64

BIN="$(xcrun swift build -c "$CONFIGURATION" --arch arm64 --show-bin-path)/Silenzio"
if [[ ! -x "$BIN" ]]; then
  echo "error: binary not found at $BIN" >&2
  exit 1
fi

ICON_SRC="$ROOT/Silenzio.icns"
if [[ ! -f "$ICON_SRC" ]]; then
  echo "error: app icon not found at $ICON_SRC" >&2
  exit 1
fi

echo "Packaging ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "$BIN" "${MACOS_DIR}/Silenzio"
cp "$ROOT/Resources/Info.plist" "${CONTENTS}/Info.plist"
cp "$ICON_SRC" "${RESOURCES_DIR}/Silenzio.icns"
chmod +x "${MACOS_DIR}/Silenzio"

# Ad-hoc sign so Accessibility / TCC prompts attach to the bundle identity.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "${APP_DIR}" >/dev/null
fi

echo "Built ${APP_DIR}"
echo "  Run with: open \"${APP_DIR}\""
