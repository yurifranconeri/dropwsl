## Azure AI Foundry

The project ships a self-contained `foundry/` package using **AIProjectClient** from `azure-ai-projects`.
The layer does **not** modify `main.py` — the dev opts in by importing what they need.

### Configuration

```bash
export AZURE_AI_PROJECT_ENDPOINT="https://<resource>.services.ai.azure.com/api/projects/<project>"
```

Find the URL in the Microsoft Foundry project overview page. Authentication reuses `auth/credential.py`.

### CLI inspector (always available)

```bash
python -m {{PKG_PREFIX}}foundry
```

Validates the endpoint, prints health, lists model deployments and connections.

### Programmatic use

```python
from {{PKG_PREFIX}}foundry import list_models, list_connections, get_openai_client

for m in list_models():
    print(m["name"], m["model_name"])

oai = get_openai_client()
```

### Optional FastAPI integration

```python
from {{PKG_PREFIX}}foundry.router import router as foundry_router
app.include_router(foundry_router, prefix="/api")
```

Adds `/api/foundry/status`, `/api/models`, `/api/models/{name}`, `/api/connections`, `/api/connections/default/{type}`.

### Optional Streamlit integration

```python
import streamlit as st
from {{PKG_PREFIX}}foundry.ui import render_foundry_panel
render_foundry_panel(st)            # or st.sidebar
```

### Structure

- `foundry/client.py` — `AIProjectClient` + `OpenAI` singletons, `foundry_health()`
- `foundry/models.py` — Model deployment discovery
- `foundry/connections.py` — Connected resources discovery
- `foundry/__main__.py` — CLI inspector
- `foundry/router.py` — FastAPI APIRouter (opt-in)
- `foundry/ui.py` — Streamlit panel (opt-in)

> The Foundry client reuses the credential from `auth/credential.py` (azure-identity layer).
