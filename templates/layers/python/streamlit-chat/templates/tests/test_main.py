"""Tests for the Streamlit Chat UI -- uses AppTest (no server needed)."""

from streamlit.testing.v1 import AppTest


def test_app_loads() -> None:
    """App should load without errors (even without backend)."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=10)
    assert not at.exception


def test_has_title() -> None:
    """App should display a title."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=10)
    assert len(at.title) > 0


def test_has_chat_input() -> None:
    """App should have a chat input widget."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=10)
    assert len(at.chat_input) > 0


def test_has_parameter_sliders() -> None:
    """App should expose Temperature and Top P sliders."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=10)
    slider_labels = [s.label for s in at.slider]
    assert "Temperature" in slider_labels
    assert "Top P" in slider_labels


def test_has_truncation_selectbox() -> None:
    """App should have a Truncation selectbox."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=10)
    select_labels = [s.label for s in at.selectbox]
    assert "Truncation" in select_labels


def test_has_reasoning_effort_selectbox() -> None:
    """App should have a Reasoning effort selectbox (inside expander)."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=10)
    select_labels = [s.label for s in at.selectbox]
    assert "Reasoning effort" in select_labels


def test_has_limit_output_checkbox() -> None:
    """App should have a checkbox to limit output tokens."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=10)
    checkbox_labels = [c.label for c in at.checkbox]
    assert "Limit output tokens" in checkbox_labels


def test_has_api_mode_selectbox() -> None:
    """App should have an API Mode selectbox with both options."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=10)
    select_labels = [s.label for s in at.selectbox]
    assert "API Mode" in select_labels


def test_api_mode_default_is_responses() -> None:
    """API Mode should default to Responses."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=10)
    api_mode_box = next(s for s in at.selectbox if s.label == "API Mode")
    assert api_mode_box.value == "Responses"


def test_has_debug_toggle_on_by_default() -> None:
    """App should have a Debug bar toggle, enabled by default."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=10)
    toggle_labels = [t.label for t in at.toggle]
    assert "Debug bar" in toggle_labels
    debug_toggle = next(t for t in at.toggle if t.label == "Debug bar")
    assert debug_toggle.value is True


def test_debug_bar_shows_placeholder() -> None:
    """Debug bar should show placeholder text before any message."""
    at = AppTest.from_file("{{TEST_PATH}}")
    at.run(timeout=10)
    # With debug on and no messages, expect the placeholder caption
    captions = [c.value for c in at.caption]
    assert any("Send a message" in c for c in captions)
