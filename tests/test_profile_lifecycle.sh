#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/ggk-profile-test-$$"; trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP/base/data" "$TMP/base/runtime"; cp "$ROOT/scripts/profile_manager.sh" "$TMP/base/profile_manager.sh"; chmod +x "$TMP/base/profile_manager.sh"; echo /dev/null > "$TMP/base/runtime/input_device"
# Stale observer snapshot deliberately says zero. Live CSV already contains 100
# healthy touches: regression for the on-device 100%-but-not-ready bug.
cat > "$TMP/base/data/profile.txt" <<'P'
DCPRO_GHOSTGUARD_NATIVE_PROFILE_V4
MODE=LEARN
CONTACTS=0
SUSPECTS=0
WOULD_DROP=0
INCOMPLETE_CONTACTS=0
RISK_LOW=0
RISK_MEDIUM=0
RISK_HIGH=0
RISK_MAX=0
BASELINE_COUNT=0
AVG_DURATION_US=0
AVG_PATH_PX=0
AVG_TOUCH_MAJOR=0
FRAMES=1
RAW_EVENTS=1
PROTECT_ACTIVE=0
INPUT_GRAB=OFF
FAIL_OPEN=1
P
cat > "$TMP/base/data/contacts.csv" <<'C'
timestamp,tracking_id,x,y,duration_us,touch_major,path_px,risk_score,risk_signals,evidence_mask,class,shadow_action,end_type
C
i=1; while [ "$i" -le 100 ]; do printf '%s,1,%s,%s,120000,7,14,0,0,0,NORMAL,ALLOW,BTN_TOUCH_UP\n' "$i" "$((100+i))" "$((200+i))" >> "$TMP/base/data/contacts.csv"; i=$((i+1)); done
run_pm(){ GG_BASE="$TMP/base" GG_SERIAL=KOBO123456 GG_TOUCH_DEVICE=/dev/null GG_TOUCH_NAME='FocalTech Touchscreen' GG_FP_CANONICAL="${FP_CANONICAL:-controller-A}" GG_NOW='2026-08-22T00:20:00+0700' GG_STAMP='20260822_002000' PROFILE_READY_BASELINE_MIN=60 PROFILE_READY_CONTACTS_MIN=80 PROFILE_READY_MAX_INCOMPLETE_PCT=25 PROBATION_SESSIONS=2 "$TMP/base/profile_manager.sh" "$@"; }
getv(){ sed -n "s/^$1=//p" "$TMP/base/data/profile_v5.txt"|head -n1; }
run_pm sync
[ "$(getv STATE)" = PENDING_APPROVAL ]; [ "$(getv PROFILE_READY)" = 1 ]; [ "$(getv READINESS_REASON)" = BASELINE_STABLE_LIVE ]; [ "$(getv CONTACTS)" = 100 ]; [ "$(getv BASELINE_COUNT)" = 100 ]
run_pm approve >/dev/null; [ "$(getv STATE)" = PROBATION ]; [ "$(getv PROTECT_ACTIVE)" = 0 ]
run_pm session-start; run_pm session-end; [ "$(getv PROBATION_COMPLETED)" = 1 ]
run_pm session-start; run_pm session-end; [ "$(getv STATE)" = PROBATION_PASSED ]; [ "$(getv PROTECT_ELIGIBLE)" = 1 ]; [ "$(getv PROTECT_ACTIVE)" = 0 ]
printf 'STATE=ACTIVE\nPROTECT_ACTIVE=1\n' > "$TMP/base/data/PROTECT_STATUS.ggstate"; run_pm sync; [ "$(getv PROTECT_ACTIVE)" = 1 ]; [ "$(getv INPUT_GRAB)" = EVIOCGRAB ]
FP_CANONICAL=controller-B run_pm ensure-binding; [ "$(getv STATE)" = CALIBRATION ]; [ "$(getv BASELINE_COUNT)" = 0 ]; [ ! -f "$TMP/base/data/profile.txt" ]; find "$TMP/base/data/profile_archive" -type f -name profile_v5.txt|grep -q .
echo 'profile lifecycle tests: OK'
