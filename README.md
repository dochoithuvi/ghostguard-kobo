# DCPRO GhostGuard Kobo

GhostGuard for Kobo e-readers. This repository is both the Kobo source tree and the public online distribution source.

## Current milestone

**v0.8.3 Protect Beta**

- Fixes the `Learning: 100%` but Profile V5 still `CALIBRATION` bug by making live `contacts.csv` authoritative when it is newer than the observer snapshot.
- Controller Fingerprint + Profile V5 lifecycle.
- Five-item NickelMenu UX only.
- Shared signed GhostGuard Kindle/Kobo license registry.
- One-file `KoboRoot.tgz` install/update.
- Real guarded Protect path: physical evdev -> 10 ms quarantine -> classifier -> uinput -> Nickel.
- EVIOCGRAB is attempted only after the virtual touchscreen exists and the supervisor verifies Nickel has opened it.
- `SYN_DROPPED`, uinput write/read faults, process exit, or missing uinput leave/release the physical input fail-open.

## Customer menu

```text
GhostGuard - Status
GhostGuard - Start
GhostGuard - Activate Profile
GhostGuard - Stop
GhostGuard - Report
```

`GhostGuard - Start` chooses automatically:

```text
CALIBRATION                  -> LEARN
PENDING_APPROVAL             -> SHADOW
PROBATION                    -> SHADOW
PROBATION_PASSED             -> PROTECT
```

## Profile / Protect flow

```text
Start -> LEARN
  -> enough live data
PENDING_APPROVAL
  -> Activate Profile
PROBATION 0/2
  -> two completed Shadow sessions
PROBATION_PASSED
  -> Start
PROTECT
  -> create capability-cloned uinput touchscreen
  -> wait until Nickel has opened virtual input
  -> arm EVIOCGRAB
  -> quarantine first 10 ms
  -> high-confidence ultra-short ghost: DROP
  -> normal/long/multitouch: ALLOW to uinput
```

Protect never arms merely because a config flag says so. `PROBATION_PASSED`, `PROTECT_ELIGIBLE=1`, a working uinput device, and verified Nickel consumption are all required.

## Status

Status reports live touch counts, baseline, Watch/Suspect/Candidate telemetry, last-touch risk, Protect state, blocked count, and fail-open reason. `PROTECT_STATUS.ggstate` exposes conditions such as `ACTIVE`, `UINPUT_UNAVAILABLE`, `NICKEL_VIRTUAL_NOT_OPEN`, `SYN_DROPPED_FAIL_OPEN`, and `UINPUT_WRITE_FAILED_FAIL_OPEN`.

## Recommended install: one file

Stable endpoint:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/KoboRoot.tgz
```

Copy without extracting to:

```text
KOBOeReader/.kobo/KoboRoot.tgz
```

Safely eject the Kobo. The normal Kobo update mechanism installs/reboots. Learned Profile V5 and signed license cache are not bundled in the archive, so updates preserve customer state.

## Shared GhostGuard license

Kobo uses the same signed registry as GhostGuard Kindle:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.json
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.sig
```

The registry is RSA-SHA256 signed and keyed by SHA-256 serial hashes. Active `kobo`, `ghostguard`, `ghostguard-kobo`, or `ultimate` entitlement is accepted.

## Build

Requirements: Go 1.22+, clang + lld, host C compiler, Python 3, `zip`, `tar`, `gzip`.

```sh
make test
make native-binaries
make package
make koboroot
```

Outputs:

```text
dist/GhostGuard-Kobo-v0.8.3.zip
dist/GhostGuard-Kobo-v0.8.3-KoboRoot.tgz
```

CI cross-builds the native ARMv7/AArch64 Protect engine from source and applies the safety hardening transform before compilation. It also checks Profile V5 lifecycle, the live-readiness regression, independent evidence families, five-menu UX, shared-license verification, and KoboRoot integrity.

## Safety boundary

Protect Beta intentionally blocks only contacts that end inside the 10 ms quarantine window and meet the high-confidence `WOULD_DROP` gate with at least two independent evidence families. Multitouch and contacts that survive the quarantine window are forwarded conservatively. Once a contact has been released to Nickel, v0.8.3 does not attempt to retract it.

This is proprietary DCPRO software. Never commit private registry signing keys, raw customer serial databases, or customer datasets.
