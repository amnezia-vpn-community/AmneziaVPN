"""TC-01 · L1 · Binary Sanity

Verifies that the AmneziaVPN .bin installer:
  1. Is downloadable from the configured URL.
  2. Is not empty / truncated (size > 1 MB).
  3. Is executable (chmod +x succeeds, file is a valid ELF or self-extracting script).
  4. Responds to ``--help`` or ``--version`` with exit code 0 *or* a known
     self-extractor exit code (Qt IFW installers often exit 1 from --help on
     some builds, but must not crash with SIGSEGV/SIGABRT).

This test does NOT install AmneziaVPN — it only inspects the binary.
No root access or Xvfb display is required.
"""

from __future__ import annotations

import os
import stat
from pathlib import Path

import pytest

from amnezia_tests.config import settings

pytestmark = [pytest.mark.l1]

# Qt Installer Framework --help / --version exit codes vary across builds.
# Accept 0 and 1 (IFW often prints help but exits 1).
# Explicitly reject negative codes (signals) and codes > 1.
_ACCEPTABLE_EXIT_CODES = {0, 1}


class TestBinarySanity:
    """TC-01: AmneziaVPN installer binary sanity checks."""

    def test_file_downloaded(self, downloaded_bin: Path) -> None:
        """Installer file must exist at the expected path."""
        assert downloaded_bin.exists(), f"Installer not found at {downloaded_bin}"

    def test_file_size_minimum(self, downloaded_bin: Path) -> None:
        """Installer must be at least 1 MB (guards against truncated downloads)."""
        size = downloaded_bin.stat().st_size
        min_size = 1024 * 1024  # 1 MB
        assert size >= min_size, (
            f"Installer is suspiciously small: {size} bytes < {min_size} minimum. "
            "The download may be truncated or the URL is wrong."
        )

    def test_file_is_executable(self, downloaded_bin: Path) -> None:
        """Installer must have execute permission bits set."""
        mode = stat.S_IMODE(downloaded_bin.stat().st_mode)
        assert mode & stat.S_IXUSR, f"Installer is not executable: mode={oct(mode)}"

    def test_file_is_elf_or_script(self, downloaded_bin: Path) -> None:
        """Installer must start with an ELF magic number or a shell shebang.

        AmneziaVPN Linux installers are Qt IFW self-extractors that begin
        with a shell script stub followed by a 7-zip payload.  The first
        bytes are typically ``#!/bin/sh`` or the ELF magic ``\\x7fELF``.
        """
        with open(downloaded_bin, "rb") as f:
            header = f.read(4)

        is_elf = header == b"\x7fELF"
        is_shell = downloaded_bin.read_bytes()[:100].lstrip().startswith(b"#!")

        assert is_elf or is_shell, (
            f"Installer does not start with ELF magic or shell shebang. "
            f"First 4 bytes: {header!r}. "
            "File may be corrupt or the URL points to the wrong artifact."
        )

    def test_help_or_version_exit_code(self, downloaded_bin: Path) -> None:
        """Running installer with ``--help`` or ``--version`` must not crash.

        Acceptable exit codes: 0 (success) or 1 (Qt IFW style help-then-exit).
        Signal terminations (negative codes on POSIX, e.g. -11 for SIGSEGV) fail.
        """
        import subprocess

        # Try --version first, fall back to --help
        for flag in ("--version", "--help"):
            result = subprocess.run(
                [str(downloaded_bin), flag],
                capture_output=True,
                text=True,
                timeout=30,
                env={**os.environ, "DISPLAY": ""},  # no display needed
            )
            code = result.returncode
            if code in _ACCEPTABLE_EXIT_CODES:
                # Success — at least one flag worked acceptably
                return

        # Neither flag gave an acceptable code — fail with details
        pytest.fail(
            f"Installer --version/--help returned unexpected exit code: {code}. "
            f"stdout={result.stdout[:200]!r} stderr={result.stderr[:200]!r}"
        )

    def test_version_output_contains_digits(self, downloaded_bin: Path) -> None:
        """Version output (if any) should contain digit characters resembling a version number."""
        import subprocess

        result = subprocess.run(
            [str(downloaded_bin), "--version"],
            capture_output=True,
            text=True,
            timeout=30,
            env={**os.environ, "DISPLAY": ""},
        )
        combined = result.stdout + result.stderr
        if not combined.strip():
            pytest.skip("--version produced no output — skipping version content check")

        has_digits = any(ch.isdigit() for ch in combined)
        assert has_digits, f"--version output contains no digits. Output: {combined[:300]!r}"

    def test_sha256_if_configured(self, downloaded_bin: Path) -> None:
        """If AMNEZIA_BUILD_SHA256 is set, the downloaded file must match it."""
        expected = settings.build_sha256
        if not expected:
            pytest.skip("AMNEZIA_BUILD_SHA256 not configured — skipping checksum verification")

        import hashlib

        sha256 = hashlib.sha256()
        with open(downloaded_bin, "rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                sha256.update(chunk)

        actual = sha256.hexdigest()
        assert actual == expected.lower(), (
            f"SHA-256 mismatch!\n  expected: {expected.lower()}\n  actual:   {actual}"
        )
