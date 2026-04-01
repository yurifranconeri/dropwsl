"""Chat via Chat Completions API — for partner models and model-router.

Uses the OpenAI client from the foundry layer to interact with
Azure AI model deployments that support the Chat Completions API
(partner models like DeepSeek, Llama, Mistral, Phi-4, and model-router).
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
    instructions: str | None = None,
    history: list[dict] | None = None,
    temperature: float | None = None,
    top_p: float | None = None,
    max_output_tokens: int | None = None,
    reasoning_effort: str | None = None,
) -> dict:
    """Send a message and return the full response (synchronous).

    Uses the Chat Completions API (client.chat.completions.create).
    Multi-turn is client-side via the history parameter.
    All optional parameters are forwarded only when explicitly set (not None).
    """
    resolved = resolve_model(model)
    client = get_openai_client()

    messages = _build_messages(message, instructions=instructions, history=history)
    kwargs: dict = {"model": resolved, "messages": messages}
    _apply_completions_kwargs(
        kwargs,
        temperature=temperature,
        top_p=top_p,
        max_output_tokens=max_output_tokens,
        reasoning_effort=reasoning_effort,
    )

    response = client.chat.completions.create(**kwargs)

    choice = response.choices[0] if response.choices else None
    text = choice.message.content or "" if choice else ""

    return {
        "response_id": str(response.id) if response.id else "",
        "model": str(getattr(response, "model", resolved)),
        "text": text,
        "usage": usage_to_dict(response.usage),
        "usage_details": usage_details_to_dict(response.usage),
    }


def send_message_stream(
    message: str,
    *,
    model: str | None = None,
    instructions: str | None = None,
    history: list[dict] | None = None,
    temperature: float | None = None,
    top_p: float | None = None,
    max_output_tokens: int | None = None,
    reasoning_effort: str | None = None,
) -> Iterator[dict]:
    """Send a message and yield streaming events.

    Event types:
      - {"type": "created", "response_id": "chatcmpl-..."}
      - {"type": "delta", "text": "..."}
      - {"type": "done", "response_id": "...", "model": "...", "usage": {...}}
    """
    resolved = resolve_model(model)
    client = get_openai_client()

    messages = _build_messages(message, instructions=instructions, history=history)
    kwargs: dict = {
        "model": resolved,
        "messages": messages,
        "stream": True,
        "stream_options": {"include_usage": True},
    }
    _apply_completions_kwargs(
        kwargs,
        temperature=temperature,
        top_p=top_p,
        max_output_tokens=max_output_tokens,
        reasoning_effort=reasoning_effort,
    )

    stream = client.chat.completions.create(**kwargs)

    response_id = ""
    model_name = resolved
    for chunk in stream:
        if not response_id and chunk.id:
            response_id = str(chunk.id)
            model_name = str(getattr(chunk, "model", resolved))
            yield {"type": "created", "response_id": response_id}

        if chunk.choices:
            delta = chunk.choices[0].delta
            if delta and delta.content:
                yield {"type": "delta", "text": delta.content}

        if chunk.usage:
            yield {
                "type": "done",
                "response_id": response_id,
                "model": model_name,
                "usage": usage_to_dict(chunk.usage),
                "usage_details": usage_details_to_dict(chunk.usage),
            }


def _build_messages(
    message: str,
    *,
    instructions: str | None = None,
    history: list[dict] | None = None,
) -> list[dict]:
    """Build the messages array for the Chat Completions API.

    Order: system (instructions) → history → current user message.
    """
    messages: list[dict] = []
    if instructions:
        messages.append({"role": "system", "content": instructions})
    if history:
        messages.extend(history)
    messages.append({"role": "user", "content": message})
    return messages


def _apply_completions_kwargs(
    kwargs: dict,
    *,
    temperature: float | None,
    top_p: float | None,
    max_output_tokens: int | None,
    reasoning_effort: str | None,
) -> None:
    """Add optional Chat Completions API parameters to kwargs (in-place).

    Key differences from Responses API:
      - max_output_tokens → max_completion_tokens
      - reasoning_effort is top-level (not nested in a dict)
      - truncation and store are NOT supported
    """
    if temperature is not None:
        kwargs["temperature"] = temperature
    if top_p is not None:
        kwargs["top_p"] = top_p
    if max_output_tokens is not None:
        kwargs["max_completion_tokens"] = max_output_tokens
    if reasoning_effort is not None:
        kwargs["reasoning_effort"] = reasoning_effort
