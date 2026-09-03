#!/usr/bin/env zsh
set -euo pipefail

cd "$(dirname "$0")"

mkdir -p .build/release
for ARCH in arm64 x86_64; do
    swiftc -parse-as-library Sources/iPhoneBatteryMenu/main.swift \
        -target "$ARCH-apple-macos13.0" \
        -module-cache-path ".build/module-cache/$ARCH" \
        -o ".build/release/ChargePeek-$ARCH" \
        -framework AppKit
done

lipo -create \
    .build/release/ChargePeek-arm64 \
    .build/release/ChargePeek-x86_64 \
    -output .build/release/ChargePeek

APP_DIR=".build/release/ChargePeek.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/release/ChargePeek" "$MACOS_DIR/ChargePeek"
cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ChargePeek</string>
    <key>CFBundleIdentifier</key>
    <string>local.ChargePeek</string>
    <key>CFBundleName</key>
    <string>ChargePeek</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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
