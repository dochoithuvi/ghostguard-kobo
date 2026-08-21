# Changelog

## 0.8.2.1 - 2026-08-21

- Added Kindle-style customer learning progress to `GhostGuard - Status`.
- Status now shows learning percentage, touch count, baseline count, incomplete-data quality, Profile state, Probation progress, and the next recommended action.
- Added `ui_action.sh` so customer actions automatically restore legacy native state only while needed and archive it again when idle.
- Migrates `profile_v5.txt`, `LICENSE_STATUS.txt`, `KOBO_DEVICE_ID.txt`, `LAST_ACTION.txt`, `RUNTIME_FAULT.txt`, and idle `profile.txt` to private `.ggstate/.ggdata` extensions so Nickel stops treating them as books after the next library rescan.
- Report output is moved from `/mnt/onboard/GhostGuard_Reports` to hidden `/mnt/onboard/.kobo/GhostGuard_Reports` after creation.
- Keeps the five-item customer menu unchanged.
- Protect remains disabled (`PROTECT_ACTIVE=0`, no EVIOCGRAB, no uinput).

## 0.8.2 - 2026-08-21

- Simplified the customer NickelMenu to exactly five items: Status, Start, Activate Profile, Stop, Report.
- Added Auto Start routing so customers no longer choose Learn or Shadow manually.
- License/debug/fingerprint/manual mode actions remain backend-only.
- Protect remains disabled.

## 0.8.1-profile-v5 - 2026-08-21

- Added Controller Fingerprint based on serial-independent touchscreen identity/capabilities.
- Added Profile V5 control-plane with atomic profile writes and controller binding.
- Added Auto Learn readiness gates and automatic Learn -> Shadow transition at Profile Ready.
- Added explicit profile approval action.
- Added 2-session Shadow-only probation and `PROBATION_PASSED` / `PROTECT_ELIGIBLE=1`.
- Added automatic baseline invalidation/archive when the controller fingerprint changes.
- Added Profile V5 data to status and diagnostic reports.
- Added lifecycle regression test and package sync target.
- Protect remains disabled (`PROTECT_ACTIVE=0`, no EVIOCGRAB, no uinput).

## 0.8.0-foundation - 2026-08-21

- Created standalone `ghostguard-kobo` repository layout.
- Archived v0.7.3 as the stable reference release.
- Added Ed25519 serial-bound license format v4.
- Added static ARMv7/AArch64 license verifier binaries.
- Added separate admin signing tool source; private signing key excluded from repo.
- Fixed supervisor input detection drift by reusing validated runtime input device.
- Extracted classifier into a testable modular core.
- Replaced raw signal-count semantics with independent evidence families.
- Added right/bottom edge support when controller absolute bounds are known.
- Protect remains disabled; shipped observer stays fail-open Shadow-only.
