#!/bin/sh
# GhostGuard emergency fail-open stop. Must return immediately.
set -u
BASE=/mnt/onboard/.adds/ghostguard
RUN="$BASE/runtime"
DATA="$BASE/data"
RUNFLAG="$RUN/RUN"
ARMFILE="$RUN/PROTECT_ARMED"
CHILDPID="$RUN/daemon.pid"
PIDFILE="$RUN/supervisor.pid"
PST="$DATA/PROTECT_STATUS.ggstate"

# Prevent supervisor from restarting first, then terminate the process which owns
# the physical evdev fd. Process exit closes EVIOCGRAB in the kernel.
rm -f "$RUNFLAG" "$ARMFILE" 2>/dev/null || true
if [ -f "$CHILDPID" ]; then
    C="$(cat "$CHILDPID" 2>/dev/null || true)"
    [ -n "$C" ] && kill -TERM "$C" 2>/dev/null || true
fi
if [ -f "$PIDFILE" ]; then
    P="$(cat "$PIDFILE" 2>/dev/null || true)"
    [ -n "$P" ] && kill -TERM "$P" 2>/dev/null || true
fi
printf 'STATE=EMERGENCY_STOP\nPROTECT_ACTIVE=0\nFAIL_OPEN=1\n' > "$PST" 2>/dev/null || true

# Cleanup is intentionally detached; nothing here may hold NickelMenu waiting.
(
    sleep 1
    if [ -f "$CHILDPID" ]; then
        C="$(cat "$CHILDPID" 2>/dev/null || true)"
        [ -n "$C" ] && kill -KILL "$C" 2>/dev/null || true
    fi
    if [ -f "$PIDFILE" ]; then
        P="$(cat "$PIDFILE" 2>/dev/null || true)"
        [ -n "$P" ] && kill -KILL "$P" 2>/dev/null || true
    fi
    rm -f "$PIDFILE" "$CHILDPID" "$ARMFILE" 2>/dev/null || true
) >/dev/null 2>&1 &

exit 0
