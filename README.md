# DCPRO Kobo Tools Repository


DCPRO GhostGuard for Kobo e-readers.

This repository is intentionally separate from the Kindle GhostGuard codebase.
Kobo uses a different runtime stack (Nickel/NickelMenu, evdev controllers,
ARMv7/AArch64 binaries, and future uinput-based protection), so the two product
lines can evolve and be tested independently.

## Current repository milestone

**v0.8.0-foundation**

- Keeps the proven v0.7.3 native observer binaries under `legacy/v0.7.3/` for regression/reference use; the obsolete shared-secret license verifier and its secret are intentionally not published.
- Ships the proven v0.7.3 native observer binaries for ARMv7/AArch64 in the current package tree.
- Keeps **Protect disabled**: no EVIOCGRAB, no uinput, fail-open behavior remains.
- Fixes supervisor/controller input-device detection drift.
- Adds a modular classifier core for Profile V5 work.
- Fixes independent-evidence accounting: FAST and BASE_SHORT belong to one
  TIMING family and cannot satisfy the 2-family gate by themselves.
- Adds symmetric edge-distance support when absolute controller bounds are known.
- Adds Ed25519-signed, serial-bound `license.key` verification. No signing
  secret/private key is shipped in this repository.

## Runtime paths on Kobo

```text
/mnt/onboard/.adds/ghostguard/
  ghostguard.sh
  supervisor.sh
  license_bridge.sh
  license.key                  # customer-specific; never commit
  bin/
    ghostguardd-armv7
    ghostguardd-aarch64
    gg-license-verify-armv7
    gg-license-verify-aarch64
  data/
  runtime/

/mnt/onboard/.adds/nm/ghostguard
```

## License flow

The user experience stays close to GhostGuard Kindle: each device receives a
customer-specific `license.key` bound to the Kobo serial.

The cryptography is different: Kobo v0.8 uses **Ed25519** signatures.

- Admin side: private key signs licenses.
- Kobo side: verifier binaries contain only the public key.
- Copying a valid `license.key` to another Kobo fails with `SERIAL_MISMATCH`.
- Changing license fields invalidates the signature.
- Clock rollback after a successful validation is rejected using
  `data/license_last_date`.

See `docs/LICENSE_SYSTEM.md`.

## Build

Requirements for development host: Go 1.22+ and a C compiler for unit tests.

```sh
make test
make license-verifiers
make package
```

`make package` produces `dist/GhostGuard-Kobo-v0.8.0-foundation.zip`.

## Safety status

The shipped touch engine is still SHADOW-only. The `src/` modular core is the
basis for Profile V5 and the later quarantine/uinput Protect engine. Do not turn
Protect on by simply changing a flag in the v0.7.3 observer binary.

## Repository layout

```text
cmd/                    Go license verifier/admin source
config/                 runtime defaults + public verification key
include/ + src/          modular GhostGuard core under development
legacy/v0.7.3/           observer binaries/reference notes only
nickelmenu/              NickelMenu config source
package/                 files copied to Kobo for current build
profiles/                future controller presets
scripts/                 shell controller/supervisor/license bridge
tests/                   host-side classifier tests
tools/                   dataset analysis helpers
```

## Public-source distribution

The repository is public for inspection and development visibility, like the
Kindle GhostGuard workflow. It is **not** an open license grant: see `LICENSE`.
Never commit the private signing key, customer `license.key` files, or customer
datasets.
