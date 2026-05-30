"""FastAPI APIRouter for Key Vault — opt-in.

Mount in your FastAPI app:

    from {{PKG_PREFIX}}keyvault.router import router as keyvault_router
    app.include_router(keyvault_router, prefix="/api/keyvault")

Endpoints (all metadata-only — secret values are never returned via HTTP):
    GET  /api/keyvault/status         vault status + summary
    GET  /api/keyvault/secrets        list secret metadata
    GET  /api/keyvault/secrets/{name} single secret metadata
"""

import os

from fastapi import APIRouter, HTTPException

from .client import keyvault_health
from .secrets import _NAME_RE, get_secret, list_secrets

router = APIRouter(tags=["keyvault"])


@router.get("/status")
def keyvault_status() -> dict:
    """Return vault connection status and a summary count."""
    healthy = keyvault_health()
    if not healthy:
        return {
            "connected": False,
            "vault_url": os.environ.get("AZURE_KEYVAULT_URL", ""),
            "error": "Vault unreachable. Check AZURE_KEYVAULT_URL and credentials.",
        }
    secrets = list_secrets()
    return {
        "connected": True,
        "vault_url": os.environ.get("AZURE_KEYVAULT_URL", ""),
        "summary": {"total_secrets": len(secrets)},
    }


@router.get("/secrets")
def api_list_secrets(enabled_only: bool = True) -> list[dict]:
    """List secret metadata (values are NEVER included)."""
    return list_secrets(enabled_only=enabled_only)


@router.get("/secrets/{name}")
def api_get_secret(name: str) -> dict:
    """Get single secret metadata. Values are NEVER returned via HTTP."""
    if not _NAME_RE.match(name):
        raise HTTPException(status_code=422, detail=f"Invalid secret name: {name!r}")
    try:
        return get_secret(name, reveal=False)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
