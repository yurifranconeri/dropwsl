"""User authentication for Streamlit apps.

Public API:

    from {{PKG_PREFIX}}users import require_login, logout, get_current_user

Storage is abstracted via the `CredentialStore` Protocol; `YamlStore` is the
default. Credentials are stored as bcrypt hashes in
`users_data/credentials.yaml` (gitignored). The cookie HMAC key comes from
the `AUTH_COOKIE_KEY` environment variable.
"""

from .gate import get_current_user, logout, require_login
from .store import (
    CredentialStore,
    User,
    YamlStore,
    hash_password,
    verify_password,
)

__all__ = [
    "CredentialStore",
    "User",
    "YamlStore",
    "get_current_user",
    "hash_password",
    "logout",
    "require_login",
    "verify_password",
]
