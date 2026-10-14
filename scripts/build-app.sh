#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
export CLANG_MODULE_CACHE_PATH="$PROJECT_ROOT/.build/ModuleCache"
export SWIFT_MODULECACHE_PATH="$PROJECT_ROOT/.build/ModuleCache"

SWIFT_OPTIONS=(--scratch-path "$PROJECT_ROOT/.build" --cache-path "$PROJECT_ROOT/.build/cache" --config-path "$PROJECT_ROOT/.build/config" --security-path "$PROJECT_ROOT/.build/security" --disable-sandbox)
swift build -c release "${SWIFT_OPTIONS[@]}"
BIN_DIR="$(swift build -c release "${SWIFT_OPTIONS[@]}" --show-bin-path)"
APP_DIR="$PROJECT_ROOT/dist/FoundationChat.app"
bash "$PROJECT_ROOT/scripts/build-icon.sh"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/AppleFoundationChat" "$APP_DIR/Contents/MacOS/AppleFoundationChat"
cp "$BIN_DIR/FMTerminalLauncher" "$APP_DIR/Contents/MacOS/FMTerminalLauncher"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP_DIR/Contents/MacOS/FMTerminalLauncher"
codesign --force --sign - "$APP_DIR"
codesign --verify --strict "$APP_DIR"
echo "App erstellt: $APP_DIR"
