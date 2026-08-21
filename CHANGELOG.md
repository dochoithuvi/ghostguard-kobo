# Changelog

## 0.8.1-profile-v5 - 2026-08-21

- Added Controller Fingerprint based on serial-independent touchscreen identity/capabilities.
- Added Profile V5 control-plane with atomic profile writes and controller binding.
- Added Auto Learn readiness gates and automatic Learn -> Shadow transition at Profile Ready.
- Added explicit `GG · Approve Profile` action.
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
