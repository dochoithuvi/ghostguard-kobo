#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# Customer Start must be observation-only.
grep -q '"$CORE" shadow' "$ROOT/scripts/ui_action.sh"
! grep -q '"$CORE" start' "$ROOT/scripts/ui_action.sh"

# Core protect command must degrade to Shadow.
grep -q 'Protect bị khóa ở v0.8.7.1; chuyển sang SHADOW' "$ROOT/scripts/ghostguard.sh"
grep -q 'PROTECT) MODE=SHADOW' "$ROOT/scripts/ghostguard.sh"

# Supervisor must never launch native in PROTECT and must clear every arm gate.
grep -q 'SAFETY_LOCKDOWN requested=' "$ROOT/scripts/supervisor.sh"
grep -q 'live PROTECT -> SHADOW restart' "$ROOT/scripts/supervisor.sh"
grep -q 'rm -f "$ARMFILE" "$FILTERFILE" "$WATCHFILE"' "$ROOT/scripts/supervisor.sh"
! grep -q 'arm_protect' "$ROOT/scripts/supervisor.sh"
! grep -q 'protect_controller' "$ROOT/scripts/supervisor.sh"

# Defaults and UX must make the lockout explicit.
grep -q '^SAFETY_LOCKDOWN=1$' "$ROOT/config/defaults.conf"
grep -q '^PROTECT_ACTIVE=0$' "$ROOT/config/defaults.conf"
grep -q 'Protect: DISABLED (Safety Lockdown)' "$ROOT/scripts/nm_quick.sh"
grep -q 'EVIOCGRAB: OFF' "$ROOT/scripts/nm_quick.sh"
grep -q '^Version: 0.8.7.1$' "$ROOT/package/.adds/ghostguard/VERSION"

echo 'safety lockdown regression checks: PASS'
