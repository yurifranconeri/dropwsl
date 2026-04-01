# dropwsl

<!-- badges -->
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> Dev environment on WSL with a single command.

dropwsl installs Docker, kubectl, kind, helm, Azure CLI, GitHub CLI, and generates projects with ready-to-use Dev Containers — all in one run.

**Philosophy:** WSL handles infrastructure (Docker, k8s tooling). Languages and runtimes live **inside containers**, isolated per project. VS Code connects via Remote WSL + Dev Containers.

## Quick Start

### One-liner (no git required)

Open **Terminal** or **Command Prompt** as Administrator and run:

```bat
curl.exe -fsSL -o %TEMP%\install.cmd https://raw.githubusercontent.com/yurifranconeri/dropwsl/main/install.cmd && %TEMP%\install.cmd
```

Downloads the latest `install.cmd` from `main`, then fetches the latest repository snapshot and runs the installer. Installs WSL + Ubuntu (if needed), configures `.wslconfig`, and provisions the environment automatically.

> The bootstrap path is rolling: it always installs the latest version currently available on `main`.

> If WSL was just installed, restart Windows and run `C:\dropwsl\install.cmd` again.

### From a clone (for contributors)

```powershell
git clone https://github.com/yurifranconeri/dropwsl.git C:\dropwsl
cd C:\dropwsl
.\install.cmd   # Run as Administrator
```

### Manual

```powershell
wsl --install Ubuntu-24.04
# Restart Windows if prompted, then:
```

```bash
# Inside WSL
git clone https://github.com/yurifranconeri/dropwsl.git ~/dropwsl
cd ~/dropwsl
bash dropwsl.sh
```

On first run the script enables `systemd` and **WSL will shut down** — this is expected. Reopen WSL and run again.

### Verify

```bash
# Reopen WSL (so the docker group takes effect)
docker run hello-world
dropwsl validate
```

### Create Your First Project

```bash
dropwsl new my-service python
# → VS Code opens → accept "Reopen in Container" → done!
```

## Prerequisites

- Windows 10/11 with WSL 2
- Ubuntu 22.04+ or Debian 12+ (Ubuntu 24.04 recommended)
- Internet access
- *(Optional)* [Git for Windows](https://git-scm.com/download/win) — needed for GCM credential helper

## What Gets Installed

| Tool | Source |
|------|--------|
| systemd | `/etc/wsl.conf` |
| Docker Engine + Compose v2 + BuildX | Official Docker repo |
| kubectl | Official `pkgs.k8s.io` repo |
| kind | Binary with SHA256 checksum |
| helm | Official install script |
| Azure CLI | Microsoft apt repo |
| GitHub CLI | Official apt repo |
| Git Credential Manager | Git for Windows (auto-configured) |
| VS Code extensions | WSL, Dev Containers, Docker (Windows-side) |

> Tools and versions are configurable via [`config.yaml`](config.yaml).

## Commands

After installation, day-to-day commands work from **PowerShell** (proxied to WSL) or directly inside **WSL**. The initial bootstrap entry point is `install.cmd`.

| Command | Description |
|---------|-------------|
| `dropwsl install` | Install all tools + validate |
| `dropwsl validate` | Validate only (no installs) |
| `dropwsl doctor` | Diagnostics with probable causes and fixes |
| `dropwsl scaffold python` | Add Dev Container to an existing project |
| `dropwsl new <name> <lang>` | Create new project with Dev Container |
| `dropwsl new <ws> --service <svc> <lang>` | Create service in a multi-service workspace |
| `dropwsl update` | Update scripts and templates |
| `dropwsl clean-soft` | Remove tools (preserves the distro) |
| `dropwsl --help` | Full help |

**Flags:** `--quiet` (`-q`), `--yes` (`-y`), `--no-defaults`, `--service <name>`

## Layers (`--with`)

Customize projects with composable layers:

```bash
dropwsl new my-api python --with src,fastapi,uv,gitleaks
```

### Python

| Layer | What it does |
|-------|-------------|
| `src` | Reorganizes to `src/` layout (PEP 621) |
| `fastapi` | FastAPI + Uvicorn with `/health` (port 8000) |
| `streamlit` | Streamlit showcase (port 8501). Mutually exclusive with `fastapi` |
| `mypy` | mypy with strict mode |
| `uv` | Replaces pip with uv (10-100x faster installs) |
| `postgres` | SQLAlchemy 2.0 + psycopg3 + db/ package + compose service |
| `redis` | Redis client + cache/ package + compose service |
| `azure-identity` | Azure DefaultAzureCredential + `/api/identity` health check |
| `azure-ai-foundry` | Azure AI Foundry client + models + connections (requires `azure-identity`) |
| `azure-ai-chat` | Chat API with streaming SSE (requires `azure-ai-foundry`) |
| `streamlit-chat` | Chat UI frontend with streaming (requires `streamlit`) |
| `testcontainers` | Pytest fixtures with ephemeral PostgreSQL (requires `postgres`) |
| `locust` | Load testing with locustfile.py |

### Shared (cross-language)

| Layer | What it does |
|-------|-------------|
| `compose` | Generates `compose.yaml` skeleton + `.env.example` |
| `gitleaks` | Secret detection via pre-commit |
| `semgrep` | Static security analysis |
| `trivy` | Container vulnerability scanning |
| `mcp-fetch` | MCP server for web scraping |
| `mcp-git` | MCP server for git operations |
| `mcp-github` | MCP server for GitHub (issues, PRs) |
| `mcp-docker` | MCP server for Docker |
| `agent-developer` | AI Developer agent (Copilot + skills + knowledge) |
| `agent-po` | AI Product Owner agent |
| `agent-qa` | AI QA Lead agent |
| `agent-tech-lead` | AI Tech Lead agent |

## Multi-Service Workspace (`--service`)

```bash
# Create workspace with API + Worker sharing infrastructure
dropwsl new platform --service api python --with src,fastapi,postgres,redis
dropwsl new platform --service worker python --with src
```

Each `--service` adds:
- `services/<name>/` with code, tests, and production Dockerfile
- `.devcontainer/<name>/` with compose-based devcontainer
- Service in the shared `compose.yaml` (auto-incremental ports: 8001, 8002, ...)

Infrastructure layers (`postgres`, `redis`) inject services into the shared `compose.yaml`.

```
~/projects/platform/
├── compose.yaml
├── .devcontainer/
│   ├── api/
│   └── worker/
└── services/
    ├── api/
    └── worker/
```

## Customization

Edit [`config.yaml`](config.yaml) — no code changes needed:

```yaml
core:
  azure-cli:
    enabled: false
  kubectl:
    version: "1.33"

vscode:
  extensions:
    - ms-vscode-remote.remote-wsl
    - ms-vscode-remote.remote-containers
    - ms-azuretools.vscode-docker
    - ms-python.python
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REPO_URL` | `https://github.com/yurifranconeri/dropwsl.git` | Repository URL (self-update) |
| `INSTALL_DIR` | `~/.local/share/dropwsl` | Installation directory inside WSL |
| `PROJECTS_DIR` | `~/projects` | Base directory for `dropwsl new` |

## Uninstall

```powershell
# Remove tools from WSL + .wslconfig (distro preserved)
.\uninstall.cmd

# Dry-run (shows what would be done)
.\uninstall.cmd -WhatIf

# Destroy the distro (DATA LOSS — asks for confirmation)
.\uninstall.cmd -Unregister

# Nuclear — also uninstalls WSL from Windows
.\uninstall.cmd -Purge -Force
```

## Documentation

| Document | Content |
|----------|---------|
| [Design](docs/DESIGN.md) | Architecture, what gets installed, project structure |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common errors and solutions |
| [Tests](tests/README.md) | How to run tests and understand test structure |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
