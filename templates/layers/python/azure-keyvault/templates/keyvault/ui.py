"""Streamlit panel for Key Vault — opt-in.

Render in your Streamlit app:

    import streamlit as st
    from {{PKG_PREFIX}}keyvault.ui import render_keyvault_panel
    render_keyvault_panel(st)

Or as a sidebar widget:

    render_keyvault_panel(st.sidebar)

The panel only displays metadata. Secret values are never rendered in the UI.
"""

import os
from typing import Any

from .client import keyvault_health
from .secrets import list_secrets


def render_keyvault_panel(st: Any) -> None:
    """Render a self-contained Key Vault status panel."""
    st.subheader("Azure Key Vault")
    url = os.environ.get("AZURE_KEYVAULT_URL", "")
    if not url:
        st.warning("AZURE_KEYVAULT_URL not set.")
        return

    st.caption(url)
    if not keyvault_health():
        st.error("Vault unreachable. Check credentials and URL.")
        return

    try:
        items = list_secrets()
    except Exception as exc:
        st.error(f"Failed to list secrets: {exc}")
        return

    st.success(f"Connected. {len(items)} secret(s) discovered.")
    if not items:
        return
    with st.expander(f"Secrets ({len(items)}) — metadata only"):
        st.dataframe(
            [
                {
                    "name": s["name"],
                    "enabled": s["enabled"],
                    "content_type": s.get("content_type") or "",
                    "expires_on": s.get("expires_on") or "",
                    "updated_on": s.get("updated_on") or "",
                }
                for s in items
            ],
            use_container_width=True,
        )
