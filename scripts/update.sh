#!/bin/sh
# DCPRO GhostGuard Kobo online updater - v0.8.3.3
# Fetches the release manifest metadata, verifies KoboRoot SHA256, stages it in
# .kobo, then optionally reboots. Existing GhostGuard data is untouched.
set -u

BASE=/mnt/onboard/.adds/ghostguard
DATA="$BASE/data"
RUN="$BASE/runtime"
KOBO=/mnt/onboard/.kobo
VERSION_FILE="$BASE/VERSION"
STATE="$DATA/UPDATE_STATUS.ggstate"
STAGED="$RUN/UPDATE_STAGED"
MANIFEST_TMP="$RUN/manifest.online.json.tmp"
PACKAGE_TMP="$KOBO/KoboRoot.tgz.part"
PACKAGE_FINAL="$KOBO/KoboRoot.tgz"
RAW_BASE=https://raw.githubusercontent.com/dochoithuvi/ghostguard-kobo/main
CDN_BASE=https://cdn.jsdelivr.net/gh/dochoithuvi/ghostguard-kobo@main
CHECK_TTL=3600

mkdir -p "$DATA" "$RUN" "$KOBO" 2>/dev/null || true

current_version() {
    sed -n 's/^Version:[[:space:]]*//p' "$VERSION_FILE" 2>/dev/null | head -n 1
}

now_epoch() {
    date '+%s' 2>/dev/null || echo 0
}

kv() {
    F="$1"; K="$2"
    [ -r "$F" ] && sed -n "s/^${K}=//p" "$F" 2>/dev/null | head -n 1
}

write_state() {
    CUR="$1"; LATEST="$2"; AVAIL="$3"; RESULT="$4"; MSG="$5"; SHA="${6:-}"
    TMP="$STATE.tmp.$$"
    {
        echo "CURRENT=$CUR"
        echo "LATEST=$LATEST"
        echo "UPDATE_AVAILABLE=$AVAIL"
        echo "RESULT=$RESULT"
        echo "MESSAGE=$MSG"
        echo "KOBOROOT_SHA256=$SHA"
        echo "CHECK_EPOCH=$(now_epoch)"
    } > "$TMP" && mv -f "$TMP" "$STATE"
}

run_download() {
    URL="$1"; OUT="$2"
    rm -f "$OUT" 2>/dev/null || true
    if command -v curl >/dev/null 2>&1; then
        curl -L -f -sS --connect-timeout 10 --max-time 60 -o "$OUT" "$URL" 2>/dev/null && [ -s "$OUT" ] && return 0
        rm -f "$OUT" 2>/dev/null || true
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q -T 20 -t 2 -O "$OUT" "$URL" 2>/dev/null && [ -s "$OUT" ] && return 0
        rm -f "$OUT" 2>/dev/null || true
        wget -q -O "$OUT" "$URL" 2>/dev/null && [ -s "$OUT" ] && return 0
        rm -f "$OUT" 2>/dev/null || true
    fi
    if command -v busybox >/dev/null 2>&1; then
        busybox wget -q -T 20 -t 2 -O "$OUT" "$URL" 2>/dev/null && [ -s "$OUT" ] && return 0
        rm -f "$OUT" 2>/dev/null || true
        busybox wget -q -O "$OUT" "$URL" 2>/dev/null && [ -s "$OUT" ] && return 0
        rm -f "$OUT" 2>/dev/null || true
    fi
    return 1
}

fetch_rel() {
    REL="$1"; OUT="$2"
    run_download "$RAW_BASE/$REL" "$OUT" && return 0
    run_download "$CDN_BASE/$REL" "$OUT"
}

manifest_value() {
    K="$1"; F="$2"
    sed -n "s/.*\"${K}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$F" 2>/dev/null | head -n 1
}

sha256_file() {
    F="$1"
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$F" 2>/dev/null | awk '{print $1}'; return; fi
    if command -v busybox >/dev/null 2>&1; then busybox sha256sum "$F" 2>/dev/null | awk '{print $1}'; return; fi
    echo ""
}

version_gt() {
    A="$1"; B="$2"
    awk -v A="$A" -v B="$B" 'BEGIN {
      na=split(A,a,"."); nb=split(B,b,"."); n=(na>nb?na:nb);
      for(i=1;i<=n;i++){x=a[i]+0;y=b[i]+0;if(x>y)exit 0;if(x<y)exit 1}
      exit 1
    }'
}

load_manifest() {
    fetch_rel manifest.online.json "$MANIFEST_TMP" || return 1
    LATEST="$(manifest_value version "$MANIFEST_TMP")"
    EXPECTED="$(manifest_value koboroot_sha256 "$MANIFEST_TMP")"
    STABLE="$(manifest_value koboroot_stable "$MANIFEST_TMP")"
    [ -n "$STABLE" ] || STABLE=KoboRoot.tgz
    case "$EXPECTED" in
        [0-9a-fA-F][0-9a-fA-F]*) ;;
        *) return 2 ;;
    esac
    [ "${#EXPECTED}" -eq 64 ] 2>/dev/null || return 2
    [ -n "$LATEST" ] || return 2
    return 0
}

check_update() {
    CUR="$(current_version)"; [ -n "$CUR" ] || CUR=unknown
    if ! load_manifest; then
        write_state "$CUR" "unknown" 0 NETWORK_ERROR "Không tải/xác thực được manifest cập nhật."
        rm -f "$MANIFEST_TMP" 2>/dev/null || true
        return 1
    fi
    if version_gt "$LATEST" "$CUR"; then
        AVAIL=1; RES=AVAILABLE; MSG="Có bản mới $LATEST"
    else
        AVAIL=0; RES=CURRENT; MSG="Đang dùng bản mới nhất."
    fi
    write_state "$CUR" "$LATEST" "$AVAIL" "$RES" "$MSG" "$EXPECTED"
    rm -f "$MANIFEST_TMP" 2>/dev/null || true
    return 0
}

check_if_stale() {
    NOW="$(now_epoch)"; LAST="$(kv "$STATE" CHECK_EPOCH)"
    case "$NOW" in ''|*[!0-9]*) check_update >/dev/null 2>&1 || true; return 0;; esac
    case "$LAST" in ''|*[!0-9]*) check_update >/dev/null 2>&1 || true; return 0;; esac
    AGE=$((NOW - LAST))
    [ "$AGE" -ge 0 ] 2>/dev/null && [ "$AGE" -lt "$CHECK_TTL" ] 2>/dev/null && return 0
    check_update >/dev/null 2>&1 || true
}

install_update() {
    CUR="$(current_version)"; [ -n "$CUR" ] || CUR=unknown
    rm -f "$STAGED" "$PACKAGE_TMP" 2>/dev/null || true
    echo "GhostGuard Online Update"
    echo "Current: $CUR"
    echo "Đang kiểm tra bản mới..."
    if ! load_manifest; then
        write_state "$CUR" "unknown" 0 NETWORK_ERROR "Không tải/xác thực được manifest cập nhật."
        echo "Lỗi: không tải được manifest từ GitHub/mirror."
        rm -f "$MANIFEST_TMP" 2>/dev/null || true
        return 3
    fi
    echo "Latest: $LATEST"
    if ! version_gt "$LATEST" "$CUR"; then
        write_state "$CUR" "$LATEST" 0 CURRENT "Đang dùng bản mới nhất." "$EXPECTED"
        echo "GhostGuard đã là bản mới nhất."
        rm -f "$MANIFEST_TMP" 2>/dev/null || true
        return 0
    fi

    echo "Đang tải GhostGuard $LATEST..."
    if ! fetch_rel "$STABLE" "$PACKAGE_TMP"; then
        write_state "$CUR" "$LATEST" 1 DOWNLOAD_FAILED "Tải KoboRoot.tgz thất bại." "$EXPECTED"
        echo "Lỗi: tải KoboRoot.tgz thất bại. Bản hiện tại không thay đổi."
        rm -f "$PACKAGE_TMP" "$MANIFEST_TMP" 2>/dev/null || true
        return 4
    fi

    ACTUAL="$(sha256_file "$PACKAGE_TMP")"
    if [ -z "$ACTUAL" ]; then
        write_state "$CUR" "$LATEST" 1 SHA_TOOL_MISSING "Thiết bị không có SHA256 verifier." "$EXPECTED"
        echo "Lỗi: không có sha256sum; không cài update chưa xác minh."
        rm -f "$PACKAGE_TMP" "$MANIFEST_TMP" 2>/dev/null || true
        return 5
    fi
    if [ "$ACTUAL" != "$EXPECTED" ]; then
        write_state "$CUR" "$LATEST" 1 SHA_MISMATCH "Checksum không khớp; update bị hủy." "$EXPECTED"
        echo "Lỗi: SHA256 không khớp. Update đã bị hủy."
        rm -f "$PACKAGE_TMP" "$MANIFEST_TMP" 2>/dev/null || true
        return 6
    fi

    sync 2>/dev/null || true
    mv -f "$PACKAGE_TMP" "$PACKAGE_FINAL" || {
        write_state "$CUR" "$LATEST" 1 STAGE_FAILED "Không ghi được .kobo/KoboRoot.tgz." "$EXPECTED"
        echo "Lỗi: không stage được KoboRoot.tgz."
        rm -f "$PACKAGE_TMP" "$MANIFEST_TMP" 2>/dev/null || true
        return 7
    }
    sync 2>/dev/null || true
    echo "$LATEST" > "$STAGED"
    write_state "$CUR" "$LATEST" 1 STAGED "Đã tải và xác minh; Kobo sẽ reboot để cài." "$EXPECTED"
    rm -f "$MANIFEST_TMP" 2>/dev/null || true
    echo "SHA256: OK"
    echo "Đã sẵn sàng cập nhật lên $LATEST."
    echo "Kobo sẽ tự khởi động lại sau vài giây."
    return 0
}

reboot_if_staged() {
    [ -s "$STAGED" ] && [ -s "$PACKAGE_FINAL" ] || return 0
    rm -f "$STAGED" 2>/dev/null || true
    sync 2>/dev/null || true
    sleep 4
    if command -v reboot >/dev/null 2>&1; then reboot; exit 0; fi
    if command -v busybox >/dev/null 2>&1; then busybox reboot; exit 0; fi
    return 1
}

case "${1:-check}" in
    check) check_update ;;
    check-if-stale) check_if_stale ;;
    install|update) install_update ;;
    reboot-if-staged) reboot_if_staged ;;
    status) [ -r "$STATE" ] && cat "$STATE" || echo "RESULT=UNKNOWN" ;;
    *) echo "Usage: $0 {check|check-if-stale|install|reboot-if-staged|status}"; exit 2 ;;
esac
