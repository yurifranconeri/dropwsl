"""Streamlit panel for Azure Identity — opt-in.

Render in your Streamlit app:

    import streamlit as st
    from {{PKG_PREFIX}}auth.ui import render_identity_panel
    render_identity_panel(st)            # or st.sidebar
"""

from typing import Any

from azure.core.exceptions import ClientAuthenticationError

from .credential import decode_token_claims, get_credential


def render_identity_panel(st: Any) -> None:
    """Render a self-contained Azure Identity status panel."""
    st.subheader("Azure Identity")
    try:
        credential = get_credential()
        token = credential.get_token("https://management.azure.com/.default")
    except ClientAuthenticationError as exc:
        st.error(f"Authentication failed: {exc.message}")
        st.caption("Run `az login` inside the dev container.")
        return
    except Exception as exc:
        st.error(f"DefaultAzureCredential failed: {exc}")
        return

    claims = decode_token_claims(token.token)
    st.success("Authenticated.")
    st.write(
        {
            "name": claims.get("name", ""),
            "email": claims.get("upn", claims.get("unique_name", "")),
            "tenant_id": claims.get("tid", ""),
            "object_id": claims.get("oid", ""),
            "expires_at": claims.get("exp_iso", ""),
        }
    )
