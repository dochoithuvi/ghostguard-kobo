# DCPRO Kobo Tools Repository

DCPRO GhostGuard for Kobo e-readers.

This repository is intentionally separate from the Kindle GhostGuard codebase because Kobo uses Nickel/NickelMenu, evdev controllers and ARMv7/AArch64 native binaries. It also acts as the **public online distribution source** for Kobo, analogous to `ghostguard-kindle` on Kindle.

## Current milestone

**v0.8.1-profile-v5**

- Preserves v0.7.3 under `legacy/v0.7.3/` as reference.
- Keeps Protect disabled: no EVIOCGRAB, no uinput, fail-open behavior remains.
- Adds Controller Fingerprint bound to serial + touchscreen identity/capabilities.
- Adds Profile V5 lifecycle: `CALIBRATION -> PENDING_APPROVAL -> PROBATION -> PROBATION_PASSED`.
- Auto Learn returns to Shadow when the profile is ready and waits for explicit approval.
- Runs 2 Shadow-only probation sessions after approval.
- Invalidates/archives learned data if the controller fingerprint changes.
- Uses independent evidence families in the classifier and symmetric edge-distance support.

## Online / OneClick install

Stable OneClick endpoint:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/DCPRO_GhostGuard_Kobo_OneClick.sh
```

The OneClick installer reads:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/manifest.online.json
```

and downloads the current versioned ZIP from `packages/ghostguard-kobo/artifacts/`, verifies SHA256 when available, preserves `data/` + `SAFE_MODE`, then replaces the runtime and NickelMenu files.

Typical shell invocation:

```sh
wget -qO /tmp/ggk-oneclick.sh \
  https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/DCPRO_GhostGuard_Kobo_OneClick.sh \
  && sh /tmp/ggk-oneclick.sh
```

GitHub Actions automatically builds/tests the ARMv7/AArch64 package and publishes the current artifact + `manifest.online.json` whenever runtime changes land on `main`.

## Shared GhostGuard license

Kobo uses the **same signed online license registry as GhostGuard Kindle**. There is no separate Kobo `license.key` issuance flow.

Authoritative endpoints:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.json
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.sig
```

The registry is RSA-SHA256 signed and stores SHA-256 serial hashes. Kobo uses the same public trust anchors as Kindle and accepts active entries with `kobo`, `ghostguard`, `ghostguard-kobo`, or `ultimate` entitlement. A successfully verified registry is cached for up to 7 days for offline use; clock rollback checks remain fail-closed.

This means license administration stays centralized: add/renew the Kobo serial in the existing GhostGuard license database instead of generating a separate Kobo license file.

## Runtime paths

```text
/mnt/onboard/.adds/ghostguard/
  ghostguard.sh
  supervisor.sh
  profile_manager.sh
  license_bridge.sh
  defaults.conf
  bin/
    ghostguardd-armv7
    ghostguardd-aarch64
    gg-license-verify-armv7
    gg-license-verify-aarch64
  data/
    profile_v5.txt
    online_licenses.json
    online_licenses.sig
    online_license_sync_state
  runtime/

/mnt/onboard/.adds/nm/ghostguard
```

## Profile V5 flow

```text
LEARN / CALIBRATION
        |
        v
PENDING_APPROVAL
        | GG · Approve Profile
        v
PROBATION (2 Shadow-only sessions)
        |
        v
PROBATION_PASSED
(PROTECT_ELIGIBLE=1, PROTECT_ACTIVE=0)
```

`PROBATION_PASSED` is only an eligibility state for a future Protect Beta. v0.8.1 never blocks touch input.

## Build

Requirements: Go 1.22+ and a C compiler.

```sh
make test
make license-verifiers
make package
```

`make test` covers classifier logic, Profile V5 lifecycle and shared signed-registry verification including tamper/serial mismatch cases.

## Repository layout

```text
cmd/                    Go shared-registry verifier
config/                 runtime defaults
include/ + src/          modular GhostGuard core
legacy/v0.7.3/           original observer reference
nickelmenu/              NickelMenu config
package/                 Kobo package tree
profiles/                controller preset groundwork
scripts/                 controller/supervisor/license/Profile V5 manager
tests/                   regression tests
.github/workflows/       CI + online artifact publisher
```

## Distribution/security boundary

This is proprietary DCPRO software. Public repository contents may include source, native artifacts and public verification keys. Never commit the private registry signing key, raw customer serial database or customer datasets.
