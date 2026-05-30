"""Tests for the config/ package (pydantic-settings)."""

from __future__ import annotations

import json
from collections.abc import Iterator
from pathlib import Path

import pytest
from pydantic import SecretStr, ValidationError

from config import Field, Settings, get_settings
from config.settings import Settings as SettingsClass


@pytest.fixture(autouse=True)
def _clear_settings_cache(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """Reset cached Settings between tests and clear env so .env doesn't leak."""
    get_settings.cache_clear()
    for var in ("APP_NAME", "APP_ENV", "LOG_LEVEL"):
        monkeypatch.delenv(var, raising=False)
    yield
    get_settings.cache_clear()


def test_get_settings_returns_settings_instance() -> None:
    settings = get_settings()
    assert isinstance(settings, Settings)


def test_get_settings_is_cached_singleton() -> None:
    first = get_settings()
    second = get_settings()
    assert first is second


def test_defaults_applied_when_env_empty() -> None:
    settings = get_settings()
    assert settings.app_env == "development"
    assert settings.log_level == "INFO"
    assert settings.app_name  # non-empty


def test_env_override_reflected_after_cache_clear(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_NAME", "override-app")
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.app_name == "override-app"


def test_invalid_app_env_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "invalid-env")
    get_settings.cache_clear()
    with pytest.raises(ValidationError):
        get_settings()


def test_invalid_log_level_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("LOG_LEVEL", "TRACE")
    get_settings.cache_clear()
    with pytest.raises(ValidationError):
        get_settings()


def test_case_insensitive_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("app_env", "staging")
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.app_env == "staging"


def test_extra_env_vars_are_ignored(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("UNRELATED_VAR", "from-another-layer")
    get_settings.cache_clear()
    # Should not raise; extra="ignore" is in model_config.
    get_settings()


def test_dotenv_file_loaded(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    env_file = tmp_path / ".env"
    env_file.write_text("APP_NAME=from-dotenv\n", encoding="utf-8")
    monkeypatch.chdir(tmp_path)
    get_settings.cache_clear()
    settings = get_settings()
    assert settings.app_name == "from-dotenv"


def test_secretstr_is_masked_in_dump() -> None:
    class WithSecret(SettingsClass):
        token: SecretStr = Field(default=SecretStr("super-secret"))

    dumped = json.dumps(WithSecret().model_dump(), default=str)
    assert "super-secret" not in dumped


def test_schema_is_json_serialisable() -> None:
    schema = Settings.model_json_schema()
    json.dumps(schema)  # raises if not serialisable
