# Changelog

## 0.8.3.1 - 2026-08-22

- Fixed `GhostGuard - Status` NickelMenu timeouts by moving Profile V5 sync to a background best-effort kick and increasing the local popup timeout budget.
- Runtime Profile V5, native observer profile, license/device/fault state now use `.ggstate/.ggdata` permanently while the engine is running; they are no longer temporarily restored as `.txt`.
- Native ARMv7/AArch64 builds now write `observer_profile.ggdata` and `RUNTIME_FAULT.ggstate` directly.
- Added migration of legacy `profile_v5.txt`, `profile.txt`, `LICENSE_STATUS.txt`, `KOBO_DEVICE_ID.txt`, `RUNTIME_FAULT.txt`, `status.txt`, and `LAST_ACTION.txt` into private state names.
- Reports retain only compressed `.tar.gz/.tar` archives. Loose old report trees such as `SYSTEM.txt`, status/profile snapshots and `LATEST` directories are removed automatically.
- `GhostGuard - Status` and `GhostGuard - Stop` trigger a Nickel library rescan after cleanup so stale GhostGuard book cards disappear from My Books.
- Added CI gates preventing the shipped core/profile manager/native runtime from writing document-like `.txt` state.
- Protect Beta logic is unchanged from v0.8.3.

## 0.8.3 - 2026-08-22

- Fixed `Learning: 100%` while Profile V5 remained `CALIBRATION`: live `contacts.csv` is now authoritative when newer than the batched native profile snapshot.
- Added regression coverage for stale observer profile + ready live CSV data.
- Added native ARMv7/AArch64 evdev/uinput Protect Beta engine, built from source in CI with clang/lld.
- Auto Start now routes `PROBATION_PASSED` profiles to `PROTECT`.
- Protect creates a capability-cloned virtual touchscreen and waits for the supervisor to verify Nickel has opened it before attempting `EVIOCGRAB`.
- Added 10 ms contact quarantine. Only ultra-short high-confidence `WOULD_DROP` contacts with at least two independent evidence families are suppressed.
- Multitouch and contacts longer than the quarantine window are forwarded conservatively.
- Added fail-open handling for missing uinput, failed virtual creation/write, input read failure, `SYN_DROPPED`, and daemon exit.
- Build-time native hardening suppresses the remainder of a dropped contact frame to avoid orphan UP/SYN tails and destroys the virtual input on runtime fail-open.
- Status now shows Watch/Suspect/Candidate live telemetry, last-touch risk, Protect state, blocked count and explicit fail-open reason.
- Customer NickelMenu remains exactly five items; shared Kindle/Kobo license registry remains unchanged.

## 0.8.2.2 - 2026-08-21

- Fixed live learning visibility: `GhostGuard - Status` now reads `contacts.csv` directly instead of waiting for the native observer's batched `profile.txt` flush.
- Touches, baseline progress, incomplete-data percentage, and `WOULD_DROP` ghost candidates now update from the live contact stream.
- Preserves Profile V5 as the authoritative readiness state; live CSV counters are presentation/diagnostic data only.
- Renamed packaged `SAFETY.txt` to `SAFETY.ggdata` so modern Kobo firmware does not expose it as a book.
- Keeps the five-item customer menu unchanged.
- Protect remains disabled (`PROTECT_ACTIVE=0`, no EVIOCGRAB, no uinput).

## 0.8.2.1 - 2026-08-21

- Added Kindle-style customer learning progress to `GhostGuard - Status`.
- Status now shows learning percentage, touch count, baseline count, incomplete-data quality, Profile state, Probation progress, and the next recommended action.
- Added `ui_action.sh` so customer actions automatically restore legacy native state only while needed and archive it again when idle.
- Migrates runtime `.txt` state to private `.ggstate/.ggdata` extensions so Nickel stops treating it as books after the next library rescan.
- Report output is moved to hidden `/mnt/onboard/.kobo/GhostGuard_Reports` after creation.
- Keeps the five-item customer menu unchanged.
- Protect remains disabled.

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
- Protect remains disabled.

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
