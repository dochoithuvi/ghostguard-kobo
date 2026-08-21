# DCPRO Kobo Tools Repository

DCPRO GhostGuard for Kobo e-readers.

This repository is intentionally separate from the Kindle GhostGuard codebase.
Kobo uses a different runtime stack (Nickel/NickelMenu, evdev controllers,
ARMv7/AArch64 binaries, and future uinput-based protection), so the two product
lines can evolve and be tested independently.

## Current repository milestone

**v0.8.1-profile-v5**

- Preserves v0.7.3 under `legacy/v0.7.3/` as an immutable reference.
- Ships the proven v0.7.3 native observer binaries for ARMv7/AArch64.
- Keeps **Protect disabled**: no EVIOCGRAB, no uinput, fail-open behavior remains.
- Adds a stable Controller Fingerprint bound to serial + touchscreen identity/capabilities.
- Adds Profile V5 lifecycle: `CALIBRATION -> PENDING_APPROVAL -> PROBATION -> PROBATION_PASSED`.
- Auto Learn stops learning when the readiness gates are met and returns the observer to Shadow while waiting for approval.
- Requires explicit user approval before probation; probation remains Shadow-only for 2 completed sessions.
- Invalidates and archives learned data if the controller fingerprint changes.
- Fixes supervisor/controller input-device detection drift.
- Adds a modular classifier core for Profile V5 work.
- Fixes independent-evidence accounting: FAST and BASE_SHORT belong to one
  TIMING family and cannot satisfy the 2-family gate by themselves.
- Adds symmetric edge-distance support when absolute controller bounds are known.
- Adds Ed25519-signed, serial-bound `license.key` verification with static Kobo
  verifier binaries. No signing secret/private key is shipped in this repository.

## Runtime paths on Kobo

```text
/mnt/onboard/.adds/ghostguard/
  ghostguard.sh
  supervisor.sh
  profile_manager.sh
  license_bridge.sh
  defaults.conf
  license.key                  # customer-specific; never commit
  bin/
    ghostguardd-armv7
    ghostguardd-aarch64
    gg-license-verify-armv7
    gg-license-verify-aarch64
  data/
  runtime/

/mnt/onboard/.adds/nm/ghostguard
```

## License flow

The user experience stays close to GhostGuard Kindle: each device receives a
customer-specific `license.key` bound to the Kobo serial.

The cryptography is different: Kobo v0.8 uses **Ed25519** signatures.

- Admin side: private key signs licenses.
- Kobo side: verifier binaries contain only the public key.
- Copying a valid `license.key` to another Kobo fails with `SERIAL_MISMATCH`.
- Changing license fields invalidates the signature.
- Clock rollback after a successful validation is rejected using
  `data/license_last_date`.

See `docs/LICENSE_SYSTEM.md`.

## Build

Requirements for development host: Go 1.22+ and a C compiler for unit tests.

```sh
make test                 # classifier + Profile V5 lifecycle
make license-verifiers
make package
```

`make package` produces `dist/GhostGuard-Kobo-v0.8.1-profile-v5.zip`.

## Profile V5 flow

```text
LEARN / CALIBRATION
        | readiness gates met
        v
PENDING_APPROVAL  (observer automatically returns to SHADOW)
        | GG · Approve Profile
        v
PROBATION         (2 completed Shadow-only sessions)
        | sessions completed
        v
PROBATION_PASSED  (PROTECT_ELIGIBLE=1, PROTECT_ACTIVE=0)
```

Default readiness gates are configurable in `config/defaults.conf`: 60 clean
baseline contacts, 80 total contacts, and <=25% incomplete contacts. These are
development defaults intended to be tuned from the Kobo dataset.

The V5 control profile is stored at `data/profile_v5.txt`. The native observer
continues to own `data/profile.txt` (V4 telemetry/baseline) in this release so
v0.8.1 can add lifecycle safety without replacing the proven low-level binary.

See `docs/PROFILE_V5.md`.

## Safety status

The shipped touch engine is still SHADOW-only. v0.8.1 adds the Profile V5
control-plane around the proven v0.7.3 observer. `PROBATION_PASSED` only sets
`PROTECT_ELIGIBLE=1`; it never enables blocking. The later quarantine/uinput
Protect engine must still be implemented separately. Do not turn Protect on by
simply changing a flag in the v0.7.3 observer binary.

## Repository layout

```text
cmd/                    Go license verifier/admin source
config/                 runtime defaults
include/ + src/          modular GhostGuard core under development
legacy/v0.7.3/           original reference release
nickelmenu/              NickelMenu config source
package/                 files copied to Kobo for current build
profiles/                future controller presets
scripts/                 shell controller/supervisor/license + Profile V5 manager
tests/                   host-side classifier + lifecycle tests
tools/                   dataset analysis helpers
```

## Distribution

This project is proprietary DCPRO software. Do not commit private signing keys,
customer licenses, or customer datasets.
