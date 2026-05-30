"""Key Vault package — Azure Key Vault secret management.

Public API:
  - get_secret_client()  — lazy SecretClient singleton
  - keyvault_health()    — True if the vault is reachable
  - list_secrets()       — list secret metadata (no values)
  - get_secret(name, reveal=False)  — secret metadata; value only when reveal=True

CLI:
  python -m {{PKG_PREFIX}}keyvault   # validates config, prints health, lists secrets

Optional integrations (opt-in by import — layer never modifies main.py):
  - keyvault.router  — FastAPI APIRouter (mount with app.include_router)
  - keyvault.ui      — Streamlit panel (call render_keyvault_panel(st))
"""

from .client import get_secret_client, keyvault_health
from .secrets import get_secret, list_secrets

__all__ = [
    "get_secret",
    "get_secret_client",
    "keyvault_health",
    "list_secrets",
]
