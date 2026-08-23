#!/usr/bin/env python3
"""Prepare the shipped Kobo runtime without document-like state filenames.

Source scripts retain a little legacy compatibility for host tests and migration,
but the installed package must never create .txt state while Nickel is running.
"""
from pathlib import Path

ROOT = Path("package/.adds/ghostguard")


def rewrite(path: Path, fn) -> None:
    src = path.read_text()
    out = fn(src)
    if out == src:
        raise SystemExit(f"runtime transform made no change: {path}")
    path.write_text(out)


def core_runtime(src: str) -> str:
    src = src.replace(".txt", ".ggdata")
    src = src.replace("profile_v5.ggdata", "profile_v5.ggstate")
    src = src.replace("LICENSE_STATUS.ggdata", "LICENSE_STATUS.ggstate")
    src = src.replace("KOBO_DEVICE_ID.ggdata", "KOBO_DEVICE_ID.ggstate")
    src = src.replace("RUNTIME_FAULT.ggdata", "RUNTIME_FAULT.ggstate")
    src = src.replace('$DATA/profile.ggdata', '$DATA/observer_profile.ggdata')
    return src


def profile_runtime(src: str) -> str:
    src = src.replace(".txt", ".ggdata")
    src = src.replace("profile_v5.ggdata", "profile_v5.ggstate")
    src = src.replace(
        'OBSERVER_PROFILE="${GG_OBSERVER_PROFILE:-$DATA/profile.ggdata}"',
        'OBSERVER_PROFILE="${GG_OBSERVER_PROFILE:-$DATA/observer_profile.ggdata}"',
    )
    return src


def quick_runtime(src: str) -> str:
    # Status must never block NickelMenu on Profile V5 recomputation or update I/O.
    old = '  [ -x "$PM" ]&&"$PM" sync >/dev/null 2>&1||true\n'
    new = '  if [ -x "$PM" ]; then "$PM" sync >/dev/null 2>&1 & fi\n'
    if old not in src:
        raise SystemExit("nm_quick synchronous sync anchor missing")
    src = src.replace(old, new, 1)
    src = src.replace("GhostGuard Kobo 0.8.3.3 Protect Beta", "GhostGuard Kobo 0.8.3.4 Protect Beta")
    src = src.replace("Đã đủ dữ liệu - chờ kích hoạt", "Đã đủ dữ liệu - Start sẽ tự kích hoạt")
    src = src.replace("Next: GhostGuard - Activate Profile", "Next: GhostGuard - Start (tự kích hoạt Profile).")
    return src


rewrite(ROOT / "ghostguard.sh", core_runtime)
rewrite(ROOT / "profile_manager.sh", profile_runtime)
rewrite(ROOT / "nm_quick.sh", quick_runtime)

for path in (ROOT / "ghostguard.sh", ROOT / "profile_manager.sh"):
    text = path.read_text()
    if ".txt" in text:
        raise SystemExit(f"document-like runtime filename remains in {path}")

print("runtime preparation: private state + auto-activate UX + nonblocking status OK")
