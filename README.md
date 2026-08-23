# DCPRO GhostGuard Kobo

GhostGuard for Kobo e-readers. This repository is both the Kobo source tree and the public online distribution source.

## Current milestone

**v0.8.3.3 Protect Beta + Online Update**

- Live `contacts.csv` drives Profile V5 readiness when observer snapshots lag.
- Controller Fingerprint + Profile V5 lifecycle.
- Five-item NickelMenu UX only.
- Shared signed GhostGuard Kindle/Kobo license registry.
- One-file `KoboRoot.tgz` first install plus on-device Online Update for later versions.
- Real guarded Protect path: physical evdev -> 10 ms quarantine -> classifier -> uinput -> Nickel.
- EVIOCGRAB is attempted only after the virtual touchscreen exists and the supervisor verifies Nickel has opened it; v0.8.3.2 adds one controlled Nickel rebind when hotplug alone is insufficient.
- `SYN_DROPPED`, uinput write/read faults, process exit, missing uinput, or failed Nickel rebind leave/release the physical input fail-open.

## Customer menu

```text
GhostGuard - Status
GhostGuard - Start
GhostGuard - Activate Profile
GhostGuard - Stop
GhostGuard - Update
```

`GhostGuard - Report` remains available in the backend for diagnostics but is no longer exposed in the customer menu.

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
  -> hotplug / one controlled Nickel rebind if required
  -> verify Nickel opened virtual input
  -> arm EVIOCGRAB
  -> quarantine first 10 ms
  -> high-confidence ultra-short ghost: DROP
  -> normal/long/multitouch: ALLOW to uinput
```

Protect never arms merely because a config flag says so. `PROBATION_PASSED`, `PROTECT_ELIGIBLE=1`, a working uinput device, and verified Nickel consumption are all required.

## Status

Status reports live touch counts, baseline, Watch/Suspect/Candidate telemetry, last-touch risk, Protect state, blocked count and fail-open reason. It also starts a throttled update check in the background and shows cached `Update: Up to date` or `Update: AVAILABLE -> <version>` without blocking the Status popup.

## First install: one file

Stable endpoint:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/KoboRoot.tgz
```

Copy without extracting to:

```text
KOBOeReader/.kobo/KoboRoot.tgz
```

Safely eject the Kobo. The normal Kobo update mechanism installs/reboots. Learned Profile V5 and signed license cache are not bundled in the archive, so updates preserve customer state.

## Later updates: no USB required

After GhostGuard is installed, use:

```text
GhostGuard - Update
```

The updater:

```text
Wi-Fi
  -> fetch manifest.online.json
  -> compare installed/latest version
  -> download KoboRoot.tgz to .kobo/KoboRoot.tgz.part
  -> verify manifest SHA256
  -> atomic rename to .kobo/KoboRoot.tgz
  -> reboot
  -> normal Kobo updater installs the new release
```

If download, SHA verification or staging fails, the currently installed GhostGuard is left untouched. GitHub Raw is primary and jsDelivr is the fallback mirror.

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
dist/GhostGuard-Kobo-v0.8.3.3.zip
dist/GhostGuard-Kobo-v0.8.3.3-KoboRoot.tgz
```

CI cross-builds the native ARMv7/AArch64 Protect engine from source and applies the safety hardening transform before compilation. It also checks Profile V5 lifecycle, live-readiness, independent evidence families, five-menu UX, shared-license verification, Online Update staging markers and KoboRoot integrity.

## Safety boundary

Protect Beta intentionally blocks only contacts that end inside the 10 ms quarantine window and meet the high-confidence `WOULD_DROP` gate with at least two independent evidence families. Multitouch and contacts that survive the quarantine window are forwarded conservatively. Once a contact has been released to Nickel, the current Protect Beta does not attempt to retract it.

This is proprietary DCPRO software. Never commit private registry signing keys, raw customer serial databases or customer datasets.
