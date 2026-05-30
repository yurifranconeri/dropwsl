## Authentication (Azure Identity)

The project ships a self-contained `auth/` package using **DefaultAzureCredential**.
The layer does **not** modify `main.py` — the dev opts in by importing what they need.

### Configuration

Local development:

```bash
az login   # inside the dev container
```

CI/CD / Production (set environment variables):

```bash
export AZURE_TENANT_ID="..."
export AZURE_CLIENT_ID="..."
export AZURE_CLIENT_SECRET="..."
```

### CLI inspector (always available)

```bash
python -m {{PKG_PREFIX}}auth
```

Acquires a token, prints decoded JWT claims (name, email, tenant, object id, expiration). Never prints the token.

### Programmatic use

```python
from {{PKG_PREFIX}}auth import get_credential, credential_health

cred = get_credential()
print("ok" if credential_health() else "degraded")
```

### Optional FastAPI integration

```python
from {{PKG_PREFIX}}auth.router import router as auth_router
app.include_router(auth_router, prefix="/api")
```

Adds `GET /api/identity` returning decoded JWT claims.

### Optional Streamlit integration

```python
import streamlit as st
from {{PKG_PREFIX}}auth.ui import render_identity_panel
render_identity_panel(st)            # or st.sidebar
```

### Structure

- `auth/credential.py` — `DefaultAzureCredential` singleton, `credential_health()`, `decode_token_claims()`
- `auth/__main__.py` — CLI token inspector
- `auth/router.py` — FastAPI APIRouter (opt-in)
- `auth/ui.py` — Streamlit panel (opt-in)
