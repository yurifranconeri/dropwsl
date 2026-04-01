


# --- Foundry (Azure AI Projects) -- discovery ---


@app.get("/api/foundry/status")
def foundry_status() -> dict:
    """Return Foundry project connection status and summary."""
    import os

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


@app.get("/api/models")
def api_list_models(
    model_name: str | None = None,
    model_publisher: str | None = None,
) -> list[dict]:
    """List model deployments. Optional filters: ?model_name=...&model_publisher=..."""
    return list_models(model_name=model_name, model_publisher=model_publisher)


@app.get("/api/models/{deployment_name}")
def api_get_model(deployment_name: str) -> dict:
    """Get full details of a single model deployment."""
    from fastapi import HTTPException

    try:
        return get_model(deployment_name)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@app.get("/api/connections")
def api_list_connections(connection_type: str | None = None) -> list[dict]:
    """List connected resources. Optional filter: ?connection_type=AzureOpenAI"""
    return list_connections(connection_type=connection_type)


@app.get("/api/connections/default/{connection_type}")
def api_get_default_connection(connection_type: str) -> dict:
    """Get the default connection of a given type."""
    from fastapi import HTTPException

    try:
        return get_default_connection(connection_type)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
