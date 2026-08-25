#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# Customer Start must never request PROTECT in the rollback build.
grep -q '"$CORE" shadow' "$ROOT/scripts/ui_action.sh"
! grep -A12 '^    start)' "$ROOT/scripts/ui_action.sh" | grep -q '"$CORE" start'

# Any stale or explicit PROTECT mode must be clamped before native launch.
grep -q 'force_shadow_mode' "$ROOT/scripts/supervisor.sh"
grep -q 'requested=PROTECT forced=SHADOW' "$ROOT/scripts/supervisor.sh"
grep -q 'MODE="$(force_shadow_mode "$REQUESTED")"' "$ROOT/scripts/supervisor.sh"
grep -q 'PROBATION_PASSED -> SHADOW retained' "$ROOT/scripts/supervisor.sh"

# Release defaults and UI must advertise that no EVIOCGRAB protection is active.
grep -q '^SAFETY_ROLLBACK=1$' "$ROOT/config/defaults.conf"
grep -q '^PROTECT_ACTIVE=0$' "$ROOT/config/defaults.conf"
grep -q 'GhostGuard Kobo 0.8.6.1 Safety Rollback' "$ROOT/scripts/nm_quick.sh"
grep -q 'Protect: DISABLED (Safety Rollback)' "$ROOT/scripts/nm_quick.sh"
grep -q 'EVIOCGRAB: OFF' "$ROOT/scripts/nm_quick.sh"

# Native Protect code remains buildable for future handshake work, but this
# release has no supervisor route that can reach arm_protect after clamping.
python3 "$ROOT/tools/prepare_native.py"
grep -q 'EVIOCGRAB' "$ROOT/.build/ghostguardd.c"

echo 'v0.8.6.1 Safety Rollback static gates: OK'
