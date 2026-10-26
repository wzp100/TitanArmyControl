#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="$ROOT/.build/audio-driver-sources"
python3 "$ROOT/AudioDriver/prepare.py" "$STAGE"
xcrun clang++ -std=c++17 -O1 -g -fblocks -fsanitize=address,undefined -arch arm64 -mmacosx-version-min=27.0 \
    -Wno-deprecated-declarations -Wno-format \
    -I "$STAGE/proxyAudioDevice" -I "$STAGE/shared" -I "$STAGE/proxyAudioDevice/PublicUtility" \
    "$ROOT/AudioDriver/DriverTests.cpp" \
    "$STAGE/proxyAudioDevice/ProxyAudioDevice.cpp" "$STAGE/proxyAudioDevice/AudioRingBuffer.cpp" \
    "$STAGE/proxyAudioDevice/utilities.cpp" "$STAGE/shared/AudioDevice.cpp" \
    "$STAGE/proxyAudioDevice/PublicUtility/CAMutex.cpp" \
    "$STAGE/proxyAudioDevice/PublicUtility/CADebugMacros.cpp" \
    "$STAGE/proxyAudioDevice/PublicUtility/CADebugPrintf.cpp" \
    "$STAGE/proxyAudioDevice/PublicUtility/CAHostTimeBase.cpp" \
    -framework CoreAudio -framework CoreFoundation -framework CoreServices -framework IOKit \
    -o "$ROOT/.build/TitanArmyAudioTests"
ASAN_OPTIONS=detect_leaks=0 "$ROOT/.build/TitanArmyAudioTests"
