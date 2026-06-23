#!/bin/bash
# Build a release binary and wrap it in a double-clickable .app, installed to /Applications.
# Usage: ./make-app.sh [destination-dir]   (default: /Applications)
set -euo pipefail

APP_NAME="DL4 Conductor"
BUNDLE_ID="com.ryanlee.dl4conductor"
DEST="${1:-/Applications}"

if [ ! -f Resources/AppIcon.icns ]; then
    echo "Icon missing — generating…"
    ./make-icon.sh
fi

echo "Building release…"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/dl4"

APP_DIR="$DEST/$APP_NAME.app"
echo "Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN" "$APP_DIR/Contents/MacOS/dl4"
cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>dl4</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Serves the looper remote page to your phone on the local network.</string>
</dict>
</plist>
PLIST

echo "Code signing (ad-hoc)…"
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "Installed: $APP_DIR"
echo "Launch it from Spotlight/Launchpad, or:  open \"$APP_DIR\""
