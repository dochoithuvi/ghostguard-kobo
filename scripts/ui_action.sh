#!/bin/sh
# GhostGuard Kobo v0.8.3.1 customer action wrapper.
# Runtime state uses private extensions permanently. Legacy .txt state is only
# consumed here during migration and is never recreated by the packaged runtime.
set -u

BASE=/mnt/onboard/.adds/ghostguard
DATA="$BASE/data"
RUN="$BASE/runtime"
CORE="$BASE/ghostguard.sh"
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
    # v0.8.2.x / v0.8.3 temporarily exposed these as text documents while the
    # engine was running. From v0.8.3.1 onward the private names are canonical.
    move_legacy "$DATA/profile_v5.txt" "$DATA/profile_v5.ggstate"
    move_legacy "$DATA/profile.txt" "$DATA/observer_profile.ggdata"
    move_legacy "$DATA/LICENSE_STATUS.txt" "$DATA/LICENSE_STATUS.ggstate"
    move_legacy "$DATA/KOBO_DEVICE_ID.txt" "$DATA/KOBO_DEVICE_ID.ggstate"
    move_legacy "$DATA/RUNTIME_FAULT.txt" "$DATA/RUNTIME_FAULT.ggstate"
    move_legacy "$DATA/status.txt" "$DATA/status.ggstate"
    move_legacy "$DATA/LAST_ACTION.txt" "$DATA/LAST_ACTION.ggstate"
}

cleanup_loose_reports() {
    # Keep only compressed report archives. Loose SYSTEM/status/profile text from
    # older builds is what Nickel was importing into My Books.
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
            case "$F" in
                *.tar.gz|*.tar) ;;
                *) rm -rf "$F" 2>/dev/null || true ;;
            esac
        done
    fi

    # Internal temporary report trees are never needed after the archive exists.
    [ -d "$DATA/reports" ] && rm -rf "$DATA/reports"/* 2>/dev/null || true

    # Remove stale document-like diagnostics left by pre-0.8.3.1 builds after
    # their canonical state has already been migrated above.
    find "$DATA" -type f -name '*.txt' -exec rm -f {} \; 2>/dev/null || true
}

cleanup_all() {
    migrate_legacy_state
    cleanup_loose_reports
}

ACTION="${1:-cleanup}"
shift 2>/dev/null || true
cleanup_all

case "$ACTION" in
    start|approve|stop|report)
        "$CORE" "$ACTION" "$@"
        RC=$?
        ;;
    cleanup)
        echo "GhostGuard library cleanup complete."
        RC=0
        ;;
    *)
        echo "Unsupported UI action: $ACTION"
        exit 2
        ;;
esac

# Core v0.8.3.1 writes only private extensions, but run cleanup once more after
# an action so legacy report trees from an interrupted older build are removed.
cleanup_all
exit "$RC"
