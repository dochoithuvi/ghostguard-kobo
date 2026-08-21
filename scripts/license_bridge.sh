#!/bin/sh
# DCPRO GhostGuard Kobo shared online license bridge.
# Uses the SAME signed license registry and RSA-SHA256 trust anchors as
# ghostguard-kindle. No customer license.key and no private key lives on Kobo.
set -u

ACTION="${1:-check}"
BASE="${DCPRO_PLUGIN_DIR:-/mnt/onboard/.adds/ghostguard}"
DATA="$BASE/data"
CACHE_JSON="$DATA/online_licenses.json"
CACHE_SIG="$DATA/online_licenses.sig"
SYNC_STATE="$DATA/online_license_sync_state"
DATE_STATE="$DATA/license_last_date"
SERIAL_ARG="${2:-}"
GRACE_SECONDS="${DCPRO_LICENSE_GRACE_SECONDS:-604800}"
REG_PRIMARY="${DCPRO_LICENSE_REGISTRY_URL:-https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.json}"
SIG_PRIMARY="${DCPRO_LICENSE_SIGNATURE_URL:-https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.sig}"
REG_MIRROR="${DCPRO_LICENSE_REGISTRY_MIRROR_URL:-https://cdn.jsdelivr.net/gh/dochoithuvi/ghostguard-kindle@main/licenses/licenses.json}"
SIG_MIRROR="${DCPRO_LICENSE_SIGNATURE_MIRROR_URL:-https://cdn.jsdelivr.net/gh/dochoithuvi/ghostguard-kindle@main/licenses/licenses.sig}"

say_no(){ printf 'DENY|%s\n' "$1"; exit 1; }
[ "$ACTION" = "check" ] || say_no "UNSUPPORTED_ACTION"
mkdir -p "$DATA" 2>/dev/null || true

clean_serial(){ printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9'; }
if [ -z "$SERIAL_ARG" ] && [ -f /mnt/onboard/.kobo/version ]; then
    SERIAL_ARG="$(sed -n '1{s/,.*//;p;}' /mnt/onboard/.kobo/version 2>/dev/null)"
fi
SERIAL="$(clean_serial "$SERIAL_ARG")"
[ -n "$SERIAL" ] || say_no "SERIAL_UNAVAILABLE"

case "$(uname -m 2>/dev/null)" in
    aarch64|arm64) VERIFY="$BASE/bin/gg-license-verify-aarch64" ;;
    armv8*|armv7*|armv6*|arm*) VERIFY="$BASE/bin/gg-license-verify-armv7" ;;
    *) say_no "UNSUPPORTED_ARCH" ;;
esac
[ -x "$VERIFY" ] || say_no "LICENSE_VERIFIER_MISSING"

get(){
    U="$1"; O="$2"; rm -f "$O" 2>/dev/null
    if command -v curl >/dev/null 2>&1; then curl -L --fail --silent --show-error "$U" -o "$O"
    elif command -v wget >/dev/null 2>&1; then wget -q -O "$O" "$U"
    else return 127
    fi
}

verify_pair(){
    SRC="$1"; J="$2"; S="$3"
    set -- "$VERIFY" --registry "$J" --signature "$S" --serial "$SERIAL" --state "$DATE_STATE" --source "$SRC"
    if [ "$SRC" = "cache" ]; then set -- "$@" --sync-state "$SYNC_STATE" --grace-seconds "$GRACE_SECONDS"; fi
    if [ -n "${DCPRO_NOW_DATE:-}" ]; then set -- "$@" --today "$DCPRO_NOW_DATE"; fi
    if [ -n "${DCPRO_NOW_EPOCH:-}" ]; then set -- "$@" --now-epoch "$DCPRO_NOW_EPOCH"; fi
    "$@"
}

TMPJ="$DATA/.online_licenses.json.tmp.$$"
TMPS="$DATA/.online_licenses.sig.tmp.$$"
try_source(){
    R="$1"; S="$2"; NAME="$3"
    get "$R" "$TMPJ" || return 1
    get "$S" "$TMPS" || return 1
    OUT="$(verify_pair online "$TMPJ" "$TMPS" 2>&1)"; RC=$?
    [ $RC -eq 0 ] || { printf '%s\n' "$OUT"; return $RC; }
    mv -f "$TMPJ" "$CACHE_JSON" || return 1
    mv -f "$TMPS" "$CACHE_SIG" || return 1
    EPOCH="$(date +%s 2>/dev/null || echo 0)"
    {
        echo "SYNC_EPOCH=$EPOCH"
        echo "SYNC_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"
        echo "SOURCE=$NAME"
    } > "$SYNC_STATE.tmp" && mv -f "$SYNC_STATE.tmp" "$SYNC_STATE"
    printf '%s;SOURCE=%s\n' "$OUT" "$NAME"
    return 0
}

if try_source "$REG_PRIMARY" "$SIG_PRIMARY" GITHUB_RAW; then exit 0; fi
rm -f "$TMPJ" "$TMPS" 2>/dev/null
if try_source "$REG_MIRROR" "$SIG_MIRROR" JSDELIVR; then exit 0; fi
rm -f "$TMPJ" "$TMPS" 2>/dev/null

if [ -s "$CACHE_JSON" ] && [ -s "$CACHE_SIG" ]; then
    verify_pair cache "$CACHE_JSON" "$CACHE_SIG" && exit 0
fi
say_no "ONLINE_ALL_SOURCES_FAILED_AND_CACHE_UNUSABLE"
