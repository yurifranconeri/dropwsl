"""Streamlit panel for Azure AI Foundry — opt-in.

Render in your Streamlit app:

    import streamlit as st
    from {{PKG_PREFIX}}foundry.ui import render_foundry_panel
    render_foundry_panel(st)            # or st.sidebar
"""

import os
from typing import Any

from .client import foundry_health
from .connections import list_connections
from .models import list_models


def render_foundry_panel(st: Any) -> None:
    """Render a self-contained Foundry status panel."""
    st.subheader("Azure AI Foundry")
    endpoint = os.environ.get("AZURE_AI_PROJECT_ENDPOINT", "")
    if not endpoint:
        st.warning("AZURE_AI_PROJECT_ENDPOINT not set.")
        return

    st.caption(endpoint)
    if not foundry_health():
        st.error("Project unreachable. Check credentials and endpoint.")
        return

    try:
        models = list_models()
        connections = list_connections()
    except Exception as exc:
        st.error(f"Discovery failed: {exc}")
        return

    st.success(f"Connected. {len(models)} model(s), {len(connections)} connection(s).")

    if models:
        with st.expander(f"Model deployments ({len(models)})"):
            st.dataframe(
                [
                    {
                        "name": m["name"],
                        "model": m.get("model_name", ""),
                        "publisher": m.get("model_publisher", ""),
                        "capabilities": ", ".join(m.get("capabilities", [])),
                    }
                    for m in models
                ],
                use_container_width=True,
            )

    if connections:
        with st.expander(f"Connections ({len(connections)})"):
            st.dataframe(connections, use_container_width=True)
