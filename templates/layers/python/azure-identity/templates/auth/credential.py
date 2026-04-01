"""Azure credential — lazy singleton using DefaultAzureCredential.

DefaultAzureCredential tries (in order):
  1. Environment variables (AZURE_CLIENT_ID + AZURE_TENANT_ID + AZURE_CLIENT_SECRET)
  2. Workload Identity (Kubernetes)
  3. Managed Identity (Azure VMs, App Service, Functions, Container Apps)
  4. Azure CLI (az login)
  5. Azure Developer CLI (azd auth login)
  6. Azure PowerShell
  7. Interactive Browser (fallback)

The same code works in dev and prod without changes.
"""

import base64
import json
import logging
from datetime import UTC, datetime

from azure.core.exceptions import ClientAuthenticationError
from azure.identity import DefaultAzureCredential

logger = logging.getLogger(__name__)

_credential: DefaultAzureCredential | None = None

# Default scope for Azure management plane — used by health check and token decode.
_DEFAULT_SCOPE = "https://management.azure.com/.default"


def get_credential() -> DefaultAzureCredential:
    """Return a shared DefaultAzureCredential instance (lazy init)."""
    global _credential  # noqa: PLW0603
    if _credential is None:
        _credential = DefaultAzureCredential()
    return _credential


def credential_health() -> bool:
    """Return True if the credential can acquire a token."""
    try:
        get_credential().get_token(_DEFAULT_SCOPE)
        return True
    except (ClientAuthenticationError, Exception):
        logger.debug("credential_health failed", exc_info=True)
        return False


def decode_token_claims(token: str) -> dict:
    """Decode JWT payload (claims) without signature verification.

    This is safe for local inspection — the token was just acquired from
    a trusted identity provider. Never use this for authorization decisions.
    """
    # JWT = header.payload.signature — we only need the payload (index 1)
    payload = token.split(".")[1]
    # Fix base64 padding
    padding = 4 - len(payload) % 4
    if padding != 4:
        payload += "=" * padding
    decoded = json.loads(base64.urlsafe_b64decode(payload))
    # Add human-readable expiration
    exp = decoded.get("exp")
    if exp:
        decoded["exp_iso"] = datetime.fromtimestamp(exp, tz=UTC).isoformat()
    return decoded
