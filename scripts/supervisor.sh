#!/bin/sh
# GhostGuard Kobo v0.8.7.1 Safety Lockdown supervisor.
# No path in this release may launch native mode PROTECT or arm EVIOCGRAB.
set -u
BASE=/mnt/onboard/.adds/ghostguard
RUN="$BASE/runtime"; DATA="$BASE/data"; LOG="$DATA/native.log"
RUNFLAG="$RUN/RUN"; MODEFILE="$RUN/mode"; INPUTFILE="$RUN/input_device"; CHILDPID="$RUN/daemon.pid"
ARMFILE="$RUN/PROTECT_ARMED"; FILTERFILE="$RUN/PROTECT_FILTER_ARMED"; WATCHFILE="$RUN/PROTECT_WATCHDOG"
PROFILE_MGR="$BASE/profile_manager.sh"; PST="$DATA/PROTECT_STATUS.ggstate"; HST="$DATA/HANDSHAKE_STATUS.ggstate"
mkdir -p "$RUN" "$DATA" 2>/dev/null || true

arch_name(){ case "$(uname -m 2>/dev/null)" in aarch64|arm64) echo aarch64;; arm*) echo armv7;; *) echo unknown;; esac; }
find_touch(){
  if [ -r "$INPUTFILE" ]; then D="$(head -n1 "$INPUTFILE"|tr -d '\r\n')"; [ -n "$D" ]&&[ -r "$D" ]&&{ echo "$D";return;}; fi
  for P in /sys/class/input/event*; do
    [ -e "$P" ] || continue
    N="$(cat "$P/device/name" 2>/dev/null|tr '[:upper:]' '[:lower:]')"
    case "$N" in
      *ghostguard*virtual*) continue;;
      *touch*|*cyttsp*|*zforce*|*elan*|*goodix*|*focal*|*fts*|*mtk*tpd*|*multitouch*) E="$(basename "$P")"; [ -r "/dev/input/$E" ]&&{ echo "/dev/input/$E"; return; };;
    esac
  done
}
write_safe_state(){
  printf 'STATE=SAFETY_LOCKDOWN_SHADOW\nPROTECT_ACTIVE=0\nFILTER_ACTIVE=0\nFAIL_OPEN=1\n' > "$PST" 2>/dev/null || true
  printf 'STATE=LOCKED_OUT\nREASON=EVIOCGRAB_DISABLED_ON_REAL_DEVICE\nFAIL_OPEN=1\n' > "$HST" 2>/dev/null || true
}
force_safe_mode(){
  M="$1"
  case "$M" in
    LEARN) echo LEARN;;
    *)
      [ "$M" = SHADOW ] || echo "$(date) SAFETY_LOCKDOWN requested=$M forced=SHADOW" >> "$LOG"
      echo SHADOW
      ;;
  esac
}

rm -f "$ARMFILE" "$FILTERFILE" "$WATCHFILE" 2>/dev/null || true
write_safe_state
trap 'rm -f "$ARMFILE" "$FILTERFILE" "$WATCHFILE" 2>/dev/null || true; write_safe_state; [ -f "$CHILDPID" ] && kill -TERM "$(cat "$CHILDPID" 2>/dev/null)" 2>/dev/null || true; exit 0' HUP INT TERM

while [ -f "$RUNFLAG" ]; do
  [ -f "$BASE/SAFE_MODE" ] && break
  rm -f "$ARMFILE" "$FILTERFILE" "$WATCHFILE" 2>/dev/null || true
  write_safe_state
  ARCH="$(arch_name)"; BIN="$BASE/bin/ghostguardd-$ARCH"
  [ -x "$BIN" ] || { echo "$(date) NO_BINARY arch=$ARCH" >> "$LOG"; break; }
  INPUT="$(find_touch)"
  [ -n "$INPUT" ] || { echo "$(date) WAIT_TOUCH" >> "$LOG"; sleep 4; continue; }
  echo "$INPUT" > "$INPUTFILE"
  REQUESTED="$(cat "$MODEFILE" 2>/dev/null)"
  MODE="$(force_safe_mode "$REQUESTED")"
  echo "$MODE" > "$MODEFILE"
  echo "$(date) START mode=$MODE requested=$REQUESTED input=$INPUT arch=$ARCH safety_lockdown=1" >> "$LOG"
  "$BIN" >> "$LOG" 2>&1 & C=$!
  echo "$C" > "$CHILDPID"
  [ "$MODE" = SHADOW ] && [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" session-start >/dev/null 2>&1 || true
  while kill -0 "$C" 2>/dev/null; do
    sleep 5
    [ -f "$RUNFLAG" ] || break
    CUR="$(cat "$MODEFILE" 2>/dev/null)"
    if [ "$CUR" = PROTECT ]; then
      echo SHADOW > "$MODEFILE"
      rm -f "$ARMFILE" "$FILTERFILE" "$WATCHFILE" 2>/dev/null || true
      write_safe_state
      echo "$(date) SAFETY_LOCKDOWN live PROTECT -> SHADOW restart" >> "$LOG"
      kill -TERM "$C" 2>/dev/null || true
      break
    fi
    if [ -x "$PROFILE_MGR" ]; then
      "$PROFILE_MGR" sync >/dev/null 2>&1 || true
      PS="$("$PROFILE_MGR" state 2>/dev/null || echo CALIBRATION)"
      CUR="$(cat "$MODEFILE" 2>/dev/null)"
      if [ "$CUR" = LEARN ] && [ "$PS" = PENDING_APPROVAL ]; then
        echo SHADOW > "$MODEFILE"
        echo "$(date) PROFILE_READY -> SHADOW" >> "$LOG"
        kill -TERM "$C" 2>/dev/null || true
        break
      fi
      if [ "$PS" = PROBATION_PASSED ]; then write_safe_state; fi
    fi
  done
  rm -f "$ARMFILE" "$FILTERFILE" "$WATCHFILE" 2>/dev/null || true
  wait "$C"; RC=$?
  rm -f "$CHILDPID"
  echo "$(date) CHILD_EXIT rc=$RC safety_lockdown retry_in=4s" >> "$LOG"
  [ -f "$RUNFLAG" ] || break
  sleep 4
done
rm -f "$CHILDPID" "$ARMFILE" "$FILTERFILE" "$WATCHFILE" 2>/dev/null || true
write_safe_state
echo "$(date) SUPERVISOR_EXIT safety_lockdown=1" >> "$LOG"
