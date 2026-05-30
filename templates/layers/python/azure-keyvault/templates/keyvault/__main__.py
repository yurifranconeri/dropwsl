"""Runnable inspector for the Key Vault module.

Usage:
    python -m {{PKG_PREFIX}}keyvault

Validates AZURE_KEYVAULT_URL, prints the health check, and lists secret metadata.
Never prints any secret value.
"""

import logging
import os
import sys

from .client import keyvault_health
from .secrets import list_secrets

logging.basicConfig(level=logging.WARNING)


def main() -> int:
    url = os.environ.get("AZURE_KEYVAULT_URL", "")
    if not url:
        print("AZURE_KEYVAULT_URL not set.")
        print(
            '\nSet it to your vault URL:\n'
            '  export AZURE_KEYVAULT_URL="https://<vault-name>.vault.azure.net/"'
        )
        return 1

    print(f"Vault:  {url}")
    print(f"Health: {'ok' if keyvault_health() else 'degraded'}\n")

    try:
        items = list_secrets()
    except Exception as exc:
        print(f"Failed to list secrets: {exc}")
        return 2

    if not items:
        print("No secrets found.")
        return 0

    print(f"Secrets ({len(items)}, metadata only — values never printed):")
    for s in items:
        tags = ",".join(f"{k}={v}" for k, v in (s.get("tags") or {}).items()) or "-"
        ct = s.get("content_type") or "-"
        exp = s.get("expires_on") or "-"
        print(f"  - {s['name']}  enabled={s['enabled']}  type={ct}  expires={exp}  tags=[{tags}]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
