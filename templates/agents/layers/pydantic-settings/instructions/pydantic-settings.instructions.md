---
applyTo: "**/*.py"
---

# pydantic-settings Rules

- Read configuration via `get_settings()` from the `config` package -- never call `os.environ`, `os.getenv` or `dotenv` directly in app code
- To add a new config value: add a typed `Field` to the `Settings` class in `config/settings.py`, document it, and add a matching line to `.env.example`
- Use `SecretStr` for any sensitive value (tokens, passwords, connection strings) so it is masked in logs and dumps
- Required values: declare with `Field(...)` (no default) so validation fails fast at startup if missing
- Use validation constraints (`pattern=`, `ge=`, `le=`, `min_length=`, etc.) instead of post-hoc `if` checks
- Inject settings into FastAPI endpoints with `Depends(get_settings)`; in Streamlit/scripts, call `get_settings()` once at module top
- In tests, call `get_settings.cache_clear()` between cases that monkeypatch environment variables
- Inspect: `python -m <pkg>.config show | validate | dump-env | schema`
