"""Application settings.

Edit the `Settings` class below to add your typed configuration fields.
Values are loaded (in order of precedence) from:

    1. Environment variables (e.g. APP_ENV=production)
    2. A `.env` file in the current working directory
    3. The defaults declared on each Field

Validation runs once when `Settings()` is instantiated. Missing required
fields or invalid values raise `ValidationError` at startup, so the app
fails fast instead of crashing later in runtime.

Read settings at runtime via `get_settings()` (cached singleton).
"""

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration model.

    Add typed fields below. Use `pydantic.SecretStr` for sensitive values so
    they are masked in `repr()`, `str()` and `model_dump()` output.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",          # tolerate extra vars from other layers / apps
        case_sensitive=False,    # APP_NAME and app_name both work
    )

    # ------------------------------------------------------------------
    # Default fields (rename or remove as you see fit)
    # ------------------------------------------------------------------

    app_name: str = Field(
        default="{{PROJECT_NAME}}",
        description="Display name shown in UI and logs.",
    )
    app_env: str = Field(
        default="development",
        pattern="^(development|staging|production)$",
        description="Deployment environment.",
    )
    log_level: str = Field(
        default="INFO",
        pattern="^(DEBUG|INFO|WARNING|ERROR|CRITICAL)$",
        description="Root log level.",
    )

    # ------------------------------------------------------------------
    # Examples for your own fields (uncomment and adapt)
    # ------------------------------------------------------------------
    # database_url: str = Field(..., description="Required, no default.")
    # api_token: SecretStr = Field(..., description="Masked in logs / dumps.")
    # pool_size: int = Field(default=10, ge=1, le=100)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Returns the cached Settings instance for the process.

    Examples
    --------
    FastAPI:
        from fastapi import Depends
        from {{PKG_PREFIX}}config import Settings, get_settings

        @app.get("/")
        def root(s: Settings = Depends(get_settings)):
            return {"env": s.app_env}

    Streamlit / scripts:
        from {{PKG_PREFIX}}config import get_settings
        settings = get_settings()

    In tests, call `get_settings.cache_clear()` between cases that
    monkeypatch environment variables.
    """
    return Settings()
