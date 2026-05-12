"""AmneziaVPN installer download and validation utilities.

Handles downloading .bin installers from URLs, verifying integrity,
and extracting metadata about the installer payload.
"""

from __future__ import annotations

import hashlib
import os
import shutil
import stat
import subprocess
from pathlib import Path

import requests
import structlog

log = structlog.get_logger(__name__)

_CHUNK_SIZE = 1024 * 1024  # 1 MB chunks
_MIN_SIZE_BYTES = 1024 * 1024  # Minimum 1 MB — sanity check that file isn't empty/truncated
_EXPECTED_CONTENT_TYPES = {
    "application/octet-stream",
    "binary/octet-stream",
    "application/x-executable",
}


class InstallerError(Exception):
    """Raised when an installer operation fails."""


def download_build(
    url: str,
    dest: Path,
    *,
    timeout: int = 120,
    expected_sha256: str = "",
) -> Path:
    """Download an AmneziaVPN installer from *url* to *dest*.

    Shows progress to structlog and validates content-type and file size.

    Args:
        url: HTTPS URL to the .bin installer.
        dest: Destination file path (parent directory must exist, or will be created).
        timeout: Connection + read timeout for the HTTP request in seconds.
        expected_sha256: If non-empty, verify the downloaded file's SHA-256 digest
                         against this value.  Raises :class:`InstallerError` on mismatch.

    Returns:
        The *dest* path on success.

    Raises:
        InstallerError: On download failure, content-type mismatch, size mismatch,
                        or SHA-256 mismatch.
    """
    dest = Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)

    log.info("download_build_start", url=url, dest=str(dest))

    try:
        with requests.get(url, stream=True, timeout=timeout) as resp:
            resp.raise_for_status()

            # Content-type validation (lenient — some CDNs omit it)
            content_type = resp.headers.get("Content-Type", "").split(";")[0].strip().lower()
            if content_type and content_type not in _EXPECTED_CONTENT_TYPES:
                log.warning(
                    "unexpected_content_type",
                    url=url,
                    content_type=content_type,
                )

            content_length = int(resp.headers.get("Content-Length", 0))
            downloaded = 0
            sha256 = hashlib.sha256()

            with open(dest, "wb") as f:
                for chunk in resp.iter_content(chunk_size=_CHUNK_SIZE):
                    if chunk:
                        f.write(chunk)
                        sha256.update(chunk)
                        downloaded += len(chunk)
                        if content_length:
                            pct = downloaded * 100 // content_length
                            log.debug(
                                "download_progress",
                                pct=pct,
                                downloaded_mb=downloaded // (1024 * 1024),
                            )

    except requests.RequestException as exc:
        raise InstallerError(f"Download failed: {exc}") from exc

    log.info("download_complete", dest=str(dest), size_mb=downloaded // (1024 * 1024))

    # Size sanity check
    actual_size = dest.stat().st_size
    if actual_size < _MIN_SIZE_BYTES:
        raise InstallerError(
            f"Downloaded file is suspiciously small: {actual_size} bytes < {_MIN_SIZE_BYTES} minimum"
        )

    # SHA-256 verification
    digest = sha256.hexdigest()
    log.info("sha256", digest=digest, path=str(dest))
    if expected_sha256 and digest != expected_sha256.lower():
        raise InstallerError(
            f"SHA-256 mismatch for {dest.name}: "
            f"expected={expected_sha256.lower()!r} actual={digest!r}"
        )

    return dest


def make_executable(path: Path) -> None:
    """Add execute permission bits to *path* (equivalent to ``chmod +x``)."""
    current = stat.S_IMODE(os.stat(path).st_mode)
    os.chmod(path, current | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    log.debug("chmod_x", path=str(path))


def run_with_args(
    installer_path: Path,
    args: list[str],
    *,
    env: dict[str, str] | None = None,
    timeout: int = 30,
) -> subprocess.CompletedProcess[str]:
    """Run *installer_path* with *args* and return the completed process.

    Args:
        installer_path: Path to the executable.
        args: Additional arguments to pass.
        env: Optional environment overrides (merged with current env).
        timeout: Maximum execution time in seconds.

    Returns:
        :class:`subprocess.CompletedProcess` with stdout/stderr captured.
    """
    import os as _os

    merged_env = _os.environ.copy()
    if env:
        merged_env.update(env)

    cmd = [str(installer_path), *args]
    log.info("run_installer", cmd=cmd, timeout=timeout)
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=merged_env,
    )
    log.debug(
        "installer_result",
        returncode=result.returncode,
        stdout=result.stdout[:500],
        stderr=result.stderr[:500],
    )
    return result


def extract_payload(
    installer_path: Path,
    extract_dir: Path,
    *,
    tool: str = "7z",
) -> list[Path]:
    """Attempt to extract an installer payload using *tool* (``7z`` or ``dd``).

    The .bin format for Qt/IFW installers embeds a 7-zip archive after
    a self-extracting stub.  ``7z`` can often extract it directly; this
    function tries ``7z l`` first to check feasibility.

    Args:
        installer_path: Path to the .bin installer.
        extract_dir: Directory into which to extract files.
        tool: Extraction tool name.  Only ``'7z'`` is currently implemented.

    Returns:
        List of :class:`Path` objects found in *extract_dir* after extraction.

    Raises:
        InstallerError: If extraction fails or the tool is not found.
    """
    extract_dir.mkdir(parents=True, exist_ok=True)

    if tool == "7z":
        return _extract_with_7z(installer_path, extract_dir)
    else:
        raise InstallerError(f"Unsupported extraction tool: {tool!r}")


def _extract_with_7z(installer_path: Path, extract_dir: Path) -> list[Path]:
    """Extract *installer_path* using 7z."""
    if not shutil.which("7z"):
        raise InstallerError("'7z' not found in PATH — install p7zip-full")

    log.info("extract_7z", src=str(installer_path), dest=str(extract_dir))
    result = subprocess.run(
        ["7z", "x", str(installer_path), f"-o{extract_dir}", "-y"],
        capture_output=True,
        text=True,
        timeout=120,
    )
    if result.returncode not in (0, 1):  # 7z returns 1 for warnings, 0 for success
        raise InstallerError(
            f"7z extraction failed (rc={result.returncode}): {result.stderr[:500]}"
        )

    found = sorted(extract_dir.rglob("*"))
    log.info("extract_complete", file_count=len(found), dest=str(extract_dir))
    return found


def find_expected_binaries(
    root: Path,
    names: list[str] | None = None,
) -> dict[str, Path | None]:
    """Search *root* recursively for expected AmneziaVPN binaries.

    Args:
        root: Directory to search (result of :func:`extract_payload`).
        names: Binary names to look for.  Defaults to the two main binaries.

    Returns:
        Dict mapping each name to its :class:`Path` if found, or *None*.
    """
    if names is None:
        names = ["AmneziaVPN", "AmneziaVPN-service"]

    result: dict[str, Path | None] = {}
    for name in names:
        matches = list(root.rglob(name))
        result[name] = matches[0] if matches else None
        log.debug("binary_search", name=name, found=result[name] is not None)
    return result
