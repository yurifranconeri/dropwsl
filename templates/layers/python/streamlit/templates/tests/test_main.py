"""Tests for the Streamlit app -- uses AppTest (no server needed)."""

from streamlit.testing.v1 import AppTest


def test_app_loads() -> None:
    """App should load without errors."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=10)
    assert not at.exception


def test_has_title() -> None:
    """App should have a title."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=10)
    assert len(at.title) > 0
