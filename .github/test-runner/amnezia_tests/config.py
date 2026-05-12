"""Runtime configuration via pydantic-settings.

All settings can be overridden via environment variables or a .env file.
Prefix all env vars with AMNEZIA_ (e.g. AMNEZIA_BUILD_URL).
"""

from __future__ import annotations

from pathlib import Path

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Central config for the AmneziaVPN test suite."""

    model_config = SettingsConfigDict(
        env_prefix="AMNEZIA_",
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ── Build artifact ────────────────────────────────────────────────────
    build_url: str = Field(
        default=(
            "https://github.com/amnezia-vpn/amnezia-client/releases/download/"
            "4.8.15.4/AmneziaVPN_4.8.15.4_linux_x64.tar"
        ),
        description=(
            "Full URL to the AmneziaVPN build artifact to test. "
            "Accepts .bin (self-extracting installer) or .tar (archive containing the .bin). "
            "When a .tar is provided, the .bin inside is extracted automatically."
        ),
    )
    build_sha256: str = Field(
        default="",
        description=(
            "Optional expected SHA-256 of the build artifact. "
            "Leave empty to skip checksum verification."
        ),
    )

    # ── Runner identity ───────────────────────────────────────────────────
    runner_id: str = Field(
        default="local",
        description="Unique runner identifier (hostname or CI job ID).",
    )

    # ── Display ───────────────────────────────────────────────────────────
    display: str = Field(
        default=":99",
        description="X11 DISPLAY value (e.g. :99 for Xvfb).",
    )
    resolution: str = Field(
        default="1280x960",
        description="Screen resolution WxH used for Xvfb and template matching.",
    )
    color_depth: int = Field(
        default=24,
        description="Color depth for the virtual display.",
    )

    # ── Artifact storage ──────────────────────────────────────────────────
    artifact_dir: Path = Field(
        default=Path("/tmp/amnezia-artifacts"),
        description="Root directory where test artifacts (screenshots, logs) are stored.",
    )

    # ── Network / VPN ─────────────────────────────────────────────────────
    ip_check_url: str = Field(
        default="https://api.ipify.org",
        description="URL that returns the caller's public IP in plain text.",
    )
    ip_check_timeout: int = Field(
        default=10,
        description="Timeout in seconds for IP-check HTTP requests.",
    )
    ip_check_retries: int = Field(
        default=3,
        description="Number of retry attempts for IP-check requests.",
    )

    # ── Test VPN server (for L3+) ─────────────────────────────────────────
    vpn_config_key: str = Field(
        default="",
        description=(
            "vpn:// URI for the test VPN server config. "
            "Required for TC-02 (import) and TC-03 (connect) tests."
        ),
    )

    # ── Timeouts ──────────────────────────────────────────────────────────
    app_launch_timeout: int = Field(
        default=30,
        description="Seconds to wait for the AmneziaVPN GUI to become visible.",
    )
    connect_timeout: int = Field(
        default=60,
        description="Seconds to wait for VPN connection to establish.",
    )
    disconnect_timeout: int = Field(
        default=30,
        description="Seconds to wait for VPN to disconnect.",
    )

    # ── OpenCV template matching ──────────────────────────────────────────
    template_confidence: float = Field(
        default=0.8,
        ge=0.0,
        le=1.0,
        description="Minimum confidence threshold for OpenCV template matching.",
    )

    # ── Installer options ─────────────────────────────────────────────────
    installer_timeout: int = Field(
        default=120,
        description="Seconds to wait for the .bin installer to complete.",
    )

    @field_validator("resolution")
    @classmethod
    def _validate_resolution(cls, v: str) -> str:
        parts = v.split("x")
        if len(parts) != 2 or not all(p.isdigit() for p in parts):
            raise ValueError(f"resolution must be WxH (e.g. 1280x960), got: {v!r}")
        return v

    @property
    def screen_geometry(self) -> str:
        """Full Xvfb -screen geometry string e.g. '1280x960x24'."""
        return f"{self.resolution}x{self.color_depth}"

    @property
    def resolution_tuple(self) -> tuple[int, int]:
        """(width, height) as integers."""
        w, h = self.resolution.split("x")
        return int(w), int(h)


# Module-level singleton — import this everywhere instead of constructing Settings()
settings = Settings()
