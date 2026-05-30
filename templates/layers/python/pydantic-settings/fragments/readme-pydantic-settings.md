## Configuration

Typed application configuration via [pydantic-settings](https://docs.pydantic.dev/latest/concepts/pydantic_settings/).

```bash
# Copy the example, then edit values for your environment:
cp .env.example .env

# Validate the configuration (exits non-zero on errors):
python -m {{PKG_PREFIX}}config validate

# Inspect current settings (secrets are masked):
python -m {{PKG_PREFIX}}config show

# Print the JSON schema of the Settings class:
python -m {{PKG_PREFIX}}config schema

# Dump a .env template derived from the Settings class fields:
python -m {{PKG_PREFIX}}config dump-env
```

### Usage

```python
from {{PKG_PREFIX}}config import get_settings

settings = get_settings()       # cached singleton, validated once
print(settings.app_env)
```

### FastAPI (opt-in)

```python
from fastapi import Depends
from {{PKG_PREFIX}}config import Settings, get_settings

@app.get("/health")
def health(settings: Settings = Depends(get_settings)):
    return {"env": settings.app_env, "app": settings.app_name}
```

### Streamlit (opt-in)

```python
import streamlit as st
from {{PKG_PREFIX}}config import get_settings

settings = get_settings()
st.set_page_config(page_title=settings.app_name)
```

### Adding fields

Edit `{{PKG_PREFIX}}config/settings.py` and add typed fields to the `Settings` class. Use `SecretStr` for sensitive values so they are masked in logs and dumps:

```python
from pydantic import Field, SecretStr

class Settings(BaseSettings):
    # existing fields...
    database_url: str = Field(..., description="Required, no default")
    api_token: SecretStr = Field(..., description="Masked in repr and dumps")
    pool_size: int = Field(default=10, ge=1, le=100)
```

Validation happens at `Settings()` instantiation; missing required fields raise `ValidationError` at startup instead of crashing in runtime.
