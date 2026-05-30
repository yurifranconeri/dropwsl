"""Auth package — Azure DefaultAzureCredential.

Public API:
  - get_credential()       — DefaultAzureCredential singleton
  - credential_health()    — True if a token can be acquired
  - decode_token_claims()  — JWT claims (no signature verification)

CLI:
  python -m {{PKG_PREFIX}}auth   # token inspector

Optional integrations (opt-in by import — layer never modifies main.py):
  - auth.router  — FastAPI APIRouter (mount with app.include_router)
  - auth.ui      — Streamlit panel (call render_identity_panel(st))
"""

from .credential import credential_health, decode_token_claims, get_credential

__all__ = [
    "credential_health",
    "decode_token_claims",
    "get_credential",
]
