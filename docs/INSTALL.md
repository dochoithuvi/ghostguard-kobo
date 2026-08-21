# Install / update GhostGuard Kobo

## Recommended: online OneClick

GhostGuard Kobo is distributed from this GitHub repository. From a Kobo shell/KTerm/SSH session, run:

```sh
wget -qO /tmp/ggk-oneclick.sh \
  https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/DCPRO_GhostGuard_Kobo_OneClick.sh \
  && sh /tmp/ggk-oneclick.sh
```

If `curl` is available instead:

```sh
curl -L --fail \
  https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/DCPRO_GhostGuard_Kobo_OneClick.sh \
  -o /tmp/ggk-oneclick.sh \
  && sh /tmp/ggk-oneclick.sh
```

OneClick reads `manifest.online.json`, downloads the current versioned ZIP, validates its SHA256 when the device has a compatible hashing utility, preserves learned/runtime data that must survive an update, installs the runtime and NickelMenu files, and keeps Protect disabled.

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

## Manual package install

If online OneClick is unavailable:

1. Stop GhostGuard if an older build is running.
2. Download the current artifact referenced by `manifest.online.json`.
3. Verify its SHA256 against the manifest when possible.
4. Extract the ZIP to the root of the Kobo USB drive so `.adds/ghostguard/` and `.adds/nm/ghostguard` are placed correctly.
5. Safely eject/reboot as required by NickelMenu.
6. Open `GG · Status` and confirm `License: OK`.
7. Start with `GG · Learn` or `GG · Shadow`.

When updating manually, preserve `.adds/ghostguard/data/` because it contains Profile V5 state and the signed license-registry cache.

## Profile V5 first run

1. Run `GG · Learn`.
2. Use the device normally until `GG · Status` shows `Profile V5: PENDING_APPROVAL`.
3. Select `GG · Approve Profile`.
4. Complete two normal Shadow sessions.
5. Status will show `PROBATION_PASSED`.

`PROBATION_PASSED` only means the profile is eligible for a later Protect Beta. In v0.8.1, Protect remains OFF: no EVIOCGRAB and no uinput touch suppression.
