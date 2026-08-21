# GhostGuard Kobo v0.7.3 reference

This directory intentionally contains only the proven v0.7.3 native observer
binaries and non-secret reference notes.

The original v0.7.3 offline license verifier used a shared signing secret on the
device. That verifier and secret are **not published** in this public repository.
v0.8+ replaces it with Ed25519 verification where Kobo contains only a public
key.

Do not use this directory as an install package. Use the current `package/` tree
or a tagged release artifact instead.
