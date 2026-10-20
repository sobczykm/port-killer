#!/bin/zsh
# Builds PortKiller.app (ad-hoc signed) into ./build
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP=build/PortKiller.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/PortKiller "$APP/Contents/MacOS/PortKiller"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "Built $APP"
if [[ "${1:-}" == "run" ]]; then
  pkill -x PortKiller || true
  open "$APP"
fi
