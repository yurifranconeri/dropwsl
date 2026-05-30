## Azure Key Vault

The project ships a self-contained `keyvault/` package. It does **not** modify `main.py` —
the dev opts in by importing what they need.

### Configuration

```bash
export AZURE_KEYVAULT_URL="https://<vault-name>.vault.azure.net/"
```

Authentication reuses `auth/credential.py` (DefaultAzureCredential).

### CLI inspector (always available)

```bash
python -m {{PKG_PREFIX}}keyvault
```

Validates the URL, prints health, lists secret metadata. **Never prints values.**

### Programmatic use

```python
from {{PKG_PREFIX}}keyvault import list_secrets, get_secret

secrets = list_secrets()                     # metadata only
db_pwd = get_secret("db-password", reveal=True)["value"]
```

### Optional FastAPI integration

```python
from {{PKG_PREFIX}}keyvault.router import router as keyvault_router
app.include_router(keyvault_router, prefix="/api/keyvault")
```

Adds `GET /api/keyvault/status`, `/secrets`, `/secrets/{name}`. **Metadata only — never values.**

### Optional Streamlit integration

```python
import streamlit as st
from {{PKG_PREFIX}}keyvault.ui import render_keyvault_panel
render_keyvault_panel(st)            # or st.sidebar
```

### Structure

- `keyvault/client.py` — `SecretClient` singleton, `keyvault_health()`
- `keyvault/secrets.py` — `list_secrets()`, `get_secret(name, reveal=False)`, name validation
- `keyvault/__main__.py` — CLI inspector
- `keyvault/router.py` — FastAPI APIRouter (opt-in)
- `keyvault/ui.py` — Streamlit panel (opt-in)

> Secret values are returned only when the caller passes `reveal=True` programmatically.
> They are never exposed via the HTTP API or rendered in the Streamlit UI.
