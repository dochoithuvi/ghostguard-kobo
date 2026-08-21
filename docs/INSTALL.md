# Install / update GhostGuard Kobo

## Recommended: one-file KoboRoot install

This is the simplest GhostGuard Kobo installation path and does not require SSH, KTerm, or typing shell commands.

1. Download the stable file:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/KoboRoot.tgz
```

2. Connect the Kobo to the computer by USB.
3. Show hidden folders if necessary.
4. Copy the file exactly here, without extracting or renaming it:

```text
KOBOeReader/.kobo/KoboRoot.tgz
```

5. Safely eject/disconnect the Kobo.
6. Kobo processes the package through its normal update mechanism and reboots automatically.
7. After boot, open `GhostGuard - Status` and then use `GhostGuard - Start`.

The archive installs the GhostGuard runtime into `/mnt/onboard/.adds/ghostguard/` and its NickelMenu configuration into `/mnt/onboard/.adds/nm/ghostguard`.

Updates are profile-safe: the published `KoboRoot.tgz` intentionally excludes Profile V5 state, signed license cache, and learned/runtime data.

## v0.8.2 customer menu

Only five GhostGuard items are exposed to the user:

```text
GhostGuard - Status
GhostGuard - Start
GhostGuard - Activate Profile
GhostGuard - Stop
GhostGuard - Report
```

`GhostGuard - Start` automatically selects the correct internal mode:

```text
CALIBRATION / no approved profile -> LEARN
PENDING_APPROVAL                 -> SHADOW
PROBATION                        -> SHADOW
PROBATION_PASSED                 -> SHADOW
```

If the controller fingerprint changes, Profile V5 resets safely to calibration and Start learns a new baseline. Users never need to choose Learn or Shadow manually.

When a signed license cache is available, Start validates it locally. If no usable cache exists, Start attempts the shared GhostGuard online registry automatically after NickelMenu requests Wi-Fi autoconnect.

`GhostGuard - Activate Profile` is used only after Status shows `Profile: Ready to activate`. It moves Profile V5 into the two-session Shadow probation stage. Protect remains disabled in v0.8.2.

## NickelMenu prerequisite

GhostGuard's menu entries require a compatible NickelMenu installation. GhostGuard does not bundle or overwrite NickelMenu itself.

## Optional: shell OneClick

If the device already has KTerm/SSH access, the online bootstrap is still available:

```sh
wget -qO /tmp/ggk-oneclick.sh \
  https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/DCPRO_GhostGuard_Kobo_OneClick.sh \
  && sh /tmp/ggk-oneclick.sh
```

OneClick reads `manifest.online.json`, downloads the current versioned ZIP, validates its SHA256 when possible, preserves learned/runtime data, and updates the GhostGuard files.

Installer log:

```text
/mnt/onboard/GhostGuard_Installer.log
```

## License

No separate Kobo `license.key` is required. Kobo uses the same signed online GhostGuard license registry as Kindle:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.json
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.sig
```

Active entries with `kobo`, `ghostguard`, `ghostguard-kobo`, or `ultimate` entitlement are accepted after RSA-SHA256 registry verification. A successfully verified registry is cached for up to 7 days for offline use. A fresh signed registry which revokes, expires, suspends, disables, or omits the device is denied immediately.

## Manual ZIP install

If both KoboRoot and shell OneClick are unavailable, download the ZIP artifact referenced by `manifest.online.json`, verify SHA256 when possible, and extract it to the root of the Kobo USB drive. Preserve `.adds/ghostguard/data/` when updating manually.

## Safety

v0.8.2 remains Shadow-only from the touch-blocking perspective. `PROBATION_PASSED` means the profile is eligible for a later Protect release, but this version still uses no EVIOCGRAB and no uinput touch suppression.
