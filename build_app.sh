#!/bin/bash
# Builds StashBar.app from the SwiftPM release binary.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="StashBar"
BUILD_CONFIG="release"
APP_DIR="dist/${APP_NAME}.app"
INSTALL_DIR="/Applications/${APP_NAME}.app"
PACKAGE_ONLY="${STASHBAR_PACKAGE_ONLY:-0}"

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

echo "==> Code signing with stable local dev identity"
# Uses a persistent self-signed codesigning identity when one already exists
# in the login keychain instead of ad-hoc ("-") signing. Ad-hoc signing has
# no stable identity, so macOS assigns a brand-new TCC entry on every
# rebuild -- forcing Accessibility/Screen Recording to be re-granted after
# every single code change. A stable identity keeps the same permission
# grants across rebuilds. (Self-signed certs aren't policy-trusted, so they
# won't show up in `security find-identity -v -p codesigning`; check the
# raw keychain listing instead, which is what codesign itself consults.)
SIGN_IDENTITY="StashBar Local Dev"
if ! security find-certificate -c "$SIGN_IDENTITY" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
    echo "    (fallback: stable identity not found in keychain, signing ad-hoc)"
    codesign --force --deep --sign - "${APP_DIR}"
else
    if ! codesign --force --deep --sign "$SIGN_IDENTITY" "${APP_DIR}"; then
        echo "    (fallback: stable identity exists but codesign could not use it, signing ad-hoc)"
        codesign --force --deep --sign - "${APP_DIR}"
    fi
fi

if [ "$PACKAGE_ONLY" = "1" ]; then
    echo "==> Package-only build complete at ${APP_DIR}"
    exit 0
fi

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
