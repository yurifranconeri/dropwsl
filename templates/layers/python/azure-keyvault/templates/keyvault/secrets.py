"""Key Vault secret discovery and retrieval.

Defaults to metadata-only. Reading values requires explicit `reveal=True`
and emits a WARNING log entry — secret values must never leak by accident.
"""

import logging
import re
from typing import Any

from .client import get_secret_client

logger = logging.getLogger(__name__)

# Azure Key Vault secret name rules: 1-127 chars, [0-9a-zA-Z-]
_NAME_RE = re.compile(r"^[0-9a-zA-Z-]{1,127}$")


def _validate_name(name: str) -> None:
    if not isinstance(name, str) or not _NAME_RE.match(name):
        raise ValueError(
            f"Invalid secret name: {name!r}. "
            "Must be 1-127 characters, [0-9a-zA-Z-] only."
        )


def _props_to_dict(props: Any) -> dict:
    """Serialize SecretProperties to a JSON-safe dict (metadata only)."""
    return {
        "name": props.name,
        "id": str(props.id) if props.id else None,
        "version": props.version,
        "enabled": props.enabled,
        "content_type": props.content_type,
        "tags": dict(props.tags) if props.tags else {},
        "expires_on": props.expires_on.isoformat() if props.expires_on else None,
        "created_on": props.created_on.isoformat() if props.created_on else None,
        "updated_on": props.updated_on.isoformat() if props.updated_on else None,
    }


def list_secrets(enabled_only: bool = True) -> list[dict]:
    """List all secret metadata in the vault. Values are NEVER included."""
    client = get_secret_client()
    out: list[dict] = []
    for props in client.list_properties_of_secrets():
        if enabled_only and props.enabled is False:
            continue
        out.append(_props_to_dict(props))
    return out


def get_secret(name: str, reveal: bool = False) -> dict:
    """Get a secret. By default returns metadata only.

    Args:
        name: Secret name (1-127 chars, [0-9a-zA-Z-]).
        reveal: When True, includes the secret value in the result and logs a WARNING.

    Raises:
        ValueError: If the name violates Azure Key Vault naming rules.
        KeyError: If the secret does not exist.
    """
    _validate_name(name)
    client = get_secret_client()
    try:
        secret = client.get_secret(name)
    except Exception as exc:
        # ResourceNotFoundError -> KeyError for a clean public contract
        if "SecretNotFound" in repr(exc) or "NotFound" in repr(exc):
            raise KeyError(f"Secret not found: {name!r}") from exc
        raise

    result = _props_to_dict(secret.properties)
    if reveal:
        logger.warning("Secret value revealed for %r — caller must handle it securely.", name)
        result["value"] = secret.value
    return result
