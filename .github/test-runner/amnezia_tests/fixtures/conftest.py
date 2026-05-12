"""Top-level pytest fixtures shared across all test suites.

Import hierarchy:
  conftest.py (this file) → suites/l1_sanity, suites/l2_smoke, etc.

All fixtures here use ``autouse=False`` unless they are truly universal.
"""

from __future__ import annotations

import os
import subprocess
import time
from collections.abc import Generator
from pathlib import Path

import pytest
import structlog

from amnezia_tests.config import settings
from amnezia_tests.utils import screen

log = structlog.get_logger(__name__)


# ── Logging configuration ─────────────────────────────────────────────────
def _configure_structlog() -> None:
    """Configure structlog for test output."""
    structlog.configure(
        processors=[
            structlog.stdlib.add_log_level,
            structlog.dev.ConsoleRenderer(colors=False),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(20),  # INFO
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
    )


_configure_structlog()


# ── Artifact directory ────────────────────────────────────────────────────


@pytest.fixture(scope="session")
def artifact_dir() -> Path:
    """Return the root artifact directory, creating it if necessary.

    Controlled by :attr:`~amnezia_tests.config.Settings.artifact_dir`.
    """
    d = settings.artifact_dir
    d.mkdir(parents=True, exist_ok=True)
    (d / "screenshots").mkdir(exist_ok=True)
    (d / "logs").mkdir(exist_ok=True)
    log.info("artifact_dir_ready", path=str(d))
    return d


# ── Xvfb display fixture ─────────────────────────────────────────────────


class XvfbProcess:
    """Wrapper around a running Xvfb process."""

    def __init__(self, display: str, geometry: str, pid: int) -> None:
        self.display = display
        self.geometry = geometry
        self.pid = pid

    def __repr__(self) -> str:
        return f"XvfbProcess(display={self.display!r}, pid={self.pid})"


@pytest.fixture(scope="session")
def xvfb_display() -> Generator[XvfbProcess, None, None]:
    """Start an Xvfb virtual display for the duration of the test session.

    If the DISPLAY environment variable is already set (e.g. inside the
    linux-runner container where start-runner.sh already started Xvfb),
    this fixture reuses the existing display and does NOT start a new Xvfb.

    Yields:
        :class:`XvfbProcess` with display and geometry info.
    """
    existing_display = os.environ.get("DISPLAY", "")

    if existing_display:
        log.info("xvfb_reuse_existing", display=existing_display)
        yield XvfbProcess(
            display=existing_display,
            geometry=settings.screen_geometry,
            pid=-1,  # unknown PID — we didn't start it
        )
        return

    display = settings.display
    geometry = settings.screen_geometry
    display_num = display.lstrip(":")

    # Remove stale lock files
    _cleanup_xvfb_locks(display_num)

    log.info("xvfb_start", display=display, geometry=geometry)
    proc = subprocess.Popen(
        [
            "Xvfb",
            display,
            "-screen",
            "0",
            geometry,
            "-ac",
            "+extension",
            "GLX",
            "+extension",
            "RANDR",
            "+render",
            "-noreset",
            "-dpi",
            "96",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    os.environ["DISPLAY"] = display

    # Wait for Xvfb to be ready (up to 30 s)
    ready = _wait_for_xvfb(display, timeout=30)
    if not ready:
        proc.terminate()
        raise RuntimeError(f"Xvfb did not start within 30 s on display {display}")

    log.info("xvfb_ready", display=display, pid=proc.pid)
    xvfb = XvfbProcess(display=display, geometry=geometry, pid=proc.pid)

    yield xvfb

    log.info("xvfb_teardown", display=display)
    proc.terminate()
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()
    _cleanup_xvfb_locks(display_num)


def _cleanup_xvfb_locks(display_num: str) -> None:
    """Remove stale Xvfb lock files for *display_num*."""
    lock = Path(f"/tmp/.X{display_num}-lock")
    socket_path = Path(f"/tmp/.X11-unix/X{display_num}")
    for p in (lock, socket_path):
        if p.exists():
            p.unlink(missing_ok=True)
            log.debug("removed_stale_lock", path=str(p))


def _wait_for_xvfb(display: str, timeout: float = 30.0) -> bool:
    """Return True when Xvfb on *display* is ready to accept connections."""
    env = {**os.environ, "DISPLAY": display}
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = subprocess.run(
            ["xdotool", "getdisplaygeometry"],
            env=env,
            capture_output=True,
        )
        if result.returncode == 0:
            return True
        time.sleep(0.5)
    return False


# ── Screenshot-on-failure ─────────────────────────────────────────────────


@pytest.fixture(autouse=True)
def screenshot_on_fail(
    request: pytest.FixtureRequest, artifact_dir: Path
) -> Generator[None, None, None]:
    """Automatically capture a screenshot when a test fails.

    Only captures if the DISPLAY environment variable is set (i.e. Xvfb
    is available).  Silently skips in purely headless/unit test contexts.
    """
    yield

    failed = request.node.rep_call.failed if hasattr(request.node, "rep_call") else False
    if failed and os.environ.get("DISPLAY"):
        name = f"FAIL_{request.node.name}"
        try:
            path = screen.screenshot(name, artifact_dir)
            log.warning("screenshot_on_fail", test=request.node.name, path=str(path))
        except Exception as exc:
            log.warning("screenshot_on_fail_error", exc=str(exc))


@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(
    item: pytest.Item,
    call: pytest.CallInfo[None],
) -> Generator[None, None, None]:
    """Attach call outcome to the request node so screenshot_on_fail can access it."""
    outcome = yield
    rep = outcome.get_result()  # type: ignore[attr-defined]
    setattr(item, "rep_" + rep.when, rep)


# ── Temp directory per test ────────────────────────────────────────────────


@pytest.fixture()
def test_tmp_dir(tmp_path: Path) -> Path:
    """Return a unique temporary directory for each test."""
    return tmp_path


# ── Build artifact (downloaded .bin) ─────────────────────────────────────


@pytest.fixture(scope="session")
def downloaded_bin(tmp_path_factory: pytest.TempPathFactory) -> Path:
    """Download the AmneziaVPN installer artifact and return a path to the .bin.

    Handles two artifact types:
    - ``.bin``: self-extracting installer — downloaded directly.
    - ``.tar``: archive containing ``AmneziaVPN_Linux_Installer.bin`` — extracted automatically.

    The file is stored in a session-scoped temp dir so multiple tests
    can share it without re-downloading.

    Controlled by :attr:`~amnezia_tests.config.Settings.build_url`.
    """
    import tarfile

    from amnezia_tests.utils.installer import download_build, make_executable

    dest_dir: Path = tmp_path_factory.mktemp("amnezia-bin")
    url = settings.build_url
    filename = url.split("/")[-1] or "AmneziaVPN.bin"
    downloaded = dest_dir / filename

    # Support local file paths (for CI with pre-downloaded artifacts)
    if url.startswith(("http://", "https://")):
        log.info("downloading_build", url=url, dest=str(downloaded))
        download_build(url, downloaded, expected_sha256=settings.build_sha256)
    else:
        # Local path — just copy/symlink it
        import shutil as _shutil

        local_path = Path(url)
        if not local_path.exists():
            raise FileNotFoundError(f"AMNEZIA_BUILD_URL points to missing local file: {local_path}")
        _shutil.copy2(local_path, downloaded)
        log.info("copied_local_build", src=str(local_path), dest=str(downloaded))

    # If the download is a .tar archive, extract the .bin from it
    if downloaded.suffix == ".tar" or tarfile.is_tarfile(downloaded):
        log.info("extracting_tar", tar=str(downloaded))
        with tarfile.open(downloaded, "r:*") as tf:
            # Find the .bin member
            bin_member = next(
                (m for m in tf.getmembers() if m.name.endswith(".bin")), None
            )
            if bin_member is None:
                raise FileNotFoundError(
                    f"No .bin file found inside tar archive: {downloaded}. "
                    f"Members: {[m.name for m in tf.getmembers()]}"
                )
            tf.extract(bin_member, dest_dir, filter="data")
            extracted = dest_dir / bin_member.name
        log.info("tar_extracted", bin=str(extracted))
        make_executable(extracted)
        return extracted

    make_executable(downloaded)
    return downloaded
