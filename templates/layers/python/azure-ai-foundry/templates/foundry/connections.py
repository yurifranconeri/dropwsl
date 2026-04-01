"""Foundry connections — connected Azure resources discovery."""

import logging

from .client import get_project_client

logger = logging.getLogger(__name__)


def list_connections(*, connection_type: str | None = None) -> list[dict]:
    """List connected resources in the Foundry project.

    Accepts an optional connection_type filter (e.g. "AzureOpenAI", "AzureAISearch").
    """
    client = get_project_client()
    kwargs: dict = {}
    if connection_type:
        kwargs["connection_type"] = connection_type

    result = []
    for c in client.connections.list(**kwargs):
        result.append(_connection_to_dict(c))
    return result


def get_default_connection(connection_type: str) -> dict:
    """Get the default connection of a given type.

    Raises KeyError if no default connection exists for that type.
    """
    client = get_project_client()
    try:
        c = client.connections.get_default(connection_type=connection_type)
    except Exception as exc:
        raise KeyError(
            f"No default connection for type '{connection_type}': {exc}"
        ) from exc
    return _connection_to_dict(c)


def _connection_to_dict(c: object) -> dict:
    """Convert a connection object to a JSON-safe dict."""
    return {
        "name": str(getattr(c, "name", "")),
        "connection_type": str(getattr(c, "connection_type", "")),
        "target": str(getattr(c, "target", "")),
    }
