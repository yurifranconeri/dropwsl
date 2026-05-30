## Chat (Responses + Completions API)

Self-contained `chat/` package: shipped as a runnable Python module with optional FastAPI router and Streamlit panel. The layer never modifies `main.py`.

### Quick check (no integration)

```bash
export AZURE_AI_CHAT_MODEL="gpt-4.1"
python -m {{PKG_PREFIX}}chat
```

Interactive Responses-API chat in the terminal.

### FastAPI integration (opt-in)

Add two lines to your `main.py`:

```python
from {{PKG_PREFIX}}chat.router import router as chat_router

app.include_router(chat_router, prefix="/api")
```

Endpoints:

| Endpoint | Method | Description |
|---|---|---|
| `/api/chat` | POST | Send a message and get a full response |
| `/api/chat/stream` | POST | Send a message and stream the response (SSE) |

### Streamlit integration (opt-in)

```python
import streamlit as st
from {{PKG_PREFIX}}chat.ui import render_chat_panel

render_chat_panel(st)
```

Maintains conversation history in `st.session_state` and uses `previous_response_id` for server-side multi-turn.

### Request body (HTTP)

```json
{
  "message": "Hello, how are you?",
  "model": "gpt-4.1",
  "previous_response_id": null,
  "instructions": null,
  "api_mode": "responses"
}
```

- `message` (required): the user message.
- `model` (optional): deployment name. Falls back to `AZURE_AI_CHAT_MODEL`.
- `previous_response_id` (optional, Responses only): chain responses for multi-turn (server-side stateful).
- `instructions` (optional): system prompt.
- `api_mode` (optional, default `responses`): switch to `completions` for partner models / model-router.

### Streaming (SSE)

```
data: {"type": "created", "response_id": "resp_abc123"}
data: {"type": "delta", "text": "Hello"}
data: {"type": "delta", "text": "!"}
data: {"type": "done", "response_id": "resp_abc123", "model": "gpt-4.1", "usage": {...}}
```

### Structure

- `chat/__main__.py` — runnable CLI inspector (`python -m {{PKG_PREFIX}}chat`)
- `chat/responses.py` — Responses API: `send_message()`, `send_message_stream()`
- `chat/completions.py` — Chat Completions API (partner models, model-router)
- `chat/_common.py` — shared helpers (model resolution, usage parsing, `chat_health()`)
- `chat/models.py` — `ChatRequest`, `ChatResponse` (Pydantic)
- `chat/router.py` — FastAPI `APIRouter` (opt-in)
- `chat/ui.py` — Streamlit `render_chat_panel()` (opt-in)
- `chat/__init__.py` — re-exports

> The chat layer reuses the OpenAI client from `foundry/client.py` (azure-ai-foundry layer).
