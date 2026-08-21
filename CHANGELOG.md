# Changelog

## 0.8.0-foundation - 2026-08-21

- Created standalone `ghostguard-kobo` repository layout.
- Kept v0.7.3 observer binaries/reference notes; omitted the obsolete shared-secret verifier and secret from the public repository.
- Added Ed25519 serial-bound license format v4.
- Added reproducible ARMv7/AArch64 license verifier builds.
- Added separate admin signing tool source; private signing key excluded from repo.
- Fixed supervisor input detection drift by reusing validated runtime input device.
- Extracted classifier into a testable modular core.
- Replaced raw signal-count semantics with independent evidence families.
- Added right/bottom edge support when controller absolute bounds are known.
- Protect remains disabled; shipped observer stays fail-open Shadow-only.
