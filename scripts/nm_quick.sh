#!/bin/sh
# DCPRO GhostGuard Kobo v0.8.3 fast Status. No network I/O.
set -u
BASE=/mnt/onboard/.adds/ghostguard; DATA="$BASE/data"; RUN="$BASE/runtime"; DEFAULTS="$BASE/defaults.conf"
PV5="$DATA/profile_v5.txt"; PV5S="$DATA/profile_v5.ggstate"; LIC="$DATA/LICENSE_STATUS.txt"; LICS="$DATA/LICENSE_STATUS.ggstate"
CSV="$DATA/contacts.csv"; PIDFILE="$RUN/supervisor.pid"; MODEFILE="$RUN/mode"; PST="$DATA/PROTECT_STATUS.ggstate"; BLOCK="$DATA/blocked.gglog"; PM="$BASE/profile_manager.sh"
mkdir -p "$DATA" "$RUN" 2>/dev/null||true
clean_serial(){ [ -f /mnt/onboard/.kobo/version ]&&sed -n '1{s/,.*//;p;}' /mnt/onboard/.kobo/version 2>/dev/null|tr '[:lower:]' '[:upper:]'|tr -cd 'A-Z0-9'; }
is_running(){ [ -f "$PIDFILE" ]||return 1; P="$(cat "$PIDFILE" 2>/dev/null)";[ -n "$P" ]&&kill -0 "$P" 2>/dev/null; }
pfile(){ [ -s "$PV5" ]&&echo "$PV5"||echo "$PV5S"; }; lfile(){ [ -s "$LIC" ]&&echo "$LIC"||echo "$LICS"; }
kv(){ F="$1";K="$2";[ -r "$F" ]&&sed -n "s/^${K}=//p" "$F" 2>/dev/null|head -n1; }; v5(){ kv "$(pfile)" "$1"; }; cfg(){ V="$(kv "$DEFAULTS" "$1")";[ -n "$V" ]&&echo "$V"||echo "$2"; }
num(){ case "${1:-}" in ''|*[!0-9]*) echo 0;;*)echo "$1";;esac; }; pct(){ N="$(num "$1")";D="$(num "$2")";[ "$D" -gt 0 ]&&{ X=$((N*100/D));[ "$X" -gt 100 ]&&X=100;echo "$X";}||echo 0; }
# contacts|baseline|incomplete|watch|suspect|candidate|last_risk|last_class|last_action
live(){ [ -s "$CSV" ]||{ echo '0|0|0|0|0|0|0|-|-';return;}; awk -F, 'NR==1{next}NF>=13{n++;r=$8+0;c=$11;a=$12;d=$5+0;if(c=="INCOMPLETE")inc++;else{if(c=="WATCH")w++;if(c=="SUSPECT")s++;if(a=="WOULD_DROP")cand++;if($3!=""&&$4!=""&&$3!="-1"&&$4!="-1"&&d>=8000&&r<35)b++}lr=r;lc=c;la=a}END{printf "%d|%d|%d|%d|%d|%d|%d|%s|%s\n",n+0,b+0,inc+0,w+0,s+0,cand+0,lr+0,lc?lc:"-",la?la:"-"}' "$CSV" 2>/dev/null||echo '0|0|0|0|0|0|0|-|-'; }
license_summary(){ F="$(lfile)";FIRST="$(head -n1 "$F" 2>/dev/null)";case "$FIRST" in OK\|*)echo Active;;DENY\|*)echo "Denied - ${FIRST#DENY|}"|cut -d';' -f1;;*)echo 'Not synced';;esac; }
friendly(){ case "$1" in CALIBRATION|'')echo 'Đang học';;PENDING_APPROVAL)echo 'Đã đủ dữ liệu - chờ kích hoạt';;PROBATION)echo 'Đang kiểm tra Profile';;PROBATION_PASSED)echo 'Đã sẵn sàng bảo vệ';;*)echo "$1";;esac; }
protect_state(){ [ -r "$PST" ]&&{ S="$(kv "$PST" STATE)";[ -n "$S" ]&&echo "$S"&&return;};echo OFF; }
blocked(){ [ -s "$BLOCK" ]&&wc -l < "$BLOCK"|tr -d ' '||echo 0; }
show_status(){
  [ -x "$PM" ]&&"$PM" sync >/dev/null 2>&1||true
  if is_running;then ENG=RUNNING;MODE="$(cat "$MODEFILE" 2>/dev/null)";[ -n "$MODE" ]||MODE=-;else ENG=STOPPED;MODE=-;fi
  PS="$(v5 STATE)";[ -n "$PS" ]||PS=CALIBRATION; PC="$(num "$(v5 PROBATION_COMPLETED)")";PN="$(num "$(v5 PROBATION_REQUIRED)")";[ "$PN" -gt 0 ]||PN=2
  OLD="$IFS";IFS='|';set -- $(live);IFS="$OLD"; C="$(num "${1:-0}")";B="$(num "${2:-0}")";I="$(num "${3:-0}")";W="$(num "${4:-0}")";SUS="$(num "${5:-0}")";CAN="$(num "${6:-0}")";LR="$(num "${7:-0}")";LC="${8:--}";LA="${9:--}"
  NC="$(num "$(cfg PROFILE_READY_CONTACTS_MIN 80)")";NB="$(num "$(cfg PROFILE_READY_BASELINE_MIN 60)")";MI="$(num "$(cfg PROFILE_READY_MAX_INCOMPLETE_PCT 25)")";CP="$(pct "$C" "$NC")";BP="$(pct "$B" "$NB")";P="$CP";[ "$BP" -lt "$P" ]&&P="$BP";IP=0;[ "$C" -gt 0 ]&&IP=$((I*100/C))
  echo 'GhostGuard Kobo 0.8.3 Protect Beta';echo "Engine: $ENG | Auto mode: $MODE";echo "License: $(license_summary)";echo "Profile: $(friendly "$PS")"
  case "$PS" in CALIBRATION|'') echo "Learning: ${P}%";echo "Touches: $C/$NC | Baseline: $B/$NB";echo "Data quality: incomplete ${IP}% (max ${MI}%)";;PENDING_APPROVAL) echo 'Learning: 100% - đủ dữ liệu';echo "Touches: $C/$NC | Baseline: $B/$NB";;PROBATION) echo "Probation: $PC/$PN sessions";;PROBATION_PASSED) echo "Probation: Passed ($PN/$PN)";;esac
  if [ "$W" -gt 0 ]||[ "$SUS" -gt 0 ]||[ "$CAN" -gt 0 ];then echo "Ghost telemetry: Watch $W | Suspect $SUS | Candidate $CAN";fi
  [ "$C" -gt 0 ]&&echo "Last touch: risk $LR | $LC / $LA"
  PSTAT="$(protect_state)"; BL="$(blocked)"
  if [ "$ENG" = RUNNING ]&&[ "$MODE" = PROTECT ]&&[ "$PSTAT" = ACTIVE ];then echo "Protect: ON | Blocked: $BL | Quarantine: 10ms";else case "$PSTAT" in UINPUT_UNAVAILABLE|UINPUT_CREATE_FAILED|UINPUT_CONFIG_WRITE_FAILED|EVIOCGRAB_FAILED|NICKEL_VIRTUAL_NOT_OPEN|SYN_DROPPED_FAIL_OPEN|UINPUT_WRITE_FAILED_FAIL_OPEN|INPUT_READ_FAILED_FAIL_OPEN) echo "Protect: OFF (fail-open) | $PSTAT";;VIRTUAL_READY_WAITING_FOR_NICKEL)echo 'Protect: PREPARING | waiting Nickel virtual touch';;*) echo 'Protect: OFF';;esac;fi
  echo 'Fail-open: ON'
  case "$PS" in CALIBRATION|'')echo 'Next: tiếp tục dùng máy bình thường.';;PENDING_APPROVAL)echo 'Next: GhostGuard - Activate Profile';;PROBATION)echo 'Next: Start/Stop đủ 2 phiên Probation.';;PROBATION_PASSED) [ "$PSTAT" = ACTIVE ]&&echo 'Next: GhostGuard đang bảo vệ.'||echo 'Next: GhostGuard - Start để bật Protect.';;esac
}
case "${1:-status}" in status)show_status;;license)echo "DEVICE_ID=$(clean_serial)";cat "$(lfile)" 2>/dev/null||echo NOT_SYNCED;;device-id)echo "DEVICE_ID=$(clean_serial)";;cleanup)echo done;;*)echo "Usage: $0 status";exit 1;;esac
