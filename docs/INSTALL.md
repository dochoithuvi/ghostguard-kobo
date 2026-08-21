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
6. Kobo will process the package through its normal update mechanism and reboot automatically.
7. After boot, open `GG · Status`, then start with `GG · Learn` or `GG · Shadow`.

The archive installs the GhostGuard runtime into `/mnt/onboard/.adds/ghostguard/` and its NickelMenu configuration into `/mnt/onboard/.adds/nm/ghostguard`.

Updates are profile-safe: the published `KoboRoot.tgz` intentionally excludes `profile_v5.txt`, `online_licenses.json`, `online_licenses.sig`, `online_license_sync_state`, and other learned/runtime state. Existing data therefore remains in place when a newer package overwrites the runtime files.

### NickelMenu prerequisite

GhostGuard's menu entries require a compatible NickelMenu installation. GhostGuard does not bundle or overwrite NickelMenu itself. This matters especially on newer Kobo firmware because NickelMenu compatibility can vary by firmware version.

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

No separate Kobo `license.key` is required.

Kobo uses the same signed online GhostGuard license registry as Kindle:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.json
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.sig
```

Add or renew the Kobo serial in the existing GhostGuard license database. Active entries with `kobo`, `ghostguard`, `ghostguard-kobo`, or `ultimate` entitlement are accepted after RSA-SHA256 registry verification.

A successfully verified registry is cached for up to 7 days for offline use. A fresh signed registry that revokes, expires, suspends, disables, or omits the device is denied immediately and does not fall back to stale cache.

## Manual ZIP install

If both KoboRoot and shell OneClick are unavailable:

1. Stop GhostGuard if an older build is running.
2. Download the current ZIP artifact referenced by `manifest.online.json`.
3. Verify its SHA256 against the manifest when possible.
4. Extract the ZIP to the root of the Kobo USB drive so `.adds/ghostguard/` and `.adds/nm/ghostguard` are placed correctly.
5. Safely eject/reboot as required by NickelMenu.
6. Open `GG · Status` and confirm `License: OK`.

When updating manually, preserve `.adds/ghostguard/data/` because it contains Profile V5 state and the signed license-registry cache.

## Profile V5 first run

1. Run `GG · Learn`.
2. Use the device normally until `GG · Status` shows `Profile V5: PENDING_APPROVAL`.
3. Select `GG · Approve Profile`.
4. Complete two normal Shadow sessions.
5. Status will show `PROBATION_PASSED`.

`PROBATION_PASSED` only means the profile is eligible for a later Protect Beta. In v0.8.1, Protect remains OFF: no EVIOCGRAB and no uinput touch suppression.
