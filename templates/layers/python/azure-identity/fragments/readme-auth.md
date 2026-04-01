## Authentication (Azure Identity)

The project uses **DefaultAzureCredential** for Azure authentication.
The credential chain tries (in order): environment variables, managed identity, Azure CLI, and browser.

### Local development

```bash
# Inside the dev container:
az login
python main.py
```

### CI/CD / Production

Set environment variables:

```bash
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
```

### Structure

- `auth/credential.py` — `DefaultAzureCredential` singleton, health check, JWT decode
- `auth/__init__.py` — Re-exports

> Run `az login` once inside the dev container. The token is cached for subsequent runs.
