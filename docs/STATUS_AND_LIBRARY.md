# Status and Kobo library cleanup

GhostGuard Kobo v0.8.2.1 keeps the five-item customer menu while improving two areas.

## Learning status

`GhostGuard - Status` shows:

- engine state and automatic internal mode;
- license state/reason;
- Profile V5 state;
- learning percentage;
- observed touches vs required touches;
- baseline samples vs required baseline;
- incomplete-data percentage vs the allowed maximum;
- ghost candidate count when present;
- probation progress;
- the next recommended customer action.

The progress percentage is the conservative minimum of touch-count progress and baseline-count progress. Profile V5 readiness remains authoritative; the percentage is customer UX and does not bypass readiness gates.

## Runtime files in My Books

Modern Kobo firmware may index text files under hidden `.adds` folders. GhostGuard therefore archives customer/runtime text state to private extensions when the engine is idle:

- `profile_v5.txt` -> `profile_v5.ggstate`
- `profile.txt` -> `observer_profile.ggdata`
- `LICENSE_STATUS.txt` -> `LICENSE_STATUS.ggstate`
- `KOBO_DEVICE_ID.txt` -> `KOBO_DEVICE_ID.ggstate`
- `LAST_ACTION.txt` -> `LAST_ACTION.ggstate`
- `RUNTIME_FAULT.txt` -> `RUNTIME_FAULT.ggstate`

The customer action wrapper restores legacy native filenames only when an action requires them. `GhostGuard - Stop` archives the files again and asks Nickel to rescan books, removing stale GhostGuard cards from My Books.

Diagnostic reports are moved to `/mnt/onboard/.kobo/GhostGuard_Reports` after creation so their text files are not exposed as books.

No changes are made to the customer's `Kobo eReader.conf`.
