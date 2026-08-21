#!/bin/sh
set -eu

grep -q 'Learning:.*%' scripts/nm_quick.sh
grep -q 'Touches:' scripts/nm_quick.sh
grep -q 'Baseline:' scripts/nm_quick.sh
grep -q 'Data quality:' scripts/nm_quick.sh
grep -q 'profile_v5.ggstate' scripts/nm_quick.sh
grep -q 'observer_profile.ggdata' scripts/ui_action.sh
grep -q 'LICENSE_STATUS.ggstate' scripts/ui_action.sh
grep -q '/mnt/onboard/.kobo/GhostGuard_Reports' scripts/ui_action.sh
! grep -q 'LAST_ACTION.txt' nickelmenu/ghostguard
grep -q 'nickel_misc : rescan_books' nickelmenu/ghostguard

echo 'status/library cleanup regression checks: PASS'
