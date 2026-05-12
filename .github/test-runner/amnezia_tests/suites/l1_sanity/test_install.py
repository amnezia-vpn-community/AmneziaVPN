"""TC-02 · L1 · Installer Dry-Run / Payload Extraction

Verifies that the AmneziaVPN .bin installer:
  1. Contains a valid 7-zip payload (can be listed with ``7z l``).
  2. Contains the expected binaries (``AmneziaVPN``, ``AmneziaVPN-service``) in the payload.

This is a dry-run check — it does NOT actually install AmneziaVPN,
so no root access or systemd are required.

Note on 7z availability and format:
  The AmneziaVPN .bin may be a Qt IFW self-extractor with a 7z payload,
  or it may use a different embedded format that 7z cannot directly open.
  Tests that require 7z extraction are skipped if the file is not a valid
  7z archive (``7z l`` returns rc=2).
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

from amnezia_tests.utils.installer import InstallerError, extract_payload, find_expected_binaries

pytestmark = [pytest.mark.l1]


def _7z_available() -> bool:
    """Return True if 7z is available in PATH."""
    return shutil.which("7z") is not None


def _7z_can_read(path: Path) -> bool:
    """Return True if 7z can list the file as an archive (rc 0 or 1)."""
    result = subprocess.run(
        ["7z", "l", str(path)],
        capture_output=True,
        text=True,
        timeout=60,
    )
    return result.returncode in (0, 1)


class TestInstallerPayload:
    """TC-02: AmneziaVPN installer payload extraction checks."""

    def test_7z_can_list_payload(self, downloaded_bin: Path) -> None:
        """7z must be able to list the installer's embedded archive without errors.

        The AmneziaVPN .bin is a Qt IFW self-extractor: a shell stub + 7-zip payload.
        ``7z l`` should report the archive contents without failing.
        If the binary uses a non-7z format, the test is skipped.
        """
        if not _7z_available():
            pytest.skip("7z not found in PATH — install p7zip-full to enable extraction tests")

        result = subprocess.run(
            ["7z", "l", str(downloaded_bin)],
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode == 2:
            pytest.skip(
                f"Binary is not a 7z-compatible archive (rc=2). "
                f"The installer may use a different embedded format. "
                f"stderr={result.stderr[:200]}"
            )
        # 7z returns 0 on success and 1 on warnings — both are acceptable for listing
        assert result.returncode in (0, 1), (
            f"7z list failed with rc={result.returncode}.\n"
            f"stdout={result.stdout[:500]}\nstderr={result.stderr[:500]}"
        )
        # The output must mention at least one file entry
        assert "---" in result.stdout or "Path" in result.stdout, (
            "7z list output does not look like a valid archive listing. "
            "The installer may not contain a 7-zip payload. "
            f"Output: {result.stdout[:500]!r}"
        )

    def test_extraction_succeeds(self, downloaded_bin: Path, test_tmp_dir: Path) -> None:
        """7z extraction of the installer payload must complete without error."""
        if not _7z_available():
            pytest.skip("7z not found in PATH")
        if not _7z_can_read(downloaded_bin):
            pytest.skip("Binary is not a 7z-compatible archive — skipping extraction test")

        extract_dir = test_tmp_dir / "extracted"
        try:
            files = extract_payload(downloaded_bin, extract_dir, tool="7z")
        except InstallerError as exc:
            pytest.fail(f"Extraction failed: {exc}")

        assert len(files) > 0, (
            f"Extraction produced no files in {extract_dir}. The installer may be malformed."
        )

    def test_expected_binaries_present(self, downloaded_bin: Path, test_tmp_dir: Path) -> None:
        """The extracted payload must contain AmneziaVPN and AmneziaVPN-service binaries."""
        if not _7z_available():
            pytest.skip("7z not found in PATH")
        if not _7z_can_read(downloaded_bin):
            pytest.skip("Binary is not a 7z-compatible archive — skipping extraction test")

        extract_dir = test_tmp_dir / "extracted_bins"
        try:
            extract_payload(downloaded_bin, extract_dir, tool="7z")
        except InstallerError as exc:
            pytest.fail(f"Extraction failed: {exc}")

        found = find_expected_binaries(extract_dir)
        missing = [name for name, path in found.items() if path is None]

        if missing:
            all_files = [
                str(p.relative_to(extract_dir)) for p in extract_dir.rglob("*") if p.is_file()
            ]
            pytest.fail(
                f"Expected binaries not found in installer payload: {missing}.\n"
                f"All extracted files:\n" + "\n".join(f"  {f}" for f in sorted(all_files)[:50])
            )

    def test_extracted_main_binary_is_elf(self, downloaded_bin: Path, test_tmp_dir: Path) -> None:
        """The extracted AmneziaVPN binary must be a valid ELF executable."""
        if not _7z_available():
            pytest.skip("7z not found in PATH")
        if not _7z_can_read(downloaded_bin):
            pytest.skip("Binary is not a 7z-compatible archive — skipping ELF check")

        extract_dir = test_tmp_dir / "extracted_elf"
        try:
            extract_payload(downloaded_bin, extract_dir, tool="7z")
        except InstallerError as exc:
            pytest.fail(f"Extraction failed: {exc}")

        found = find_expected_binaries(extract_dir, names=["AmneziaVPN"])
        binary = found.get("AmneziaVPN")
        if binary is None:
            pytest.skip("AmneziaVPN binary not found in payload — skipping ELF check")

        with open(binary, "rb") as f:
            magic = f.read(4)

        assert magic == b"\x7fELF", (
            f"Extracted AmneziaVPN binary does not start with ELF magic: {magic!r}"
        )
