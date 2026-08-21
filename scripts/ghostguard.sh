#!/bin/sh
# DCPRO GhostGuard Kobo v0.8.0 Foundation / Shadow
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
KEY="$BASE/license.key"
LICENSE_STATE="$DATA/license_last_date"
LICENSE_STATUS="$DATA/LICENSE_STATUS.txt"
DEVICE_INFO="$DATA/KOBO_DEVICE_ID.txt"
LOG="$DATA/native.log"
REPORT_ROOT=/mnt/onboard/GhostGuard_Reports

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
    # Prefer explicit touchscreen-like names in sysfs.
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

    # Fallback: look for an event handler in a block whose name resembles touch.
    if [ -r /proc/bus/input/devices ]; then
        awk '
            BEGIN{IGNORECASE=1; name=""; handlers=""}
            /^N: Name=/{name=$0}
            /^H: Handlers=/{handlers=$0}
            /^$/{
                if (name ~ /(touch|cyttsp|zforce|elan|goodix|focal|fts|mtk)/) {
                    n=split(handlers,a," ");
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
    MODEL="$(grep -m1 '^N: Name=' /proc/bus/input/devices 2>/dev/null | sed 's/^N: Name=//')"
    INPUT="$(find_touch)"
    {
        echo "DCPRO_GHOSTGUARD_KOBO_DEVICE_V1"
        echo "DEVICE_ID=$SERIAL"
        echo "ARCH=$(arch_name)"
        echo "FIRMWARE=$FW"
        echo "INPUT_DEVICE=$INPUT"
        echo "LICENSE_PATH=$KEY"
        echo "ENGINE=NATIVE_EVDEV"
        echo "LICENSE_FORMAT=4"
        echo "LICENSE_SIGNATURE=ED25519"
        echo "PROTECT_ACTIVE=0"
    } > "$DEVICE_INFO"
}

license_check() {
    SERIAL="$(clean_serial)"
    DCPRO_LICENSE_PATH="$KEY" DCPRO_LICENSE_STATE="$LICENSE_STATE" \
        "$BASE/license_bridge.sh" check "$SERIAL" > "$LICENSE_STATUS.tmp" 2>&1
    RC=$?
    mv -f "$LICENSE_STATUS.tmp" "$LICENSE_STATUS" 2>/dev/null || true
    return $RC
}

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

start_engine() {
    MODE="$1"
    write_device_info
    migrate_learning_old
    if [ -f "$SAFE" ]; then
        echo "SAFE_MODE đang bật. Hãy tắt SAFE_MODE trước."
        return 2
    fi
    if is_running; then
        CUR="$(cat "$MODEFILE" 2>/dev/null)"
        if [ "$CUR" = "$MODE" ]; then
            echo "GhostGuard đang chạy: $MODE"
            return 0
        fi
        stop_engine >/dev/null 2>&1
        sleep 1
    fi
    if ! license_check; then
        echo "License chưa hợp lệ."
        cat "$LICENSE_STATUS" 2>/dev/null
        echo "DEVICE_ID=$(clean_serial)"
        return 3
    fi
    INPUT="$(find_touch)"
    if [ -z "$INPUT" ] || [ ! -r "$INPUT" ]; then
        echo "Không tìm thấy touchscreen evdev đọc được."
        write_device_info
        return 4
    fi
    BIN="$(binary_path)"
    if [ -z "$BIN" ] || [ ! -x "$BIN" ]; then
        echo "Không có native binary phù hợp: $(uname -m 2>/dev/null)"
        return 5
    fi
    echo "$INPUT" > "$INPUTFILE"
    echo "$MODE" > "$MODEFILE"
    echo 1 > "$RUNFLAG"
    rm -f "$DATA/RUNTIME_FAULT.txt"
    if command -v setsid >/dev/null 2>&1; then
        setsid "$BASE/supervisor.sh" >/dev/null 2>&1 &
    elif command -v nohup >/dev/null 2>&1; then
        nohup "$BASE/supervisor.sh" >/dev/null 2>&1 &
    else
        "$BASE/supervisor.sh" >/dev/null 2>&1 &
    fi
    SP=$!
    echo "$SP" > "$PIDFILE"
    sleep 1
    if is_running; then
        echo "GhostGuard Native đã chạy: $MODE"
        echo "Input: $INPUT"
        echo "Protect: OFF (fail-open)"
        return 0
    fi
    echo "Không khởi động được supervisor."
    return 6
}

stop_engine() {
    rm -f "$RUNFLAG"
    if [ -f "$CHILDPID" ]; then
        C="$(cat "$CHILDPID" 2>/dev/null)"; [ -n "$C" ] && kill "$C" 2>/dev/null || true
    fi
    if [ -f "$PIDFILE" ]; then
        P="$(cat "$PIDFILE" 2>/dev/null)"; [ -n "$P" ] && kill "$P" 2>/dev/null || true
    fi
    sleep 1
    rm -f "$PIDFILE" "$CHILDPID"
    echo "GhostGuard đã dừng. Cảm ứng không bị grab ở bất kỳ thời điểm nào."
}

profile_value() {
    K="$1"
    [ -f "$DATA/profile.txt" ] || return 0
    sed -n "s/^${K}=//p" "$DATA/profile.txt" 2>/dev/null | head -n 1
}

touch_name() {
    D="$(find_touch)"
    E="$(basename "$D" 2>/dev/null)"
    [ -n "$E" ] && cat "/sys/class/input/$E/device/name" 2>/dev/null
}

controller_class() {
    N="$(touch_name | tr '[:upper:]' '[:lower:]')"
    case "$N" in
        *fts*|*focal*) echo FocalTech ;;
        *elan*) echo ELAN ;;
        *zforce*) echo zForce ;;
        *goodix*) echo Goodix ;;
        *) echo Generic ;;
    esac
}

status_engine() {
    write_device_info
    if is_running; then
        STATE="RUNNING"
        MODE_NOW="$(cat "$MODEFILE" 2>/dev/null)"
    else
        STATE="STOPPED"
        MODE_NOW="-"
    fi
    if license_check; then LIC="OK"; else LIC="DENIED"; fi
    [ -f "$SAFE" ] && SAFE_NOW="ON" || SAFE_NOW="OFF"

    C="$(profile_value CONTACTS)"; [ -n "$C" ] || C=0
    I="$(profile_value INCOMPLETE_CONTACTS)"; [ -n "$I" ] || I=0
    L="$(profile_value RISK_LOW)"; [ -n "$L" ] || L=0
    M="$(profile_value RISK_MEDIUM)"; [ -n "$M" ] || M=0
    H="$(profile_value RISK_HIGH)"; [ -n "$H" ] || H=0
    W="$(profile_value WOULD_DROP)"; [ -n "$W" ] || W=0
    BC="$(profile_value BASELINE_COUNT)"; [ -n "$BC" ] || BC=0
    RM="$(profile_value RISK_MAX)"; [ -n "$RM" ] || RM=0

    echo "GhostGuard Kobo v0.8.0-foundation"
    echo "Device: $(clean_serial) | $(controller_class)"
    echo "$STATE | $MODE_NOW | License: $LIC"
    echo "Contacts: $C | Incomplete: $I"
    echo "Risk L/M/H: $L/$M/$H | Candidate: $W"
    echo "Baseline: $BC | Risk max: $RM/100"
    echo "Touch: $(basename "$(find_touch)" 2>/dev/null) $(touch_name)"
    echo "Protect OFF | Grab NEVER | Safe: $SAFE_NOW"
}

status_full() {
    status_engine
    echo
    echo "DEVICE_ID: $(clean_serial)"
    echo "ARCH: $(arch_name)"
    [ -f "$LICENSE_STATUS" ] && { echo "--- License ---"; cat "$LICENSE_STATUS"; }
    [ -f "$DATA/profile.txt" ] && { echo "--- Profile ---"; cat "$DATA/profile.txt"; }
    [ -f "$DATA/RUNTIME_FAULT.txt" ] && { echo "--- Runtime fault ---"; cat "$DATA/RUNTIME_FAULT.txt"; }
}

make_report() {
    mkdir -p "$REPORT_ROOT" "$DATA/reports" 2>/dev/null
    TS="$(date +%Y%m%d_%H%M%S 2>/dev/null)"
    [ -n "$TS" ] || TS=unknown
    SERIAL="$(clean_serial)"; [ -n "$SERIAL" ] || SERIAL=KOBO_UNKNOWN

    TMP="$DATA/reports/report_$TS"
    LATEST="$REPORT_ROOT/LATEST"
    LAST="$REPORT_ROOT/REPORT_LAST.txt"

    rm -rf "$TMP" "$LATEST" 2>/dev/null
    mkdir -p "$TMP" "$LATEST" 2>/dev/null

    # Refresh current metadata first.
    write_device_info
    license_check >/dev/null 2>&1 || true

    cp "$DEVICE_INFO" "$TMP/" 2>/dev/null || true
    cp "$DATA/profile.txt" "$TMP/" 2>/dev/null || true
    cp "$DATA/contacts.csv" "$TMP/" 2>/dev/null || true
    cp "$DATA/RUNTIME_FAULT.txt" "$TMP/" 2>/dev/null || true
    cp "$LICENSE_STATUS" "$TMP/" 2>/dev/null || true
    cp "$LOG" "$TMP/" 2>/dev/null || true

    # Exact CSV snapshot at report time. This is independent from profile flush cadence.
    if [ -f "$DATA/contacts.csv" ]; then
        awk -F, '
            NR==1 { next }
            {
                n++
                if ($11=="INCOMPLETE") inc++
                else {
                    r=$8+0
                    if (r<35) low++
                    else if (r<65) med++
                    else high++
                    if ($12=="WOULD_DROP") cand++
                }
            }
            END {
                print "CSV_CONTACTS=" n+0
                print "CSV_INCOMPLETE=" inc+0
                print "CSV_RISK_LOW=" low+0
                print "CSV_RISK_MEDIUM=" med+0
                print "CSV_RISK_HIGH=" high+0
                print "CSV_CANDIDATES=" cand+0
            }
        ' "$DATA/contacts.csv" > "$TMP/CSV_LIVE_SNAPSHOT.txt" 2>/dev/null || true
    fi

    {
        echo "DATE=$(date 2>/dev/null)"
        echo "UNAME=$(uname -a 2>/dev/null)"
        echo "UPTIME=$(uptime 2>/dev/null)"
        echo "MODE=$(cat "$MODEFILE" 2>/dev/null)"
        echo "SAFE_MODE=$([ -f "$SAFE" ] && echo 1 || echo 0)"
        echo "TOUCH=$(find_touch)"
        echo "TOUCH_NAME=$(touch_name)"
        echo "CONTROLLER_CLASS=$(controller_class)"
        echo "ARCH=$(arch_name)"
        echo "INPUTS:"
        for P in /sys/class/input/event*; do
            [ -e "$P" ] && echo "$(basename "$P"): $(cat "$P/device/name" 2>/dev/null)"
        done
    } > "$TMP/SYSTEM.txt"

    # Always expose an unpacked latest report so USB users can retrieve it
    # even if this firmware lacks gzip/tar options.
    cp -R "$TMP"/. "$LATEST"/ 2>/dev/null || true

    OUT=""
    ARCHIVE_ERROR=""

    # Try regular tar first.
    if command -v tar >/dev/null 2>&1; then
        CAND="$REPORT_ROOT/DCPRO_GhostGuard_KoboNative_${SERIAL}_${TS}.tar.gz"
        if tar -czf "$CAND" -C "$TMP" . 2>"$TMP/tar_error.txt" && [ -s "$CAND" ]; then
            OUT="$CAND"
        else
            rm -f "$CAND" 2>/dev/null
            CAND="$REPORT_ROOT/DCPRO_GhostGuard_KoboNative_${SERIAL}_${TS}.tar"
            if tar -cf "$CAND" -C "$TMP" . 2>>"$TMP/tar_error.txt" && [ -s "$CAND" ]; then
                OUT="$CAND"
            fi
        fi
    fi

    # BusyBox fallback if tar command or its gzip mode is unusual.
    if [ -z "$OUT" ] && command -v busybox >/dev/null 2>&1; then
        CAND="$REPORT_ROOT/DCPRO_GhostGuard_KoboNative_${SERIAL}_${TS}.tar"
        if busybox tar -cf "$CAND" -C "$TMP" . 2>>"$TMP/tar_error.txt" && [ -s "$CAND" ]; then
            OUT="$CAND"
        fi
    fi

    if [ -f "$TMP/tar_error.txt" ]; then
        cp "$TMP/tar_error.txt" "$LATEST/" 2>/dev/null || true
        ARCHIVE_ERROR="$(tail -n 3 "$TMP/tar_error.txt" 2>/dev/null)"
    fi

    {
        echo "DCPRO GhostGuard Kobo Report"
        echo "TIME=$TS"
        echo "DEVICE_ID=$SERIAL"
        echo "LATEST_FOLDER=$LATEST"
        if [ -n "$OUT" ]; then
            echo "ARCHIVE=$OUT"
            echo "RESULT=OK"
        else
            echo "ARCHIVE=NONE"
            echo "RESULT=LATEST_FOLDER_ONLY"
            [ -n "$ARCHIVE_ERROR" ] && echo "ARCHIVE_ERROR=$ARCHIVE_ERROR"
        fi
    } > "$LAST"

    sync 2>/dev/null || true

    if [ -n "$OUT" ]; then
        echo "Report OK"
        echo "$OUT"
        echo "Backup folder: $LATEST"
        rm -rf "$TMP" 2>/dev/null
        return 0
    fi

    echo "Archive không tạo được, nhưng dữ liệu đã lưu an toàn tại:"
    echo "$LATEST"
    echo "Chi tiết: $LAST"
    return 0
}

case "${1:-status}" in
    start|learn) start_engine LEARN ;;
    shadow) start_engine SHADOW ;;
    stop) stop_engine ;;
    status) status_engine ;;
    status-full) status_full ;;
    report) write_device_info; make_report ;;
    safe-on) stop_engine >/dev/null 2>&1; echo 1 > "$SAFE"; echo "SAFE_MODE: ON" ;;
    safe-off) rm -f "$SAFE"; echo "SAFE_MODE: OFF" ;;
    device-id) write_device_info; cat "$DEVICE_INFO" ;;
    license) write_device_info; license_check; cat "$LICENSE_STATUS"; exit $? ;;
    *) echo "Usage: $0 {learn|shadow|stop|status|status-full|report|safe-on|safe-off|device-id|license}"; exit 1 ;;
esac
