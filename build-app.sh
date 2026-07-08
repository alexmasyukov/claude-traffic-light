#!/usr/bin/env bash
# Собирает релизный TrafficLight.app и ставит его в ~/Applications.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="claude-traffic-light"
TARGET="TrafficLight"                    # имя SwiftPM-продукта (внутреннее)
BUNDLE_ID="com.alex.claude-traffic-light"
VERSION="1.2"
DEST="${HOME}/Applications"
APP="${DEST}/${APP_NAME}.app"

cd "$DIR"

echo "→ Release-сборка…"
swift build -c release >/dev/null
BIN="$(swift build -c release --show-bin-path)/${TARGET}"

echo "→ Сборка бандла ${APP}"
rm -rf "$APP"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "$BIN" "${APP}/Contents/MacOS/${APP_NAME}"

cat > "${APP}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>     <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>      <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>         <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key> <string>${VERSION}</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSAppleEventsUsageDescription</key> <string>Bring the app running Claude Code (your IDE or terminal) to the front when you click its traffic light.</string>
</dict>
</plist>
PLIST

# Ad-hoc подпись, чтобы Gatekeeper/сеть не ругались.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "✓ Готово: ${APP}"
