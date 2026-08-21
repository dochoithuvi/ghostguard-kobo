#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/ggk-profile-test-$$"
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP/base/data" "$TMP/base/runtime"
cp "$ROOT/scripts/profile_manager.sh" "$TMP/base/profile_manager.sh"
chmod +x "$TMP/base/profile_manager.sh"

echo /dev/null > "$TMP/base/runtime/input_device"
cat > "$TMP/base/data/profile.txt" <<'P'
DCPRO_GHOSTGUARD_NATIVE_PROFILE_V4
MODE=LEARN
CONTACTS=100
SUSPECTS=2
WOULD_DROP=1
INCOMPLETE_CONTACTS=5
NO_POSITION_CONTACTS=5
MAX_RISK_SIGNALS=2
RISK_LOW=95
RISK_MEDIUM=4
RISK_HIGH=1
RISK_MAX=92
BASELINE_COUNT=70
AVG_DURATION_US=118000
AVG_PATH_PX=14
AVG_TOUCH_MAJOR=7
FRAMES=500
RAW_EVENTS=2000
X_MIN=12
X_MAX=1068
Y_MIN=9
Y_MAX=1428
PROTECT_ACTIVE=0
INPUT_GRAB=NEVER
FAIL_OPEN=1
P
printf 'header\n' > "$TMP/base/data/contacts.csv"

run_pm() {
    GG_BASE="$TMP/base" GG_SERIAL=KOBO123456 GG_TOUCH_DEVICE=/dev/null \
    GG_TOUCH_NAME='FocalTech Touchscreen' GG_FP_CANONICAL="${FP_CANONICAL:-controller-A}" \
    GG_NOW='2026-08-21T16:00:00+0700' GG_STAMP='20260821_160000' \
    PROFILE_READY_BASELINE_MIN=60 PROFILE_READY_CONTACTS_MIN=80 \
    PROFILE_READY_MAX_INCOMPLETE_PCT=25 PROBATION_SESSIONS=2 \
    "$TMP/base/profile_manager.sh" "$@"
}

getv() { sed -n "s/^$1=//p" "$TMP/base/data/profile_v5.txt" | head -n1; }

run_pm ensure-binding
run_pm sync
[ "$(getv STATE)" = PENDING_APPROVAL ]
[ "$(getv PROFILE_READY)" = 1 ]
[ "$(getv CONTROLLER_CLASS)" = FocalTech ]

run_pm approve >/dev/null
[ "$(getv STATE)" = PROBATION ]
[ "$(getv PROBATION_COMPLETED)" = 0 ]
[ "$(getv PROTECT_ACTIVE)" = 0 ]

run_pm session-start
[ "$(getv PROBATION_SESSION_OPEN)" = 1 ]
run_pm session-end
[ "$(getv PROBATION_COMPLETED)" = 1 ]
[ "$(getv STATE)" = PROBATION ]

run_pm session-start
run_pm session-end
[ "$(getv PROBATION_COMPLETED)" = 2 ]
[ "$(getv STATE)" = PROBATION_PASSED ]
[ "$(getv PROTECT_ELIGIBLE)" = 1 ]
[ "$(getv PROTECT_ACTIVE)" = 0 ]

FP_CANONICAL=controller-B run_pm ensure-binding
[ "$(getv STATE)" = CALIBRATION ]
[ "$(getv BASELINE_COUNT)" = 0 ]
[ ! -f "$TMP/base/data/profile.txt" ]
find "$TMP/base/data/profile_archive" -type f -name 'profile_v5.txt' | grep -q .

echo "profile lifecycle tests: OK"
