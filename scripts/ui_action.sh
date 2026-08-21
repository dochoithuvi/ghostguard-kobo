#!/bin/sh
# Customer-facing GhostGuard action wrapper.
# Restores legacy native text state only for the duration it is required, then
# archives it to non-document extensions whenever the engine is stopped.
set -u

BASE=/mnt/onboard/.adds/ghostguard
DATA="$BASE/data"
RUN="$BASE/runtime"
CORE="$BASE/ghostguard.sh"
PIDFILE="$RUN/supervisor.pid"
REPORT_PUBLIC=/mnt/onboard/GhostGuard_Reports
REPORT_HIDDEN=/mnt/onboard/.kobo/GhostGuard_Reports

mkdir -p "$DATA" "$RUN" 2>/dev/null || true

is_running() {
    [ -f "$PIDFILE" ] || return 1
    P="$(cat "$PIDFILE" 2>/dev/null)"
    [ -n "$P" ] || return 1
    kill -0 "$P" 2>/dev/null
}

restore_native_state() {
    [ ! -f "$DATA/profile_v5.txt" ] && [ -f "$DATA/profile_v5.ggstate" ] && mv -f "$DATA/profile_v5.ggstate" "$DATA/profile_v5.txt" 2>/dev/null || true
    [ ! -f "$DATA/profile.txt" ] && [ -f "$DATA/observer_profile.ggdata" ] && mv -f "$DATA/observer_profile.ggdata" "$DATA/profile.txt" 2>/dev/null || true
    [ ! -f "$DATA/LICENSE_STATUS.txt" ] && [ -f "$DATA/LICENSE_STATUS.ggstate" ] && mv -f "$DATA/LICENSE_STATUS.ggstate" "$DATA/LICENSE_STATUS.txt" 2>/dev/null || true
    [ ! -f "$DATA/KOBO_DEVICE_ID.txt" ] && [ -f "$DATA/KOBO_DEVICE_ID.ggstate" ] && mv -f "$DATA/KOBO_DEVICE_ID.ggstate" "$DATA/KOBO_DEVICE_ID.txt" 2>/dev/null || true
    [ ! -f "$DATA/RUNTIME_FAULT.txt" ] && [ -f "$DATA/RUNTIME_FAULT.ggstate" ] && mv -f "$DATA/RUNTIME_FAULT.ggstate" "$DATA/RUNTIME_FAULT.txt" 2>/dev/null || true
}

archive_runtime_docs() {
    # License/device/fault status is not consumed continuously, so it can always
    # live under private extensions after an action completes.
    [ -f "$DATA/LICENSE_STATUS.txt" ] && mv -f "$DATA/LICENSE_STATUS.txt" "$DATA/LICENSE_STATUS.ggstate" 2>/dev/null || true
    [ -f "$DATA/KOBO_DEVICE_ID.txt" ] && mv -f "$DATA/KOBO_DEVICE_ID.txt" "$DATA/KOBO_DEVICE_ID.ggstate" 2>/dev/null || true
    [ -f "$DATA/RUNTIME_FAULT.txt" ] && mv -f "$DATA/RUNTIME_FAULT.txt" "$DATA/RUNTIME_FAULT.ggstate" 2>/dev/null || true
    [ -f "$DATA/LAST_ACTION.txt" ] && mv -f "$DATA/LAST_ACTION.txt" "$DATA/LAST_ACTION.ggstate" 2>/dev/null || true

    # Profile V5 and the native observer profile are needed while the observer is
    # live. Once stopped, persist them under extensions Nickel does not treat as
    # books. The next Start restores them automatically.
    if ! is_running; then
        [ -f "$DATA/profile_v5.txt" ] && mv -f "$DATA/profile_v5.txt" "$DATA/profile_v5.ggstate" 2>/dev/null || true
        [ -f "$DATA/profile.txt" ] && mv -f "$DATA/profile.txt" "$DATA/observer_profile.ggdata" 2>/dev/null || true
    fi
}

hide_reports() {
    [ -d "$REPORT_PUBLIC" ] || return 0
    mkdir -p "$REPORT_HIDDEN" 2>/dev/null || true
    for F in "$REPORT_PUBLIC"/*; do
        [ -e "$F" ] || continue
        mv -f "$F" "$REPORT_HIDDEN/" 2>/dev/null || true
    done
    rmdir "$REPORT_PUBLIC" 2>/dev/null || true
}

ACTION="${1:-status}"
shift 2>/dev/null || true
restore_native_state

case "$ACTION" in
    start|approve|stop|report)
        "$CORE" "$ACTION" "$@"
        RC=$?
        ;;
    *)
        echo "Unsupported UI action: $ACTION"
        exit 2
        ;;
esac

[ "$ACTION" = report ] && hide_reports
archive_runtime_docs
exit "$RC"
