"""Azure AI Foundry project client — lazy singletons.

Uses AIProjectClient from azure-ai-projects SDK to connect to a
Microsoft Foundry project. Requires AZURE_AI_PROJECT_ENDPOINT.

Provides two singletons:
  - get_project_client() — AIProjectClient (deployments, connections, agents)
  - get_openai_client()  — OpenAI client (chat, responses, files)

Both are lazy-initialized and shared across the application.
"""

import logging
import os

from azure.ai.projects import AIProjectClient
from openai import OpenAI

from auth.credential import get_credential

logger = logging.getLogger(__name__)

_client: AIProjectClient | None = None
_openai_client: OpenAI | None = None


def get_project_client() -> AIProjectClient:
    """Return a shared AIProjectClient instance (lazy init).

    Raises ValueError if AZURE_AI_PROJECT_ENDPOINT is not set.
    """
    global _client  # noqa: PLW0603
    if _client is None:
        endpoint = os.environ.get("AZURE_AI_PROJECT_ENDPOINT", "")
        if not endpoint:
            raise ValueError(
                "AZURE_AI_PROJECT_ENDPOINT not set. "
                "Find it in your Microsoft Foundry project overview page."
            )
        _client = AIProjectClient(
            endpoint=endpoint,
            credential=get_credential(),
        )
    return _client


def get_openai_client() -> OpenAI:
    """Return a shared OpenAI client from the Foundry project (lazy init).

    The client is pre-configured with the project's endpoint and credentials.
    Use it for chat completions, responses, files, and fine-tuning.
    """
    global _openai_client  # noqa: PLW0603
    if _openai_client is None:
        _openai_client = get_project_client().get_openai_client()
    return _openai_client


def foundry_health() -> bool:
    """Return True if the Foundry project is reachable."""
    try:
        client = get_project_client()
        # Lightweight call — list first page of deployments
        next(iter(client.deployments.list()), None)
        return True
    except Exception:
        logger.debug("foundry_health failed", exc_info=True)
        return False
