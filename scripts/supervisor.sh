#!/bin/sh
# GhostGuard Kobo v0.8.7.1 Emergency Shadow Rollback supervisor.
# Hard safety rule: this release NEVER launches native PROTECT and never creates PROTECT_ARMED.
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
      *touch*|*cyttsp*|*zforce*|*elan*|*goodix*|*focal*|*fts*|*mtk*tpd*|*multitouch*) E="$(basename "$P")"; [ -r "/dev/input/$E" ]&&{ echo "/dev/input/$E";return;};;
    esac
  done
}
write_safe_state(){
  printf 'STATE=SHADOW_ROLLBACK\nPROTECT_ACTIVE=0\nFILTER_ACTIVE=0\nEVIOCGRAB=OFF\nFAIL_OPEN=1\n' > "$PST" 2>/dev/null || true
  printf 'STATE=DISABLED\nREASON=V0_8_7_REAL_DEVICE_EVIOCGRAB_REGRESSION\nFAIL_OPEN=1\n' > "$HST" 2>/dev/null || true
}
clear_protect_gates(){ rm -f "$ARMFILE" "$FILTERFILE" "$WATCHFILE" 2>/dev/null || true; }
force_shadow_mode(){
  M="$1"
  case "$M" in
    LEARN) echo LEARN ;;
    SHADOW|'') echo SHADOW ;;
    *)
      echo SHADOW > "$MODEFILE"
      clear_protect_gates
      write_safe_state
      echo "$(date) SAFETY_ROLLBACK requested=$M forced=SHADOW" >> "$LOG"
      echo SHADOW
      ;;
  esac
}
fail_open_exit(){
  clear_protect_gates
  [ -f "$CHILDPID" ] && { C="$(cat "$CHILDPID" 2>/dev/null)"; [ -n "$C" ]&&kill -TERM "$C" 2>/dev/null||true; }
  write_safe_state
  exit 0
}
trap fail_open_exit HUP INT TERM

clear_protect_gates
write_safe_state

while [ -f "$RUNFLAG" ]; do
  [ -f "$BASE/SAFE_MODE" ] && break
  ARCH="$(arch_name)"; BIN="$BASE/bin/ghostguardd-$ARCH"
  [ -x "$BIN" ] || { echo "$(date) NO_BINARY arch=$ARCH" >> "$LOG"; break; }
  INPUT="$(find_touch)"
  [ -n "$INPUT" ] || { echo "$(date) WAIT_TOUCH" >> "$LOG"; sleep 4; continue; }
  echo "$INPUT" > "$INPUTFILE"
  REQUESTED="$(cat "$MODEFILE" 2>/dev/null)"; MODE="$(force_shadow_mode "$REQUESTED")"
  clear_protect_gates
  echo "$(date) START mode=$MODE requested=$REQUESTED input=$INPUT arch=$ARCH" >> "$LOG"
  "$BIN" >> "$LOG" 2>&1 & C=$!; echo "$C" > "$CHILDPID"
  [ "$MODE" = SHADOW ] && [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" session-start >/dev/null 2>&1 || true

  while kill -0 "$C" 2>/dev/null; do
    sleep 5
    [ -f "$RUNFLAG" ] || break
    CUR="$(cat "$MODEFILE" 2>/dev/null)"
    if [ "$CUR" = PROTECT ]; then
      echo SHADOW > "$MODEFILE"; clear_protect_gates; write_safe_state
      echo "$(date) SAFETY_ROLLBACK live PROTECT request -> SHADOW restart" >> "$LOG"
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
      if [ "$CUR" = SHADOW ] && [ "$PS" = PROBATION_PASSED ]; then
        write_safe_state
        echo "$(date) PROBATION_PASSED -> SHADOW retained by v0.8.7.1 rollback" >> "$LOG"
      fi
    fi
  done

  clear_protect_gates
  wait "$C"; RC=$?; rm -f "$CHILDPID"
  echo "$(date) CHILD_EXIT rc=$RC fail-open retry_in=4s" >> "$LOG"
  [ -f "$RUNFLAG" ] || break
  sleep 4
done

rm -f "$CHILDPID" 2>/dev/null || true
clear_protect_gates
write_safe_state
echo "$(date) SUPERVISOR_EXIT" >> "$LOG"
