#!/bin/bash
# Builds StashBar.app from the SwiftPM release binary and installs it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="StashBar"
BUILD_CONFIG="release"
APP_DIR="dist/${APP_NAME}.app"
INSTALL_DIR="/Applications/${APP_NAME}.app"

echo "==> Building ${BUILD_CONFIG} binary"
swift build -c "${BUILD_CONFIG}"

BIN_PATH=".build/${BUILD_CONFIG}/${APP_NAME}"
if [ ! -f "$BIN_PATH" ]; then
    echo "Build product not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> Assembling app bundle at ${APP_DIR}"
rm -rf "dist"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "$BIN_PATH" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "${APP_DIR}/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "${APP_DIR}"

echo "==> Installing to ${INSTALL_DIR}"
if [ -d "${INSTALL_DIR}" ]; then
    echo "Quitting any running instance"
    osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
    pkill -f "/Applications/${APP_NAME}.app/Contents/MacOS/${APP_NAME}" >/dev/null 2>&1 || true
    sleep 0.5
    rm -rf "${INSTALL_DIR}"
fi
cp -R "${APP_DIR}" "${INSTALL_DIR}"

echo "==> Done. Launching ${APP_NAME}"
open "${INSTALL_DIR}"
echo "StashBar icon (🗃) should now appear in your menu bar."
