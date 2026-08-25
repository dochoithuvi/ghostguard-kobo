#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# Protect plumbing remains compiled for later redesign, but runtime must lock it out.
grep -q 'Protect bị khóa ở v0.8.7.1; chuyển sang SHADOW' "$ROOT/scripts/ghostguard.sh"
grep -q 'SAFETY_LOCKDOWN requested=' "$ROOT/scripts/supervisor.sh"
! grep -q 'arm_protect' "$ROOT/scripts/supervisor.sh"
grep -q 'EVIOCGRAB' "$ROOT/src/ghostguardd.c"
grep -q 'UI_DEV_CREATE' "$ROOT/src/ghostguardd.c"
grep -q 'SYN_DROPPED_FAIL_OPEN' "$ROOT/src/ghostguardd.c"
python3 "$ROOT/tools/prepare_native.py"
grep -q 'suppress_tail=1' "$ROOT/.build/ghostguardd.c"
grep -q 'protect_hold_us' "$ROOT/.build/ghostguardd.c"
grep -q '25000u' "$ROOT/.build/ghostguardd.c"
grep -q 'FAMILY_TIMING' "$ROOT/.build/ghostguardd.c"
echo 'protect plumbing compiled; runtime safety lockdown gates: OK'
