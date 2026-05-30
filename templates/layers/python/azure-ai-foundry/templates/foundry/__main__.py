"""Runnable inspector for the Foundry module.

Usage:
    python -m {{PKG_PREFIX}}foundry

Validates AZURE_AI_PROJECT_ENDPOINT, prints health, lists model deployments
and connections.
"""

import logging
import os
import sys

from .client import foundry_health
from .connections import list_connections
from .models import list_models

logging.basicConfig(level=logging.WARNING)


def main() -> int:
    endpoint = os.environ.get("AZURE_AI_PROJECT_ENDPOINT", "")
    if not endpoint:
        print("AZURE_AI_PROJECT_ENDPOINT not set.")
        print(
            "\nSet it to your Foundry project endpoint:\n"
            "  export AZURE_AI_PROJECT_ENDPOINT="
            '"https://<resource>.services.ai.azure.com/api/projects/<project>"'
        )
        return 1

    print(f"Endpoint: {endpoint}")
    print(f"Health:   {'ok' if foundry_health() else 'degraded'}\n")

    try:
        models = list_models()
        if models:
            print(f"Model deployments ({len(models)}):")
            for m in models:
                caps = ", ".join(m.get("capabilities", [])) or "n/a"
                print(
                    f"  - {m['name']}  model={m['model_name']}  "
                    f"publisher={m['model_publisher']}  capabilities=[{caps}]"
                )
        else:
            print("No model deployments found.")
    except Exception as exc:
        print(f"Failed to list models: {exc}")

    try:
        connections = list_connections()
        if connections:
            print(f"\nConnections ({len(connections)}):")
            for c in connections:
                print(f"  - {c['name']}  type={c['connection_type']}  target={c['target']}")
        else:
            print("\nNo connections found.")
    except Exception as exc:
        print(f"Failed to list connections: {exc}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
