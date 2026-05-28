#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
SOURCE_SUFFIXES = {".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp", ".hxx", ".mm"}
PENDING_SOCKET = re.compile(
    r"(?:\b(?:auto|QLocalSocket)\s*\*?\s*)?(?P<socket>[A-Za-z_]\w*)\s*="
    r"\s*[^;]*\bnextPendingConnection\s*\(\s*\)\s*;"
)
DIRECT_PENDING_HANDOFF = re.compile(
    r"(?:addHostSideConnection|DaemonLocalServerConnection)\s*\([^;{}]*"
    r"\bnextPendingConnection\s*\("
)
AUTH_GUARD = (
    r"if\s*\(\s*!\s*(?:amnezia::)?authorizeLocalIpcSocket\s*\(\s*{socket}\s*,[^)]*\)\s*\)"
    r"\s*\{{[\s\S]*?\breturn\s*;"
)
PRIVILEGED_HANDOFFS = (
    r"addHostSideConnection\s*\(\s*{socket}\s*\)",
    r"DaemonLocalServerConnection\s*\([^;{{}}]*,\s*{socket}\s*\)",
)


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


def tracked_source_paths() -> list[Path]:
    try:
        result = subprocess.run(
            ["git", "-C", str(ROOT), "ls-files"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        paths = (ROOT / line for line in result.stdout.splitlines())
    except (OSError, subprocess.CalledProcessError):
        paths = ROOT.rglob("*")

    return sorted(path for path in paths if path.suffix in SOURCE_SUFFIXES and path.is_file())


def unguarded_pending_socket_handoffs(text: str) -> list[str]:
    errors: list[str] = []
    for match in PENDING_SOCKET.finditer(text):
        socket = match.group("socket")
        search_from = match.end()
        nearest_handoff: re.Match[str] | None = None
        for pattern in PRIVILEGED_HANDOFFS:
            handoff = re.search(pattern.format(socket=re.escape(socket)), text[search_from:])
            if handoff and (nearest_handoff is None or handoff.start() < nearest_handoff.start()):
                nearest_handoff = handoff

        if nearest_handoff is None:
            continue

        handoff_start = search_from + nearest_handoff.start()
        guarded_region = text[search_from:handoff_start]
        if not re.search(AUTH_GUARD.format(socket=re.escape(socket)), guarded_region):
            errors.append(f"{socket}: nextPendingConnection() reaches privileged handoff without fail-closed IPC auth")

    return errors


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

    raw_handoff = re.compile(r"addHostSideConnection\s*\(\s*[\s\S]{0,200}?nextPendingConnection\s*\(")
    world_access_sources: list[Path] = []
    for path in tracked_source_paths():
        rel = path.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        if raw_handoff.search(text) or DIRECT_PENDING_HANDOFF.search(text):
            errors.append(f"{rel}: raw nextPendingConnection() handoff to QtRO")
        if "WorldAccessOption" in text:
            world_access_sources.append(path)
            if "authorizeLocalIpcSocket" not in text:
                errors.append(f"{rel}: WorldAccessOption listener lacks IPC auth gate")
            for handoff_error in unguarded_pending_socket_handoffs(text):
                errors.append(f"{rel}: {handoff_error}")

    if not world_access_sources:
        errors.append("missing WorldAccessOption IPC listeners to guard")

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
