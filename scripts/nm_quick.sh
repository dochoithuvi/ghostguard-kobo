#!/bin/sh
# DCPRO GhostGuard Kobo v0.8.7.1 Emergency Shadow Rollback fast Status.
set -u
BASE=/mnt/onboard/.adds/ghostguard; DATA="$BASE/data"; RUN="$BASE/runtime"
PV5="$DATA/profile_v5.ggstate"; LIC="$DATA/LICENSE_STATUS.ggstate"; PIDFILE="$RUN/supervisor.pid"; MODEFILE="$RUN/mode"
BLOCK="$DATA/blocked.gglog"; UPD="$BASE/update.sh"; USTATE="$DATA/UPDATE_STATUS.ggstate"; PM="$BASE/profile_manager.sh"
mkdir -p "$DATA" "$RUN" 2>/dev/null || true
kv(){ F="$1"; K="$2"; [ -r "$F" ]&&sed -n "s/^${K}=//p" "$F" 2>/dev/null|head -n1; }
is_running(){ [ -f "$PIDFILE" ]||return 1; P="$(cat "$PIDFILE" 2>/dev/null)"; [ -n "$P" ]&&kill -0 "$P" 2>/dev/null; }
license_summary(){ F="$LIC"; FIRST="$(head -n1 "$F" 2>/dev/null)"; case "$FIRST" in OK\|*) echo Active;; DENY\|*) echo "Denied - ${FIRST#DENY|}"|cut -d';' -f1;; *) echo 'Not synced';; esac; }
profile_state(){ [ -x "$PM" ]&&"$PM" state 2>/dev/null||echo CALIBRATION; }
blocked_total(){ [ -s "$BLOCK" ]&&wc -l < "$BLOCK"|tr -d ' '||echo 0; }
blocked_burst(){ [ -s "$BLOCK" ]&&awk '/reason=BURST/{n++}END{print n+0}' "$BLOCK" 2>/dev/null||echo 0; }
blocked_episode(){ [ -s "$BLOCK" ]&&awk '/reason=EPISODE/{n++}END{print n+0}' "$BLOCK" 2>/dev/null||echo 0; }
update_summary(){
  [ -r "$USTATE" ] || { echo 'Update: checking...'; return; }
  R="$(kv "$USTATE" RESULT)"; L="$(kv "$USTATE" LATEST)"
  case "$R" in
    AVAILABLE) echo "Update: AVAILABLE -> ${L:-new version}";;
    CURRENT) echo "Update: Up to date (${L:-current})";;
    STAGED) echo "Update: Staged -> ${L:-new version}";;
    DOWNLOAD_FAILED|SHA_MISMATCH|SHA_TOOL_MISSING|STAGE_FAILED|NETWORK_ERROR) echo 'Update: check/download unavailable';;
    *) echo 'Update: checking...';;
  esac
}
show_status(){
  [ -x "$PM" ]&&"$PM" sync >/dev/null 2>&1 &
  [ -x "$UPD" ]&&"$UPD" check-if-stale >/dev/null 2>&1 &
  if is_running; then ENG=RUNNING; MODE="$(cat "$MODEFILE" 2>/dev/null)"; else ENG=STOPPED; MODE=-; fi
  [ "$MODE" = PROTECT ] && MODE=SHADOW
  PS="$(profile_state)"; [ -n "$PS" ] || PS=CALIBRATION
  BL="$(blocked_total)"; BB="$(blocked_burst)"; BE="$(blocked_episode)"; BC=$((BL-BB-BE)); [ "$BC" -lt 0 ]&&BC=0
  echo 'GhostGuard Kobo 0.8.7.1 Emergency Shadow Rollback'
  echo "Engine: $ENG | Mode: $MODE"
  echo "License: $(license_summary)"
  update_summary
  echo "Profile: $PS"
  echo "Protect: DISABLED | Historical blocked: $BL (Classic $BC | Burst $BB | Episode $BE)"
  echo 'EVIOCGRAB: OFF | Safety Handshake: DISABLED'
  echo 'Ghost Episode Guard: MONITOR-ONLY | Ghost Capture: ON'
  echo 'Fail-open: ON'
  case "$PS" in
    CALIBRATION|'') echo 'Next: dùng máy bình thường để tiếp tục học.';;
    PENDING_APPROVAL) echo 'Next: GhostGuard - Start để tự kích hoạt Profile và chạy Shadow.';;
    PROBATION) echo 'Next: tiếp tục Start/Stop đủ phiên Probation; Protect vẫn khóa an toàn.';;
    PROBATION_PASSED) echo 'Next: Start chỉ chạy Shadow + Ghost Capture trong v0.8.7.1.';;
    *) echo 'Next: Start chỉ chạy Shadow + Ghost Capture.';;
  esac
}
case "${1:-status}" in status) show_status;; cleanup) echo done;; *) echo "Usage: $0 status"; exit 1;; esac
