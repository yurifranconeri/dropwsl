"""Foundry package — Azure AI Projects client management and discovery.

Public API:
  - get_project_client(), get_openai_client(), foundry_health()
  - list_models(), get_model()
  - list_connections(), get_default_connection()

CLI:
  python -m {{PKG_PREFIX}}foundry   # status, models, connections inspector

Optional integrations (opt-in by import — layer never modifies main.py):
  - foundry.router  — FastAPI APIRouter (mount with app.include_router)
  - foundry.ui      — Streamlit panel (call render_foundry_panel(st))
"""

from .client import foundry_health, get_openai_client, get_project_client
from .connections import get_default_connection, list_connections
from .models import get_model, list_models

__all__ = [
    "foundry_health",
    "get_default_connection",
    "get_model",
    "get_openai_client",
    "get_project_client",
    "list_connections",
    "list_models",
]
