#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
TARGETS = [
    ROOT / "service/server/localserver.cpp",
    ROOT / "ipc/ipcserver.cpp",
    ROOT / "ipc/ipc.h",
    ROOT / "client/core/utils/ipcClient.cpp",
]


def main() -> int:
    errors: list[str] = []

    ipc_h = (ROOT / "ipc/ipc.h").read_text(encoding="utf-8")
    if "authorizeLocalIpcSocket" not in ipc_h:
        errors.append("ipc/ipc.h: missing authorizeLocalIpcSocket helper")

    raw_handoff = re.compile(r"addHostSideConnection\s*\(\s*[^;\n]*nextPendingConnection\s*\(")
    for path in TARGETS:
        rel = path.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        if raw_handoff.search(text):
            errors.append(f"{rel}: raw nextPendingConnection() handoff to QtRO")

    for rel in ("service/server/localserver.cpp", "ipc/ipcserver.cpp"):
        text = (ROOT / rel).read_text(encoding="utf-8")
        if "WorldAccessOption" in text and "authorizeLocalIpcSocket" not in text:
            errors.append(f"{rel}: WorldAccessOption listener lacks IPC auth gate")

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print("IPC auth gate static checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
