#!/bin/sh
BASE=/mnt/onboard/.adds/ghostguard
RUN="$BASE/runtime"
DATA="$BASE/data"
LOG="$DATA/native.log"
RUNFLAG="$RUN/RUN"
MODEFILE="$RUN/mode"
INPUTFILE="$RUN/input_device"
CHILDPID="$RUN/daemon.pid"

arch_name() {
    case "$(uname -m 2>/dev/null)" in
        aarch64|arm64) echo aarch64 ;;
        armv8*|armv7*|armv6*|arm*) echo armv7 ;;
        *) echo unknown ;;
    esac
}

find_touch() {
    # Prefer the device selected and validated by ghostguard.sh. This prevents
    # controller/supervisor detection drift on Kobo variants whose touchscreen
    # is only discoverable through /proc/bus/input/devices.
    if [ -r "$INPUTFILE" ]; then
        D="$(head -n 1 "$INPUTFILE" 2>/dev/null | tr -d '\r\n')"
        [ -n "$D" ] && [ -r "$D" ] && { echo "$D"; return 0; }
    fi

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
                    n=split(handlers,a," ");
                    for(i=1;i<=n;i++) if(a[i] ~ /^event[0-9]+$/){print "/dev/input/" a[i]; exit}
                }
                name=""; handlers=""
            }
        ' /proc/bus/input/devices 2>/dev/null | head -n 1
    fi
}

mkdir -p "$RUN" "$DATA" 2>/dev/null
while [ -f "$RUNFLAG" ]; do
    [ -f "$BASE/SAFE_MODE" ] && break
    ARCH="$(arch_name)"
    BIN="$BASE/bin/ghostguardd-$ARCH"
    if [ ! -x "$BIN" ]; then echo "$(date) NO_BINARY arch=$ARCH" >> "$LOG"; break; fi
    INPUT="$(find_touch)"
    if [ -z "$INPUT" ]; then
        echo "$(date) WAIT_TOUCH" >> "$LOG"
        sleep 4
        continue
    fi
    echo "$INPUT" > "$INPUTFILE"
    echo "$(date) START mode=$(cat "$MODEFILE" 2>/dev/null) input=$INPUT arch=$ARCH" >> "$LOG"
    "$BIN" >> "$LOG" 2>&1 &
    C=$!; echo "$C" > "$CHILDPID"
    wait "$C"
    RC=$?
    rm -f "$CHILDPID"
    echo "$(date) CHILD_EXIT rc=$RC; fail-open; retry_in=4s" >> "$LOG"
    [ -f "$RUNFLAG" ] || break
    sleep 4
done
rm -f "$CHILDPID"
echo "$(date) SUPERVISOR_EXIT" >> "$LOG"
