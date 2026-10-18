#!/bin/bash
# Builds Whisky (Release), installs it to /Applications and relaunches it.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate --quiet
xcodebuild -project Whisky.xcodeproj -scheme Whisky -configuration Release \
  -derivedDataPath build.noindex/DerivedData -destination 'platform=macOS,arch=arm64' \
  build -quiet

app="build.noindex/DerivedData/Build/Products/Release/Whisky.app"
codesign --verify --strict "$app"

# Quit the running copy (it restores nothing, so a plain terminate is safe).
osascript -e 'tell application id "com.chung.whisky" to quit' >/dev/null 2>&1 || true
for _ in $(seq 1 20); do pgrep -x Whisky >/dev/null || break; sleep 0.2; done
pkill -x Whisky 2>/dev/null || true

rm -rf /Applications/Whisky.app
ditto "$app" /Applications/Whisky.app
open /Applications/Whisky.app
echo "installed /Applications/Whisky.app"
