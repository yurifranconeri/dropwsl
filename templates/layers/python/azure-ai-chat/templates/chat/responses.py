"""Chat via Responses API — send messages, stream responses.

Uses the OpenAI client from the foundry layer to interact with
Azure AI model deployments that support the Responses API.
"""

import logging
from collections.abc import Iterator

from foundry.client import get_openai_client

from ._common import resolve_model, usage_details_to_dict, usage_to_dict

logger = logging.getLogger(__name__)


def send_message(
    message: str,
    *,
    model: str | None = None,
    previous_response_id: str | None = None,
    instructions: str | None = None,
    temperature: float | None = None,
    top_p: float | None = None,
    max_output_tokens: int | None = None,
    truncation: str | None = None,
    store: bool | None = None,
    reasoning_effort: str | None = None,
) -> dict:
    """Send a message and return the full response (synchronous).

    Uses the Responses API (client.responses.create).
    Supports multi-turn via previous_response_id (server-side stateful).
    All optional parameters are forwarded only when explicitly set (not None).
    """
    resolved = resolve_model(model)
    client = get_openai_client()

    kwargs: dict = {"model": resolved, "input": message}
    if previous_response_id:
        kwargs["previous_response_id"] = previous_response_id
    if instructions:
        kwargs["instructions"] = instructions
    _apply_optional_kwargs(
        kwargs,
        temperature=temperature,
        top_p=top_p,
        max_output_tokens=max_output_tokens,
        truncation=truncation,
        store=store,
        reasoning_effort=reasoning_effort,
    )

    response = client.responses.create(**kwargs)

    return {
        "response_id": str(response.id),
        "model": str(getattr(response, "model", resolved)),
        "text": response.output_text or "",
        "usage": usage_to_dict(response.usage),
        "usage_details": usage_details_to_dict(response.usage),
    }


def send_message_stream(
    message: str,
    *,
    model: str | None = None,
    previous_response_id: str | None = None,
    instructions: str | None = None,
    temperature: float | None = None,
    top_p: float | None = None,
    max_output_tokens: int | None = None,
    truncation: str | None = None,
    store: bool | None = None,
    reasoning_effort: str | None = None,
) -> Iterator[dict]:
    """Send a message and yield streaming events.

    Event types:
      - {"type": "created", "response_id": "resp_..."}
      - {"type": "delta", "text": "..."}
      - {"type": "done", "response_id": "...", "model": "...", "usage": {...}}
    """
    resolved = resolve_model(model)
    client = get_openai_client()

    kwargs: dict = {"model": resolved, "input": message, "stream": True}
    if previous_response_id:
        kwargs["previous_response_id"] = previous_response_id
    if instructions:
        kwargs["instructions"] = instructions
    _apply_optional_kwargs(
        kwargs,
        temperature=temperature,
        top_p=top_p,
        max_output_tokens=max_output_tokens,
        truncation=truncation,
        store=store,
        reasoning_effort=reasoning_effort,
    )

    stream = client.responses.create(**kwargs)

    for event in stream:
        if event.type == "response.created":
            yield {
                "type": "created",
                "response_id": str(event.response.id),
            }
        elif event.type == "response.output_text.delta":
            yield {"type": "delta", "text": event.delta}
        elif event.type == "response.completed":
            yield {
                "type": "done",
                "response_id": str(event.response.id),
                "model": str(getattr(event.response, "model", resolved)),
                "usage": usage_to_dict(event.response.usage),
                "usage_details": usage_details_to_dict(event.response.usage),
            }


def _apply_optional_kwargs(
    kwargs: dict,
    *,
    temperature: float | None,
    top_p: float | None,
    max_output_tokens: int | None,
    truncation: str | None,
    store: bool | None,
    reasoning_effort: str | None,
) -> None:
    """Add optional Responses API parameters to kwargs (in-place).

    Only includes parameters that are explicitly set (not None),
    so models that don't support a parameter won't receive it.
    """
    if temperature is not None:
        kwargs["temperature"] = temperature
    if top_p is not None:
        kwargs["top_p"] = top_p
    if max_output_tokens is not None:
        kwargs["max_output_tokens"] = max_output_tokens
    if truncation is not None:
        kwargs["truncation"] = truncation
    if store is not None:
        kwargs["store"] = store
    if reasoning_effort is not None:
        kwargs["reasoning"] = {"effort": reasoning_effort}
