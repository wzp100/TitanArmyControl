#!/bin/bash
# Builds TitanArmyControl.app (a self-contained, ad-hoc signed macOS bundle).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP="$ROOT/build/TitanArmyControl.app"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG" --product TitanArmyControl
swift build -c "$CONFIG" --product titanarmyctl
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

"$ROOT/scripts/build-audio-driver.sh"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/TitanArmyControl" "$APP/Contents/MacOS/TitanArmyControl"
cp "$BIN_DIR/titanarmyctl" "$APP/Contents/MacOS/titanarmyctl"
cp "$ROOT/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp -R "$ROOT/build/TitanArmyAudio.driver" "$APP/Contents/Resources/"
cp "$ROOT/AudioDriver/install-audio.sh" "$APP/Contents/Resources/install-audio.sh"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>TitanArmyControl</string>
    <key>CFBundleDisplayName</key>
    <string>TitanArmyControl</string>
    <key>CFBundleIdentifier</key>
    <string>local.titanarmy.control</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>TitanArmyControl</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh-Hans</string>
        <string>en</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>27.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP" 2>&1 | sed 's/^/    /'

echo "==> Done: $APP"
