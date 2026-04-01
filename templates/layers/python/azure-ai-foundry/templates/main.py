"""Azure AI Foundry — project discovery: models, connections."""

import logging
import os

from foundry.client import foundry_health
from foundry.connections import list_connections
from foundry.models import list_models

logging.basicConfig(level=logging.WARNING)


def main() -> None:
    endpoint = os.environ.get("AZURE_AI_PROJECT_ENDPOINT", "")
    if not endpoint:
        print("AZURE_AI_PROJECT_ENDPOINT not set.")
        print(
            "\nSet it to your Foundry project endpoint:\n"
            "  export AZURE_AI_PROJECT_ENDPOINT="
            '"https://<resource>.services.ai.azure.com/api/projects/<project>"'
        )
        return

    print(f"Endpoint: {endpoint}")
    print(f"Health:   {'ok' if foundry_health() else 'degraded'}\n")

    try:
        models = list_models()
        if models:
            print(f"Model deployments ({len(models)}):")
            for m in models:
                caps = ", ".join(m.get("capabilities", [])) or "n/a"
                print(f"  - {m['name']}  model={m['model_name']}  publisher={m['model_publisher']}  capabilities=[{caps}]")
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


if __name__ == "__main__":
    main()
