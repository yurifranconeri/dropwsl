"""{{PROJECT_NAME}} — Chat UI powered by Streamlit + Azure AI."""

import contextlib
import time

import streamlit as st

from chat_ui.api import get_models, stream_message

# ── Page config ───────────────────────────────────────────────────

st.set_page_config(
    page_title="{{PROJECT_NAME}} — Chat",
    page_icon="💬",
    layout="centered",
)

# ── Session state defaults ────────────────────────────────────────

if "messages" not in st.session_state:
    st.session_state.messages = []
if "chat_history" not in st.session_state:
    st.session_state.chat_history = []
if "response_id" not in st.session_state:
    st.session_state.response_id = None
if "last_usage" not in st.session_state:
    st.session_state.last_usage = {}
if "last_usage_details" not in st.session_state:
    st.session_state.last_usage_details = {}
if "last_model" not in st.session_state:
    st.session_state.last_model = ""
if "last_latency_ms" not in st.session_state:
    st.session_state.last_latency_ms = 0
if "last_api_mode" not in st.session_state:
    st.session_state.last_api_mode = ""
if "models" not in st.session_state:
    with contextlib.suppress(Exception):
        st.session_state.models = get_models()
    if "models" not in st.session_state:
        st.session_state.models = []

# ── Sidebar ───────────────────────────────────────────────────────

with st.sidebar:
    st.title("Settings")

    # API Mode toggle
    api_mode_label = st.selectbox(
        "API Mode",
        options=["Responses", "Chat Completions"],
        index=0,
        help="Responses API: native OpenAI models (gpt-4.1, o-series, gpt-5). "
        "Chat Completions: all models (partner, model-router, etc).",
    )
    _is_completions = api_mode_label == "Chat Completions"

    # Model selector — only models with chat_completion capability
    chat_models = [
        m["name"]
        for m in st.session_state.models
        if "chat_completion" in m.get("capabilities", [])
    ]
    if not chat_models:
        st.warning("No chat models available. Is the backend running?")
        chat_models = ["gpt-4.1"]

    selected_model = st.selectbox("Model", chat_models)

    # System prompt
    system_prompt = st.text_area(
        "System prompt",
        placeholder="You are a helpful assistant.",
        height=80,
    )

    # New chat
    if st.button("New Chat", use_container_width=True):
        st.session_state.messages = []
        st.session_state.chat_history = []
        st.session_state.response_id = None
        st.session_state.last_usage = {}
        st.session_state.last_usage_details = {}
        st.session_state.last_model = ""
        st.session_state.last_latency_ms = 0
        st.session_state.last_api_mode = ""
        with contextlib.suppress(Exception):
            st.session_state.models = get_models()
        st.rerun()

    # ── Parameters ────────────────────────────────────────────────

    st.divider()
    st.subheader("Parameters")

    temperature = st.slider(
        "Temperature",
        min_value=0.0,
        max_value=2.0,
        value=1.0,
        step=0.05,
        help="Controls randomness. Lower = focused and deterministic, "
        "higher = creative and varied. Default: 1.0",
    )

    top_p = st.slider(
        "Top P",
        min_value=0.0,
        max_value=1.0,
        value=1.0,
        step=0.05,
        help="Nucleus sampling. 0.1 = only top 10%% probability tokens. "
        "Adjust this OR temperature, not both. Default: 1.0",
    )

    if temperature != 1.0 and top_p != 1.0:
        st.caption(
            "⚠️ Changing both Temperature and Top P is not recommended "
            "— adjust one at a time for predictable results."
        )

    limit_tokens = st.checkbox("Limit output tokens", value=False)
    max_output_tokens = None
    if limit_tokens:
        max_output_tokens = st.number_input(
            "Max output tokens",
            min_value=1,
            max_value=128000,
            value=4096,
            step=256,
            help="Upper bound for generated tokens (including reasoning). "
            "Leave unchecked for no limit.",
        )

    truncation = st.selectbox(
        "Truncation",
        options=["disabled", "auto"],
        index=0,
        disabled=_is_completions,
        help="'auto' silently truncates input if it exceeds the model's "
        "context window. 'disabled' returns a 400 error instead."
        + (" (Not available in Chat Completions mode)" if _is_completions else ""),
    )

    # ── Reasoning (collapsed — o-series / gpt-5 only) ────────────

    with st.expander("Reasoning (o-series / gpt-5 only)"):
        reasoning_options = ["None", "low", "medium", "high"]
        reasoning_effort = st.selectbox(
            "Reasoning effort",
            options=reasoning_options,
            index=0,
            help="How much effort the model spends on internal reasoning. "
            "Only supported by reasoning models (o-series, gpt-5). "
            "Other models will return an error if set.",
        )
        if reasoning_effort == "None":
            reasoning_effort = None

    # ── Advanced (collapsed) ──────────────────────────────────────

    with st.expander("Advanced"):
        store = st.checkbox(
            "Store response",
            value=True,
            disabled=_is_completions,
            help="Save the response server-side for later retrieval via API. "
            "Disable for privacy-sensitive conversations."
            + (" (Not available in Chat Completions mode)" if _is_completions else ""),
        )

    # ── Debug toggle (ON by default) ─────────────────────────────

    st.divider()
    debug_enabled = st.toggle("Debug bar", value=True)

# ── Prepare optional params (only non-default) ───────────────────

_api_mode = "completions" if _is_completions else "responses"
_temperature = temperature if temperature != 1.0 else None
_top_p = top_p if top_p != 1.0 else None
_truncation = truncation if truncation != "disabled" and not _is_completions else None
_store = store if not store and not _is_completions else None

# ── Chat ──────────────────────────────────────────────────────────

st.title("{{PROJECT_NAME}}")

for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])

if prompt := st.chat_input("Type a message..."):
    # Show user message
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    # Build history for Chat Completions mode
    _history = st.session_state.chat_history if _is_completions else None
    _prev_id = st.session_state.response_id if not _is_completions else None

    # Stream AI response
    with st.chat_message("assistant"):
        placeholder = st.empty()
        full_text = ""
        error_text = ""
        t_start = time.monotonic()

        try:
            for event in stream_message(
                prompt,
                model=selected_model,
                api_mode=_api_mode,
                previous_response_id=_prev_id,
                instructions=system_prompt or None,
                history=_history,
                temperature=_temperature,
                top_p=_top_p,
                max_output_tokens=max_output_tokens,
                truncation=_truncation,
                store=_store,
                reasoning_effort=reasoning_effort,
            ):
                etype = event.get("type")
                if etype == "delta":
                    full_text += event.get("text", "")
                    placeholder.markdown(full_text + "▌")
                elif etype == "done":
                    st.session_state.response_id = event.get("response_id")
                    st.session_state.last_usage = event.get("usage", {})
                    st.session_state.last_usage_details = event.get(
                        "usage_details", {}
                    )
                    st.session_state.last_model = event.get("model", "")
                    st.session_state.last_api_mode = _api_mode
                elif etype == "error":
                    error_text = event.get("message", "Unknown error")
        except Exception as exc:
            error_text = str(exc)

        t_end = time.monotonic()
        st.session_state.last_latency_ms = (t_end - t_start) * 1000

        if error_text:
            placeholder.empty()
            st.error(error_text)
            full_text = f"Error: {error_text}"
        else:
            placeholder.markdown(full_text)

        # ── Inline debug (inside assistant bubble) ────────────
        if debug_enabled and not error_text:
            u = st.session_state.last_usage
            ud = st.session_state.last_usage_details
            tok_summary = ""
            if u:
                tok_summary = (
                    f" | **Tokens:** {u.get('input_tokens', 0)} in"
                    f" / {u.get('output_tokens', 0)} out"
                    f" / {u.get('total_tokens', 0)} total"
                )
                reasoning_tok = ud.get("reasoning_tokens", 0)
                cached_tok = ud.get("cached_tokens", 0)
                if reasoning_tok:
                    tok_summary += f" ({reasoning_tok} reasoning)"
                if cached_tok:
                    tok_summary += f" ({cached_tok} cached)"
            st.caption(
                f"**{st.session_state.last_api_mode}** | "
                f"{st.session_state.last_model} | "
                f"{st.session_state.last_latency_ms:,.0f} ms"
                f"{tok_summary}  \n"
                f"`{st.session_state.response_id or '—'}`"
            )

    st.session_state.messages.append(
        {"role": "assistant", "content": full_text}
    )
    # Update history for Chat Completions multi-turn
    if _is_completions:
        st.session_state.chat_history.append(
            {"role": "user", "content": prompt}
        )
        st.session_state.chat_history.append(
            {"role": "assistant", "content": full_text}
        )
