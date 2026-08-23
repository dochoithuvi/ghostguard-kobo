#!/bin/sh
# DCPRO GhostGuard Kobo OneClick installer/updater.
# Downloads the current release from ghostguard-kobo manifest and installs .adds.
set -u

REPO_RAW="https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main"
REPO_MIRROR="https://cdn.jsdelivr.net/gh/dochoithuvi/ghostguard-kobo@main"
TMP="/tmp/ghostguard-kobo-oneclick.$$"
MANIFEST="$TMP/manifest.json"
PKG="$TMP/ghostguard-kobo.zip"
ONBOARD="/mnt/onboard"

cleanup(){ rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
mkdir -p "$TMP" || exit 1

fetch(){
    URL="$1"; OUT="$2"
    if command -v wget >/dev/null 2>&1; then wget -q -O "$OUT" "$URL" && return 0; fi
    if command -v busybox >/dev/null 2>&1; then busybox wget -q -O "$OUT" "$URL" && return 0; fi
    if command -v curl >/dev/null 2>&1; then curl -fsSL "$URL" -o "$OUT" && return 0; fi
    return 1
}

fetch_any(){
    REL="$1"; OUT="$2"
    fetch "$REPO_RAW/$REL" "$OUT" && return 0
    fetch "$REPO_MIRROR/$REL" "$OUT" && return 0
    return 1
}

json_value(){
    K="$1"; F="$2"
    sed -n "s/.*\"${K}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$F" 2>/dev/null | head -n1
}

sha_file(){
    F="$1"
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$F" | awk '{print $1}'; return; fi
    if command -v busybox >/dev/null 2>&1; then busybox sha256sum "$F" 2>/dev/null | awk '{print $1}'; return; fi
    echo ""
}

extract_zip(){
    F="$1"; DEST="$2"
    if command -v unzip >/dev/null 2>&1; then unzip -oq "$F" -d "$DEST" && return 0; fi
    if command -v busybox >/dev/null 2>&1; then busybox unzip -o "$F" -d "$DEST" >/dev/null && return 0; fi
    return 1
}

echo "GhostGuard Kobo OneClick: checking latest release..."
fetch_any "manifest.online.json" "$MANIFEST" || { echo "ERROR: cannot download manifest."; exit 2; }
VERSION="$(json_value version "$MANIFEST")"
ARTIFACT="$(json_value artifact "$MANIFEST")"
EXPECTED="$(json_value sha256 "$MANIFEST")"
[ -n "$VERSION" ] && [ -n "$ARTIFACT" ] || { echo "ERROR: invalid manifest."; exit 3; }

echo "Latest: $VERSION"
fetch_any "$ARTIFACT" "$PKG" || { echo "ERROR: cannot download package."; exit 4; }
if [ -n "$EXPECTED" ]; then
    ACTUAL="$(sha_file "$PKG")"
    [ -n "$ACTUAL" ] || { echo "ERROR: SHA256 unavailable."; exit 5; }
    [ "$ACTUAL" = "$EXPECTED" ] || { echo "ERROR: SHA256 mismatch."; exit 6; }
fi

extract_zip "$PKG" "$ONBOARD" || { echo "ERROR: unzip unavailable/failed."; exit 7; }
chmod +x "$ONBOARD/.adds/ghostguard/"*.sh "$ONBOARD/.adds/ghostguard/bin/"* 2>/dev/null || true
sync

echo "GhostGuard Kobo $VERSION installed/updated."
echo "Open NickelMenu -> GhostGuard - Status."
