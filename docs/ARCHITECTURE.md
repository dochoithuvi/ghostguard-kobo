# Architecture direction

## Stable reference

`legacy/v0.7.3/` keeps the proven observer binaries and reference notes for
regression analysis. The obsolete v0.7.3 shared-secret verifier and signing
secret are intentionally excluded from this public repository. v0.8+ uses only
the Ed25519 public-key verification design.

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

Planned state machine:

```text
CALIBRATION
  -> READY
  -> PENDING_APPROVAL
  -> APPROVED
  -> PROBATION
  -> PROTECT
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
