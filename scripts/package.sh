#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/SerialTerminal.xcodeproj"
SCHEME="SerialTerminal"
CONFIGURATION="Release"
DIST_DIR="$ROOT_DIR/dist"
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
    --icon-size 128 \
    --app-drop-link 600 400 \
    "$OUTPUT_PATH" \
    "$STAGING_DIR"

printf 'Created %s (version %s, build %s)\n' "$OUTPUT_PATH" "$VERSION" "$BUILD"
