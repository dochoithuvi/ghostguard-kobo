# Shared GhostGuard License System

GhostGuard Kobo uses the **same signed online license registry as GhostGuard Kindle**. There is no separate Kobo `license.key` issuance flow.

## Authoritative registry

Primary:

```text
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.json
https://raw.githubusercontent.com/dochoithuvi/ghostguard-kindle/main/licenses/licenses.sig
```

Mirror: the same files through jsDelivr.

The registry is signed with RSA-SHA256. Kobo ships only the same public trust anchors used by Kindle; private signing keys are never present on Kobo or in this repository.

## Device lookup

The Kobo serial is normalized to uppercase alphanumeric form and SHA-256 hashed. That hash is looked up in `entries[].serial_hash`, matching the Kindle privacy model.

A Kobo entitlement is accepted only when:

- the signed registry verifies;
- the serial hash matches this Kobo;
- `status` is active;
- issue/expiry checks pass; and
- features include `kobo`, `ghostguard`, `ghostguard-kobo`, or `ultimate`.

`ultimate` therefore grants the shared GhostGuard product entitlement. Kobo-specific customers may use `kobo,ultimate` in the same database.

## Offline grace

After a successful online sync, Kobo caches the signed registry and signature under `.adds/ghostguard/data/`:

```text
online_licenses.json
online_licenses.sig
online_license_sync_state
license_last_date
```

Default offline grace is 604800 seconds (7 days), matching Kindle. Clock rollback is fail-closed.

A fresh, correctly signed registry that explicitly revokes, expires, disables, suspends or omits a device **never falls back to an older cache**. Cache fallback is only for network/source/verification unavailability.

## Security boundary

Public source may contain verifier code and public RSA keys. Never publish the private registry signing key or raw customer serial database.
