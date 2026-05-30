
## Configuration

- Typed settings via pydantic-settings (`config/` package)
- Read at runtime with `get_settings()` (cached singleton)
- Never call `os.environ` or `os.getenv` in app code -- add a typed field to `Settings` instead
- Use `SecretStr` for sensitive values so they mask in logs and dumps
- Inspect: `python -m <pkg>.config show | validate | dump-env | schema`
