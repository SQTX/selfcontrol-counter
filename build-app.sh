#!/bin/sh
# Build SelfControl as a standalone app and install it to /Applications.
#
# Why the extra codesign step: this fork is built with local ad-hoc signing
# (no Developer ID). Xcode's in-build signing does not consistently re-seal the
# prebuilt Sparkle.framework (it keeps the original developer's Team ID), so the
# app crashes at launch with "Library not loaded: Sparkle ... different Team
# IDs". A single deep ad-hoc re-sign after the build fixes it.
#
# Usage: ./build-app.sh   (run from the repo root)
set -e

CONFIG="${1:-Release}"
APP_NAME="SelfControl.app"
DEST="/Applications/${APP_NAME}"

echo "==> Building ${CONFIG}..."
xcodebuild -workspace SelfControl.xcworkspace -scheme SelfControl -configuration "${CONFIG}" build

BUILT=$(find ~/Library/Developer/Xcode/DerivedData/SelfControl-*/Build/Products/"${CONFIG}" \
        -maxdepth 1 -name "${APP_NAME}" 2>/dev/null | head -1)
if [ -z "${BUILT}" ]; then echo "ERROR: built app not found"; exit 1; fi
echo "==> Built: ${BUILT}"

# stop any running instance, install fresh
pkill -f "${APP_NAME}/Contents/MacOS/SelfControl" 2>/dev/null || true
sleep 1
rm -rf "${DEST}" "${HOME}/Applications/${APP_NAME}"
ditto "${BUILT}" "${DEST}"

echo "==> Re-signing ad-hoc (deep) so embedded Sparkle matches..."
codesign --force --deep --sign - "${DEST}"

echo "==> Installed to ${DEST}"
echo "==> Launching..."
open "${DEST}"
