#!/bin/sh
# DCPRO GhostGuard Kobo - fast NickelMenu helper.
# Never performs network I/O. Long-running actions are launched by NickelMenu
# with cmd_spawn and write their result to data/LAST_ACTION.txt.
set -u

BASE=/mnt/onboard/.adds/ghostguard
DATA="$BASE/data"
RUN="$BASE/runtime"
PROFILE_V5="$DATA/profile_v5.txt"
LICENSE_STATUS="$DATA/LICENSE_STATUS.txt"
LAST_ACTION="$DATA/LAST_ACTION.txt"
PIDFILE="$RUN/supervisor.pid"
MODEFILE="$RUN/mode"

mkdir -p "$DATA" "$RUN" 2>/dev/null || true

clean_serial() {
    if [ -f /mnt/onboard/.kobo/version ]; then
        sed -n '1{s/,.*//;p;}' /mnt/onboard/.kobo/version 2>/dev/null \
            | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9'
    fi
}

v5_value() {
    K="$1"
    [ -f "$PROFILE_V5" ] || return 0
    sed -n "s/^${K}=//p" "$PROFILE_V5" 2>/dev/null | head -n 1
}

is_running() {
    [ -f "$PIDFILE" ] || return 1
    P="$(cat "$PIDFILE" 2>/dev/null)"
    [ -n "$P" ] || return 1
    kill -0 "$P" 2>/dev/null
}

license_first() {
    [ -s "$LICENSE_STATUS" ] && head -n 1 "$LICENSE_STATUS" 2>/dev/null || true
}

license_summary() {
    FIRST="$(license_first)"
    case "$FIRST" in
        OK\|*) echo "ACTIVE" ;;
        DENY\|*) echo "DENIED" ;;
        *) echo "NOT_SYNCED" ;;
    esac
}

license_reason() {
    FIRST="$(license_first)"
    case "$FIRST" in
        DENY\|*) printf '%s\n' "${FIRST#DENY|}" | cut -d';' -f1 ;;
        *) echo "" ;;
    esac
}

friendly_profile() {
    case "$1" in
        CALIBRATION|'') echo "Learning" ;;
        PENDING_APPROVAL) echo "Ready to activate" ;;
        PROBATION) echo "Probation" ;;
        PROBATION_PASSED) echo "Active profile" ;;
        *) echo "$1" ;;
    esac
}

show_status() {
    SERIAL="$(clean_serial)"; [ -n "$SERIAL" ] || SERIAL=KOBO_UNKNOWN
    if is_running; then
        STATE=RUNNING
        MODE="$(cat "$MODEFILE" 2>/dev/null)"; [ -n "$MODE" ] || MODE=-
    else
        STATE=STOPPED
        MODE=-
    fi
    PS="$(v5_value STATE)"; [ -n "$PS" ] || PS=CALIBRATION
    PC="$(v5_value PROBATION_COMPLETED)"; [ -n "$PC" ] || PC=0
    PN="$(v5_value PROBATION_REQUIRED)"; [ -n "$PN" ] || PN=2
    LIC="$(license_summary)"

    echo "GhostGuard Kobo 0.8.2"
    echo "Device: $SERIAL"
    echo "Engine: $STATE | Mode: $MODE"
    case "$LIC" in
        ACTIVE) echo "License: Active" ;;
        NOT_SYNCED) echo "License: Not synced (Start will sync automatically)" ;;
        DENIED) echo "License: Denied - $(license_reason)" ;;
    esac
    echo "Profile: $(friendly_profile "$PS")"
    [ "$PS" = "PROBATION" ] && echo "Probation: $PC/$PN"
    echo "Protect: OFF | Fail-open: ON"
    case "$PS" in
        CALIBRATION) echo "Next: GhostGuard - Start" ;;
        PENDING_APPROVAL) echo "Next: GhostGuard - Activate Profile" ;;
        PROBATION|PROBATION_PASSED) echo "Next: GhostGuard - Start" ;;
    esac
}

show_license() {
    echo "DEVICE_ID=$(clean_serial)"
    if [ -s "$LICENSE_STATUS" ]; then cat "$LICENSE_STATUS"; else echo "NOT_SYNCED"; fi
}

show_last() {
    if [ -s "$LAST_ACTION" ]; then cat "$LAST_ACTION"; else echo "Chưa có kết quả tác vụ."; fi
}

case "${1:-status}" in
    status) show_status ;;
    license) show_license ;;
    device-id) echo "DEVICE_ID=$(clean_serial)" ;;
    last) show_last ;;
    *) echo "Usage: $0 {status|license|device-id|last}"; exit 1 ;;
esac
