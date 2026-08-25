#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

grep -q '"$CORE" start' "$ROOT/scripts/ui_action.sh"
grep -q 'PROTECT_FILTER_ARMED' "$ROOT/scripts/ghostguard.sh"
grep -q 'PROTECT_WATCHDOG' "$ROOT/scripts/ghostguard.sh"
grep -q 'wait_proxy_preflight' "$ROOT/scripts/supervisor.sh"
grep -q 'deadman_watch' "$ROOT/scripts/supervisor.sh"
grep -q 'nickel_has_fd.*arm_now' "$ROOT/scripts/supervisor.sh"
grep -q 'PRECHECK_TIMEOUT_NO_POST_GRAB_FORWARD' "$ROOT/scripts/supervisor.sh"
grep -q 'FILTER_GATE_MISSING' "$ROOT/scripts/supervisor.sh"
grep -q 'SAFETY_HANDSHAKE_PASS' "$ROOT/scripts/supervisor.sh"
grep -q 'rm -f "$FILTERFILE" "$ARMFILE" "$WATCHFILE"' "$ROOT/scripts/supervisor.sh"
grep -q 'SAFETY_HANDSHAKE=1' "$ROOT/config/defaults.conf"
grep -q 'SAFETY_ROLLBACK=0' "$ROOT/config/defaults.conf"
grep -q 'ESCAPE_GRACE_CONTACTS=3' "$ROOT/config/defaults.conf"
grep -q 'ESCAPE_MAX_CONSECUTIVE_BLOCKS=2' "$ROOT/config/defaults.conf"
python3 "$ROOT/tools/prepare_native.py"
grep -q 'STATE=ACTIVE_PRECHECK' "$ROOT/.build/ghostguardd.c"
grep -q 'filter_arm_path' "$ROOT/.build/ghostguardd.c"
grep -q 'PRECHECK_FORWARD_OK' "$ROOT/.build/ghostguardd.c"
grep -q 'FILTER_DISARMED_FAIL_OPEN' "$ROOT/.build/ghostguardd.c"
grep -q 'protect_requested=0' "$ROOT/.build/ghostguardd.c"
grep -q 'escape_grace_contacts=3u' "$ROOT/.build/ghostguardd.c"
grep -q 'consecutive_blocks>=2u' "$ROOT/.build/ghostguardd.c"
grep -q 'ALLOW_ESCAPE' "$ROOT/.build/ghostguardd.c"
# The filter gate must be checked before any classifier block path.
python3 - "$ROOT/.build/ghostguardd.c" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
p=s.index('static void protect_process')
f=s.index('if(!filter_active)',p)
b=s.index('BLOCK_CLASSIC',p)
assert f < b, 'filter gate must precede classifier blocking'
assert 'if(filter_active&&!file_exists(filter_arm_path))' in s[p:b]
PY

echo 'safety handshake/deadman regression checks: PASS'
