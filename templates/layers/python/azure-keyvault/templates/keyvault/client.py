"""Azure Key Vault client — lazy singleton sharing the credential from auth/."""

import logging
import os

from azure.keyvault.secrets import SecretClient

from auth.credential import get_credential

logger = logging.getLogger(__name__)

_client: SecretClient | None = None


def get_secret_client() -> SecretClient:
    """Return a shared SecretClient instance (lazy init).

    Raises ValueError if AZURE_KEYVAULT_URL is not set.
    """
    global _client  # noqa: PLW0603
    if _client is None:
        url = os.environ.get("AZURE_KEYVAULT_URL", "")
        if not url:
            raise ValueError(
                "AZURE_KEYVAULT_URL not set. "
                "Find it in the Azure Portal: Key Vault > Overview > Vault URI."
            )
        _client = SecretClient(vault_url=url, credential=get_credential())
    return _client


def keyvault_health() -> bool:
    """Return True if the vault is reachable.

    Uses list_properties_of_secrets — does NOT read any secret value.
    """
    try:
        client = get_secret_client()
        next(iter(client.list_properties_of_secrets()), None)
        return True
    except Exception:
        logger.debug("keyvault_health failed", exc_info=True)
        return False
