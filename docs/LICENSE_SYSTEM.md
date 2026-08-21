# GhostGuard Kobo License System v4

## Goal

Keep the familiar per-device `license.key` workflow while preventing a copied
repository/package from being able to mint new licenses.

## Trust model

GhostGuard Kobo v4 uses Ed25519 public-key signatures.

- The **private key** exists only in the administrator package and is never
  committed to `ghostguard-kobo`.
- The **public key** is embedded in the static Kobo verifier binaries.
- `license_bridge.sh` does not contain a signing secret.

This removes the major weakness of the earlier shared-secret SHA-256 scheme,
where possession of the manager/source could reveal the signing secret.

## `license.key` format

```text
# DCPRO GhostGuard Kobo offline license
license_format=4
serial=N123456789012
customer=Example Customer
issued_at=2026-08-21
expire=2026-12-31
features=ghostguard-kobo,ultimate
license_id=DCPRO-20260821-1A2B3C4D
sig_alg=ed25519
sig=<base64 Ed25519 signature>
```

Canonical signed payload:

```text
4|SERIAL|CUSTOMER|ISSUED_AT|EXPIRE|FEATURES|LICENSE_ID|ed25519
```

Serial is normalized to uppercase ASCII alphanumeric characters before signing
and verification.

## Device validation

`license_bridge.sh` selects one of:

```text
bin/gg-license-verify-armv7
bin/gg-license-verify-aarch64
```

The verifier checks:

1. required fields occur exactly once;
2. `license_format=4` and `sig_alg=ed25519`;
3. license serial matches the current Kobo serial;
4. feature grants include `ghostguard-kobo`, `ghostguard`, `kobo`, or `ultimate`;
5. issue/expiry dates are valid;
6. system date is not before `issued_at`;
7. system date has not rolled back behind the last successful validation;
8. Ed25519 signature is valid.

The verifier fails closed for license errors. The touch engine itself remains
fail-open with respect to input handling.

## Admin key handling

Keep the generated `private_key.txt` outside the Git repository and outside any
public release folder. Back it up offline. If it is lost, existing licenses keep
working but new licenses cannot be issued with the same trust anchor. If it is
leaked, rotate the key and ship a verifier update containing the new public key.
