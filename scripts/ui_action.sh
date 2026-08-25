#!/bin/sh
# GhostGuard Kobo v0.8.7.1 Emergency Shadow Rollback customer action wrapper.
# Stop is emergency-first; Start is SHADOW-only. No EVIOCGRAB path is reachable from UI.
set -u

BASE=/mnt/onboard/.adds/ghostguard
DATA="$BASE/data"
RUN="$BASE/runtime"
CORE="$BASE/ghostguard.sh"
EMERGENCY="$BASE/emergency_stop.sh"
PROFILE_MGR="$BASE/profile_manager.sh"
UPDATER="$BASE/update.sh"
REPORT_PUBLIC=/mnt/onboard/GhostGuard_Reports
REPORT_HIDDEN=/mnt/onboard/.kobo/GhostGuard_Reports

mkdir -p "$DATA" "$RUN" "$REPORT_HIDDEN" 2>/dev/null || true

move_legacy() {
    SRC="$1"; DST="$2"
    [ -f "$SRC" ] || return 0
    mv -f "$SRC" "$DST" 2>/dev/null || {
        cp "$SRC" "$DST" 2>/dev/null && rm -f "$SRC" 2>/dev/null || true
    }
}

migrate_legacy_state() {
    move_legacy "$DATA/profile_v5.txt" "$DATA/profile_v5.ggstate"
    move_legacy "$DATA/profile.txt" "$DATA/observer_profile.ggdata"
    move_legacy "$DATA/LICENSE_STATUS.txt" "$DATA/LICENSE_STATUS.ggstate"
    move_legacy "$DATA/KOBO_DEVICE_ID.txt" "$DATA/KOBO_DEVICE_ID.ggstate"
    move_legacy "$DATA/RUNTIME_FAULT.txt" "$DATA/RUNTIME_FAULT.ggstate"
    move_legacy "$DATA/status.txt" "$DATA/status.ggstate"
    move_legacy "$DATA/LAST_ACTION.txt" "$DATA/LAST_ACTION.ggstate"
}

cleanup_loose_reports() {
    if [ -d "$REPORT_PUBLIC" ]; then
        for F in "$REPORT_PUBLIC"/*.tar.gz "$REPORT_PUBLIC"/*.tar; do
            [ -f "$F" ] || continue
            mv -f "$F" "$REPORT_HIDDEN/" 2>/dev/null || true
        done
        rm -rf "$REPORT_PUBLIC" 2>/dev/null || true
    fi
    if [ -d "$REPORT_HIDDEN" ]; then
        for F in "$REPORT_HIDDEN"/*; do
            [ -e "$F" ] || continue
            case "$F" in *.tar.gz|*.tar) ;; *) rm -rf "$F" 2>/dev/null || true ;; esac
        done
    fi
    [ -d "$DATA/reports" ] && rm -rf "$DATA/reports"/* 2>/dev/null || true
    find "$DATA" -type f -name '*.txt' -exec rm -f {} \; 2>/dev/null || true
    rm -f "$BASE/SAFETY.txt" "$BASE/SAFETY.ggdata" "$BASE/STATUS_LIBRARY_NOTES" 2>/dev/null || true
    find "$BASE" -maxdepth 1 -type f -name '*.txt' -exec rm -f {} \; 2>/dev/null || true
}

cleanup_all() { migrate_legacy_state; cleanup_loose_reports; }

auto_activate_if_ready() {
    [ -x "$PROFILE_MGR" ] || return 0
    STATE="$($PROFILE_MGR state 2>/dev/null || echo CALIBRATION)"
    [ "$STATE" = PENDING_APPROVAL ] || return 0
    "$CORE" approve >/dev/null 2>&1 || return $?
    return 0
}

emergency_stop() {
    if [ -x "$EMERGENCY" ]; then
        "$EMERGENCY" >/dev/null 2>&1 || true
    else
        rm -f "$RUN/RUN" "$RUN/PROTECT_ARMED" "$RUN/PROTECT_FILTER_ARMED" "$RUN/PROTECT_WATCHDOG" 2>/dev/null || true
        [ -f "$RUN/daemon.pid" ] && kill -TERM "$(cat "$RUN/daemon.pid" 2>/dev/null)" 2>/dev/null || true
        [ -f "$RUN/supervisor.pid" ] && kill -TERM "$(cat "$RUN/supervisor.pid" 2>/dev/null)" 2>/dev/null || true
    fi
    (
        sleep 1
        [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" session-end >/dev/null 2>&1 || true
        [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" sync >/dev/null 2>&1 || true
        cleanup_all
    ) >/dev/null 2>&1 &
    return 0
}

ACTION="${1:-cleanup}"
shift 2>/dev/null || true

if [ "$ACTION" = stop ]; then emergency_stop; exit 0; fi
cleanup_all

case "$ACTION" in
    start)
        auto_activate_if_ready || { RC=$?; echo "Không thể tự kích hoạt Profile."; cleanup_all; exit "$RC"; }
        # v0.8.7.1 emergency rollback: observation only, never request PROTECT.
        "$CORE" shadow "$@"
        RC=$?
        ;;
    update)
        [ -x "$UPDATER" ] || { echo "Online updater chưa sẵn sàng."; RC=8; cleanup_all; exit "$RC"; }
        "$UPDATER" install
        RC=$?
        [ "$RC" -eq 0 ] && "$UPDATER" reboot-if-staged >/dev/null 2>&1 || true
        ;;
    approve|report)
        "$CORE" "$ACTION" "$@"; RC=$? ;;
    cleanup)
        echo "GhostGuard library cleanup complete."; RC=0 ;;
    *)
        echo "Unsupported UI action: $ACTION"; exit 2 ;;
esac

cleanup_all
exit "$RC"
