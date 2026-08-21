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

## Recommended install: one file, no shell

Stable one-file endpoint:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/KoboRoot.tgz
```

Install/update:

1. Download `KoboRoot.tgz` from the stable endpoint above.
2. Connect the Kobo by USB.
3. Copy the file **without extracting or renaming it** to the hidden folder:

```text
KOBOeReader/.kobo/KoboRoot.tgz
```

4. Safely eject/disconnect the Kobo.
5. Kobo processes the package using its normal boot-time update slot and reboots automatically.
6. After boot, open `GG · Status`, then use `GG · Learn` or `GG · Shadow`.

This package contains only the GhostGuard runtime, native binaries, defaults and NickelMenu configuration under `/mnt/onboard/.adds/`. It deliberately does **not** ship `profile_v5.txt`, signed license-cache files or other learned data, so installing a newer `KoboRoot.tgz` does not reset the existing GhostGuard profile.

> NickelMenu itself is not bundled. If the device does not already have a compatible NickelMenu installation, install a compatible NickelMenu build separately for that Kobo firmware.

GitHub Actions automatically rebuilds and refreshes the stable `KoboRoot.tgz` whenever runtime changes land on `main`. A versioned copy is also retained under `packages/ghostguard-kobo/artifacts/` and its SHA256 is published in `manifest.online.json` and `packages/ghostguard-kobo/SHA256SUMS`.

## Shell OneClick (optional)

For Kobo devices where KTerm/SSH is available, the existing online bootstrap remains supported:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/DCPRO_GhostGuard_Kobo_OneClick.sh
```

Typical invocation:

```sh
wget -qO /tmp/ggk-oneclick.sh \
  https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/DCPRO_GhostGuard_Kobo_OneClick.sh \
  && sh /tmp/ggk-oneclick.sh
```

The shell installer reads `manifest.online.json`, downloads the current ZIP artifact, verifies SHA256 when available, preserves `data/` + `SAFE_MODE`, then updates the runtime and NickelMenu files.

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

Requirements: Go 1.22+, a C compiler, `zip`, `tar`, and `gzip`.

```sh
make test
make package
make koboroot
```

Build outputs:

```text
dist/GhostGuard-Kobo-v0.8.1-profile-v5.zip
dist/GhostGuard-Kobo-v0.8.1-profile-v5-KoboRoot.tgz
```

`make test` covers classifier logic, Profile V5 lifecycle and shared signed-registry verification including tamper/serial mismatch cases. CI also validates that the KoboRoot archive has the correct `/mnt/onboard/.adds/...` paths and does not contain learned-profile or license-cache state.

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
