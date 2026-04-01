"""Shared helpers for chat API implementations (Responses + Completions)."""

import logging
import os

logger = logging.getLogger(__name__)

DEFAULT_MODEL_ENV = "AZURE_AI_CHAT_MODEL"


def resolve_model(model: str | None) -> str:
    """Resolve model deployment name: explicit param > env var > error."""
    if model:
        return model
    env_model = os.environ.get(DEFAULT_MODEL_ENV, "")
    if env_model:
        return env_model
    raise ValueError(
        f"{DEFAULT_MODEL_ENV} not set and no model specified in request. "
        "Pass 'model' in the request body or set the environment variable."
    )


def chat_health() -> bool:
    """Return True if chat is likely functional.

    Checks that AZURE_AI_CHAT_MODEL is configured.
    Does not make API calls — foundry health covers connectivity.
    """
    return bool(os.environ.get(DEFAULT_MODEL_ENV, ""))


def usage_to_dict(usage: object) -> dict:
    """Convert a usage object to a JSON-safe dict.

    Works for both Responses API and Chat Completions API usage objects.
    Responses: input_tokens / output_tokens / total_tokens.
    Completions: prompt_tokens / completion_tokens / total_tokens.
    Normalizes to input_tokens / output_tokens / total_tokens.
    """
    if usage is None:
        return {}
    return {
        "input_tokens": int(
            getattr(usage, "input_tokens", 0)
            or getattr(usage, "prompt_tokens", 0)
        ),
        "output_tokens": int(
            getattr(usage, "output_tokens", 0)
            or getattr(usage, "completion_tokens", 0)
        ),
        "total_tokens": int(getattr(usage, "total_tokens", 0)),
    }


def usage_details_to_dict(usage: object) -> dict:
    """Extract detailed token breakdown when available.

    Returns reasoning_tokens and cached_tokens from the usage
    sub-objects. Returns zeros gracefully for models that don't
    report these details.
    """
    if usage is None:
        return {"reasoning_tokens": 0, "cached_tokens": 0}
    output_details = getattr(usage, "output_tokens_details", None)
    input_details = getattr(usage, "input_tokens_details", None)
    return {
        "reasoning_tokens": int(getattr(output_details, "reasoning_tokens", 0)) if output_details else 0,
        "cached_tokens": int(getattr(input_details, "cached_tokens", 0)) if input_details else 0,
    }
