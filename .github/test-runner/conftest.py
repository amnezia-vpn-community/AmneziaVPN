"""Root conftest.py — re-exports all shared fixtures from the fixtures package."""
from amnezia_tests.fixtures.conftest import (  # noqa: F401
    artifact_dir,
    downloaded_bin,
    pytest_runtest_makereport,
    screenshot_on_fail,
    test_tmp_dir,
    xvfb_display,
)
