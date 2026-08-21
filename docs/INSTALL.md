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

v0.8.0-foundation is still Shadow-only. Do not enable EVIOCGRAB/uinput by
patching constants in the legacy observer.
