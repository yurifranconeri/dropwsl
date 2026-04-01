"""HTTP client for the Chat API backend.

Communicates with the FastAPI backend via HTTP — zero coupling to backend code.
Configure the backend URL via CHAT_API_URL environment variable.
"""

import json
import logging
import os
from collections.abc import Iterator

import requests

logger = logging.getLogger(__name__)

DEFAULT_BASE_URL = "http://localhost:8000"


def _base_url() -> str:
    """Return the Chat API base URL from env or default."""
    return os.environ.get("CHAT_API_URL", DEFAULT_BASE_URL).rstrip("/")


def get_models() -> list[dict]:
    """Fetch available models from GET /api/models."""
    resp = requests.get(f"{_base_url()}/api/models", timeout=10)
    resp.raise_for_status()
    return resp.json()


def _build_chat_payload(
    message: str,
    *,
    model: str | None = None,
    api_mode: str = "responses",
    previous_response_id: str | None = None,
    instructions: str | None = None,
    history: list[dict] | None = None,
    temperature: float | None = None,
    top_p: float | None = None,
    max_output_tokens: int | None = None,
    truncation: str | None = None,
    store: bool | None = None,
    reasoning_effort: str | None = None,
) -> dict:
    """Build JSON payload for chat endpoints.

    Only includes optional parameters when explicitly set (not None).
    """
    payload: dict = {"message": message, "api_mode": api_mode}
    if model:
        payload["model"] = model
    if previous_response_id:
        payload["previous_response_id"] = previous_response_id
    if instructions:
        payload["instructions"] = instructions
    if history:
        payload["history"] = history
    if temperature is not None:
        payload["temperature"] = temperature
    if top_p is not None:
        payload["top_p"] = top_p
    if max_output_tokens is not None:
        payload["max_output_tokens"] = max_output_tokens
    if truncation is not None:
        payload["truncation"] = truncation
    if store is not None:
        payload["store"] = store
    if reasoning_effort is not None:
        payload["reasoning_effort"] = reasoning_effort
    return payload


def send_message(
    message: str,
    *,
    model: str | None = None,
    api_mode: str = "responses",
    previous_response_id: str | None = None,
    instructions: str | None = None,
    history: list[dict] | None = None,
    temperature: float | None = None,
    top_p: float | None = None,
    max_output_tokens: int | None = None,
    truncation: str | None = None,
    store: bool | None = None,
    reasoning_effort: str | None = None,
) -> dict:
    """Send a chat message via POST /api/chat (synchronous)."""
    payload = _build_chat_payload(
        message,
        model=model,
        api_mode=api_mode,
        previous_response_id=previous_response_id,
        instructions=instructions,
        history=history,
        temperature=temperature,
        top_p=top_p,
        max_output_tokens=max_output_tokens,
        truncation=truncation,
        store=store,
        reasoning_effort=reasoning_effort,
    )

    resp = requests.post(
        f"{_base_url()}/api/chat", json=payload, timeout=120
    )
    resp.raise_for_status()
    return resp.json()


def stream_message(
    message: str,
    *,
    model: str | None = None,
    api_mode: str = "responses",
    previous_response_id: str | None = None,
    instructions: str | None = None,
    history: list[dict] | None = None,
    temperature: float | None = None,
    top_p: float | None = None,
    max_output_tokens: int | None = None,
    truncation: str | None = None,
    store: bool | None = None,
    reasoning_effort: str | None = None,
) -> Iterator[dict]:
    """Send a chat message via POST /api/chat/stream (SSE).

    Yields parsed event dicts:
      - {"type": "created", "response_id": "..."}
      - {"type": "delta", "text": "..."}
      - {"type": "done", "response_id": "...", "model": "...", "usage": {...}}
      - {"type": "error", "message": "..."}
    """
    payload = _build_chat_payload(
        message,
        model=model,
        api_mode=api_mode,
        previous_response_id=previous_response_id,
        instructions=instructions,
        history=history,
        temperature=temperature,
        top_p=top_p,
        max_output_tokens=max_output_tokens,
        truncation=truncation,
        store=store,
        reasoning_effort=reasoning_effort,
    )

    with requests.post(
        f"{_base_url()}/api/chat/stream",
        json=payload,
        stream=True,
        timeout=120,
    ) as resp:
        resp.raise_for_status()
        for line in resp.iter_lines(decode_unicode=True):
            if not line or not line.startswith("data: "):
                continue
            try:
                yield json.loads(line[6:])
            except json.JSONDecodeError:
                logger.warning("Unparseable SSE line: %s", line)
