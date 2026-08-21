#!/bin/sh
# DCPRO GhostGuard Kobo Profile V5 lifecycle manager.
# Control-plane only: this release never grabs or blocks touchscreen input.
set -u

BASE="${GG_BASE:-/mnt/onboard/.adds/ghostguard}"
DATA="${GG_DATA:-$BASE/data}"
RUN="${GG_RUN:-$BASE/runtime}"
OBSERVER_PROFILE="${GG_OBSERVER_PROFILE:-$DATA/profile.txt}"
PROFILE="${GG_PROFILE_V5:-$DATA/profile_v5.txt}"
ARCHIVE="$DATA/profile_archive"
DEFAULTS="${GG_DEFAULTS:-$BASE/defaults.conf}"
INPUTFILE="$RUN/input_device"
LOG="$DATA/native.log"

mkdir -p "$DATA" "$RUN" "$ARCHIVE" 2>/dev/null || true

cfg() {
    K="$1"; D="$2"
    E="$(eval "printf '%s' \"\${$K:-}\"")"
    [ -n "$E" ] && { printf '%s\n' "$E"; return; }
    if [ -r "$DEFAULTS" ]; then
        V="$(sed -n "s/^${K}=//p" "$DEFAULTS" 2>/dev/null | head -n 1)"
        [ -n "$V" ] && { printf '%s\n' "$V"; return; }
    fi
    printf '%s\n' "$D"
}

now_iso() {
    [ -n "${GG_NOW:-}" ] && { printf '%s\n' "$GG_NOW"; return; }
    date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date 2>/dev/null || echo unknown
}

stamp() {
    [ -n "${GG_STAMP:-}" ] && { printf '%s\n' "$GG_STAMP"; return; }
    date '+%Y%m%d_%H%M%S' 2>/dev/null || echo unknown
}

clean_serial_text() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9'; }
serial_now() {
    [ -n "${GG_SERIAL:-}" ] && { clean_serial_text "$GG_SERIAL"; echo; return; }
    if [ -f /mnt/onboard/.kobo/version ]; then
        S="$(sed -n '1{s/,.*//;p;}' /mnt/onboard/.kobo/version 2>/dev/null)"
        clean_serial_text "$S"; echo
    fi
}

input_now() {
    [ -n "${GG_TOUCH_DEVICE:-}" ] && { printf '%s\n' "$GG_TOUCH_DEVICE"; return; }
    [ -r "$INPUTFILE" ] && head -n 1 "$INPUTFILE" 2>/dev/null | tr -d '\r\n'
}

sys_value() { [ -r "$1" ] && tr -d '\r\n' < "$1" 2>/dev/null; }

controller_name() {
    [ -n "${GG_TOUCH_NAME:-}" ] && { printf '%s\n' "$GG_TOUCH_NAME"; return; }
    D="$(input_now)"; E="$(basename "$D" 2>/dev/null)"
    [ -n "$E" ] && sys_value "/sys/class/input/$E/device/name"
}

controller_class() {
    N="$(controller_name | tr '[:upper:]' '[:lower:]')"
    case "$N" in
        *fts*|*focal*) echo FocalTech ;;
        *elan*) echo ELAN ;;
        *zforce*) echo zForce ;;
        *goodix*) echo Goodix ;;
        *cyttsp*) echo Cypress ;;
        *) echo Generic ;;
    esac
}

fingerprint_canonical() {
    [ -n "${GG_FP_CANONICAL:-}" ] && { printf '%s\n' "$GG_FP_CANONICAL"; return; }
    D="$(input_now)"; E="$(basename "$D" 2>/dev/null)"; SYS="/sys/class/input/$E/device"
    printf 'name=%s\n' "$(controller_name)"
    printf 'phys=%s\n' "$(sys_value "$SYS/phys")"
    printf 'uniq=%s\n' "$(sys_value "$SYS/uniq")"
    printf 'bustype=%s\n' "$(sys_value "$SYS/id/bustype")"
    printf 'vendor=%s\n' "$(sys_value "$SYS/id/vendor")"
    printf 'product=%s\n' "$(sys_value "$SYS/id/product")"
    printf 'version=%s\n' "$(sys_value "$SYS/id/version")"
    printf 'abs_caps=%s\n' "$(sys_value "$SYS/capabilities/abs")"
    printf 'key_caps=%s\n' "$(sys_value "$SYS/capabilities/key")"
    printf 'rel_caps=%s\n' "$(sys_value "$SYS/capabilities/rel")"
    printf 'prop=%s\n' "$(sys_value "$SYS/properties")"
    [ -r "$SYS/uevent" ] && sed 's/[[:space:]]*$//' "$SYS/uevent" 2>/dev/null | sort
}

fingerprint_hash() {
    CANON="$(fingerprint_canonical)"
    if command -v sha256sum >/dev/null 2>&1; then
        H="$(printf '%s' "$CANON" | sha256sum 2>/dev/null | awk '{print $1}')"
        [ -n "$H" ] && { echo "sha256:$H"; return; }
    fi
    if command -v busybox >/dev/null 2>&1; then
        H="$(printf '%s' "$CANON" | busybox sha256sum 2>/dev/null | awk '{print $1}')"
        [ -n "$H" ] && { echo "sha256:$H"; return; }
        C="$(printf '%s' "$CANON" | busybox cksum 2>/dev/null | awk '{print $1":"$2}')"
        [ -n "$C" ] && { echo "cksum:$C"; return; }
    fi
    if command -v cksum >/dev/null 2>&1; then
        C="$(printf '%s' "$CANON" | cksum 2>/dev/null | awk '{print $1":"$2}')"
        [ -n "$C" ] && { echo "cksum:$C"; return; }
    fi
    # Last-resort deterministic marker. This is a safety identity, not a secret.
    printf 'raw:'; printf '%s' "$CANON" | tr -cd 'A-Za-z0-9' | cut -c1-96; echo
}

kv_get_file() {
    F="$1"; K="$2"; D="${3:-}"
    [ -r "$F" ] || { printf '%s\n' "$D"; return; }
    V="$(sed -n "s/^${K}=//p" "$F" 2>/dev/null | head -n 1)"
    [ -n "$V" ] && printf '%s\n' "$V" || printf '%s\n' "$D"
}
v5_get() { kv_get_file "$PROFILE" "$1" "${2:-}"; }
obs_get() { kv_get_file "$OBSERVER_PROFILE" "$1" "${2:-0}"; }

num() { case "${1:-}" in ''|*[!0-9]*) echo 0 ;; *) echo "$1" ;; esac; }
percent() { N="$(num "$1")"; D="$(num "$2")"; [ "$D" -gt 0 ] 2>/dev/null && echo $((N * 100 / D)) || echo 0; }

archive_current() {
    WHY="$1"; TS="$(stamp)"; DIR="$ARCHIVE/${TS}_${WHY}"
    mkdir -p "$DIR" 2>/dev/null || true
    [ -f "$PROFILE" ] && cp "$PROFILE" "$DIR/profile_v5.txt" 2>/dev/null || true
    [ -f "$OBSERVER_PROFILE" ] && cp "$OBSERVER_PROFILE" "$DIR/observer_profile.txt" 2>/dev/null || true
    [ -f "$DATA/contacts.csv" ] && cp "$DATA/contacts.csv" "$DIR/contacts.csv" 2>/dev/null || true
}

reset_observer_data() {
    WHY="$1"; TS="$(stamp)"; DIR="$ARCHIVE/${TS}_${WHY}"
    mkdir -p "$DIR" 2>/dev/null || true
    [ -f "$OBSERVER_PROFILE" ] && mv "$OBSERVER_PROFILE" "$DIR/observer_profile.txt" 2>/dev/null || true
    [ -f "$DATA/contacts.csv" ] && mv "$DATA/contacts.csv" "$DIR/contacts.csv" 2>/dev/null || true
}

write_profile() {
    STATE="$1"
    SERIAL="$(serial_now)"; [ -n "$SERIAL" ] || SERIAL=KOBO_UNKNOWN
    FP="$(fingerprint_hash)"
    NAME="$(controller_name | tr '\n' ' ' | tr -d '\r')"
    CLASS="$(controller_class)"
    INPUT="$(input_now)"
    CREATED="$(v5_get CREATED_AT "$(now_iso)")"
    READY_AT="$(v5_get READY_AT '')"
    APPROVED_AT="$(v5_get APPROVED_AT '')"
    PASSED_AT="$(v5_get PROBATION_PASSED_AT '')"
    P_COMPLETED="$(num "$(v5_get PROBATION_COMPLETED 0)")"
    P_OPEN="$(num "$(v5_get PROBATION_SESSION_OPEN 0)")"
    P_STARTED="$(v5_get PROBATION_SESSION_STARTED_AT '')"
    P_REQUIRED="$(num "$(cfg PROBATION_SESSIONS 2)")"; [ "$P_REQUIRED" -gt 0 ] || P_REQUIRED=2

    CONTACTS="$(num "$(obs_get CONTACTS 0)")"
    INCOMPLETE="$(num "$(obs_get INCOMPLETE_CONTACTS 0)")"
    BASELINE="$(num "$(obs_get BASELINE_COUNT 0)")"
    INC_PCT="$(percent "$INCOMPLETE" "$CONTACTS")"
    AVG_DUR="$(num "$(obs_get AVG_DURATION_US 0)")"
    AVG_PATH="$(num "$(obs_get AVG_PATH_PX 0)")"
    AVG_MAJOR="$(num "$(obs_get AVG_TOUCH_MAJOR 0)")"
    XMIN="$(obs_get X_MIN '')"; XMAX="$(obs_get X_MAX '')"; YMIN="$(obs_get Y_MIN '')"; YMAX="$(obs_get Y_MAX '')"
    RISK_MAX="$(num "$(obs_get RISK_MAX 0)")"
    CAND="$(num "$(obs_get WOULD_DROP 0)")"

    READY_BASELINE="$(num "$(cfg PROFILE_READY_BASELINE_MIN 60)")"
    READY_CONTACTS="$(num "$(cfg PROFILE_READY_CONTACTS_MIN 80)")"
    READY_INC="$(num "$(cfg PROFILE_READY_MAX_INCOMPLETE_PCT 25)")"

    READY=0; REASON=LEARNING
    if [ "$BASELINE" -ge "$READY_BASELINE" ] 2>/dev/null && \
       [ "$CONTACTS" -ge "$READY_CONTACTS" ] 2>/dev/null && \
       [ "$INC_PCT" -le "$READY_INC" ] 2>/dev/null && \
       [ "$AVG_DUR" -gt 0 ] 2>/dev/null && \
       [ -n "$XMIN" ] && [ -n "$XMAX" ] && [ -n "$YMIN" ] && [ -n "$YMAX" ]; then
        READY=1; REASON=BASELINE_STABLE
    else
        REASON="need_baseline_${READY_BASELINE}_contacts_${READY_CONTACTS}_incomplete_le_${READY_INC}pct"
    fi

    if [ "$STATE" = "CALIBRATION" ] && [ "$READY" -eq 1 ]; then
        STATE=PENDING_APPROVAL
        [ -n "$READY_AT" ] || READY_AT="$(now_iso)"
    fi
    if [ "$STATE" = "PROBATION" ] && [ "$P_COMPLETED" -ge "$P_REQUIRED" ] 2>/dev/null; then
        STATE=PROBATION_PASSED
        [ -n "$PASSED_AT" ] || PASSED_AT="$(now_iso)"
        P_OPEN=0
    fi

    ELIGIBLE=0; [ "$STATE" = "PROBATION_PASSED" ] && ELIGIBLE=1
    TMP="$PROFILE.tmp.$$"
    {
        echo "DCPRO_GHOSTGUARD_PROFILE_V5"
        echo "PROFILE_FORMAT=5"
        echo "STATE=$STATE"
        echo "SERIAL=$SERIAL"
        echo "CONTROLLER_FINGERPRINT=$FP"
        echo "CONTROLLER_CLASS=$CLASS"
        echo "CONTROLLER_NAME=$NAME"
        echo "INPUT_DEVICE=$INPUT"
        echo "CREATED_AT=$CREATED"
        echo "UPDATED_AT=$(now_iso)"
        echo "READY_AT=$READY_AT"
        echo "APPROVED_AT=$APPROVED_AT"
        echo "PROBATION_PASSED_AT=$PASSED_AT"
        echo "PROFILE_READY=$READY"
        echo "READINESS_REASON=$REASON"
        echo "CONTACTS=$CONTACTS"
        echo "INCOMPLETE_CONTACTS=$INCOMPLETE"
        echo "INCOMPLETE_PCT=$INC_PCT"
        echo "BASELINE_COUNT=$BASELINE"
        echo "AVG_DURATION_US=$AVG_DUR"
        echo "AVG_PATH_PX=$AVG_PATH"
        echo "AVG_TOUCH_MAJOR=$AVG_MAJOR"
        echo "X_MIN=$XMIN"
        echo "X_MAX=$XMAX"
        echo "Y_MIN=$YMIN"
        echo "Y_MAX=$YMAX"
        echo "RISK_MAX=$RISK_MAX"
        echo "SHADOW_CANDIDATES=$CAND"
        echo "PROBATION_REQUIRED=$P_REQUIRED"
        echo "PROBATION_COMPLETED=$P_COMPLETED"
        echo "PROBATION_SESSION_OPEN=$P_OPEN"
        echo "PROBATION_SESSION_STARTED_AT=$P_STARTED"
        echo "PROTECT_ELIGIBLE=$ELIGIBLE"
        echo "PROTECT_ACTIVE=0"
        echo "INPUT_GRAB=NEVER"
        echo "FAIL_OPEN=1"
    } > "$TMP" || return 1
    mv -f "$TMP" "$PROFILE"
}

ensure_binding() {
    SERIAL="$(serial_now)"; [ -n "$SERIAL" ] || SERIAL=KOBO_UNKNOWN
    FP="$(fingerprint_hash)"
    if [ -f "$PROFILE" ]; then
        OLD_SERIAL="$(v5_get SERIAL '')"; OLD_FP="$(v5_get CONTROLLER_FINGERPRINT '')"
        if [ -n "$OLD_SERIAL" ] && [ "$OLD_SERIAL" != "$SERIAL" ]; then
            archive_current SERIAL_CHANGED; reset_observer_data SERIAL_CHANGED; rm -f "$PROFILE"
        elif [ -n "$OLD_FP" ] && [ "$OLD_FP" != "$FP" ]; then
            archive_current CONTROLLER_CHANGED; reset_observer_data CONTROLLER_CHANGED; rm -f "$PROFILE"
        fi
    fi
    if [ ! -f "$PROFILE" ]; then
        write_profile CALIBRATION
    else
        write_profile "$(v5_get STATE CALIBRATION)"
    fi
}

sync_profile() {
    ensure_binding
    write_profile "$(v5_get STATE CALIBRATION)"
}

approve() {
    sync_profile
    S="$(v5_get STATE CALIBRATION)"
    [ "$S" = "PENDING_APPROVAL" ] || { echo "PROFILE_NOT_READY state=$S"; return 2; }
    TMP_APPROVED="$(now_iso)"
    sed "s/^APPROVED_AT=.*/APPROVED_AT=$TMP_APPROVED/; s/^STATE=.*/STATE=PROBATION/; s/^PROBATION_COMPLETED=.*/PROBATION_COMPLETED=0/; s/^PROBATION_SESSION_OPEN=.*/PROBATION_SESSION_OPEN=0/" "$PROFILE" > "$PROFILE.tmp.$$" && mv -f "$PROFILE.tmp.$$" "$PROFILE"
    write_profile PROBATION
    echo "PROFILE_APPROVED probation=0/$(v5_get PROBATION_REQUIRED 2) protect=OFF"
}

session_start() {
    sync_profile
    S="$(v5_get STATE CALIBRATION)"
    [ "$S" = "PROBATION" ] || return 0
    OPEN="$(num "$(v5_get PROBATION_SESSION_OPEN 0)")"
    if [ "$OPEN" -eq 1 ]; then
        sed "s/^PROBATION_SESSION_OPEN=.*/PROBATION_SESSION_OPEN=0/; s/^PROBATION_SESSION_STARTED_AT=.*/PROBATION_SESSION_STARTED_AT=/" "$PROFILE" > "$PROFILE.tmp.$$" && mv -f "$PROFILE.tmp.$$" "$PROFILE"
    fi
    STARTED="$(now_iso)"
    sed "s/^PROBATION_SESSION_OPEN=.*/PROBATION_SESSION_OPEN=1/; s|^PROBATION_SESSION_STARTED_AT=.*|PROBATION_SESSION_STARTED_AT=$STARTED|" "$PROFILE" > "$PROFILE.tmp.$$" && mv -f "$PROFILE.tmp.$$" "$PROFILE"
    write_profile PROBATION
}

session_end() {
    [ -f "$PROFILE" ] || return 0
    S="$(v5_get STATE CALIBRATION)"
    [ "$S" = "PROBATION" ] || return 0
    OPEN="$(num "$(v5_get PROBATION_SESSION_OPEN 0)")"; [ "$OPEN" -eq 1 ] || return 0
    DONE="$(num "$(v5_get PROBATION_COMPLETED 0)")"; DONE=$((DONE + 1))
    sed "s/^PROBATION_COMPLETED=.*/PROBATION_COMPLETED=$DONE/; s/^PROBATION_SESSION_OPEN=.*/PROBATION_SESSION_OPEN=0/; s/^PROBATION_SESSION_STARTED_AT=.*/PROBATION_SESSION_STARTED_AT=/" "$PROFILE" > "$PROFILE.tmp.$$" && mv -f "$PROFILE.tmp.$$" "$PROFILE"
    write_profile PROBATION
}

reset_profile() {
    archive_current MANUAL_RESET
    reset_observer_data MANUAL_RESET
    rm -f "$PROFILE"
    write_profile CALIBRATION
    echo "PROFILE_RESET state=CALIBRATION"
}

status() {
    sync_profile >/dev/null 2>&1 || true
    echo "Profile V5: $(v5_get STATE CALIBRATION)"
    echo "Controller: $(v5_get CONTROLLER_CLASS Generic) | $(v5_get CONTROLLER_FINGERPRINT unknown)"
    echo "Learn: baseline $(v5_get BASELINE_COUNT 0) | contacts $(v5_get CONTACTS 0) | incomplete $(v5_get INCOMPLETE_PCT 0)%"
    echo "Ready: $(v5_get PROFILE_READY 0) | $(v5_get READINESS_REASON LEARNING)"
    echo "Probation: $(v5_get PROBATION_COMPLETED 0)/$(v5_get PROBATION_REQUIRED 2)"
    echo "Protect eligible: $(v5_get PROTECT_ELIGIBLE 0) | Protect active: 0"
}

case "${1:-status}" in
    ensure-binding) ensure_binding ;;
    sync) sync_profile ;;
    approve) approve ;;
    session-start) session_start ;;
    session-end) session_end ;;
    reset) reset_profile ;;
    state) sync_profile >/dev/null 2>&1 || true; v5_get STATE CALIBRATION ;;
    fingerprint) echo "$(fingerprint_hash)"; fingerprint_canonical ;;
    status) status ;;
    *) echo "Usage: $0 {ensure-binding|sync|approve|session-start|session-end|reset|state|fingerprint|status}"; exit 1 ;;
esac
