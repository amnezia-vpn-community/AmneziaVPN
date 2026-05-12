"""Screen interaction utilities using pyautogui + OpenCV.

All public functions are side-effect-free except for the ones that
actually move the mouse or take screenshots (clearly named).
"""

from __future__ import annotations

import time
import types
from pathlib import Path
from typing import NamedTuple

import cv2
import numpy as np
import structlog

log = structlog.get_logger(__name__)


def _get_pyautogui() -> types.ModuleType:
    """Lazy import of pyautogui — deferred because importing it requires DISPLAY."""
    import importlib

    pag = importlib.import_module("pyautogui")
    setattr(pag, "FAILSAFE", False)  # noqa: B010
    setattr(pag, "PAUSE", 0.05)  # noqa: B010
    return pag


class MatchResult(NamedTuple):
    """Result of a template matching operation."""

    found: bool
    x: int
    y: int
    confidence: float
    template_path: Path


def find_image(
    template_path: Path | str,
    region: tuple[int, int, int, int] | None = None,
    confidence: float = 0.8,
    *,
    grayscale: bool = True,
) -> MatchResult:
    """Locate *template_path* on the current screen using OpenCV template matching.

    Args:
        template_path: Path to the template PNG image to search for.
        region: Optional bounding box ``(left, top, width, height)`` to restrict
                the search area.  When *None* the entire screen is searched.
        confidence: Minimum normalised cross-correlation score in [0, 1].
                    Matches below this value are rejected.
        grayscale: Whether to perform matching in grayscale (faster, usually sufficient).

    Returns:
        A :class:`MatchResult` whose ``found`` field is *True* when a match was found
        above the confidence threshold.  ``x`` and ``y`` are the **centre** pixel
        coordinates of the best match in **screen space** (not region-relative).
    """
    template_path = Path(template_path)
    if not template_path.exists():
        log.warning("template_not_found", path=str(template_path))
        return MatchResult(found=False, x=0, y=0, confidence=0.0, template_path=template_path)

    # Take screenshot of region or full screen
    import pyscreenshot as pyscreenshot_mod

    if region is not None:
        left, top, width, height = region
        screenshot_pil = pyscreenshot_mod.grab(bbox=(left, top, left + width, top + height))
        offset_x, offset_y = left, top
    else:
        screenshot_pil = pyscreenshot_mod.grab()
        offset_x, offset_y = 0, 0

    # Convert PIL → numpy array — use Any to avoid ndarray dtype gymnastics
    screenshot_np: np.ndarray[tuple[int, ...], np.dtype[np.uint8]] = np.asarray(
        screenshot_pil, dtype=np.uint8
    )
    template_raw: np.ndarray[tuple[int, ...], np.dtype[np.uint8]] | None = cv2.imread(  # type: ignore[assignment]
        str(template_path), cv2.IMREAD_COLOR
    )

    if template_raw is None:
        log.error("template_load_failed", path=str(template_path))
        return MatchResult(found=False, x=0, y=0, confidence=0.0, template_path=template_path)

    template_np: np.ndarray[tuple[int, ...], np.dtype[np.uint8]] = template_raw

    if grayscale:
        screenshot_gray = cv2.cvtColor(screenshot_np, cv2.COLOR_RGB2GRAY)
        template_gray = cv2.cvtColor(template_np, cv2.COLOR_BGR2GRAY)
        result = cv2.matchTemplate(screenshot_gray, template_gray, cv2.TM_CCOEFF_NORMED)
    else:
        screenshot_bgr = cv2.cvtColor(screenshot_np, cv2.COLOR_RGB2BGR)
        result = cv2.matchTemplate(screenshot_bgr, template_np, cv2.TM_CCOEFF_NORMED)

    _, max_val, _, max_loc = cv2.minMaxLoc(result)
    th, tw = template_np.shape[:2]
    # Centre of the best match (screen-space coordinates)
    cx = offset_x + max_loc[0] + tw // 2
    cy = offset_y + max_loc[1] + th // 2

    found = float(max_val) >= confidence
    match = MatchResult(
        found=found, x=cx, y=cy, confidence=float(max_val), template_path=template_path
    )
    log.debug(
        "template_match",
        template=template_path.name,
        found=found,
        confidence=round(float(max_val), 4),
        center=(cx, cy),
    )
    return match


def wait_for_image(
    template_path: Path | str,
    timeout: float = 30.0,
    interval: float = 0.5,
    region: tuple[int, int, int, int] | None = None,
    confidence: float = 0.8,
) -> MatchResult:
    """Poll the screen until *template_path* appears or *timeout* elapses.

    Args:
        template_path: Path to the template image.
        timeout: Maximum seconds to wait.
        interval: Seconds between polls.
        region: Optional search region.
        confidence: Minimum confidence for a positive match.

    Returns:
        :class:`MatchResult` — ``found`` is *False* if the timeout was reached.
    """
    deadline = time.monotonic() + timeout
    log.info("wait_for_image", template=Path(template_path).name, timeout=timeout)
    while time.monotonic() < deadline:
        match = find_image(template_path, region=region, confidence=confidence)
        if match.found:
            log.info("image_found", template=Path(template_path).name, confidence=match.confidence)
            return match
        time.sleep(interval)
    log.warning("image_not_found_timeout", template=Path(template_path).name, timeout=timeout)
    return MatchResult(found=False, x=0, y=0, confidence=0.0, template_path=Path(template_path))


def click_at(
    x: int,
    y: int,
    button: str = "left",
    delay: float = 0.1,
    *,
    double: bool = False,
) -> None:
    """Move the mouse to *(x, y)* and click.

    Args:
        x: Screen X coordinate (pixels from left edge).
        y: Screen Y coordinate (pixels from top edge).
        button: Mouse button — ``'left'``, ``'right'``, or ``'middle'``.
        delay: Seconds to pause after the click.
        double: Whether to double-click.
    """
    log.debug("click", x=x, y=y, button=button, double=double)
    pag = _get_pyautogui()
    pag.moveTo(x, y, duration=0.2)
    if double:
        pag.doubleClick(x, y, button=button)
    else:
        pag.click(x, y, button=button)
    time.sleep(delay)


def click_image(
    template_path: Path | str,
    confidence: float = 0.8,
    region: tuple[int, int, int, int] | None = None,
    button: str = "left",
    delay: float = 0.1,
) -> bool:
    """Find *template_path* on screen and click its centre.

    Returns *True* on success, *False* if the image was not found.
    """
    match = find_image(template_path, region=region, confidence=confidence)
    if not match.found:
        log.warning("click_image_not_found", template=Path(template_path).name)
        return False
    click_at(match.x, match.y, button=button, delay=delay)
    return True


def screenshot(
    name: str,
    artifact_dir: Path,
    region: tuple[int, int, int, int] | None = None,
) -> Path:
    """Capture the current screen (or *region*) and save it as an artifact.

    The file is written to ``{artifact_dir}/screenshots/{name}.png``.
    The directory is created if it does not exist.

    Args:
        name: Base name for the screenshot file (without extension).
        artifact_dir: Root artifact directory (from :attr:`~amnezia_tests.config.Settings.artifact_dir`).
        region: Optional ``(left, top, width, height)`` to capture only part of the screen.

    Returns:
        Path to the saved PNG file.
    """
    import pyscreenshot as pyscreenshot_mod

    save_dir = artifact_dir / "screenshots"
    save_dir.mkdir(parents=True, exist_ok=True)
    dest = save_dir / f"{name}.png"

    if region is not None:
        left, top, width, height = region
        img = pyscreenshot_mod.grab(bbox=(left, top, left + width, top + height))
    else:
        img = pyscreenshot_mod.grab()

    img.save(dest)
    log.info("screenshot_saved", path=str(dest))
    return dest


def screen_mean_brightness(path: Path) -> float:
    """Return the mean pixel brightness (0-255) of a saved screenshot.

    Useful for asserting the screen is not black (mean > threshold).
    """
    img = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
    if img is None:
        raise FileNotFoundError(f"Cannot read image: {path}")
    return float(np.mean(img))


def type_text(text: str, interval: float = 0.05) -> None:
    """Type *text* using pyautogui with inter-key *interval* seconds."""
    log.debug("type_text", length=len(text))
    _get_pyautogui().write(text, interval=interval)


def press_key(key: str) -> None:
    """Press a single key by name (e.g. 'enter', 'tab', 'escape')."""
    log.debug("press_key", key=key)
    _get_pyautogui().press(key)


def hotkey(*keys: str) -> None:
    """Press a key combination (e.g. hotkey('ctrl', 'a'))."""
    log.debug("hotkey", keys=keys)
    _get_pyautogui().hotkey(*keys)
