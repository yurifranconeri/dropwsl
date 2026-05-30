"""Tests for the Streamlit app -- uses AppTest (no server needed)."""

from streamlit.testing.v1 import AppTest

# AppTest.run() spins up a full Streamlit script runner on first call; cold-start
# under load (e.g. fresh post-create.sh with editable install) can blow past 10s.
# 30s is the conservative upper bound observed across the full layer matrix.
_APP_TEST_TIMEOUT = 30


def test_app_loads() -> None:
    """App should load without errors."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=_APP_TEST_TIMEOUT)
    assert not at.exception


def test_has_title() -> None:
    """App should have a title."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=_APP_TEST_TIMEOUT)
    assert len(at.title) > 0
