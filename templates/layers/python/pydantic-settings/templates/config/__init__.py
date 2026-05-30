"""Typed application configuration via pydantic-settings.

Public API:
    Settings      -- the configuration model
    get_settings  -- cached factory, returns a validated Settings instance
    SecretStr     -- re-exported from pydantic for convenience
    Field         -- re-exported from pydantic for convenience
"""

from pydantic import Field, SecretStr

from {{PKG_PREFIX}}config.settings import Settings, get_settings

__all__ = ["Settings", "get_settings", "SecretStr", "Field"]
