#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
grep -q 'PROBATION_PASSED) MODE=PROTECT' "$ROOT/scripts/ghostguard.sh"
grep -q 'nickel_has_fd' "$ROOT/scripts/supervisor.sh"
grep -q 'PROTECT_ARMED' "$ROOT/scripts/supervisor.sh"
grep -q 'DCPRO GhostGuard Virtual Touch' "$ROOT/scripts/supervisor.sh"
grep -q 'EVIOCGRAB' "$ROOT/src/ghostguardd.c"
grep -q 'UI_DEV_CREATE' "$ROOT/src/ghostguardd.c"
grep -q 'SYN_DROPPED_FAIL_OPEN' "$ROOT/src/ghostguardd.c"
python3 "$ROOT/tools/prepare_native.py"
grep -q 'suppress_tail=1' "$ROOT/.build/ghostguardd.c"
grep -q 'elapsed<=10000u' "$ROOT/.build/ghostguardd.c"
grep -q 'FAMILY_TIMING' "$ROOT/.build/ghostguardd.c"
echo 'protect beta static gates: OK'
