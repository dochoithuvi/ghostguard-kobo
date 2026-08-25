#!/bin/sh
# GhostGuard Kobo v0.8.7 Safety Handshake supervisor.
# Protect may grab physical input only after Nickel owns the virtual touchscreen.
# After grab, classifier blocking stays OFF until a post-grab proxy frame succeeds.
# A deadman watchdog removes the filter gate and kills the daemon on any consumer/proxy fault.
set -u
BASE=/mnt/onboard/.adds/ghostguard; RUN="$BASE/runtime"; DATA="$BASE/data"; LOG="$DATA/native.log"
RUNFLAG="$RUN/RUN"; MODEFILE="$RUN/mode"; INPUTFILE="$RUN/input_device"; CHILDPID="$RUN/daemon.pid"
ARMFILE="$RUN/PROTECT_ARMED"; FILTERFILE="$RUN/PROTECT_FILTER_ARMED"; WATCHFILE="$RUN/PROTECT_WATCHDOG"; REBINDFILE="$RUN/nickel_rebind_once"
PROFILE_MGR="$BASE/profile_manager.sh"; PST="$DATA/PROTECT_STATUS.ggstate"; PROXYST="$DATA/PROXY_STATUS.ggstate"; HST="$DATA/HANDSHAKE_STATUS.ggstate"; VNAME='DCPRO GhostGuard Virtual Touch'
mkdir -p "$RUN" "$DATA" 2>/dev/null || true

arch_name(){ case "$(uname -m 2>/dev/null)" in aarch64|arm64) echo aarch64;; arm*) echo armv7;; *) echo unknown;; esac; }
find_touch(){ if [ -r "$INPUTFILE" ]; then D="$(head -n1 "$INPUTFILE"|tr -d '\r\n')"; [ -n "$D" ]&&[ -r "$D" ]&&{ echo "$D";return;};fi; for P in /sys/class/input/event*;do [ -e "$P" ]||continue;N="$(cat "$P/device/name" 2>/dev/null|tr '[:upper:]' '[:lower:]')";case "$N" in *ghostguard*virtual*) continue;; *touch*|*cyttsp*|*zforce*|*elan*|*goodix*|*focal*|*fts*|*mtk*tpd*) E="$(basename "$P")";[ -r "/dev/input/$E" ]&&{ echo "/dev/input/$E";return;};;esac;done; }
find_virtual(){ for P in /sys/class/input/event*;do [ -e "$P" ]||continue;[ "$(cat "$P/device/name" 2>/dev/null)" = "$VNAME" ]&&{ echo "/dev/input/$(basename "$P")";return 0;};done;return 1; }
nickel_pid(){ P="$(pidof nickel 2>/dev/null|awk '{print $1}')"; [ -n "$P" ]&&{ echo "$P";return;}; ps 2>/dev/null|awk '/[ \/]nickel([ ]|$)/&&!/awk/{print $1;exit}'; }
nickel_has_fd(){ DEV="$1"; NP="$(nickel_pid)"; [ -n "$NP" ]||return 1; for F in /proc/$NP/fd/*;do [ -e "$F" ]||continue; T="$(readlink "$F" 2>/dev/null)"; [ "$T" = "$DEV" ]&&return 0;done;return 1; }
kv(){ F="$1"; K="$2"; [ -r "$F" ]&&sed -n "s/^${K}=//p" "$F" 2>/dev/null|head -n1; }
write_pstate(){ S="$1"; A="${2:-0}"; F="${3:-0}"; printf 'STATE=%s\nPROTECT_ACTIVE=%s\nFILTER_ACTIVE=%s\nFAIL_OPEN=1\n' "$S" "$A" "$F" > "$PST"; }
write_hstate(){ S="$1"; R="${2:-}"; { echo "STATE=$S"; [ -n "$R" ]&&echo "REASON=$R"; echo 'FAIL_OPEN=1'; } > "$HST"; }
poke_input_hotplug(){ V="$1"; E="$(basename "$V" 2>/dev/null)"; if command -v udevadm >/dev/null 2>&1; then udevadm trigger --action=add --subsystem-match=input --sysname-match="$E" >/dev/null 2>&1 || udevadm trigger --subsystem-match=input >/dev/null 2>&1 || true; fi; command -v mdev >/dev/null 2>&1 && mdev -s >/dev/null 2>&1 || true; }
wait_nickel_open(){ V="$1"; LIM="$2"; W=0; while [ "$W" -lt "$LIM" ] && [ -f "$RUNFLAG" ];do [ -e "$V" ]&&poke_input_hotplug "$V"; nickel_has_fd "$V"&&return 0; sleep 1; W=$((W+1)); done; return 1; }

restart_nickel_once(){ V="$1"; [ -f "$REBINDFILE" ]&&return 1; echo 1 > "$REBINDFILE"; NP="$(nickel_pid)"; [ -n "$NP" ]||return 1; write_pstate NICKEL_REBINDING 0 0; write_hstate PRECHECK NICKEL_REBINDING; echo "$(date) NICKEL_REBIND begin old_pid=$NP virtual=$V" >> "$LOG"; kill -TERM "$NP" 2>/dev/null || return 1; W=0; while [ "$W" -lt 5 ]&&kill -0 "$NP" 2>/dev/null;do sleep 1;W=$((W+1));done
 if [ -x /etc/init.d/z-nickel-hardware-status ] && [ -x /etc/rc.local ]; then
   ( unset LD_LIBRARY_PATH; /etc/init.d/z-nickel-hardware-status >/dev/null 2>&1; sync; /etc/rc.local >/dev/null 2>&1 ) &
 elif [ -x /usr/local/Kobo/nickel ]; then
   ( export LD_LIBRARY_PATH=/usr/local/Kobo; [ -x /usr/local/Kobo/hindenburg ]&&/usr/local/Kobo/hindenburg >/dev/null 2>&1 & LIBC_FATAL_STDERR_=1 /usr/local/Kobo/nickel -platform kobo -skipFontLoad >/dev/null 2>&1 & command -v udevadm >/dev/null 2>&1&&udevadm trigger >/dev/null 2>&1 & ) &
 else
   echo "$(date) NICKEL_REBIND no restart path; fail-open" >> "$LOG"; return 1
 fi
 W=0; NEW=""; while [ "$W" -lt 15 ]&&[ -f "$RUNFLAG" ];do NEW="$(nickel_pid)"; [ -n "$NEW" ]&&[ "$NEW" != "$NP" ]&&break; sleep 1;W=$((W+1));done; [ -n "$NEW" ]||{ echo "$(date) NICKEL_REBIND no new nickel pid; fail-open" >> "$LOG"; return 1; }; echo "$(date) NICKEL_REBIND new_pid=$NEW" >> "$LOG"; poke_input_hotplug "$V"; return 0; }

arm_now(){ V="$1"; rm -f "$FILTERFILE" "$WATCHFILE" "$PROXYST" 2>/dev/null || true; write_hstate PRECHECK WAIT_POST_GRAB_FORWARD; echo 1 > "$ARMFILE"; echo "$(date) PROTECT_ARM_REQUEST virtual=$V nickel=$(nickel_pid)" >> "$LOG"; return 0; }
arm_protect(){ rm -f "$ARMFILE" "$FILTERFILE" "$WATCHFILE"; WAIT=0; V=""; while [ "$WAIT" -lt 8 ] && [ -f "$RUNFLAG" ];do V="$(find_virtual 2>/dev/null||true)"; if [ -n "$V" ]&&[ -e "$V" ];then poke_input_hotplug "$V"; nickel_has_fd "$V"&&{ arm_now "$V"; echo "$V"; return 0; };fi; sleep 1; WAIT=$((WAIT+1));done
 [ -n "$V" ]&&[ -e "$V" ]||{ echo "$(date) PROTECT_NOT_ARMED virtual event missing; fail-open" >> "$LOG"; write_pstate VIRTUAL_EVENT_NOT_FOUND 0 0; write_hstate FAIL VIRTUAL_EVENT_NOT_FOUND; return 1; }
 if restart_nickel_once "$V"; then write_pstate VIRTUAL_READY_WAITING_FOR_NICKEL 0 0; if wait_nickel_open "$V" 15; then arm_now "$V"; echo "$V"; return 0; fi; fi
 echo "$(date) PROTECT_NOT_ARMED virtual=$V; Nickel did not open virtual input after hotplug/rebind; fail-open" >> "$LOG"; write_pstate NICKEL_VIRTUAL_NOT_OPEN 0 0; write_hstate FAIL NICKEL_VIRTUAL_NOT_OPEN; return 1; }

fail_open_child(){ C="$1"; WHY="$2"; rm -f "$FILTERFILE" "$ARMFILE" "$WATCHFILE" 2>/dev/null || true; write_hstate FAIL "$WHY"; write_pstate SAFETY_FAIL_OPEN 0 0; echo SHADOW > "$MODEFILE"; echo "$(date) SAFETY_FAIL_OPEN reason=$WHY child=$C" >> "$LOG"; kill -TERM "$C" 2>/dev/null || true; ( sleep 1; kill -KILL "$C" 2>/dev/null || true ) >/dev/null 2>&1 & }

wait_proxy_preflight(){ C="$1"; V="$2"; W=0; while [ "$W" -lt 10 ] && [ -f "$RUNFLAG" ] && kill -0 "$C" 2>/dev/null; do
  nickel_has_fd "$V" || { fail_open_child "$C" NICKEL_FD_LOST_PRECHECK; return 1; }
  PS="$(kv "$PST" STATE)"; PF="$(kv "$PROXYST" FORWARDED_FRAMES)"; case "$PF" in ''|*[!0-9]*) PF=0;; esac
  case "$PS" in UINPUT_*|EVIOCGRAB_FAILED|SYN_DROPPED_FAIL_OPEN|UINPUT_WRITE_FAILED_FAIL_OPEN|FILTER_DISARMED_FAIL_OPEN|INPUT_READ_FAILED_FAIL_OPEN) fail_open_child "$C" "$PS"; return 1;; esac
  if [ "$PS" = ACTIVE_PRECHECK ] && [ "$PF" -ge 1 ]; then
    # Keep one full second of forwarding-only grace after the post-grab canary.
    sleep 1
    kill -0 "$C" 2>/dev/null || return 1
    nickel_has_fd "$V" || { fail_open_child "$C" NICKEL_FD_LOST_GRACE; return 1; }
    printf 'SEQ=1\n' > "$WATCHFILE"
    echo 1 > "$FILTERFILE"
    write_hstate PASS PROXY_FORWARD_OK
    echo "$(date) SAFETY_HANDSHAKE_PASS virtual=$V forwarded_frames=$PF filter=armed" >> "$LOG"
    return 0
  fi
  sleep 1; W=$((W+1))
 done
 fail_open_child "$C" PRECHECK_TIMEOUT_NO_POST_GRAB_FORWARD; return 1; }

deadman_watch(){ C="$1"; V="$2"; SEQ=1; while [ -f "$RUNFLAG" ] && kill -0 "$C" 2>/dev/null; do
  CUR="$(cat "$MODEFILE" 2>/dev/null)"; [ "$CUR" = PROTECT ] || return 0
  [ -e "$V" ] || { fail_open_child "$C" VIRTUAL_DEVICE_LOST; return 1; }
  nickel_has_fd "$V" || { fail_open_child "$C" NICKEL_FD_LOST; return 1; }
  PS="$(kv "$PST" STATE)"; case "$PS" in UINPUT_*|EVIOCGRAB_FAILED|SYN_DROPPED_FAIL_OPEN|UINPUT_WRITE_FAILED_FAIL_OPEN|FILTER_DISARMED_FAIL_OPEN|INPUT_READ_FAILED_FAIL_OPEN|SAFETY_FAIL_OPEN) fail_open_child "$C" "$PS"; return 1;; esac
  [ -f "$FILTERFILE" ] || { fail_open_child "$C" FILTER_GATE_MISSING; return 1; }
  SEQ=$((SEQ+1)); printf 'SEQ=%s\n' "$SEQ" > "$WATCHFILE"
  sleep 1
 done
 return 0; }

protect_controller(){ C="$1"; V="$(arm_protect 2>/dev/null)" || { [ -f "$RUNFLAG" ]&&fail_open_child "$C" ARM_PRECHECK_FAILED; return 1; }; [ -n "$V" ] || { fail_open_child "$C" VIRTUAL_PATH_EMPTY; return 1; }; wait_proxy_preflight "$C" "$V" || return 1; deadman_watch "$C" "$V"; }

signal_fail_open(){ rm -f "$FILTERFILE" "$ARMFILE" "$WATCHFILE" 2>/dev/null || true; if [ -f "$CHILDPID" ]; then C="$(cat "$CHILDPID" 2>/dev/null)"; [ -n "$C" ]&&kill -TERM "$C" 2>/dev/null||true; fi; write_hstate FAIL SUPERVISOR_SIGNAL; write_pstate SAFETY_FAIL_OPEN 0 0; exit 0; }
trap signal_fail_open HUP INT TERM

while [ -f "$RUNFLAG" ];do
 [ -f "$BASE/SAFE_MODE" ]&&break; ARCH="$(arch_name)"; BIN="$BASE/bin/ghostguardd-$ARCH"; [ -x "$BIN" ]||{ echo "$(date) NO_BINARY arch=$ARCH">>"$LOG";break;}; INPUT="$(find_touch)"; [ -n "$INPUT" ]||{ echo "$(date) WAIT_TOUCH">>"$LOG";sleep 4;continue;}; echo "$INPUT">"$INPUTFILE"; MODE="$(cat "$MODEFILE" 2>/dev/null)"; case "$MODE" in LEARN|SHADOW|PROTECT) ;; *) MODE=SHADOW; echo SHADOW > "$MODEFILE";; esac; rm -f "$ARMFILE" "$FILTERFILE" "$WATCHFILE"; echo "$(date) START mode=$MODE input=$INPUT arch=$ARCH">>"$LOG"; "$BIN" >>"$LOG" 2>&1 & C=$!; echo "$C">"$CHILDPID"
 [ "$MODE" = SHADOW ] && [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" session-start >/dev/null 2>&1 || true
 PC=""; if [ "$MODE" = PROTECT ]; then protect_controller "$C" >/dev/null 2>&1 & PC=$!; fi
 while kill -0 "$C" 2>/dev/null;do sleep 5;[ -f "$RUNFLAG" ]||break; if [ -x "$PROFILE_MGR" ];then "$PROFILE_MGR" sync >/dev/null 2>&1||true; PS="$("$PROFILE_MGR" state 2>/dev/null||echo CALIBRATION)"; CUR="$(cat "$MODEFILE" 2>/dev/null)"; if [ "$CUR" = LEARN ]&&[ "$PS" = PENDING_APPROVAL ];then echo SHADOW>"$MODEFILE";echo "$(date) PROFILE_READY -> SHADOW">>"$LOG";kill "$C" 2>/dev/null||true;break;fi; if [ "$CUR" = SHADOW ]&&[ "$PS" = PROBATION_PASSED ];then echo PROTECT>"$MODEFILE";echo "$(date) PROBATION_PASSED -> PROTECT safety-handshake restart">>"$LOG";kill "$C" 2>/dev/null||true;break;fi;fi;done
 [ -n "$PC" ]&&kill "$PC" 2>/dev/null||true; rm -f "$ARMFILE" "$FILTERFILE" "$WATCHFILE"; wait "$C"; RC=$?; rm -f "$CHILDPID"; echo "$(date) CHILD_EXIT rc=$RC fail-open retry_in=4s">>"$LOG"; [ -f "$RUNFLAG" ]||break;sleep 4
done
rm -f "$CHILDPID" "$ARMFILE" "$FILTERFILE" "$WATCHFILE"; echo "$(date) SUPERVISOR_EXIT">>"$LOG"
