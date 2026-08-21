# Architecture direction

## Stable reference

`legacy/v0.7.3/` is kept unchanged for reproducibility and regression analysis.
The package currently reuses its proven native observer binaries.

## v0.8 modular core

The first extracted component is the classifier. Evidence is grouped into
independent families:

- TIMING: FAST, BASE_SHORT
- SPATIAL: EDGE
- MOTION: PATH_BURST
- GEOMETRY: TOUCH_MAJOR

A future DROP decision requires score >= 85 and at least two independent
families. FAST + BASE_SHORT alone is not enough, even when their summed score is
high.

## Profile V5 lifecycle

```text
CALIBRATION
  -> PENDING_APPROVAL
  -> PROBATION
  -> PROBATION_PASSED
  -> (future Protect Beta only)
```

Learning never silently enables Protect.

## Protect direction

Protect will not be implemented by merely dropping already-observed events.
The intended design is:

```text
physical touchscreen
  -> EVIOCGRAB
  -> 8-10 ms quarantine buffer
  -> classifier
  -> drop suspicious complete contact OR forward through uinput
  -> Nickel
```

Any sync loss, unsupported protocol, verifier/runtime fault, or watchdog failure
must release the physical device and fail open.

## v0.8.1 Profile V5 control-plane

The low-level observer remains the proven v0.7.3-compatible Shadow binary and
continues to write `data/profile.txt` (observer Profile V4). A separate
`profile_manager.sh` owns `data/profile_v5.txt` and adds lifecycle policy without
changing input handling.

Responsibilities:

- derive a stable controller fingerprint from touchscreen name, phys/uniq, bus
  IDs, input capability masks and uevent data;
- bind Profile V5 to Kobo serial + controller fingerprint;
- archive/reset observer learning if that binding changes;
- evaluate configurable readiness gates;
- transition Learn -> pending approval -> probation -> probation passed;
- keep `PROTECT_ACTIVE=0` throughout v0.8.1.

The supervisor polls the Profile V5 manager while the observer is running. Once
readiness is reached in LEARN mode, it changes the runtime mode to SHADOW and
restarts only the observer child. This is fail-open: no input grab is involved.
