


# --- Chat (Responses API + Chat Completions API) ---


def _dispatch_chat(body: ChatRequest) -> dict:
    """Route to Responses or Completions API based on api_mode."""
    if body.api_mode == "completions":
        return send_message_completions(
            body.message,
            model=body.model,
            instructions=body.instructions,
            history=body.history,
            temperature=body.temperature,
            top_p=body.top_p,
            max_output_tokens=body.max_output_tokens,
            reasoning_effort=body.reasoning_effort,
        )
    return send_message(
        body.message,
        model=body.model,
        previous_response_id=body.previous_response_id,
        instructions=body.instructions,
        temperature=body.temperature,
        top_p=body.top_p,
        max_output_tokens=body.max_output_tokens,
        truncation=body.truncation,
        store=body.store,
        reasoning_effort=body.reasoning_effort,
    )


def _dispatch_chat_stream(body: ChatRequest):
    """Route streaming to Responses or Completions API based on api_mode."""
    if body.api_mode == "completions":
        return send_message_stream_completions(
            body.message,
            model=body.model,
            instructions=body.instructions,
            history=body.history,
            temperature=body.temperature,
            top_p=body.top_p,
            max_output_tokens=body.max_output_tokens,
            reasoning_effort=body.reasoning_effort,
        )
    return send_message_stream(
        body.message,
        model=body.model,
        previous_response_id=body.previous_response_id,
        instructions=body.instructions,
        temperature=body.temperature,
        top_p=body.top_p,
        max_output_tokens=body.max_output_tokens,
        truncation=body.truncation,
        store=body.store,
        reasoning_effort=body.reasoning_effort,
    )


@app.post("/api/chat")
def api_chat(body: ChatRequest) -> dict:
    """Send a message — routes to Responses or Completions API."""
    return _dispatch_chat(body)


@app.post("/api/chat/stream")
def api_chat_stream(body: ChatRequest):
    """Send a message and stream the response (SSE)."""
    import json

    from fastapi.responses import StreamingResponse

    def event_generator():
        try:
            for event in _dispatch_chat_stream(body):
                yield f"data: {json.dumps(event)}\n\n"
        except Exception as exc:
            yield f"data: {json.dumps({'type': 'error', 'message': str(exc)})}\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")
