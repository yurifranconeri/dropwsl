"""Chat package — Responses API + Chat Completions API.

Public API:
  - send_message(), send_message_stream()                    (Responses API)
  - send_message_completions(), send_message_stream_completions()
  - chat_health(), ChatRequest, ChatResponse

CLI:
  python -m {{PKG_PREFIX}}chat   # interactive Responses-API chat

Optional integrations (opt-in by import — layer never modifies main.py):
  - chat.router  — FastAPI APIRouter (mount with app.include_router)
  - chat.ui      — Streamlit panel (call render_chat_panel(st))
"""

from ._common import chat_health
from .completions import send_message as send_message_completions
from .completions import send_message_stream as send_message_stream_completions
from .models import ChatRequest, ChatResponse
from .responses import send_message, send_message_stream

__all__ = [
    "ChatRequest",
    "ChatResponse",
    "chat_health",
    "send_message",
    "send_message_completions",
    "send_message_stream",
    "send_message_stream_completions",
]
