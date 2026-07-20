#!/usr/bin/env zsh
set -euo pipefail

cd "$(dirname "$0")"

mkdir -p .build/release
swiftc -parse-as-library Sources/iPhoneBatteryMenu/main.swift -o .build/release/iPhoneBatteryMenu -framework AppKit

APP_DIR=".build/release/iPhoneBatteryMenu.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp ".build/release/iPhoneBatteryMenu" "$MACOS_DIR/iPhoneBatteryMenu"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>iPhoneBatteryMenu</string>
    <key>CFBundleIdentifier</key>
    <string>local.iPhoneBatteryMenu</string>
    <key>CFBundleName</key>
    <string>iPhoneBatteryMenu</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "$APP_DIR"
