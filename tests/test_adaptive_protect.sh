#!/bin/sh
set -eu
python3 tools/prepare_native.py
grep -q 'burst_guard' .build/ghostguardd.c
grep -q 'protect_hold_us' .build/ghostguardd.c
grep -q '80000u' .build/ghostguardd.c
grep -q '25000u' .build/ghostguardd.c
grep -q 'reason=BURST' .build/ghostguardd.c
grep -q 'burst_hits>=3u' .build/ghostguardd.c
grep -q 'Blocked:.*Classic.*Burst' scripts/nm_quick.sh
echo 'adaptive protect regression checks: PASS'
