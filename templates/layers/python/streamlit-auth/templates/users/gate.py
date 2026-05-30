"""Login gate for Streamlit apps.

Usage in `main.py`::

    from {{PKG_PREFIX}}users import require_login

    user = require_login()
    st.sidebar.write(f"Logged in as {user['name']}")

Reads configuration from environment variables (see `.env.example`):

- ``AUTH_COOKIE_KEY``         (required, 32+ chars, no placeholder allowed)
- ``AUTH_COOKIE_NAME``        (default: ``app_auth``)
- ``AUTH_COOKIE_EXPIRY_DAYS`` (default: ``30``)
- ``AUTH_MAX_LOGIN_ATTEMPTS`` (default: ``5``)
- ``AUTH_CREDENTIALS_PATH``   (default: ``users_data/credentials.yaml``)
"""

from __future__ import annotations

import contextlib
import os
from typing import Literal

import streamlit as st
import streamlit_authenticator as stauth

from .store import CredentialStore, User, YamlStore, to_authenticator_credentials

_PLACEHOLDER_COOKIE_KEYS = {
    "",
    "change-me-run-gen-cookie-key",
    "change-me",
}

_MIN_COOKIE_KEY_LEN = 32


class AuthConfigError(RuntimeError):
    """Raised when authentication configuration is missing or insecure."""


def _read_config() -> dict[str, str | int]:
    cookie_key = os.environ.get("AUTH_COOKIE_KEY", "")
    if cookie_key in _PLACEHOLDER_COOKIE_KEYS:
        raise AuthConfigError(
            "AUTH_COOKIE_KEY is unset or placeholder. "
            "Run `python -m {{PKG_PREFIX}}users gen-cookie-key` and put the value in .env."
        )
    if len(cookie_key) < _MIN_COOKIE_KEY_LEN:
        raise AuthConfigError(
            f"AUTH_COOKIE_KEY must be at least {_MIN_COOKIE_KEY_LEN} characters."
        )
    return {
        "cookie_key": cookie_key,
        "cookie_name": os.environ.get("AUTH_COOKIE_NAME", "app_auth"),
        "cookie_expiry_days": int(os.environ.get("AUTH_COOKIE_EXPIRY_DAYS", "30")),
        "max_login_attempts": int(os.environ.get("AUTH_MAX_LOGIN_ATTEMPTS", "5")),
    }


def _get_authenticator(store: CredentialStore) -> stauth.Authenticate:
    cfg = _read_config()
    cache_key = "_users_authenticator"
    if cache_key not in st.session_state:
        st.session_state[cache_key] = stauth.Authenticate(
            credentials=to_authenticator_credentials(store),
            cookie_name=cfg["cookie_name"],
            cookie_key=cfg["cookie_key"],
            cookie_expiry_days=cfg["cookie_expiry_days"],
            pre_authorized=None,
        )
    return st.session_state[cache_key]


def require_login(
    *,
    store: CredentialStore | None = None,
    location: Literal["main", "sidebar"] = "main",
    required_role: str | None = None,
) -> User:
    """Block render until the visitor is authenticated.

    Renders a login form, halts the script via `st.stop()` until credentials
    are valid, then returns the authenticated `User` dict. If
    `required_role` is set and does not match the user's role, the script
    is halted with an access-denied message.
    """
    backing_store = store if store is not None else YamlStore()
    authenticator = _get_authenticator(backing_store)

    cfg = _read_config()
    authenticator.login(location=location, max_login_attempts=cfg["max_login_attempts"])

    status = st.session_state.get("authentication_status")
    if status is False:
        st.error("Invalid username or password.")
        st.stop()
    if status is None:
        st.info("Please enter your credentials.")
        st.stop()

    username = st.session_state.get("username") or ""
    user = backing_store.get(username)
    if user is None:
        st.error("Authenticated user not found in store.")
        st.stop()

    if required_role is not None and user.get("role") != required_role:
        st.error(f"Access denied. Role '{required_role}' required.")
        if hasattr(authenticator, "logout"):
            authenticator.logout(location="sidebar")
        st.stop()

    # Expose logout in the sidebar by default
    if hasattr(authenticator, "logout"):
        authenticator.logout(location="sidebar")

    return user


def logout() -> None:
    """Clear the current session's authentication state and cookie.

    Note: prefer the sidebar Logout button (rendered automatically by
    `require_login`) for end-user flows. This helper is for programmatic
    use (e.g., tests, admin pages that force-logout other sessions of the
    current browser).
    """
    auth = st.session_state.get("_users_authenticator")
    if auth is not None:
        # Best-effort cookie deletion (relies on streamlit-authenticator internals)
        cookie_mgr = getattr(auth, "cookie_manager", None) or getattr(
            auth, "cookie_controller", None
        )
        cookie_name = getattr(auth, "cookie_name", None)
        if cookie_mgr is not None and cookie_name:
            for method in ("delete", "remove"):
                fn = getattr(cookie_mgr, method, None)
                if callable(fn):
                    # Best-effort: streamlit-authenticator's cookie API is not
                    # part of its public contract, so any internal error here
                    # must not block logout.
                    with contextlib.suppress(Exception):
                        fn(cookie_name)
                    break
    for key in (
        "authentication_status",
        "username",
        "name",
        "_users_authenticator",
    ):
        if key in st.session_state:
            del st.session_state[key]


def get_current_user(store: CredentialStore | None = None) -> User | None:
    """Return the currently authenticated user, or None if anonymous.

    Does NOT trigger a login form (unlike `require_login`). Useful for
    optional personalization on public pages.
    """
    if st.session_state.get("authentication_status") is not True:
        return None
    username = st.session_state.get("username") or ""
    if not username:
        return None
    backing_store = store if store is not None else YamlStore()
    return backing_store.get(username)
