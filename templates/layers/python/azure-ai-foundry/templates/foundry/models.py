"""Foundry model deployments — discovery and inspection."""

import logging

from azure.ai.projects.models import ModelDeployment

from .client import get_project_client

logger = logging.getLogger(__name__)


def list_models(
    *,
    model_name: str | None = None,
    model_publisher: str | None = None,
) -> list[dict]:
    """List model deployments with full metadata.

    Accepts optional filters by model_name and model_publisher.
    Returns enriched dicts with all available fields from ModelDeployment.
    """
    client = get_project_client()
    kwargs: dict = {}
    if model_name:
        kwargs["model_name"] = model_name
    if model_publisher:
        kwargs["model_publisher"] = model_publisher

    result = []
    for d in client.deployments.list(**kwargs):
        result.append(_deployment_to_dict(d))
    return result


def get_model(deployment_name: str) -> dict:
    """Get full details of a single model deployment.

    Raises KeyError if the deployment is not found.
    """
    client = get_project_client()
    try:
        d = client.deployments.get(deployment_name)
    except Exception as exc:
        raise KeyError(f"Deployment '{deployment_name}' not found: {exc}") from exc
    return _deployment_to_dict(d)


def _deployment_to_dict(d: object) -> dict:
    """Convert a deployment object to a JSON-safe dict."""
    info: dict = {
        "name": getattr(d, "name", ""),
        "type": getattr(d, "type", "unknown"),
    }
    if isinstance(d, ModelDeployment):
        # sku is a ModelDeploymentSku object — extract .name as string
        sku_name = ""
        if d.sku:
            sku_name = getattr(d.sku, "name", str(d.sku))
        # capabilities may be SDK objects — force to list of strings
        caps = []
        if d.capabilities:
            caps = [str(c) for c in d.capabilities]
        info.update({
            "model_name": d.model_name or "",
            "model_version": d.model_version or "",
            "model_publisher": d.model_publisher or "",
            "capabilities": caps,
            "sku": sku_name,
            "connection_name": d.connection_name or "",
        })
    return info
