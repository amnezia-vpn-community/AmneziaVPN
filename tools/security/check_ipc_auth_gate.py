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
    ROOT / "client/daemon/daemonlocalserver.cpp",
]


def extract_function_body(text: str, name: str) -> str | None:
    match = re.search(rf"\b{name}\s*\([^)]*\)\s*\{{", text)
    if not match:
        return None

    depth = 0
    for index in range(match.end() - 1, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[match.end():index]

    return None


def main() -> int:
    errors: list[str] = []

    ipc_h = (ROOT / "ipc/ipc.h").read_text(encoding="utf-8")
    auth_body = extract_function_body(ipc_h, "authorizeLocalIpcSocket")
    if auth_body is None:
        errors.append("ipc/ipc.h: missing authorizeLocalIpcSocket helper")
    elif re.search(
        r"\bAMNEZIAVPN_IPC_AUTH_UID\b[\s\S]*?\.isEmpty\s*\(\s*\)\s*\)\s*\{?\s*return\s+true\s*;",
        auth_body,
    ):
        errors.append("ipc/ipc.h: authorizeLocalIpcSocket defaults open when AMNEZIAVPN_IPC_AUTH_UID is empty")

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

    daemon_server = (ROOT / "client/daemon/daemonlocalserver.cpp").read_text(encoding="utf-8")
    if "WorldAccessOption" in daemon_server and "authorizeLocalIpcSocket" not in daemon_server:
        errors.append("client/daemon/daemonlocalserver.cpp: WorldAccessOption listener lacks IPC auth gate")

    service_unit = (ROOT / "deploy/data/linux/AmneziaVPN.service").read_text(encoding="utf-8")
    if "EnvironmentFile=/etc/AmneziaVPN/ipc-auth.env" not in service_unit:
        errors.append("deploy/data/linux/AmneziaVPN.service: missing IPC auth EnvironmentFile contract")

    post_install = (ROOT / "deploy/data/linux/post_install.sh").read_text(encoding="utf-8")
    if "AMNEZIAVPN_IPC_AUTH_UID" not in post_install or "refusing to start service" not in post_install:
        errors.append("deploy/data/linux/post_install.sh: missing fail-closed IPC auth uid provisioning")

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print("IPC auth gate static checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
