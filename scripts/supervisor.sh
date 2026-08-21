#!/bin/sh
# GhostGuard Kobo v0.8.3 supervisor. Protect is armed only after Nickel has
# opened the GhostGuard uinput device; otherwise the daemon stays ungrabbed.
set -u
BASE=/mnt/onboard/.adds/ghostguard; RUN="$BASE/runtime"; DATA="$BASE/data"; LOG="$DATA/native.log"
RUNFLAG="$RUN/RUN"; MODEFILE="$RUN/mode"; INPUTFILE="$RUN/input_device"; CHILDPID="$RUN/daemon.pid"; ARMFILE="$RUN/PROTECT_ARMED"
PROFILE_MGR="$BASE/profile_manager.sh"; PST="$DATA/PROTECT_STATUS.ggstate"; VNAME='DCPRO GhostGuard Virtual Touch'
mkdir -p "$RUN" "$DATA" 2>/dev/null || true
arch_name(){ case "$(uname -m 2>/dev/null)" in aarch64|arm64) echo aarch64;; arm*) echo armv7;; *) echo unknown;; esac; }
find_touch(){ if [ -r "$INPUTFILE" ]; then D="$(head -n1 "$INPUTFILE"|tr -d '\r\n')"; [ -n "$D" ]&&[ -r "$D" ]&&{ echo "$D";return;};fi; for P in /sys/class/input/event*;do [ -e "$P" ]||continue;N="$(cat "$P/device/name" 2>/dev/null|tr '[:upper:]' '[:lower:]')";case "$N" in *ghostguard*virtual*) continue;; *touch*|*cyttsp*|*zforce*|*elan*|*goodix*|*focal*|*fts*|*mtk*tpd*) E="$(basename "$P")";[ -r "/dev/input/$E" ]&&{ echo "/dev/input/$E";return;};;esac;done; }
find_virtual(){ for P in /sys/class/input/event*;do [ -e "$P" ]||continue;[ "$(cat "$P/device/name" 2>/dev/null)" = "$VNAME" ]&&{ echo "/dev/input/$(basename "$P")";return 0;};done;return 1; }
nickel_pid(){ P="$(pidof nickel 2>/dev/null|awk '{print $1}')"; [ -n "$P" ]&&{ echo "$P";return;}; ps 2>/dev/null|awk '/[ \/]nickel([ ]|$)/&&!/awk/{print $1;exit}'; }
nickel_has_fd(){ DEV="$1"; NP="$(nickel_pid)"; [ -n "$NP" ]||return 1; for F in /proc/$NP/fd/*;do [ -e "$F" ]||continue; T="$(readlink "$F" 2>/dev/null)"; [ "$T" = "$DEV" ]&&return 0;done;return 1; }
arm_protect(){ rm -f "$ARMFILE"; WAIT=0; V=""; while [ "$WAIT" -lt 10 ] && [ -f "$RUNFLAG" ];do command -v mdev >/dev/null 2>&1&&mdev -s >/dev/null 2>&1||true; V="$(find_virtual 2>/dev/null||true)"; if [ -n "$V" ]&&[ -e "$V" ];then if nickel_has_fd "$V";then echo 1 > "$ARMFILE"; echo "$(date) PROTECT_ARMED virtual=$V nickel=$(nickel_pid)" >> "$LOG"; return 0;fi;fi; sleep 1; WAIT=$((WAIT+1));done; echo "$(date) PROTECT_NOT_ARMED virtual=${V:-none}; Nickel did not open virtual input; fail-open" >> "$LOG"; printf 'STATE=NICKEL_VIRTUAL_NOT_OPEN\nPROTECT_ACTIVE=0\nFAIL_OPEN=1\n' > "$PST"; return 1; }
while [ -f "$RUNFLAG" ];do
 [ -f "$BASE/SAFE_MODE" ]&&break; ARCH="$(arch_name)"; BIN="$BASE/bin/ghostguardd-$ARCH"; [ -x "$BIN" ]||{ echo "$(date) NO_BINARY arch=$ARCH">>"$LOG";break;}; INPUT="$(find_touch)"; [ -n "$INPUT" ]||{ echo "$(date) WAIT_TOUCH">>"$LOG";sleep 4;continue;}; echo "$INPUT">"$INPUTFILE"; MODE="$(cat "$MODEFILE" 2>/dev/null)"; rm -f "$ARMFILE"; echo "$(date) START mode=$MODE input=$INPUT arch=$ARCH">>"$LOG"; "$BIN" >>"$LOG" 2>&1 & C=$!; echo "$C">"$CHILDPID"
 [ "$MODE" = SHADOW ] && [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" session-start >/dev/null 2>&1 || true
 AP=""; if [ "$MODE" = PROTECT ]; then arm_protect & AP=$!; fi
 while kill -0 "$C" 2>/dev/null;do sleep 5;[ -f "$RUNFLAG" ]||break; if [ -x "$PROFILE_MGR" ];then "$PROFILE_MGR" sync >/dev/null 2>&1||true; PS="$("$PROFILE_MGR" state 2>/dev/null||echo CALIBRATION)"; CUR="$(cat "$MODEFILE" 2>/dev/null)"; if [ "$CUR" = LEARN ]&&[ "$PS" = PENDING_APPROVAL ];then echo SHADOW>"$MODEFILE";echo "$(date) PROFILE_READY -> SHADOW">>"$LOG";kill "$C" 2>/dev/null||true;break;fi; if [ "$CUR" = SHADOW ]&&[ "$PS" = PROBATION_PASSED ];then echo PROTECT>"$MODEFILE";echo "$(date) PROBATION_PASSED -> PROTECT restart">>"$LOG";kill "$C" 2>/dev/null||true;break;fi;fi;done
 [ -n "$AP" ]&&kill "$AP" 2>/dev/null||true; rm -f "$ARMFILE"; wait "$C"; RC=$?; rm -f "$CHILDPID"; echo "$(date) CHILD_EXIT rc=$RC fail-open retry_in=4s">>"$LOG"; [ -f "$RUNFLAG" ]||break;sleep 4
done
rm -f "$CHILDPID" "$ARMFILE"; echo "$(date) SUPERVISOR_EXIT">>"$LOG"
