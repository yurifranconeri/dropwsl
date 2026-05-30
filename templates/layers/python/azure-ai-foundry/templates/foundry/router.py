"""FastAPI APIRouter for Azure AI Foundry — opt-in.

Mount in your FastAPI app:

    from {{PKG_PREFIX}}foundry.router import router as foundry_router
    app.include_router(foundry_router, prefix="/api")

Endpoints:
    GET /api/foundry/status               vault status + summary
    GET /api/models                       list model deployments (filters: model_name, model_publisher)
    GET /api/models/{deployment_name}     single deployment details
    GET /api/connections                  list connections (filter: connection_type)
    GET /api/connections/default/{type}   default connection of a given type
"""

import os

from fastapi import APIRouter, HTTPException

from .client import foundry_health
from .connections import get_default_connection, list_connections
from .models import get_model, list_models

router = APIRouter(tags=["foundry"])


@router.get("/foundry/status")
def foundry_status() -> dict:
    """Return Foundry project connection status and summary."""
    try:
        models = list_models()
        connections = list_connections()
        return {
            "connected": True,
            "project_endpoint": os.environ.get("AZURE_AI_PROJECT_ENDPOINT", ""),
            "summary": {
                "total_models": len(models),
                "total_connections": len(connections),
            },
            "models": models,
        }
    except Exception as exc:
        return {
            "connected": False,
            "error": f"Foundry project unreachable: {exc}. Check AZURE_AI_PROJECT_ENDPOINT.",
        }


@router.get("/models")
def api_list_models(
    model_name: str | None = None,
    model_publisher: str | None = None,
) -> list[dict]:
    """List model deployments. Optional filters: ?model_name=...&model_publisher=..."""
    return list_models(model_name=model_name, model_publisher=model_publisher)


@router.get("/models/{deployment_name}")
def api_get_model(deployment_name: str) -> dict:
    """Get full details of a single model deployment."""
    try:
        return get_model(deployment_name)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/connections")
def api_list_connections(connection_type: str | None = None) -> list[dict]:
    """List connected resources. Optional filter: ?connection_type=AzureOpenAI"""
    return list_connections(connection_type=connection_type)


@router.get("/connections/default/{connection_type}")
def api_get_default_connection(connection_type: str) -> dict:
    """Get the default connection of a given type."""
    try:
        return get_default_connection(connection_type)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


# Health helper for embedding into a /health route via app composition.
def health() -> str:
    """Return 'ok' if the Foundry project is reachable, else 'degraded'."""
    return "ok" if foundry_health() else "degraded"
