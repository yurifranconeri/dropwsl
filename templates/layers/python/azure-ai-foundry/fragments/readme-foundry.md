## Azure AI Foundry

The project uses **AIProjectClient** from `azure-ai-projects` to connect to a Microsoft Foundry project.

### Configuration

Set the project endpoint:

```bash
export AZURE_AI_PROJECT_ENDPOINT="https://<resource>.services.ai.azure.com/api/projects/<project>"
```

Find this URL in your Microsoft Foundry project overview page.

### API endpoints

| Endpoint | Description |
|---|---|
| `GET /api/foundry/status` | Project dashboard: connection status, model count, connections |
| `GET /api/models` | List model deployments (filters: `?model_name=`, `?model_publisher=`) |
| `GET /api/models/{name}` | Full details of a single deployment |
| `GET /api/connections` | List connected Azure resources (filter: `?connection_type=`) |
| `GET /api/connections/default/{type}` | Default connection for a given type |

### Local development

```bash
# Inside the dev container:
az login
export AZURE_AI_PROJECT_ENDPOINT="https://..."
python main.py
```

### Structure

- `foundry/client.py` — `AIProjectClient` + `OpenAI` singletons, health check
- `foundry/models.py` — Model deployment discovery and inspection
- `foundry/connections.py` — Connected resources discovery
- `foundry/__init__.py` — Re-exports

> The Foundry client reuses the credential from `auth/credential.py` (azure-identity layer).
