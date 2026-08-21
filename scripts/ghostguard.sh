#!/bin/sh
# DCPRO GhostGuard Kobo v0.8.1.1 Profile V5 / Shadow
# Safe native learning/shadow observer with compact NickelMenu controls.
# No EVIOCGRAB, no uinput, no touch blocking in this release.

BASE=/mnt/onboard/.adds/ghostguard
BIN_DIR="$BASE/bin"
DATA="$BASE/data"
RUN="$BASE/runtime"
PIDFILE="$RUN/supervisor.pid"
CHILDPID="$RUN/daemon.pid"
RUNFLAG="$RUN/RUN"
MODEFILE="$RUN/mode"
INPUTFILE="$RUN/input_device"
SAFE="$BASE/SAFE_MODE"
LICENSE_STATE="$DATA/license_last_date"
LICENSE_STATUS="$DATA/LICENSE_STATUS.txt"
DEVICE_INFO="$DATA/KOBO_DEVICE_ID.txt"
LOG="$DATA/native.log"
REPORT_ROOT=/mnt/onboard/GhostGuard_Reports
PROFILE_MGR="$BASE/profile_manager.sh"
PROFILE_V5="$DATA/profile_v5.txt"

mkdir -p "$DATA" "$DATA/reports" "$RUN" 2>/dev/null

clean_serial() {
    if [ -f /mnt/onboard/.kobo/version ]; then
        sed -n '1{s/,.*//;p;}' /mnt/onboard/.kobo/version 2>/dev/null \
            | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9'
    fi
}

arch_name() {
    A="$(uname -m 2>/dev/null)"
    case "$A" in
        aarch64|arm64) echo aarch64 ;;
        armv8*|armv7*|armv6*|arm*) echo armv7 ;;
        *) echo unknown ;;
    esac
}

binary_path() {
    case "$(arch_name)" in
        aarch64) echo "$BIN_DIR/ghostguardd-aarch64" ;;
        armv7) echo "$BIN_DIR/ghostguardd-armv7" ;;
        *) echo "" ;;
    esac
}

find_touch() {
    for P in /sys/class/input/event*; do
        [ -e "$P" ] || continue
        N="$(cat "$P/device/name" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
        case "$N" in
            *touch*|*cyttsp*|*zforce*|*elan*|*goodix*|*focal*|*fts*|*mtk*tpd*|*multitouch*)
                E="$(basename "$P")"
                [ -r "/dev/input/$E" ] && { echo "/dev/input/$E"; return 0; }
                ;;
        esac
    done
    if [ -r /proc/bus/input/devices ]; then
        awk '
            BEGIN{IGNORECASE=1; name=""; handlers=""}
            /^N: Name=/{name=$0}
            /^H: Handlers=/{handlers=$0}
            /^$/ {
                if (name ~ /(touch|cyttsp|zforce|elan|goodix|focal|fts|mtk)/) {
                    n=split(handlers,a," ")
                    for(i=1;i<=n;i++) if(a[i] ~ /^event[0-9]+$/){print "/dev/input/" a[i]; exit}
                }
                name="";handlers=""
            }
        ' /proc/bus/input/devices 2>/dev/null | head -n 1
    fi
}

write_device_info() {
    SERIAL="$(clean_serial)"
    [ -n "$SERIAL" ] || SERIAL=KOBO_UNKNOWN
    FW="$(cut -d, -f3 /mnt/onboard/.kobo/version 2>/dev/null | tr -d '\r\n')"
    INPUT="$(find_touch)"
    {
        echo "DCPRO_GHOSTGUARD_KOBO_DEVICE_V1"
        echo "DEVICE_ID=$SERIAL"
        echo "ARCH=$(arch_name)"
        echo "FIRMWARE=$FW"
        echo "INPUT_DEVICE=$INPUT"
        echo "LICENSE_SOURCE=SHARED_ONLINE_REGISTRY"
        echo "LICENSE_REGISTRY=ghostguard-kindle/licenses/licenses.json"
        echo "ENGINE=NATIVE_EVDEV"
        echo "LICENSE_FORMAT=SHARED_REGISTRY_V1"
        echo "LICENSE_SIGNATURE=RSA-SHA256"
        echo "PROTECT_ACTIVE=0"
    } > "$DEVICE_INFO"
}

license_run() {
    LACTION="$1"
    SERIAL="$(clean_serial)"
    DCPRO_LICENSE_STATE="$LICENSE_STATE" \
        "$BASE/license_bridge.sh" "$LACTION" "$SERIAL" > "$LICENSE_STATUS.tmp" 2>&1
    RC=$?
    mv -f "$LICENSE_STATUS.tmp" "$LICENSE_STATUS" 2>/dev/null || true
    return $RC
}

license_check() { license_run check; }
license_sync() { license_run sync; }
license_cache() { license_run cache; }

is_running() {
    [ -f "$PIDFILE" ] || return 1
    P="$(cat "$PIDFILE" 2>/dev/null)"
    [ -n "$P" ] || return 1
    kill -0 "$P" 2>/dev/null
}

migrate_learning_old() {
    if [ -f "$DATA/profile.txt" ]; then
        HDR="$(head -n 1 "$DATA/profile.txt" 2>/dev/null)"
        TS="$(date +%Y%m%d_%H%M%S 2>/dev/null)"; [ -n "$TS" ] || TS=legacy
        case "$HDR" in
            DCPRO_GHOSTGUARD_NATIVE_PROFILE_V1|DCPRO_GHOSTGUARD_NATIVE_PROFILE_V2)
                LEG="$DATA/legacy_pre_v072_$TS"
                mkdir -p "$LEG" 2>/dev/null
                mv "$DATA/profile.txt" "$LEG/profile_old.txt" 2>/dev/null || true
                mv "$DATA/contacts.csv" "$LEG/contacts_old.csv" 2>/dev/null || true
                echo "$(date 2>/dev/null) migrated V1/V2 learning data to $LEG" >> "$LOG"
                ;;
            DCPRO_GHOSTGUARD_NATIVE_PROFILE_V3)
                LEG="$DATA/legacy_pre_v073_$TS"
                mkdir -p "$LEG" 2>/dev/null
                cp "$DATA/profile.txt" "$LEG/profile_v3_seed.txt" 2>/dev/null || true
                mv "$DATA/contacts.csv" "$LEG/contacts_v3.csv" 2>/dev/null || true
                echo "$(date 2>/dev/null) V3 baseline retained; old CSV moved to $LEG" >> "$LOG"
                ;;
        esac
    fi
}

profile_value() { K="$1"; [ -f "$DATA/profile.txt" ] || return 0; sed -n "s/^${K}=//p" "$DATA/profile.txt" 2>/dev/null | head -n 1; }
v5_value() { K="$1"; [ -f "$PROFILE_V5" ] || return 0; sed -n "s/^${K}=//p" "$PROFILE_V5" 2>/dev/null | head -n 1; }
profile_sync() { [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" sync >/dev/null 2>&1 || true; }
profile_state() { [ -x "$PROFILE_MGR" ] || { echo CALIBRATION; return; }; "$PROFILE_MGR" state 2>/dev/null || echo CALIBRATION; }

touch_name() { D="$(find_touch)"; E="$(basename "$D" 2>/dev/null)"; [ -n "$E" ] && cat "/sys/class/input/$E/device/name" 2>/dev/null; }
controller_class() { N="$(touch_name | tr '[:upper:]' '[:lower:]')"; case "$N" in *fts*|*focal*) echo FocalTech ;; *elan*) echo ELAN ;; *zforce*) echo zForce ;; *goodix*) echo Goodix ;; *) echo Generic ;; esac; }

stop_engine() {
    rm -f "$RUNFLAG"
    if [ -f "$CHILDPID" ]; then C="$(cat "$CHILDPID" 2>/dev/null)"; [ -n "$C" ] && kill "$C" 2>/dev/null || true; fi
    if [ -f "$PIDFILE" ]; then P="$(cat "$PIDFILE" 2>/dev/null)"; [ -n "$P" ] && kill "$P" 2>/dev/null || true; fi
    sleep 1
    rm -f "$PIDFILE" "$CHILDPID"
    [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" session-end >/dev/null 2>&1 || true
    echo "GhostGuard đã dừng. Cảm ứng không bị grab ở bất kỳ thời điểm nào."
}

start_engine() {
    MODE="$1"
    write_device_info
    migrate_learning_old
    if [ -f "$SAFE" ]; then echo "SAFE_MODE đang bật. Hãy tắt SAFE_MODE trước."; return 2; fi
    if is_running; then CUR="$(cat "$MODEFILE" 2>/dev/null)"; if [ "$CUR" = "$MODE" ]; then echo "GhostGuard đang chạy: $MODE"; return 0; fi; stop_engine >/dev/null 2>&1; sleep 1; fi
    if ! license_check; then echo "License chưa hợp lệ."; cat "$LICENSE_STATUS" 2>/dev/null; echo "DEVICE_ID=$(clean_serial)"; return 3; fi
    INPUT="$(find_touch)"; if [ -z "$INPUT" ] || [ ! -r "$INPUT" ]; then echo "Không tìm thấy touchscreen evdev đọc được."; write_device_info; return 4; fi
    echo "$INPUT" > "$INPUTFILE"
    if [ -x "$PROFILE_MGR" ]; then
        "$PROFILE_MGR" ensure-binding >/dev/null 2>&1 || true
        PSTATE="$(profile_state)"
        if [ "$MODE" = "LEARN" ]; then case "$PSTATE" in PENDING_APPROVAL) echo "Profile V5 đã READY. Chuyển sang SHADOW để chờ duyệt."; MODE=SHADOW ;; PROBATION|PROBATION_PASSED) echo "Profile V5 đã được duyệt. Giữ SHADOW; muốn học lại hãy Reset Profile."; MODE=SHADOW ;; esac; fi
    fi
    BIN="$(binary_path)"; if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then echo "Không có native binary phù hợp: $(uname -m 2>/dev/null)"; return 5; fi
    echo "$MODE" > "$MODEFILE"; echo 1 > "$RUNFLAG"; rm -f "$DATA/RUNTIME_FAULT.txt"
    if command -v setsid >/dev/null 2>&1; then setsid "$BASE/supervisor.sh" >/dev/null 2>&1 &
    elif command -v nohup >/dev/null 2>&1; then nohup "$BASE/supervisor.sh" >/dev/null 2>&1 &
    else "$BASE/supervisor.sh" >/dev/null 2>&1 & fi
    SP=$!; echo "$SP" > "$PIDFILE"; sleep 1
    if is_running; then [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" session-start >/dev/null 2>&1 || true; echo "GhostGuard Native đã chạy: $MODE"; echo "Input: $INPUT"; echo "Profile: $(profile_state)"; echo "Protect: OFF (fail-open)"; return 0; fi
    echo "Không khởi động được supervisor."; return 6
}

status_engine() {
    write_device_info
    if is_running; then STATE="RUNNING"; MODE_NOW="$(cat "$MODEFILE" 2>/dev/null)"; else STATE="STOPPED"; MODE_NOW="-"; fi
    if license_cache; then LIC="OK"; else LIC="DENIED/NOT_SYNCED"; fi
    [ -f "$SAFE" ] && SAFE_NOW="ON" || SAFE_NOW="OFF"
    C="$(profile_value CONTACTS)"; [ -n "$C" ] || C=0
    I="$(profile_value INCOMPLETE_CONTACTS)"; [ -n "$I" ] || I=0
    L="$(profile_value RISK_LOW)"; [ -n "$L" ] || L=0
    M="$(profile_value RISK_MEDIUM)"; [ -n "$M" ] || M=0
    H="$(profile_value RISK_HIGH)"; [ -n "$H" ] || H=0
    W="$(profile_value WOULD_DROP)"; [ -n "$W" ] || W=0
    BC="$(profile_value BASELINE_COUNT)"; [ -n "$BC" ] || BC=0
    RM="$(profile_value RISK_MAX)"; [ -n "$RM" ] || RM=0
    echo "GhostGuard Kobo v0.8.1.1-hotfix"
    echo "Device: $(clean_serial) | $(controller_class)"
    echo "$STATE | $MODE_NOW | License: $LIC"
    echo "Contacts: $C | Incomplete: $I"
    echo "Risk L/M/H: $L/$M/$H | Candidate: $W"
    profile_sync
    PS="$(v5_value STATE)"; [ -n "$PS" ] || PS=CALIBRATION
    PR="$(v5_value PROFILE_READY)"; [ -n "$PR" ] || PR=0
    PC="$(v5_value PROBATION_COMPLETED)"; [ -n "$PC" ] || PC=0
    PN="$(v5_value PROBATION_REQUIRED)"; [ -n "$PN" ] || PN=2
    FP="$(v5_value CONTROLLER_FINGERPRINT)"; [ -n "$FP" ] || FP=unknown
    echo "Baseline: $BC | Risk max: $RM/100"
    echo "Profile V5: $PS | Ready: $PR | Probation: $PC/$PN"
    echo "Fingerprint: $FP"
    echo "Touch: $(basename "$(find_touch)" 2>/dev/null) $(touch_name)"
    echo "Protect OFF | Grab NEVER | Safe: $SAFE_NOW"
}

status_full() { status_engine; echo; echo "DEVICE_ID: $(clean_serial)"; echo "ARCH: $(arch_name)"; [ -f "$LICENSE_STATUS" ] && { echo "--- License ---"; cat "$LICENSE_STATUS"; }; [ -f "$DATA/profile.txt" ] && { echo "--- Observer Profile ---"; cat "$DATA/profile.txt"; }; [ -f "$PROFILE_V5" ] && { echo "--- Profile V5 ---"; cat "$PROFILE_V5"; }; [ -f "$DATA/RUNTIME_FAULT.txt" ] && { echo "--- Runtime fault ---"; cat "$DATA/RUNTIME_FAULT.txt"; }; }

make_report() {
    mkdir -p "$REPORT_ROOT" "$DATA/reports" 2>/dev/null
    TS="$(date +%Y%m%d_%H%M%S 2>/dev/null)"; [ -n "$TS" ] || TS=unknown
    SERIAL="$(clean_serial)"; [ -n "$SERIAL" ] || SERIAL=KOBO_UNKNOWN
    TMP="$DATA/reports/report_$TS"; LATEST="$REPORT_ROOT/LATEST"; LAST="$REPORT_ROOT/REPORT_LAST.txt"
    rm -rf "$TMP" "$LATEST" 2>/dev/null; mkdir -p "$TMP" "$LATEST" 2>/dev/null
    write_device_info; license_cache >/dev/null 2>&1 || true
    cp "$DEVICE_INFO" "$TMP/" 2>/dev/null || true
    cp "$DATA/profile.txt" "$TMP/observer_profile.txt" 2>/dev/null || true
    cp "$PROFILE_V5" "$TMP/profile_v5.txt" 2>/dev/null || true
    cp "$DATA/contacts.csv" "$TMP/" 2>/dev/null || true
    cp "$DATA/RUNTIME_FAULT.txt" "$TMP/" 2>/dev/null || true
    cp "$LICENSE_STATUS" "$TMP/" 2>/dev/null || true
    cp "$LOG" "$TMP/" 2>/dev/null || true
    if [ -f "$DATA/contacts.csv" ]; then awk -F, 'NR==1{next}{n++;if($11=="INCOMPLETE")inc++;else{r=$8+0;if(r<35)low++;else if(r<65)med++;else high++;if($12=="WOULD_DROP")cand++}}END{print "CSV_CONTACTS="n+0;print "CSV_INCOMPLETE="inc+0;print "CSV_RISK_LOW="low+0;print "CSV_RISK_MEDIUM="med+0;print "CSV_RISK_HIGH="high+0;print "CSV_CANDIDATES="cand+0}' "$DATA/contacts.csv" > "$TMP/CSV_LIVE_SNAPSHOT.txt" 2>/dev/null || true; fi
    {
        echo "DATE=$(date 2>/dev/null)"
        echo "UNAME=$(uname -a 2>/dev/null)"
        echo "UPTIME=$(uptime 2>/dev/null)"
        echo "MODE=$(cat "$MODEFILE" 2>/dev/null)"
        echo "PROFILE_STATE=$(profile_state)"
    } > "$TMP/SYSTEM.txt"
    cp -R "$TMP"/. "$LATEST"/ 2>/dev/null || true
    ARCHIVE="$REPORT_ROOT/GhostGuard_Kobo_${SERIAL}_${TS}.tar.gz"
    if tar -czf "$ARCHIVE" -C "$TMP" . 2>/dev/null; then
        echo "Report đã tạo:"; echo "$ARCHIVE"; echo "$ARCHIVE" > "$LAST"; return 0
    fi
    ARCHIVE="$REPORT_ROOT/GhostGuard_Kobo_${SERIAL}_${TS}.tar"
    if tar -cf "$ARCHIVE" -C "$TMP" . 2>/dev/null; then
        echo "Report đã tạo:"; echo "$ARCHIVE"; echo "$ARCHIVE" > "$LAST"; return 0
    fi
    echo "Archive không tạo được, nhưng dữ liệu đã lưu an toàn tại:"; echo "$LATEST"; echo "Chi tiết: $LAST"; return 0
}

approve_profile() {
    write_device_info
    if ! license_check; then echo "License chưa hợp lệ."; cat "$LICENSE_STATUS" 2>/dev/null; return 3; fi
    [ -x "$PROFILE_MGR" ] || { echo "Thiếu profile_manager.sh"; return 5; }
    "$PROFILE_MGR" approve || return $?
    echo SHADOW > "$MODEFILE"
    if is_running && [ -f "$CHILDPID" ]; then C="$(cat "$CHILDPID" 2>/dev/null)"; [ -n "$C" ] && kill "$C" 2>/dev/null || true; fi
    "$PROFILE_MGR" session-start >/dev/null 2>&1 || true
    echo "Đã duyệt Profile V5. Bắt đầu Probation ở SHADOW; Protect vẫn OFF."
}

reset_profile() { stop_engine >/dev/null 2>&1 || true; [ -x "$PROFILE_MGR" ] || { echo "Thiếu profile_manager.sh"; return 5; }; "$PROFILE_MGR" reset; echo "Hãy chạy GhostGuard - Learn để học lại profile."; }

case "${1:-status}" in
    start|learn) start_engine LEARN ;;
    shadow) start_engine SHADOW ;;
    stop) stop_engine ;;
    status) status_engine ;;
    status-full) status_full ;;
    report) write_device_info; make_report ;;
    approve) approve_profile ;;
    profile-status) [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" status || echo "Thiếu profile_manager.sh" ;;
    profile-reset) reset_profile ;;
    fingerprint) echo "Input: $(find_touch)"; [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" fingerprint || true ;;
    safe-on) stop_engine >/dev/null 2>&1; echo 1 > "$SAFE"; echo "SAFE_MODE: ON" ;;
    safe-off) rm -f "$SAFE"; echo "SAFE_MODE: OFF" ;;
    device-id) write_device_info; cat "$DEVICE_INFO" ;;
    license) write_device_info; license_check; RC=$?; cat "$LICENSE_STATUS"; exit $RC ;;
    license-sync) write_device_info; license_sync; RC=$?; cat "$LICENSE_STATUS"; exit $RC ;;
    license-cache) write_device_info; license_cache; RC=$?; cat "$LICENSE_STATUS"; exit $RC ;;
    *) echo "Usage: $0 {learn|shadow|stop|status|status-full|report|approve|profile-status|profile-reset|fingerprint|safe-on|safe-off|device-id|license|license-sync|license-cache}"; exit 1 ;;
esac
