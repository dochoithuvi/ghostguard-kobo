# Profile V5 lifecycle

GhostGuard Kobo v0.8.1 introduces a control profile at:

```text
/mnt/onboard/.adds/ghostguard/data/profile_v5.txt
```

It wraps the v0.7.3-compatible native observer rather than replacing it. The
observer still writes `data/profile.txt`; Profile V5 copies the important
baseline/telemetry values and adds controller identity and lifecycle state.

## Controller fingerprint

The profile is bound to the Kobo serial and to a deterministic fingerprint built
from the active touchscreen's name, phys/uniq values, input bus/vendor/product/
version IDs, capability masks, properties, and uevent information. The event node
number itself is not part of the identity, so `/dev/input/eventX` renumbering does
not invalidate a profile.

If the serial or controller fingerprint changes, GhostGuard archives the existing
Profile V5, observer profile and contact CSV, removes the live observer baseline,
and returns to `CALIBRATION`.

## Readiness

Defaults in `defaults.conf`:

- `PROFILE_READY_BASELINE_MIN=60`
- `PROFILE_READY_CONTACTS_MIN=80`
- `PROFILE_READY_MAX_INCOMPLETE_PCT=25`

When all gates are met and coordinate/average timing data exists, the state moves
to `PENDING_APPROVAL`. The supervisor automatically returns the observer from
LEARN to SHADOW.

## Approval and probation

The user explicitly selects `GG · Approve Profile`. Approval moves directly into
`PROBATION`; it does not activate Protect. Each completed start/stop Shadow
session counts once. After `PROBATION_SESSIONS` (default 2), state becomes
`PROBATION_PASSED` and `PROTECT_ELIGIBLE=1`.

For v0.8.1, these safety invariants remain fixed:

```text
PROTECT_ACTIVE=0
INPUT_GRAB=NEVER
FAIL_OPEN=1
```

A future Protect Beta must explicitly consume `PROTECT_ELIGIBLE=1`; v0.8.1 never
blocks touchscreen events.
