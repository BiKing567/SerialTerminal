#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/SerialTerminal.xcodeproj"
SCHEME="SerialTerminal"
CONFIGURATION="Release"
DIST_DIR="$ROOT_DIR/dist"
TEMPLATE_DIR="$ROOT_DIR/scripts/dmg-template"
BACKGROUND_PATH="$TEMPLATE_DIR/dmg-background.tiff"
VOLUME_ICON_PATH="$TEMPLATE_DIR/volume-icon.icns"
FINDER_TEMPLATE_PATH="$TEMPLATE_DIR/finder.DS_Store"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/serialterminal-package.XXXXXX")"
DERIVED_DATA_DIR="$WORK_DIR/DerivedData"
STAGING_DIR="$WORK_DIR/staging"
mkdir -p "$STAGING_DIR"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

command -v xcodebuild >/dev/null
command -v create-dmg >/dev/null
test -f "$BACKGROUND_PATH"
test -f "$VOLUME_ICON_PATH"
test -f "$FINDER_TEMPLATE_PATH"

mkdir -p "$DIST_DIR"
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk macosx \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    build

APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/SerialTerminal.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist")"
OUTPUT_PATH="$DIST_DIR/SerialTerminal_v${VERSION}.dmg"

ditto "$APP_PATH" "$STAGING_DIR/SerialTerminal.app"
create-dmg \
    --overwrite \
    --skip-jenkins \
    --volname "SerialTerminal $VERSION" \
    --volicon "$VOLUME_ICON_PATH" \
    --background "$BACKGROUND_PATH" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --text-size 12 \
    --icon-size 128 \
    --icon "SerialTerminal.app" 170 200 \
    --app-drop-link 490 200 \
    --hide-extension "SerialTerminal.app" \
    --add-file ".DS_Store" "$FINDER_TEMPLATE_PATH" 0 0 \
    "$OUTPUT_PATH" \
    "$STAGING_DIR"

printf 'Created %s (version %s, build %s)\n' "$OUTPUT_PATH" "$VERSION" "$BUILD"
