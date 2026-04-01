"""Pydantic models for chat request/response contracts."""

from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    """Chat message request body."""

    message: str
    model: str | None = None
    api_mode: str = Field("responses", pattern=r"^(responses|completions)$")
    previous_response_id: str | None = None
    instructions: str | None = None
    history: list[dict] | None = None
    # Sampling parameters
    temperature: float | None = Field(None, ge=0.0, le=2.0)
    top_p: float | None = Field(None, ge=0.0, le=1.0)
    max_output_tokens: int | None = Field(None, ge=1)
    # Behavior parameters (Responses API only)
    truncation: str | None = None
    store: bool | None = None
    reasoning_effort: str | None = None


class ChatResponse(BaseModel):
    """Chat message response (synchronous)."""

    response_id: str
    model: str
    text: str
    usage: dict
    usage_details: dict = Field(default_factory=dict)
