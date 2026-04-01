## Chat (Responses + Completions API)

The project includes a **chat layer** that supports both the Responses API (native OpenAI models) and Chat Completions API (partner models, model-router).

### Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/api/chat` | POST | Send a message and get a full response |
| `/api/chat/stream` | POST | Send a message and stream the response (SSE) |

### Request body

```json
{
  "message": "Hello, how are you?",
  "model": "gpt-4.1",
  "previous_response_id": null,
  "instructions": null
}
```

- `message` (required): The user message.
- `model` (optional): Deployment name. Falls back to `AZURE_AI_CHAT_MODEL` env var.
- `previous_response_id` (optional): Chain responses for multi-turn conversations (server-side stateful).
- `instructions` (optional): System prompt / instructions for the model.

### Multi-turn conversations

The Responses API supports **server-side stateful** conversations via `previous_response_id`. No need to send the full history:

```bash
# First message
curl -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What is Python?", "model": "gpt-4.1"}'

# Follow-up (pass the response_id from the first response)
curl -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "How does it compare to JavaScript?", "model": "gpt-4.1", "previous_response_id": "resp_abc123"}'
```

### Streaming (SSE)

The `/api/chat/stream` endpoint returns Server-Sent Events:

```
data: {"type": "created", "response_id": "resp_abc123"}
data: {"type": "delta", "text": "Hello"}
data: {"type": "delta", "text": "!"}
data: {"type": "done", "response_id": "resp_abc123", "model": "gpt-4.1", "usage": {...}}
```

### Structure

- `chat/responses.py` — Responses API: `send_message()`, `send_message_stream()`
- `chat/completions.py` — Chat Completions API: `send_message()`, `send_message_stream()`
- `chat/_common.py` — Shared helpers (model resolution, usage parsing)
- `chat/models.py` — `ChatRequest`, `ChatResponse` (Pydantic)
- `chat/__init__.py` — Re-exports

> The chat layer reuses the OpenAI client from `foundry/client.py` (azure-ai-foundry layer).
