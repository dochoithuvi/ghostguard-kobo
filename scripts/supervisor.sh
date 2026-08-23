#!/bin/sh
# GhostGuard Kobo v0.8.3.2 supervisor.
# Protect is armed only after Nickel has opened the GhostGuard uinput device.
# If Nickel does not hotplug the virtual input, attempt one controlled rebind;
# physical EVIOCGRAB is still forbidden until the new Nickel process owns it.
set -u
BASE=/mnt/onboard/.adds/ghostguard; RUN="$BASE/runtime"; DATA="$BASE/data"; LOG="$DATA/native.log"
RUNFLAG="$RUN/RUN"; MODEFILE="$RUN/mode"; INPUTFILE="$RUN/input_device"; CHILDPID="$RUN/daemon.pid"; ARMFILE="$RUN/PROTECT_ARMED"; REBINDFILE="$RUN/nickel_rebind_once"
PROFILE_MGR="$BASE/profile_manager.sh"; PST="$DATA/PROTECT_STATUS.ggstate"; VNAME='DCPRO GhostGuard Virtual Touch'
mkdir -p "$RUN" "$DATA" 2>/dev/null || true
arch_name(){ case "$(uname -m 2>/dev/null)" in aarch64|arm64) echo aarch64;; arm*) echo armv7;; *) echo unknown;; esac; }
find_touch(){ if [ -r "$INPUTFILE" ]; then D="$(head -n1 "$INPUTFILE"|tr -d '\r\n')"; [ -n "$D" ]&&[ -r "$D" ]&&{ echo "$D";return;};fi; for P in /sys/class/input/event*;do [ -e "$P" ]||continue;N="$(cat "$P/device/name" 2>/dev/null|tr '[:upper:]' '[:lower:]')";case "$N" in *ghostguard*virtual*) continue;; *touch*|*cyttsp*|*zforce*|*elan*|*goodix*|*focal*|*fts*|*mtk*tpd*) E="$(basename "$P")";[ -r "/dev/input/$E" ]&&{ echo "/dev/input/$E";return;};;esac;done; }
find_virtual(){ for P in /sys/class/input/event*;do [ -e "$P" ]||continue;[ "$(cat "$P/device/name" 2>/dev/null)" = "$VNAME" ]&&{ echo "/dev/input/$(basename "$P")";return 0;};done;return 1; }
nickel_pid(){ P="$(pidof nickel 2>/dev/null|awk '{print $1}')"; [ -n "$P" ]&&{ echo "$P";return;}; ps 2>/dev/null|awk '/[ \/]nickel([ ]|$)/&&!/awk/{print $1;exit}'; }
nickel_has_fd(){ DEV="$1"; NP="$(nickel_pid)"; [ -n "$NP" ]||return 1; for F in /proc/$NP/fd/*;do [ -e "$F" ]||continue; T="$(readlink "$F" 2>/dev/null)"; [ "$T" = "$DEV" ]&&return 0;done;return 1; }
write_pstate(){ printf 'STATE=%s\nPROTECT_ACTIVE=0\nFAIL_OPEN=1\n' "$1" > "$PST"; }
poke_input_hotplug(){ V="$1"; E="$(basename "$V" 2>/dev/null)"; if command -v udevadm >/dev/null 2>&1; then udevadm trigger --action=add --subsystem-match=input --sysname-match="$E" >/dev/null 2>&1 || udevadm trigger --subsystem-match=input >/dev/null 2>&1 || true; fi; command -v mdev >/dev/null 2>&1 && mdev -s >/dev/null 2>&1 || true; }
wait_nickel_open(){ V="$1"; LIM="$2"; W=0; while [ "$W" -lt "$LIM" ] && [ -f "$RUNFLAG" ];do [ -e "$V" ]&&poke_input_hotplug "$V"; nickel_has_fd "$V"&&return 0; sleep 1; W=$((W+1)); done; return 1; }
restart_nickel_once(){ V="$1"; [ -f "$REBINDFILE" ]&&return 1; echo 1 > "$REBINDFILE"; NP="$(nickel_pid)"; [ -n "$NP" ]||return 1; write_pstate NICKEL_REBINDING; echo "$(date) NICKEL_REBIND begin old_pid=$NP virtual=$V" >> "$LOG"; kill -TERM "$NP" 2>/dev/null || return 1; W=0; while [ "$W" -lt 5 ]&&kill -0 "$NP" 2>/dev/null;do sleep 1;W=$((W+1));done
 if [ -x /etc/init.d/z-nickel-hardware-status ] && [ -x /etc/rc.local ]; then
   ( unset LD_LIBRARY_PATH; /etc/init.d/z-nickel-hardware-status >/dev/null 2>&1; sync; /etc/rc.local >/dev/null 2>&1 ) &
 elif [ -x /usr/local/Kobo/nickel ]; then
   ( export LD_LIBRARY_PATH=/usr/local/Kobo; [ -x /usr/local/Kobo/hindenburg ]&&/usr/local/Kobo/hindenburg >/dev/null 2>&1 & LIBC_FATAL_STDERR_=1 /usr/local/Kobo/nickel -platform kobo -skipFontLoad >/dev/null 2>&1 & command -v udevadm >/dev/null 2>&1&&udevadm trigger >/dev/null 2>&1 & ) &
 else
   echo "$(date) NICKEL_REBIND no restart path; fail-open" >> "$LOG"; return 1
 fi
 W=0; NEW=""; while [ "$W" -lt 15 ]&&[ -f "$RUNFLAG" ];do NEW="$(nickel_pid)"; [ -n "$NEW" ]&&[ "$NEW" != "$NP" ]&&break; sleep 1;W=$((W+1));done; [ -n "$NEW" ]||{ echo "$(date) NICKEL_REBIND no new nickel pid; fail-open" >> "$LOG"; return 1; }; echo "$(date) NICKEL_REBIND new_pid=$NEW" >> "$LOG"; poke_input_hotplug "$V"; return 0; }
arm_now(){ V="$1"; echo 1 > "$ARMFILE"; echo "$(date) PROTECT_ARMED virtual=$V nickel=$(nickel_pid)" >> "$LOG"; return 0; }
arm_protect(){ rm -f "$ARMFILE"; WAIT=0; V=""; while [ "$WAIT" -lt 8 ] && [ -f "$RUNFLAG" ];do V="$(find_virtual 2>/dev/null||true)"; if [ -n "$V" ]&&[ -e "$V" ];then poke_input_hotplug "$V"; nickel_has_fd "$V"&&{ arm_now "$V";return 0; };fi; sleep 1; WAIT=$((WAIT+1));done
 [ -n "$V" ]&&[ -e "$V" ]||{ echo "$(date) PROTECT_NOT_ARMED virtual event missing; fail-open" >> "$LOG"; write_pstate VIRTUAL_EVENT_NOT_FOUND; return 1; }
 if restart_nickel_once "$V"; then write_pstate VIRTUAL_READY_WAITING_FOR_NICKEL; if wait_nickel_open "$V" 15; then arm_now "$V"; return 0; fi; fi
 echo "$(date) PROTECT_NOT_ARMED virtual=$V; Nickel did not open virtual input after hotplug/rebind; fail-open" >> "$LOG"; write_pstate NICKEL_VIRTUAL_NOT_OPEN; return 1; }
while [ -f "$RUNFLAG" ];do
 [ -f "$BASE/SAFE_MODE" ]&&break; ARCH="$(arch_name)"; BIN="$BASE/bin/ghostguardd-$ARCH"; [ -x "$BIN" ]||{ echo "$(date) NO_BINARY arch=$ARCH">>"$LOG";break;}; INPUT="$(find_touch)"; [ -n "$INPUT" ]||{ echo "$(date) WAIT_TOUCH">>"$LOG";sleep 4;continue;}; echo "$INPUT">"$INPUTFILE"; MODE="$(cat "$MODEFILE" 2>/dev/null)"; rm -f "$ARMFILE"; echo "$(date) START mode=$MODE input=$INPUT arch=$ARCH">>"$LOG"; "$BIN" >>"$LOG" 2>&1 & C=$!; echo "$C">"$CHILDPID"
 [ "$MODE" = SHADOW ] && [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" session-start >/dev/null 2>&1 || true
 AP=""; if [ "$MODE" = PROTECT ]; then arm_protect & AP=$!; fi
 while kill -0 "$C" 2>/dev/null;do sleep 5;[ -f "$RUNFLAG" ]||break; if [ -x "$PROFILE_MGR" ];then "$PROFILE_MGR" sync >/dev/null 2>&1||true; PS="$("$PROFILE_MGR" state 2>/dev/null||echo CALIBRATION)"; CUR="$(cat "$MODEFILE" 2>/dev/null)"; if [ "$CUR" = LEARN ]&&[ "$PS" = PENDING_APPROVAL ];then echo SHADOW>"$MODEFILE";echo "$(date) PROFILE_READY -> SHADOW">>"$LOG";kill "$C" 2>/dev/null||true;break;fi; if [ "$CUR" = SHADOW ]&&[ "$PS" = PROBATION_PASSED ];then echo PROTECT>"$MODEFILE";echo "$(date) PROBATION_PASSED -> PROTECT restart">>"$LOG";kill "$C" 2>/dev/null||true;break;fi;fi;done
 [ -n "$AP" ]&&kill "$AP" 2>/dev/null||true; rm -f "$ARMFILE"; wait "$C"; RC=$?; rm -f "$CHILDPID"; echo "$(date) CHILD_EXIT rc=$RC fail-open retry_in=4s">>"$LOG"; [ -f "$RUNFLAG" ]||break;sleep 4
done
rm -f "$CHILDPID" "$ARMFILE"; echo "$(date) SUPERVISOR_EXIT">>"$LOG"
