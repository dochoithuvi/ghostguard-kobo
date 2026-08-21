# Install / update on Kobo

## Manual install

1. Stop GhostGuard if an older build is running.
2. Extract the release ZIP to the root of the Kobo USB drive.
3. Create a device-specific `license.key` with the admin kit.
4. Copy it to:

```text
/mnt/onboard/.adds/ghostguard/license.key
```

5. Safely eject and reboot if required by your NickelMenu setup.
6. Open `GG · Status` and confirm `License: OK`.
7. Start with `GG · Learn` or `GG · Shadow`.

## Important

v0.8.1-profile-v5 is still Shadow-only. Do not enable EVIOCGRAB/uinput by
patching constants in the legacy observer.

## Profile V5 first run

1. Run `GG · Learn`.
2. Use the device normally until `GG · Status` shows `Profile V5: PENDING_APPROVAL`.
3. Select `GG · Approve Profile`.
4. Complete two normal Shadow sessions (start/use/stop).
5. Status will show `PROBATION_PASSED`; Protect remains OFF in v0.8.1.
