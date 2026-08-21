#!/bin/sh
# DCPRO GhostGuard Kobo license bridge v4 (Ed25519)
# No signing secret is stored on the device. The trust anchor is embedded in
# the static verifier binary shipped for ARMv7/AArch64.
set -u

ACTION="${1:-check}"
BASE="${DCPRO_PLUGIN_DIR:-/mnt/onboard/.adds/ghostguard}"
KEY="${DCPRO_LICENSE_PATH:-$BASE/license.key}"
STATE="${DCPRO_LICENSE_STATE:-$BASE/data/license_last_date}"
SERIAL_ARG="${2:-}"

say_no() { printf 'DENY|%s\n' "$1"; exit 1; }

[ "$ACTION" = "check" ] || say_no "UNSUPPORTED_ACTION"

clean_serial() {
    printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9'
}

if [ -z "$SERIAL_ARG" ] && [ -f /mnt/onboard/.kobo/version ]; then
    SERIAL_ARG="$(sed -n '1{s/,.*//;p;}' /mnt/onboard/.kobo/version 2>/dev/null)"
fi
SERIAL="$(clean_serial "$SERIAL_ARG")"
[ -n "$SERIAL" ] || say_no "SERIAL_UNAVAILABLE"
[ -f "$KEY" ] || say_no "MISSING_PLUGIN_LICENSE_KEY"
[ -s "$KEY" ] || say_no "EMPTY_PLUGIN_LICENSE_KEY"

case "$(uname -m 2>/dev/null)" in
    aarch64|arm64) VERIFY="$BASE/bin/gg-license-verify-aarch64" ;;
    armv8*|armv7*|armv6*|arm*) VERIFY="$BASE/bin/gg-license-verify-armv7" ;;
    *) say_no "UNSUPPORTED_ARCH" ;;
esac

[ -x "$VERIFY" ] || say_no "LICENSE_VERIFIER_MISSING"

if [ -n "${DCPRO_NOW_DATE:-}" ]; then
    exec "$VERIFY" --license "$KEY" --serial "$SERIAL" --state "$STATE" --today "$DCPRO_NOW_DATE"
else
    exec "$VERIFY" --license "$KEY" --serial "$SERIAL" --state "$STATE"
fi
