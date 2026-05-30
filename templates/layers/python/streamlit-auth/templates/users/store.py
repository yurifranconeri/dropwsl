"""Credential storage with a Protocol-based interface.

`YamlStore` is the default file-based implementation. To migrate to a
DB-backed store later, implement the `CredentialStore` Protocol — `gate.py`
and `cli.py` are storage-agnostic.

Threat model:
- Passwords are never stored or transmitted in plaintext.
- `verify` returns a constant-time boolean (bcrypt.checkpw).
- `list` and CLI output never expose hashes.
"""

from __future__ import annotations

import contextlib
import os
from collections.abc import Iterator
from pathlib import Path
from typing import Protocol, TextIO, TypedDict

import bcrypt
import yaml

DEFAULT_CREDENTIALS_PATH = "users_data/credentials.yaml"


class User(TypedDict, total=False):
    username: str
    name: str
    email: str
    password_hash: str
    role: str  # optional coarse-grained access tag


class CredentialStore(Protocol):
    """Interface for credential persistence."""

    def get(self, username: str) -> User | None: ...
    def list(self) -> list[User]: ...
    def upsert(self, user: User) -> None: ...
    def delete(self, username: str) -> bool: ...
    def verify(self, username: str, password: str) -> bool: ...


# ---------------------------------------------------------------------------
# Password helpers
# ---------------------------------------------------------------------------


def hash_password(password: str) -> str:
    """Hash a plaintext password with bcrypt (cost factor 12)."""
    if not password:
        raise ValueError("password must be non-empty")
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode(
        "utf-8"
    )


def verify_password(password: str, password_hash: str) -> bool:
    """Constant-time verify of a plaintext password against a bcrypt hash."""
    if not password or not password_hash:
        return False
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except (ValueError, TypeError):
        return False


# ---------------------------------------------------------------------------
# YAML file-based store
# ---------------------------------------------------------------------------


class YamlStore:
    """File-based credential store using YAML.

    File layout::

        users:
          alice:
            name: Alice Silva
            email: alice@example.com
            password_hash: $2b$12$...
            role: admin            # optional

    Concurrency: a best-effort POSIX flock is acquired during writes. Safe for
    single-process / single-replica deployments. For multi-replica, use a
    DB-backed store.
    """

    def __init__(self, path: str | Path | None = None) -> None:
        env_path = os.environ.get("AUTH_CREDENTIALS_PATH")
        self.path = Path(path or env_path or DEFAULT_CREDENTIALS_PATH)

    # ---- read ----

    def _load(self) -> dict[str, User]:
        if not self.path.exists():
            return {}
        with self.path.open("r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
        users = data.get("users") or {}
        if not isinstance(users, dict):
            return {}
        # normalize: ensure username field is present
        out: dict[str, User] = {}
        for username, raw in users.items():
            if not isinstance(raw, dict):
                continue
            user: User = {"username": str(username)}
            for k in ("name", "email", "password_hash", "role"):
                if k in raw and raw[k] is not None:
                    user[k] = str(raw[k])
            out[user["username"]] = user
        return out

    def get(self, username: str) -> User | None:
        return self._load().get(username)

    def list(self) -> list[User]:
        # Return copies without password_hash to avoid accidental exposure
        return [
            {k: v for k, v in u.items() if k != "password_hash"}  # type: ignore[misc]
            for u in self._load().values()
        ]

    # ---- write ----

    def _save(self, users: dict[str, User]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "users": {
                u["username"]: {
                    k: v for k, v in u.items() if k != "username" and v is not None
                }
                for u in users.values()
            }
        }
        tmp_path = self.path.with_suffix(self.path.suffix + ".tmp")
        with self._locked_write(tmp_path) as f:
            yaml.safe_dump(payload, f, default_flow_style=False, sort_keys=True)
        os.replace(tmp_path, self.path)
        # Best-effort: chmod is a no-op on non-POSIX filesystems (e.g. NTFS via WSL).
        with contextlib.suppress(OSError):
            os.chmod(self.path, 0o600)

    @contextlib.contextmanager
    def _locked_write(self, path: Path) -> Iterator[TextIO]:
        f = path.open("w", encoding="utf-8")
        try:
            try:
                import fcntl

                fcntl.flock(f.fileno(), fcntl.LOCK_EX)
            except (ImportError, OSError):
                pass  # non-POSIX: no lock available, best-effort
            yield f
        finally:
            f.close()

    def upsert(self, user: User) -> None:
        if "username" not in user or not user["username"]:
            raise ValueError("user must have a non-empty 'username'")
        if "password_hash" not in user or not user["password_hash"]:
            raise ValueError("user must have a non-empty 'password_hash'")
        users = self._load()
        users[user["username"]] = user
        self._save(users)

    def delete(self, username: str) -> bool:
        users = self._load()
        if username not in users:
            return False
        del users[username]
        self._save(users)
        return True

    def verify(self, username: str, password: str) -> bool:
        user = self.get(username)
        if user is None:
            return False
        return verify_password(password, user.get("password_hash", ""))


# ---------------------------------------------------------------------------
# streamlit-authenticator interop
# ---------------------------------------------------------------------------


def to_authenticator_credentials(
    store: CredentialStore,
) -> dict[str, dict[str, dict[str, str]]]:
    """Convert store contents to the dict shape expected by
    `streamlit_authenticator.Authenticate(credentials=...)`."""
    users_block: dict[str, dict[str, str]] = {}
    # `store.list()` strips password_hash; we need it here, so go raw.
    if isinstance(store, YamlStore):
        raw = store._load()  # noqa: SLF001 - intentional internal access
        for username, u in raw.items():
            users_block[username] = {
                "name": u.get("name", username),
                "email": u.get("email", ""),
                "password": u.get("password_hash", ""),
            }
    else:
        # Generic path: requires the custom store to expose hashes another way.
        # Document this contract in your store implementation.
        raise NotImplementedError(
            "to_authenticator_credentials only supports YamlStore directly. "
            "Implement an equivalent adapter for custom CredentialStore types."
        )
    return {"usernames": users_block}
