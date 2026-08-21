# DCPRO GhostGuard Kobo

GhostGuard for Kobo e-readers. This repository is both the Kobo source tree and the public online distribution source.

## Current milestone

**v0.8.2**

- Controller Fingerprint + Profile V5 lifecycle.
- One-button Auto Start: users no longer choose Learn or Shadow manually.
- Five-item NickelMenu UX only.
- Shared signed GhostGuard Kindle/Kobo license registry.
- One-file `KoboRoot.tgz` install/update.
- Protect remains disabled: no EVIOCGRAB, no uinput, fail-open behavior remains.

## Customer menu

Only these five items are exposed:

```text
GhostGuard - Status
GhostGuard - Start
GhostGuard - Activate Profile
GhostGuard - Stop
GhostGuard - Report
```

`GhostGuard - Start` chooses the internal mode automatically:

```text
CALIBRATION / new controller -> LEARN
PENDING_APPROVAL             -> SHADOW
PROBATION                    -> SHADOW
PROBATION_PASSED             -> SHADOW
```

The backend still retains diagnostic commands for support, but they are not exposed in NickelMenu.

## Recommended install: one file, no shell

Stable endpoint:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/KoboRoot.tgz
```

Copy it without extracting or renaming it to:

```text
KOBOeReader/.kobo/KoboRoot.tgz
```

Safely eject the Kobo. The device processes the package through its normal update mechanism and reboots automatically.

The archive installs GhostGuard under `/mnt/onboard/.adds/` but deliberately excludes learned Profile V5 state and signed license-cache data, so updates preserve the existing profile.

NickelMenu itself is not bundled.

## Shared GhostGuard license

Kobo uses the same signed online license registry as GhostGuard Kindle:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.json
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.sig
```

The registry is RSA-SHA256 signed and stores SHA-256 serial hashes. Kobo accepts active entries with `kobo`, `ghostguard`, `ghostguard-kobo`, or `ultimate` entitlement. A successfully verified registry is cached for up to 7 days for offline use.

`GhostGuard - Start` requests Wi-Fi autoconnect and uses the signed cache first; if no usable cache exists, it attempts an online sync automatically.

## Profile V5 flow

```text
GhostGuard - Start
        |
        v
CALIBRATION / LEARN
        |
        v
PENDING_APPROVAL
        | GhostGuard - Activate Profile
        v
PROBATION (2 Shadow-only sessions)
        | GhostGuard - Start
        v
PROBATION_PASSED
(PROTECT_ELIGIBLE=1, PROTECT_ACTIVE=0)
```

If the controller fingerprint changes, learned data is archived and the profile safely returns to calibration.

## Build

Requirements: Go 1.22+, a C compiler, `zip`, `tar`, and `gzip`.

```sh
make test
make package
make koboroot
```

Outputs for this milestone:

```text
dist/GhostGuard-Kobo-v0.8.2.zip
dist/GhostGuard-Kobo-v0.8.2-KoboRoot.tgz
```

CI verifies classifier logic, Profile V5 lifecycle, signed-registry validation, ARMv7/AArch64 verifier builds, exact five-item NickelMenu UX, package integrity, and KoboRoot archive safety.

## Optional shell OneClick

For devices with KTerm/SSH:

```sh
wget -qO /tmp/ggk-oneclick.sh \
  https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/DCPRO_GhostGuard_Kobo_OneClick.sh \
  && sh /tmp/ggk-oneclick.sh
```

## Safety

v0.8.2 is still Shadow-only from the touch-blocking perspective. `PROBATION_PASSED` only marks the profile eligible for a later Protect release. This version never grabs or suppresses touchscreen input.

## Distribution/security boundary

This is proprietary DCPRO software. Never commit private registry signing keys, raw customer serial databases, or customer datasets.
