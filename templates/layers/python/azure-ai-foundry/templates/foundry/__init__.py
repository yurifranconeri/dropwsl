"""Foundry package — Azure AI Projects client management and discovery."""

from .client import get_openai_client, get_project_client
from .connections import get_default_connection, list_connections
from .models import get_model, list_models

__all__ = [
    "get_project_client",
    "get_openai_client",
    "list_models",
    "get_model",
    "list_connections",
    "get_default_connection",
]
