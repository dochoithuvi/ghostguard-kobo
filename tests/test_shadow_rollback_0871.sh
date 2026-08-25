#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
grep -q '"$CORE" shadow' "$ROOT/scripts/ui_action.sh"
! grep -q '"$CORE" start' "$ROOT/scripts/ui_action.sh"
grep -q 'SAFETY_ROLLBACK requested=' "$ROOT/scripts/supervisor.sh"
grep -q 'PROBATION_PASSED -> SHADOW retained by v0.8.7.1 rollback' "$ROOT/scripts/supervisor.sh"
! grep -q 'arm_protect' "$ROOT/scripts/supervisor.sh"
! grep -q 'EVIOCGRAB' "$ROOT/scripts/supervisor.sh"
grep -q 'SAFETY_ROLLBACK=1' "$ROOT/config/defaults.conf"
grep -q 'PROTECT_ACTIVE=0' "$ROOT/config/defaults.conf"
grep -q 'SAFETY_HANDSHAKE=0' "$ROOT/config/defaults.conf"
grep -q 'GhostGuard Kobo 0.8.7.1 Emergency Shadow Rollback' "$ROOT/scripts/nm_quick.sh"
grep -q 'Protect: DISABLED' "$ROOT/scripts/nm_quick.sh"
grep -q 'EVIOCGRAB: OFF' "$ROOT/scripts/nm_quick.sh"
echo 'v0.8.7.1 shadow rollback gates: PASS'
