#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="$ROOT/.build/audio-driver-sources"
DRIVER="$ROOT/build/TitanArmyAudio.driver"
python3 "$ROOT/AudioDriver/prepare.py" "$STAGE"
mkdir -p "$DRIVER/Contents/MacOS" "$DRIVER/Contents/Resources"
xcrun clang++ -std=c++17 -O2 -fblocks -bundle -arch arm64 -mmacosx-version-min=27.0 \
    -Wno-deprecated-declarations -Wno-format \
    -I "$STAGE/proxyAudioDevice" -I "$STAGE/shared" -I "$STAGE/proxyAudioDevice/PublicUtility" \
    "$STAGE/proxyAudioDevice/ProxyAudioDevice.cpp" "$STAGE/proxyAudioDevice/AudioRingBuffer.cpp" \
    "$STAGE/proxyAudioDevice/utilities.cpp" "$STAGE/shared/AudioDevice.cpp" \
    "$STAGE/proxyAudioDevice/PublicUtility/CAMutex.cpp" \
    "$STAGE/proxyAudioDevice/PublicUtility/CADebugMacros.cpp" \
    "$STAGE/proxyAudioDevice/PublicUtility/CADebugPrintf.cpp" \
    "$STAGE/proxyAudioDevice/PublicUtility/CAHostTimeBase.cpp" \
    -framework CoreAudio -framework CoreFoundation -framework CoreServices -framework IOKit \
    -o "$DRIVER/Contents/MacOS/TitanArmyAudio"
python3 - "$DRIVER/Contents/Info.plist" <<'PY'
import plistlib,sys
factory='2691847A-80E3-4FEC-AC6D-955FF0B714AD'
info=dict(CFBundleIdentifier='local.titanarmy.audio',CFBundleName='TitanArmyAudio',
          CFBundleExecutable='TitanArmyAudio',CFBundlePackageType='BNDL',
          CFBundleVersion='1',CFBundleShortVersionString='1.0.0',LSMinimumSystemVersion='27.0',
          CFPlugInFactories={factory:'TitanArmyAudio_Create'},
          CFPlugInTypes={'443ABAB8-E7B3-491A-B985-BEB9187030DB':[factory]})
with open(sys.argv[1],'wb') as f: plistlib.dump(info,f)
PY
cp "$ROOT/Assets/AppIcon.icns" "$DRIVER/Contents/Resources/DeviceIcon.icns"
cp "$ROOT/Vendor/ProxyAudioDevice/LICENSE" "$DRIVER/Contents/Resources/LICENSE-ProxyAudioDevice.txt"
codesign --force --sign - "$DRIVER"
codesign --verify --strict "$DRIVER"
echo "Built $DRIVER"
