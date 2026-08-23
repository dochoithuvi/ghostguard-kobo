#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
grep -q 'GhostGuard - Stop : cmd_spawn' "$ROOT/nickelmenu/ghostguard"
grep -q 'emergency_stop' "$ROOT/scripts/ui_action.sh"
grep -q 'PROTECT_ACTIVE=0' "$ROOT/scripts/emergency_stop.sh"
grep -q 'kill -TERM' "$ROOT/scripts/emergency_stop.sh"
python3 "$ROOT/tools/prepare_native.py"
grep -q 'if(!burst_guard||elapsed>80000u)return 0;if(risk<35u)return 0;' "$ROOT/.build/ghostguardd.c"
! grep -q 'if(elapsed<=cut)return 1' "$ROOT/.build/ghostguardd.c"
echo 'safety hotfix gates: OK'
