## Chat UI

The project includes a **Streamlit Chat UI** that connects to the backend Chat API via HTTP.

| Feature | Detail |
|---|---|
| Streaming | SSE with typing cursor |
| Multi-turn | Server-side stateful via `previous_response_id` |
| Model selector | Auto-populated from `/api/models` |
| System prompt | Configurable per conversation |

### Configuration

| Variable | Default | Description |
|---|---|---|
| `CHAT_API_URL` | `http://localhost:8000` | Backend API base URL |

### Structure

- `chat_ui/api.py` — HTTP client (`get_models`, `send_message`, `stream_message`)
- `chat_ui/__init__.py` — Re-exports
