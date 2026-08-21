#!/bin/sh
# DCPRO GhostGuard Kobo v0.8.3 Protect Beta
# Auto Learn -> approval -> probation -> fail-open Protect.
set -u
BASE=/mnt/onboard/.adds/ghostguard
BIN_DIR="$BASE/bin"; DATA="$BASE/data"; RUN="$BASE/runtime"
PIDFILE="$RUN/supervisor.pid"; CHILDPID="$RUN/daemon.pid"; RUNFLAG="$RUN/RUN"
MODEFILE="$RUN/mode"; INPUTFILE="$RUN/input_device"; ARMFILE="$RUN/PROTECT_ARMED"
SAFE="$BASE/SAFE_MODE"; LICENSE_STATE="$DATA/license_last_date"
LICENSE_STATUS="$DATA/LICENSE_STATUS.txt"; DEVICE_INFO="$DATA/KOBO_DEVICE_ID.txt"
PROTECT_STATUS="$DATA/PROTECT_STATUS.ggstate"; LOG="$DATA/native.log"
REPORT_ROOT=/mnt/onboard/GhostGuard_Reports
PROFILE_MGR="$BASE/profile_manager.sh"; PROFILE_V5="$DATA/profile_v5.txt"
mkdir -p "$DATA" "$DATA/reports" "$RUN" 2>/dev/null || true

clean_serial(){ [ -f /mnt/onboard/.kobo/version ] && sed -n '1{s/,.*//;p;}' /mnt/onboard/.kobo/version 2>/dev/null | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9'; }
arch_name(){ case "$(uname -m 2>/dev/null)" in aarch64|arm64) echo aarch64;; armv8*|armv7*|armv6*|arm*) echo armv7;; *) echo unknown;; esac; }
binary_path(){ case "$(arch_name)" in aarch64) echo "$BIN_DIR/ghostguardd-aarch64";; armv7) echo "$BIN_DIR/ghostguardd-armv7";; *) echo "";; esac; }
find_touch(){
  for P in /sys/class/input/event*; do [ -e "$P" ] || continue; N="$(cat "$P/device/name" 2>/dev/null | tr '[:upper:]' '[:lower:]')"; case "$N" in *ghostguard*virtual*) continue;; *touch*|*cyttsp*|*zforce*|*elan*|*goodix*|*focal*|*fts*|*mtk*tpd*|*multitouch*) E="$(basename "$P")"; [ -r "/dev/input/$E" ] && { echo "/dev/input/$E"; return 0; };; esac; done
  [ -r /proc/bus/input/devices ] && awk 'BEGIN{IGNORECASE=1;n="";h=""}/^N: Name=/{n=$0}/^H: Handlers=/{h=$0}/^$/{if(n ~ /(touch|cyttsp|zforce|elan|goodix|focal|fts|mtk)/ && n !~ /GhostGuard Virtual/){x=split(h,a," ");for(i=1;i<=x;i++)if(a[i]~/^event[0-9]+$/){print "/dev/input/"a[i];exit}}n="";h=""}' /proc/bus/input/devices 2>/dev/null | head -n1
}
write_device_info(){ SERIAL="$(clean_serial)"; [ -n "$SERIAL" ] || SERIAL=KOBO_UNKNOWN; FW="$(cut -d, -f3 /mnt/onboard/.kobo/version 2>/dev/null | tr -d '\r\n')"; INPUT="$(find_touch)"; PA=0; [ -r "$PROTECT_STATUS" ] && grep -q '^STATE=ACTIVE$' "$PROTECT_STATUS" 2>/dev/null && PA=1; { echo DCPRO_GHOSTGUARD_KOBO_DEVICE_V2; echo "DEVICE_ID=$SERIAL"; echo "ARCH=$(arch_name)"; echo "FIRMWARE=$FW"; echo "INPUT_DEVICE=$INPUT"; echo LICENSE_SOURCE=SHARED_ONLINE_REGISTRY; echo LICENSE_REGISTRY=ghostguard-kindle/licenses/licenses.json; echo ENGINE=NATIVE_EVDEV_UINPUT; echo LICENSE_FORMAT=SHARED_REGISTRY_V1; echo LICENSE_SIGNATURE=RSA-SHA256; echo "PROTECT_ACTIVE=$PA"; } > "$DEVICE_INFO"; }
license_run(){ A="$1"; SERIAL="$(clean_serial)"; DCPRO_LICENSE_STATE="$LICENSE_STATE" "$BASE/license_bridge.sh" "$A" "$SERIAL" > "$LICENSE_STATUS.tmp" 2>&1; RC=$?; mv -f "$LICENSE_STATUS.tmp" "$LICENSE_STATUS" 2>/dev/null || true; return $RC; }
license_check(){ license_run check; }; license_sync(){ license_run sync; }; license_cache(){ license_run cache; }
is_running(){ [ -f "$PIDFILE" ] || return 1; P="$(cat "$PIDFILE" 2>/dev/null)"; [ -n "$P" ] && kill -0 "$P" 2>/dev/null; }
v5_value(){ K="$1"; [ -r "$PROFILE_V5" ] && sed -n "s/^${K}=//p" "$PROFILE_V5" 2>/dev/null | head -n1; }
profile_state(){ [ -x "$PROFILE_MGR" ] || { echo CALIBRATION; return; }; "$PROFILE_MGR" state 2>/dev/null || echo CALIBRATION; }
profile_sync(){ [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" sync >/dev/null 2>&1 || true; }

stop_engine(){
  rm -f "$RUNFLAG" "$ARMFILE" 2>/dev/null || true
  [ -f "$CHILDPID" ] && { C="$(cat "$CHILDPID" 2>/dev/null)"; [ -n "$C" ] && kill "$C" 2>/dev/null || true; }
  [ -f "$PIDFILE" ] && { P="$(cat "$PIDFILE" 2>/dev/null)"; [ -n "$P" ] && kill "$P" 2>/dev/null || true; }
  sleep 1; rm -f "$PIDFILE" "$CHILDPID" "$ARMFILE"
  [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" session-end >/dev/null 2>&1 || true
  profile_sync
  echo "GhostGuard đã dừng; EVIOCGRAB được nhả tự động (fail-open)."
}

start_engine(){
  REQUEST="$1"; write_device_info
  [ -f "$SAFE" ] && { echo "SAFE_MODE đang bật."; return 2; }
  if ! license_check; then echo "License chưa hợp lệ."; cat "$LICENSE_STATUS" 2>/dev/null; return 3; fi
  INPUT="$(find_touch)"; [ -n "$INPUT" ] && [ -r "$INPUT" ] || { echo "Không tìm thấy touchscreen evdev đọc được."; return 4; }
  echo "$INPUT" > "$INPUTFILE"
  [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" ensure-binding >/dev/null 2>&1 || true
  PSTATE="$(profile_state)"; MODE="$REQUEST"
  if [ "$REQUEST" = AUTO ] || [ "$REQUEST" = LEARN ]; then
    case "$PSTATE" in
      CALIBRATION|'') MODE=LEARN ;;
      PENDING_APPROVAL) MODE=SHADOW ;;
      PROBATION) MODE=SHADOW ;;
      PROBATION_PASSED) MODE=PROTECT ;;
      *) MODE=SHADOW ;;
    esac
  fi
  if [ "$MODE" = PROTECT ]; then
    EL="$(v5_value PROTECT_ELIGIBLE)"; [ "$PSTATE" = PROBATION_PASSED ] && [ "$EL" = 1 ] || { echo "Protect chưa đủ điều kiện: state=$PSTATE eligible=${EL:-0}"; MODE=SHADOW; }
  fi
  if is_running; then CUR="$(cat "$MODEFILE" 2>/dev/null)"; [ "$CUR" = "$MODE" ] && { echo "GhostGuard đang chạy: $MODE"; return 0; }; stop_engine >/dev/null 2>&1; sleep 1; fi
  BIN="$(binary_path)"; [ -n "$BIN" ] && [ -x "$BIN" ] || { echo "Không có native binary phù hợp."; return 5; }
  rm -f "$ARMFILE"; [ "$MODE" != PROTECT ] && rm -f "$PROTECT_STATUS" 2>/dev/null || true
  echo "$MODE" > "$MODEFILE"; echo 1 > "$RUNFLAG"; rm -f "$DATA/RUNTIME_FAULT.txt"
  if command -v setsid >/dev/null 2>&1; then setsid "$BASE/supervisor.sh" >/dev/null 2>&1 & elif command -v nohup >/dev/null 2>&1; then nohup "$BASE/supervisor.sh" >/dev/null 2>&1 & else "$BASE/supervisor.sh" >/dev/null 2>&1 & fi
  SP=$!; echo "$SP" > "$PIDFILE"; sleep 1
  if is_running; then [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" session-start >/dev/null 2>&1 || true; echo "GhostGuard đã chạy: $MODE"; [ "$MODE" = PROTECT ] && echo "Protect đang chuẩn bị uinput; chỉ grab sau khi Nickel mở virtual touch."; return 0; fi
  echo "Không khởi động được supervisor."; return 6
}

make_report(){
  mkdir -p "$REPORT_ROOT" "$DATA/reports" 2>/dev/null; TS="$(date +%Y%m%d_%H%M%S 2>/dev/null)"; [ -n "$TS" ] || TS=unknown; SERIAL="$(clean_serial)"; [ -n "$SERIAL" ] || SERIAL=KOBO_UNKNOWN; TMP="$DATA/reports/report_$TS"; rm -rf "$TMP"; mkdir -p "$TMP"; write_device_info; license_cache >/dev/null 2>&1 || true; profile_sync
  cp "$DEVICE_INFO" "$TMP/" 2>/dev/null || true; cp "$DATA/profile.txt" "$TMP/observer_profile.txt" 2>/dev/null || true; cp "$PROFILE_V5" "$TMP/profile_v5.txt" 2>/dev/null || true; cp "$DATA/contacts.csv" "$TMP/" 2>/dev/null || true; cp "$DATA/blocked.gglog" "$TMP/" 2>/dev/null || true; cp "$PROTECT_STATUS" "$TMP/" 2>/dev/null || true; cp "$DATA/RUNTIME_FAULT.txt" "$TMP/" 2>/dev/null || true; cp "$LICENSE_STATUS" "$TMP/" 2>/dev/null || true; cp "$LOG" "$TMP/" 2>/dev/null || true
  A="$REPORT_ROOT/GhostGuard_Kobo_${SERIAL}_${TS}.tar.gz"; tar -czf "$A" -C "$TMP" . 2>/dev/null && { echo "Report đã tạo: $A"; return 0; }; A="${A%.gz}"; tar -cf "$A" -C "$TMP" . 2>/dev/null && { echo "Report đã tạo: $A"; return 0; }; echo "Report data: $TMP"
}
approve_profile(){ write_device_info; license_check || { echo "License chưa hợp lệ."; return 3; }; [ -x "$PROFILE_MGR" ] || return 5; "$PROFILE_MGR" approve || return $?; echo SHADOW > "$MODEFILE"; if is_running && [ -f "$CHILDPID" ]; then C="$(cat "$CHILDPID" 2>/dev/null)"; [ -n "$C" ] && kill "$C" 2>/dev/null || true; fi; echo "Profile đã kích hoạt. Probation 0/2; Protect sẽ tự bật sau khi vượt Probation."; }
status_full(){ "$BASE/nm_quick.sh" status; echo; [ -r "$PROTECT_STATUS" ] && { echo '--- Protect ---'; cat "$PROTECT_STATUS"; }; [ -r "$PROFILE_V5" ] && { echo '--- Profile V5 ---'; cat "$PROFILE_V5"; }; [ -r "$LICENSE_STATUS" ] && { echo '--- License ---'; cat "$LICENSE_STATUS"; }; }

case "${1:-status}" in
  start|learn) start_engine AUTO;; shadow) start_engine SHADOW;; protect) start_engine PROTECT;; stop) stop_engine;; status) "$BASE/nm_quick.sh" status;; status-full) status_full;; report) make_report;; approve) approve_profile;;
  profile-status) [ -x "$PROFILE_MGR" ] && "$PROFILE_MGR" status;; profile-reset) stop_engine >/dev/null 2>&1 || true; "$PROFILE_MGR" reset;; fingerprint) "$PROFILE_MGR" fingerprint;;
  safe-on) stop_engine >/dev/null 2>&1 || true; echo 1 > "$SAFE"; echo SAFE_MODE=ON;; safe-off) rm -f "$SAFE"; echo SAFE_MODE=OFF;;
  device-id) write_device_info; cat "$DEVICE_INFO";; license) license_check; RC=$?; cat "$LICENSE_STATUS"; exit $RC;; license-sync) license_sync; RC=$?; cat "$LICENSE_STATUS"; exit $RC;; license-cache) license_cache; RC=$?; cat "$LICENSE_STATUS"; exit $RC;;
  *) echo "Usage: $0 {start|stop|status|report|approve|protect|profile-status|profile-reset|license-sync}"; exit 1;;
esac
