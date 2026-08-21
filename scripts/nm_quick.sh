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

license_summary() {
    if [ ! -s "$LICENSE_STATUS" ]; then
        echo "NOT_SYNCED"
        return
    fi
    FIRST="$(head -n 1 "$LICENSE_STATUS" 2>/dev/null)"
    case "$FIRST" in
        OK\|*) echo "OK" ;;
        DENY\|*) echo "DENIED" ;;
        *) echo "UNKNOWN" ;;
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
    PR="$(v5_value PROFILE_READY)"; [ -n "$PR" ] || PR=0
    PC="$(v5_value PROBATION_COMPLETED)"; [ -n "$PC" ] || PC=0
    PN="$(v5_value PROBATION_REQUIRED)"; [ -n "$PN" ] || PN=2
    echo "GhostGuard Kobo 0.8.1.1-hotfix"
    echo "Device: $SERIAL"
    echo "$STATE | $MODE | License: $(license_summary)"
    echo "Profile V5: $PS | Ready: $PR | Probation: $PC/$PN"
    echo "Protect: OFF | Grab: NEVER"
    case "$(license_summary)" in
        NOT_SYNCED) echo "License chưa sync. Chọn GG · Sync License, đợi vài giây rồi xem GG · License Status." ;;
        DENIED) echo "License bị từ chối. Xem GG · License Status để biết lý do." ;;
    esac
}

show_license() {
    echo "DEVICE_ID=$(clean_serial)"
    if [ -s "$LICENSE_STATUS" ]; then
        cat "$LICENSE_STATUS"
    else
        echo "NOT_SYNCED"
        echo "Chọn GG · Sync License, đợi vài giây rồi mở lại mục này."
    fi
}

show_last() {
    if [ -s "$LAST_ACTION" ]; then
        cat "$LAST_ACTION"
    else
        echo "Chưa có kết quả tác vụ."
    fi
}

case "${1:-status}" in
    status) show_status ;;
    license) show_license ;;
    device-id) echo "DEVICE_ID=$(clean_serial)" ;;
    last) show_last ;;
    *) echo "Usage: $0 {status|license|device-id|last}"; exit 1 ;;
esac
