#!/usr/bin/env bash
# Build betterclick in Release and install it to /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building Release"
xcodebuild -project betterclick.xcodeproj -scheme betterclick \
  -configuration Release -derivedDataPath .build-xcode build

APP=".build-xcode/Build/Products/Release/betterclick.app"
DEST="/Applications/betterclick.app"

echo "==> Quitting any running instance"
# Quit gracefully by bundle id, then force-kill any process running from a
# *.betterclick.app bundle. The pkill is case-INSENSITIVE (-i) on purpose:
# a differently-cased stale bundle (e.g. BetterClick.app) sharing this bundle id
# would otherwise survive and collide on TCC/Input Monitoring identity.
osascript -e 'quit app id "com.raduloov.betterclick"' 2>/dev/null || true
pkill -if '/betterclick\.app/Contents/MacOS/' 2>/dev/null || true
sleep 1

echo "==> Installing to $DEST"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "==> Signing with stable identity"
IDENTITY="betterclick-selfsign"
if security find-identity -p codesigning | grep -q "$IDENTITY"; then
  codesign --force --sign "$IDENTITY" --timestamp=none "$DEST"
  echo "    signed as '$IDENTITY' (Input Monitoring grant will persist across reinstalls)"
else
  echo "    '$IDENTITY' not found — run ./scripts/make-signing-cert.sh once to make the"
  echo "    Input Monitoring grant persist. Leaving the ad-hoc signature for now."
fi

echo "==> Launching"
open "$DEST"
echo "==> Done. If this is a fresh install path, grant Input Monitoring to the /Applications copy when prompted."
