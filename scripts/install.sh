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
osascript -e 'quit app "betterclick"' 2>/dev/null || true
pkill -f 'betterclick.app/Contents/MacOS/betterclick' 2>/dev/null || true
sleep 1

echo "==> Installing to $DEST"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "==> Launching"
open "$DEST"
echo "==> Done. If this is a fresh install path, grant Input Monitoring to the /Applications copy when prompted."
