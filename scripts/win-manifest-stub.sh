#!/bin/bash
# Manifest-tool stand-in for cross-compiling the WinUI/Reactor shell on macOS.
#
# The Windows App SDK self-contained targets merge WinRT registration
# manifests with the SDK's `mt.exe`, which is a Windows-only binary and
# therefore unrunnable on this machine. The merged manifest is only consumed
# when the app actually launches on Windows, so emulating `mt.exe -manifest
# A B -out:C` with "copy the first input to C" is enough to let the C#
# compiler type-check the Reactor UI code here.
#
# Never ship the resulting bundle to Windows: always run a real build with the
# toolchain that ships with the Windows App SDK on a Windows host.
set -euo pipefail

out=""
inputs=()
for arg in "$@"; do
  case "$arg" in
    -out:*) out="${arg#-out:}" ;;
    -out) ;;
    -*) ;;
    *) inputs+=("$arg") ;;
  esac
done

if [[ -z "$out" ]]; then
  echo "win-manifest-stub: no -out:<path> argument found" >&2
  exit 1
fi

source_manifest=""
for candidate in "${inputs[@]}"; do
  if [[ -f "$candidate" ]]; then
    source_manifest="$candidate"
    break
  fi
done

if [[ -z "$source_manifest" ]]; then
  echo "win-manifest-stub: none of the input manifests exist: ${inputs[*]}" >&2
  exit 1
fi

mkdir -p "$(dirname "$out")"
cp "$source_manifest" "$out"
echo "win-manifest-stub: $source_manifest -> $out (macOS stub, not a real merge)"
