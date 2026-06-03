#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]

SOURCE_SUFFIXES = {".cpp", ".h", ".hpp", ".mm", ".rep"}
SKIP_PREFIXES = (
    "client/3rd/",
    "client/android/",
    "client/tests/",
)

COMMAND_SINK_PATTERNS = (
    re.compile(r"\bQProcess\b"),
    re.compile(r"\bstartDetached\s*\("),
    re.compile(r"\brunScript\s*\("),
    re.compile(r"\breplaceVars\s*\("),
    re.compile(r"\bbash\s+-c\b"),
    re.compile(r"\bsh\s+-c\b"),
    re.compile(r"\bpowershell\b"),
    re.compile(r"\b-command\b"),
)

REVIEWED_SINK_FILES = {
    "client/core/configurators/ikev2Configurator.cpp",
    "client/core/configurators/openVpnConfigurator.cpp",
    "client/core/configurators/wireguardConfigurator.cpp",
    "client/core/configurators/xrayConfigurator.cpp",
    "client/core/controllers/selfhosted/installController.cpp",
    "client/core/controllers/selfhosted/installController.h",
    "client/core/controllers/selfhosted/usersController.cpp",
    "client/core/installers/sftpInstaller.cpp",
    "client/core/installers/torInstaller.cpp",
    "client/core/protocols/ikev2VpnProtocolWindows.cpp",
    "client/core/protocols/ikev2VpnProtocolWindows.h",
    "client/core/protocols/openVpnProtocol.cpp",
    "client/core/protocols/wireGuardProtocol.cpp",
    "client/core/protocols/wireGuardProtocol.h",
    "client/core/protocols/xrayProtocol.cpp",
    "client/core/protocols/xrayProtocol.h",
    "client/core/utils/selfhosted/sshSession.cpp",
    "client/core/utils/selfhosted/sshSession.h",
    "client/core/utils/utilities.cpp",
    "client/platforms/linux/daemon/linuxdaemon.cpp",
    "client/platforms/linux/daemon/linuxfirewall.cpp",
    "client/platforms/linux/daemon/linuxroutemonitor.cpp",
    "client/platforms/linux/daemon/wireguardutilslinux.cpp",
    "client/platforms/linux/daemon/wireguardutilslinux.h",
    "client/platforms/linux/linuxdependencies.cpp",
    "client/platforms/macos/daemon/macosdaemon.cpp",
    "client/platforms/macos/daemon/macosfirewall.cpp",
    "client/platforms/macos/daemon/macosroutemonitor.cpp",
    "client/platforms/macos/daemon/wireguardutilsmacos.cpp",
    "client/platforms/macos/daemon/wireguardutilsmacos.h",
    "client/platforms/macos/macosnetworkwatcher.mm",
    "client/platforms/windows/daemon/dnsutilswindows.cpp",
    "client/ui/controllers/selfhosted/installUiController.h",
    "client/ui/utils/macosUtil.mm",
    "client/ui/utils/qAutoStart.cpp",
    "ipc/ipc_process_interface.rep",
    "ipc/ipcserverprocess.cpp",
    "ipc/ipcserverprocess.h",
    "service/server/localserver.h",
    "service/server/router_linux.cpp",
    "service/server/router_mac.cpp",
    "service/server/router_win.cpp",
    "service/server/tapcontroller_win.cpp",
    "service/src/qtservice.cpp",
    "service/src/qtservice_unix.cpp",
    "service/src/qtservice_win.cpp",
}


def tracked_paths() -> list[Path]:
    result = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return [ROOT / line for line in result.stdout.splitlines()]


def is_scanned_source(path: Path) -> bool:
    rel = path.relative_to(ROOT).as_posix()
    return path.suffix in SOURCE_SUFFIXES and not rel.startswith(SKIP_PREFIXES)


def has_command_sink(path: Path) -> bool:
    text = path.read_text(encoding="utf-8", errors="ignore")
    return any(pattern.search(text) for pattern in COMMAND_SINK_PATTERNS)


def main() -> int:
    found = {
        path.relative_to(ROOT).as_posix()
        for path in tracked_paths()
        if is_scanned_source(path) and has_command_sink(path)
    }

    unknown = sorted(found - REVIEWED_SINK_FILES)
    stale = sorted(REVIEWED_SINK_FILES - found)

    if unknown or stale:
        if unknown:
            print("Unreviewed command/process sink files:", file=sys.stderr)
            for path in unknown:
                print(f"  + {path}", file=sys.stderr)
        if stale:
            print("Stale command/process sink inventory entries:", file=sys.stderr)
            for path in stale:
                print(f"  - {path}", file=sys.stderr)
        print(
            "Update REVIEWED_SINK_FILES only after static security review of the changed sink surface.",
            file=sys.stderr,
        )
        return 1

    print(f"Command/process sink inventory static check passed ({len(found)} reviewed files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
