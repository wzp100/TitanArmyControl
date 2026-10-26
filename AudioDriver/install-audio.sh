#!/bin/bash
# Invoked through the macOS administrator authentication dialog by Titan Army.
set -euo pipefail
DESTINATION="/Library/Audio/Plug-Ins/HAL/TitanArmyAudio.driver"
if [[ "$EUID" != 0 ]]; then
    echo "Administrator authentication is required." >&2
    exit 77
fi
check_identity() {
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$1/Contents/Info.plist")" == "local.titanarmy.audio" ]]
}
if [[ -e "$DESTINATION" ]]; then
    check_identity "$DESTINATION" || { echo "Unexpected installed component; refusing to replace it." >&2; exit 65; }
fi
case "${1:-}" in
    install)
        SOURCE="${2:?Missing driver bundle}"
        check_identity "$SOURCE"
        /usr/bin/codesign --verify --strict "$SOURCE"
        /bin/mkdir -p /Library/Audio/Plug-Ins/HAL
        STAGING="$(/usr/bin/mktemp -d /Library/Audio/Plug-Ins/HAL/.titanarmy-install.XXXXXXXX)"
        trap '/bin/rm -rf "$STAGING"' EXIT
        /usr/bin/ditto "$SOURCE" "$STAGING/TitanArmyAudio.driver"
        /usr/sbin/chown -R root:wheel "$STAGING/TitanArmyAudio.driver"
        /bin/chmod -R u=rwX,go=rX "$STAGING/TitanArmyAudio.driver"
        /usr/bin/codesign --verify --strict "$STAGING/TitanArmyAudio.driver"
        if [[ -e "$DESTINATION" ]]; then /bin/mv "$DESTINATION" "$STAGING/previous"; fi
        if ! /bin/mv "$STAGING/TitanArmyAudio.driver" "$DESTINATION"; then
            if [[ -e "$STAGING/previous" ]]; then /bin/mv "$STAGING/previous" "$DESTINATION"; fi
            exit 74
        fi
        ;;
    uninstall)
        if [[ -e "$DESTINATION" ]]; then /bin/rm -rf "$DESTINATION"; fi
        ;;
    *) echo "Usage: install-audio.sh install <driver> | uninstall" >&2; exit 64 ;;
esac
# launchd restarts Core Audio; no kernel extension, reboot or SIP changes.
/usr/bin/killall coreaudiod || true
echo "Titan Army audio component: ${1} complete."
