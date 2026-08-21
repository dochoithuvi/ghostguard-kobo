#!/bin/sh
# DCPRO GhostGuard Kobo OneClick v1
# Online bootstrap/update client for the public ghostguard-kobo distribution repo.
# Installs the latest published artifact from manifest.online.json while preserving
# learned data and shared-license cache. Protect is never enabled by this installer.

ROOT=${DCPRO_KOBO_ROOT:-/mnt/onboard}
BASE="$ROOT/.adds/ghostguard"
NM_DIR="$ROOT/.adds/nm"
LOG=${DCPRO_KOBO_INSTALL_LOG:-"$ROOT/GhostGuard_Installer.log"}
TMP=${DCPRO_KOBO_INSTALL_TMP:-"$ROOT/.adds/.ghostguard-oneclick"}
MANIFEST_PRIMARY=${DCPRO_KOBO_MANIFEST_PRIMARY:-https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main/manifest.online.json}
MANIFEST_MIRROR=${DCPRO_KOBO_MANIFEST_MIRROR:-https://cdn.jsdelivr.net/gh/dochoithuvi/ghostguard-kobo@main/manifest.online.json}
RAW_BASE=${DCPRO_KOBO_RAW_BASE:-https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main}
MIRROR_BASE=${DCPRO_KOBO_MIRROR_BASE:-https://cdn.jsdelivr.net/gh/dochoithuvi/ghostguard-kobo@main}

mkdir -p "$(dirname "$LOG")" "$TMP" 2>/dev/null || exit 1
: > "$LOG" 2>/dev/null || true
log(){ printf '%s\n' "$*" >> "$LOG" 2>/dev/null; }
say(){ printf '%s\n' "$*"; log "$*"; }
fail(){ say "ERROR: $*"; exit 1; }

get(){
    U="$1"; O="$2"; rm -f "$O" 2>/dev/null
    case "$U" in
        file://*) cp "${U#file://}" "$O" 2>/dev/null ;;
        /*) cp "$U" "$O" 2>/dev/null ;;
        *)
            if command -v curl >/dev/null 2>&1; then curl -L --fail --silent --show-error "$U" -o "$O"
            elif command -v wget >/dev/null 2>&1; then wget -q -O "$O" "$U"
            else return 127
            fi
            ;;
    esac
}
fetch_with_mirror(){ P="$1"; M="$2"; O="$3"; log "GET $P"; get "$P" "$O" || { log "WARN primary failed; mirror: $M"; get "$M" "$O"; }; }
json_value(){ K="$1"; F="$2"; sed -n 's/.*"'"$K"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$F" | head -n 1; }
hash_file(){
    F="$1"
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$F" | awk '{print $1}'; return 0; fi
    if command -v busybox >/dev/null 2>&1 && busybox sha256sum "$F" >/dev/null 2>&1; then busybox sha256sum "$F" | awk '{print $1}'; return 0; fi
    if command -v openssl >/dev/null 2>&1; then openssl dgst -sha256 "$F" 2>/dev/null | awk '{print $NF}'; return 0; fi
    return 1
}
unpack_zip(){ Z="$1"; D="$2"; rm -rf "$D" 2>/dev/null; mkdir -p "$D" || return 1; command -v unzip >/dev/null 2>&1 && { unzip -q "$Z" -d "$D"; return $?; }; command -v busybox >/dev/null 2>&1 && { busybox unzip -q "$Z" -d "$D"; return $?; }; return 127; }
stop_old(){ [ -f "$BASE/ghostguard.sh" ] && sh "$BASE/ghostguard.sh" stop >> "$LOG" 2>&1 || true; }

MANIFEST="$TMP/manifest.online.json"; PKG="$TMP/package.zip"; STAGE="$TMP/stage"; BACKUP="$TMP/persist"; NEW="$TMP/new-ghostguard"; OLD="$ROOT/.adds/ghostguard.pre-oneclick"
say "GhostGuard Kobo OneClick: checking latest release..."
fetch_with_mirror "$MANIFEST_PRIMARY" "$MANIFEST_MIRROR" "$MANIFEST" || fail "cannot download manifest"
VERSION="$(json_value version "$MANIFEST")"; ARTIFACT="$(json_value artifact "$MANIFEST")"; EXPECTED="$(json_value sha256 "$MANIFEST")"
[ -n "$VERSION" ] || fail "manifest missing version"; [ -n "$ARTIFACT" ] || fail "manifest missing artifact"; [ -n "$EXPECTED" ] || fail "manifest missing sha256"
case "$ARTIFACT" in http://*|https://*|file://*|/*) PRIMARY="$ARTIFACT"; MIRROR="$ARTIFACT" ;; *) PRIMARY="$RAW_BASE/$ARTIFACT"; MIRROR="$MIRROR_BASE/$ARTIFACT" ;; esac
say "Latest: $VERSION"
fetch_with_mirror "$PRIMARY" "$MIRROR" "$PKG" || fail "cannot download artifact"
[ -s "$PKG" ] || fail "artifact is empty"
ACTUAL="$(hash_file "$PKG" 2>/dev/null || true)"
if [ -n "$ACTUAL" ]; then [ "$ACTUAL" = "$EXPECTED" ] || fail "SHA256 mismatch"; log "SHA256 PASS $ACTUAL"; else log "WARN: no SHA256 utility on device; HTTPS + package structure validation only"; fi
unpack_zip "$PKG" "$STAGE" || fail "unzip unavailable or artifact invalid"
SRC="$STAGE/.adds/ghostguard"
[ -f "$SRC/ghostguard.sh" ] || fail "artifact missing ghostguard.sh"; [ -f "$SRC/profile_manager.sh" ] || fail "artifact missing Profile V5 manager"; [ -f "$SRC/bin/ghostguardd-armv7" ] || fail "artifact missing ARMv7 observer"; [ -f "$SRC/bin/ghostguardd-aarch64" ] || fail "artifact missing ARM64 observer"; [ -f "$SRC/bin/gg-license-verify-armv7" ] || fail "artifact missing ARMv7 license verifier"; [ -f "$SRC/bin/gg-license-verify-aarch64" ] || fail "artifact missing ARM64 license verifier"; [ -f "$SRC/VERSION" ] || fail "artifact missing VERSION"; grep -Fq "$VERSION" "$SRC/VERSION" 2>/dev/null || fail "artifact VERSION does not match manifest"
say "Installing $VERSION..."
stop_old
rm -rf "$BACKUP" "$NEW" 2>/dev/null; mkdir -p "$BACKUP" || fail "cannot create backup directory"
[ -d "$BASE/data" ] && cp -Rp "$BASE/data" "$BACKUP/data" 2>/dev/null || true
[ -f "$BASE/SAFE_MODE" ] && cp -p "$BASE/SAFE_MODE" "$BACKUP/SAFE_MODE" 2>/dev/null || true
cp -Rp "$SRC" "$NEW" || fail "cannot stage new GhostGuard directory"
rm -rf "$NEW/data" "$NEW/runtime" 2>/dev/null; mkdir -p "$NEW/data" "$NEW/runtime" || fail "cannot create runtime directories"
[ -d "$BACKUP/data" ] && cp -Rp "$BACKUP/data"/. "$NEW/data"/ 2>/dev/null || true
[ -f "$BACKUP/SAFE_MODE" ] && cp -p "$BACKUP/SAFE_MODE" "$NEW/SAFE_MODE" 2>/dev/null || true
chmod +x "$NEW"/*.sh "$NEW"/bin/ghostguardd-* "$NEW"/bin/gg-license-verify-* 2>/dev/null || true
mkdir -p "$ROOT/.adds" "$NM_DIR" || fail "cannot create .adds directories"
rm -rf "$OLD" 2>/dev/null; [ -d "$BASE" ] && mv "$BASE" "$OLD" || true
if ! mv "$NEW" "$BASE"; then [ -d "$OLD" ] && mv "$OLD" "$BASE" 2>/dev/null || true; fail "cannot activate new version; previous install restored"; fi
if [ -f "$STAGE/.adds/nm/ghostguard" ]; then cp -p "$STAGE/.adds/nm/ghostguard" "$NM_DIR/ghostguard" || { rm -rf "$BASE" 2>/dev/null; [ -d "$OLD" ] && mv "$OLD" "$BASE" 2>/dev/null || true; fail "cannot install NickelMenu config"; }; fi
rm -rf "$OLD" 2>/dev/null || true
say "Installed GhostGuard Kobo $VERSION"
say "License: shared GhostGuard online registry (same as Kindle)."
sh "$BASE/ghostguard.sh" status >> "$LOG" 2>&1 || true
say "Log: $LOG"
exit 0
