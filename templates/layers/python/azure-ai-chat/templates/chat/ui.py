"""Streamlit panel for chat — opt-in.

Render in your Streamlit app:

    import streamlit as st
    from {{PKG_PREFIX}}chat.ui import render_chat_panel
    render_chat_panel(st)

Maintains conversation history in st.session_state["chat_history"] and uses
server-side state via previous_response_id when api_mode="responses".
"""

from typing import Any

from ._common import chat_health
from .responses import send_message, send_message_stream


def render_chat_panel(st: Any, *, key_prefix: str = "chat") -> None:
    """Render a self-contained chat panel using the Responses API."""
    st.subheader("Chat")
    if not chat_health():
        st.warning("AZURE_AI_CHAT_MODEL not set. Set it to a deployment name.")
        return

    history_key = f"{key_prefix}_history"
    response_id_key = f"{key_prefix}_response_id"
    if history_key not in st.session_state:
        st.session_state[history_key] = []
    if response_id_key not in st.session_state:
        st.session_state[response_id_key] = None

    for entry in st.session_state[history_key]:
        with st.chat_message(entry["role"]):
            st.markdown(entry["content"])

    user_input = st.chat_input("Type a message")
    if not user_input:
        return

    st.session_state[history_key].append({"role": "user", "content": user_input})
    with st.chat_message("user"):
        st.markdown(user_input)

    with st.chat_message("assistant"):
        placeholder = st.empty()
        buffer: list[str] = []
        new_response_id: str | None = None
        try:
            for event in send_message_stream(
                user_input,
                previous_response_id=st.session_state[response_id_key],
            ):
                if event.get("type") == "created":
                    new_response_id = event.get("response_id")
                elif event.get("type") == "delta":
                    buffer.append(event.get("text", ""))
                    placeholder.markdown("".join(buffer))
                elif event.get("type") == "done":
                    new_response_id = event.get("response_id") or new_response_id
        except Exception as exc:
            placeholder.error(f"Chat failed: {exc}")
            return

        text = "".join(buffer)
        placeholder.markdown(text)
        st.session_state[history_key].append({"role": "assistant", "content": text})
        if new_response_id:
            st.session_state[response_id_key] = new_response_id
