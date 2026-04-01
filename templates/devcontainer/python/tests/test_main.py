"""Tests for main.py -- example of how to write tests with pytest."""

import pytest

from main import main


def test_main_runs_without_error(capsys: pytest.CaptureFixture[str]) -> None:
    """Verifies that main() prints the expected message."""
    main()
    captured = capsys.readouterr()
    assert captured.out.strip() == "Hello, World! 🚀"
