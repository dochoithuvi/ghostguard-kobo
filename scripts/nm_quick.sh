#!/bin/sh
# DCPRO GhostGuard Kobo - fast customer status helper.
# Never performs network I/O. It also hides stale runtime .txt files from
# Nickel's library scanner whenever the engine is stopped.
set -u

BASE=/mnt/onboard/.adds/ghostguard
DATA="$BASE/data"
RUN="$BASE/runtime"
DEFAULTS="$BASE/defaults.conf"
PROFILE_V5_TXT="$DATA/profile_v5.txt"
PROFILE_V5_STATE="$DATA/profile_v5.ggstate"
LICENSE_TXT="$DATA/LICENSE_STATUS.txt"
LICENSE_STATE="$DATA/LICENSE_STATUS.ggstate"
LAST_TXT="$DATA/LAST_ACTION.txt"
LAST_STATE="$DATA/LAST_ACTION.ggstate"
CONTACTS_CSV="$DATA/contacts.csv"
PIDFILE="$RUN/supervisor.pid"
MODEFILE="$RUN/mode"

mkdir -p "$DATA" "$RUN" 2>/dev/null || true

clean_serial() {
    if [ -f /mnt/onboard/.kobo/version ]; then
        sed -n '1{s/,.*//;p;}' /mnt/onboard/.kobo/version 2>/dev/null \
            | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9'
    fi
}

is_running() {
    [ -f "$PIDFILE" ] || return 1
    P="$(cat "$PIDFILE" 2>/dev/null)"
    [ -n "$P" ] || return 1
    kill -0 "$P" 2>/dev/null
}

# Nickel indexes text documents inside hidden folders on modern firmware.
# Keep human-readable runtime files only while the native observer actually
# needs them, and store the persistent copies with private extensions.
hide_runtime_documents() {
    is_running && return 0
    [ -f "$PROFILE_V5_TXT" ] && mv -f "$PROFILE_V5_TXT" "$PROFILE_V5_STATE" 2>/dev/null || true
    [ -f "$LICENSE_TXT" ] && mv -f "$LICENSE_TXT" "$LICENSE_STATE" 2>/dev/null || true
    [ -f "$LAST_TXT" ] && mv -f "$LAST_TXT" "$LAST_STATE" 2>/dev/null || true
    [ -f "$DATA/KOBO_DEVICE_ID.txt" ] && mv -f "$DATA/KOBO_DEVICE_ID.txt" "$DATA/KOBO_DEVICE_ID.ggstate" 2>/dev/null || true
    [ -f "$DATA/RUNTIME_FAULT.txt" ] && mv -f "$DATA/RUNTIME_FAULT.txt" "$DATA/RUNTIME_FAULT.ggstate" 2>/dev/null || true
    [ -f "$DATA/profile.txt" ] && mv -f "$DATA/profile.txt" "$DATA/observer_profile.ggdata" 2>/dev/null || true
}

hide_runtime_documents

profile_file() {
    [ -s "$PROFILE_V5_TXT" ] && { echo "$PROFILE_V5_TXT"; return; }
    echo "$PROFILE_V5_STATE"
}

license_file() {
    [ -s "$LICENSE_TXT" ] && { echo "$LICENSE_TXT"; return; }
    echo "$LICENSE_STATE"
}

last_file() {
    [ -s "$LAST_TXT" ] && { echo "$LAST_TXT"; return; }
    echo "$LAST_STATE"
}

kv_value() {
    F="$1"; K="$2"
    [ -r "$F" ] || return 0
    sed -n "s/^${K}=//p" "$F" 2>/dev/null | head -n 1
}

v5_value() { kv_value "$(profile_file)" "$1"; }

cfg() {
    K="$1"; D="$2"
    if [ -r "$DEFAULTS" ]; then
        V="$(sed -n "s/^${K}=//p" "$DEFAULTS" 2>/dev/null | head -n 1)"
        [ -n "$V" ] && { echo "$V"; return; }
    fi
    echo "$D"
}

num() { case "${1:-}" in ''|*[!0-9]*) echo 0 ;; *) echo "$1" ;; esac; }
cap100() { V="$(num "$1")"; [ "$V" -gt 100 ] 2>/dev/null && V=100; echo "$V"; }
percent_of() {
    N="$(num "$1")"; D="$(num "$2")"
    [ "$D" -gt 0 ] 2>/dev/null || { echo 0; return; }
    cap100 $((N * 100 / D))
}

# The native observer persists profile.txt in batches, but contacts.csv is
# appended contact-by-contact. Read the CSV directly so Status reflects touch
# capture immediately instead of looking stuck at 0 until the next profile flush.
# Output: contacts baseline incomplete candidates
live_csv_stats() {
    [ -s "$CONTACTS_CSV" ] || { echo "0 0 0 0"; return; }
    awk -F, '
        NR == 1 { next }
        NF >= 13 {
            contacts++
            risk = $8 + 0
            duration = $5 + 0
            cls = $11
            action = $12
            if (cls == "INCOMPLETE") incomplete++
            if (action == "WOULD_DROP") candidates++
            if (cls != "INCOMPLETE" && $3 != "" && $4 != "" && duration >= 8000 && risk < 35) baseline++
        }
        END { printf "%d %d %d %d\n", contacts+0, baseline+0, incomplete+0, candidates+0 }
    ' "$CONTACTS_CSV" 2>/dev/null || echo "0 0 0 0"
}

license_first() {
    F="$(license_file)"
    [ -s "$F" ] && head -n 1 "$F" 2>/dev/null || true
}

license_summary() {
    FIRST="$(license_first)"
    case "$FIRST" in
        OK\|*) echo ACTIVE ;;
        DENY\|*) echo DENIED ;;
        *) echo NOT_SYNCED ;;
    esac
}

license_reason() {
    FIRST="$(license_first)"
    case "$FIRST" in DENY\|*) printf '%s\n' "${FIRST#DENY|}" | cut -d';' -f1 ;; *) echo "" ;; esac
}

friendly_profile() {
    case "$1" in
        CALIBRATION|'') echo "Đang học" ;;
        PENDING_APPROVAL) echo "Đã đủ dữ liệu - chờ kích hoạt" ;;
        PROBATION) echo "Đang kiểm tra Profile" ;;
        PROBATION_PASSED) echo "Profile đã sẵn sàng" ;;
        *) echo "$1" ;;
    esac
}

show_learning_progress() {
    PS="$1"
    CONTACTS="$(num "$(v5_value CONTACTS)")"
    BASELINE="$(num "$(v5_value BASELINE_COUNT)")"
    INCOMPLETE="$(num "$(v5_value INCOMPLETE_PCT)")"
    CAND="$(num "$(v5_value SHADOW_CANDIDATES)")"

    set -- $(live_csv_stats)
    CSV_CONTACTS="$(num "${1:-0}")"
    CSV_BASELINE="$(num "${2:-0}")"
    CSV_INCOMPLETE="$(num "${3:-0}")"
    CSV_CAND="$(num "${4:-0}")"
    if [ "$CSV_CONTACTS" -gt "$CONTACTS" ] 2>/dev/null; then CONTACTS="$CSV_CONTACTS"; fi
    if [ "$CSV_BASELINE" -gt "$BASELINE" ] 2>/dev/null; then BASELINE="$CSV_BASELINE"; fi
    if [ "$CSV_CAND" -gt "$CAND" ] 2>/dev/null; then CAND="$CSV_CAND"; fi
    if [ "$CONTACTS" -gt 0 ] 2>/dev/null && [ "$CSV_CONTACTS" -gt 0 ] 2>/dev/null; then
        INCOMPLETE=$((CSV_INCOMPLETE * 100 / CSV_CONTACTS))
    fi

    NEED_CONTACTS="$(num "$(cfg PROFILE_READY_CONTACTS_MIN 80)")"
    NEED_BASELINE="$(num "$(cfg PROFILE_READY_BASELINE_MIN 60)")"
    MAX_INCOMPLETE="$(num "$(cfg PROFILE_READY_MAX_INCOMPLETE_PCT 25)")"
    CP="$(percent_of "$CONTACTS" "$NEED_CONTACTS")"
    BP="$(percent_of "$BASELINE" "$NEED_BASELINE")"
    PROGRESS="$CP"; [ "$BP" -lt "$PROGRESS" ] 2>/dev/null && PROGRESS="$BP"

    case "$PS" in
        CALIBRATION|'')
            echo "Learning: ${PROGRESS}%"
            echo "Touches: $CONTACTS/$NEED_CONTACTS | Baseline: $BASELINE/$NEED_BASELINE"
            echo "Data quality: incomplete ${INCOMPLETE}% (max ${MAX_INCOMPLETE}%)"
            [ "$CAND" -gt 0 ] 2>/dev/null && echo "Ghost candidates observed: $CAND"
            if [ "$CONTACTS" -eq 0 ] 2>/dev/null && is_running; then
                echo "Capture: waiting for first completed touch"
            elif [ "$INCOMPLETE" -gt "$MAX_INCOMPLETE" ] 2>/dev/null; then
                echo "Learning note: cần thêm thao tác ổn định để cải thiện chất lượng dữ liệu."
            else
                echo "Learning note: cứ dùng máy bình thường, GhostGuard tự học tiếp."
            fi
            ;;
        PENDING_APPROVAL)
            echo "Learning: 100% - đủ dữ liệu"
            echo "Touches: $CONTACTS/$NEED_CONTACTS | Baseline: $BASELINE/$NEED_BASELINE"
            echo "Data quality: incomplete ${INCOMPLETE}%"
            ;;
        PROBATION|PROBATION_PASSED)
            echo "Learned data: Touches $CONTACTS | Baseline $BASELINE | Candidates $CAND"
            ;;
    esac
}

show_status() {
    SERIAL="$(clean_serial)"; [ -n "$SERIAL" ] || SERIAL=KOBO_UNKNOWN
    if is_running; then
        ENGINE=RUNNING
        MODE="$(cat "$MODEFILE" 2>/dev/null)"; [ -n "$MODE" ] || MODE=-
    else
        ENGINE=STOPPED
        MODE=-
    fi
    PS="$(v5_value STATE)"; [ -n "$PS" ] || PS=CALIBRATION
    PC="$(num "$(v5_value PROBATION_COMPLETED)")"
    PN="$(num "$(v5_value PROBATION_REQUIRED)")"; [ "$PN" -gt 0 ] 2>/dev/null || PN=2
    LIC="$(license_summary)"

    echo "GhostGuard Kobo 0.8.2.2"
    echo "Engine: $ENGINE | Auto mode: $MODE"
    case "$LIC" in
        ACTIVE) echo "License: Active" ;;
        NOT_SYNCED) echo "License: Not synced - Start sẽ tự đồng bộ" ;;
        DENIED) echo "License: Denied - $(license_reason)" ;;
    esac
    echo "Profile: $(friendly_profile "$PS")"
    show_learning_progress "$PS"
    [ "$PS" = PROBATION ] && echo "Probation: $PC/$PN sessions"
    [ "$PS" = PROBATION_PASSED ] && echo "Probation: Passed ($PN/$PN)"
    echo "Protect: OFF | Fail-open: ON"

    case "$PS" in
        CALIBRATION|'')
            if [ "$ENGINE" = RUNNING ]; then echo "Next: tiếp tục dùng máy bình thường."; else echo "Next: GhostGuard - Start"; fi
            ;;
        PENDING_APPROVAL) echo "Next: GhostGuard - Activate Profile" ;;
        PROBATION) echo "Next: dùng máy bình thường; mỗi phiên hoàn tất sẽ tính vào Probation." ;;
        PROBATION_PASSED) echo "Next: GhostGuard - Start (Shadow an toàn ở v0.8.2)." ;;
    esac
}

show_license() {
    echo "DEVICE_ID=$(clean_serial)"
    F="$(license_file)"
    if [ -s "$F" ]; then cat "$F"; else echo NOT_SYNCED; fi
}

show_last() {
    F="$(last_file)"
    if [ -s "$F" ]; then cat "$F"; else echo "Chưa có kết quả tác vụ."; fi
}

case "${1:-status}" in
    status) show_status ;;
    license) show_license ;;
    device-id) echo "DEVICE_ID=$(clean_serial)" ;;
    last) show_last ;;
    cleanup) hide_runtime_documents; echo "GhostGuard library cleanup: done" ;;
    *) echo "Usage: $0 {status|license|device-id|last|cleanup}"; exit 1 ;;
esac
