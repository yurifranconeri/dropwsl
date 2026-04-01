# Design

## Philosophy

| Layer | Responsibility |
|-------|---------------|
| **WSL** | Infrastructure: Docker, kubectl, kind, helm |
| **Containers** | Languages/runtimes — isolated per project |
| **VS Code** | UI: Remote WSL + Dev Containers — zero host pollution |

WSL handles infrastructure. Languages and dependencies live **inside containers**, isolated per project. VS Code connects via Remote WSL + Dev Containers.

## Entry Points

- `install.cmd` is the official Windows bootstrap entry point for first-time installation.
- When running from a standalone downloaded `install.cmd`, it fetches the latest repository snapshot from `main` into `C:\dropwsl` before delegating to `install.ps1`.
- After installation, day-to-day commands are run through `dropwsl.cmd` from PowerShell or directly inside WSL.

## What Gets Installed

### Base

- `systemd` enabled in WSL (`/etc/wsl.conf`)
- `apt upgrade` (security patches)
- Base packages: `git`, `curl`, `wget`, `gnupg`, `ca-certificates`, `lsb-release`

### Docker (official)

- Docker Engine (official Docker repository)
- Docker Compose v2 (`docker compose`)
- Docker BuildX (`docker buildx`) — multi-platform builds
- User added to `docker` group
- Daemon managed via `systemd`

### Kubernetes Tooling

- **kubectl** — official `pkgs.k8s.io` repository
- **kind** — local Kubernetes clusters (with SHA256 verification)
- **helm** — Kubernetes package manager

### CLIs

- **Azure CLI** (`az`) — via Microsoft apt repository
- **GitHub CLI** (`gh`) — via official apt repository

### Git Credential Manager (GCM)

- Auto-configures GCM from **Git for Windows** as credential helper
- Supports SSO (Entra ID), GitHub Enterprise, Azure DevOps
- Opens browser login on first `git push`/`pull`

### VS Code (optional)

If `cmd.exe` is available, installs extensions on the **Windows side**:

- `ms-vscode-remote.remote-wsl`
- `ms-vscode-remote.remote-containers` (Dev Containers)
- `ms-azuretools.vscode-docker`

> Tools and versions are configurable via [`config.yaml`](../config.yaml).

## Project Structure

```
dropwsl/
├── install.cmd            # Windows bootstrap entry point (downloads repo if needed → install.ps1)
├── install.ps1            # Install logic (Admin): WSL + distro + .wslconfig + dropwsl.sh
├── uninstall.cmd          # Windows entry point (wrapper → uninstall.ps1)
├── uninstall.ps1          # Uninstall: clean-soft / unregister / uninstall WSL
├── dropwsl.cmd            # Proxy entry point (--help/--version resolved here)
├── dropwsl.ps1            # Proxy: forwards args to dropwsl inside WSL
├── dropwsl.sh             # Bash orchestrator: parses args, sources lib/, calls installers
├── config.yaml            # Declarative config (tools, versions, toggles)
├── VERSION                # Semantic version (e.g. 0.1.0)
├── lib/
│   ├── wsl-helpers.ps1    # Shared PowerShell helpers (dot-sourced by .ps1 files)
│   ├── common.sh          # Helpers, logging, YAML parser (pure bash)
│   ├── validate.sh        # Post-install validation (validate + doctor)
│   ├── clean.sh           # Tool removal (clean, clean-soft)
│   ├── core/              # WSL tool installers (1 file = 1 tool)
│   ├── project/           # Scaffold, new project, layer orchestration
│   └── layers/            # Optional layers (auto-discovery by directory)
│       ├── shared/        # Cross-language (agents, MCP, DevSecOps)
│       └── python/        # Python-specific layers
├── templates/
│   ├── agents/            # AI agent templates (global, layers, per language)
│   └── devcontainer/
│       └── python/        # Python template (Ruff, Pytest, Coverage, multi-stage Docker)
└── tests/                 # bats (unit/integration) + Pester (PowerShell)
```

## Execution Flow

```
install.cmd (Windows, Admin)
  ├─ If install.ps1 is missing: download latest snapshot from main to C:\dropwsl
  └─ powershell Bypass install.ps1
    ├─ Install WSL + distro
    ├─ Configure .wslconfig
    └─ Call dropwsl.sh inside WSL
            ├─ source lib/common.sh    → helpers, logging, YAML parser
            ├─ load_config config.yaml → populate ENABLED_CORE, versions
            ├─ source lib/core/*.sh    → infrastructure tools
            ├─ source lib/project/*.sh → scaffold, new, layers
            ├─ source lib/validate.sh  → validation
            ├─ source lib/clean.sh     → removal
            │
            ├─ enable_systemd_if_needed()
            ├─ apt_base()
            ├─ for tool in ENABLED_CORE → install_${tool}()
            ├─ install_vscode_extensions()
            ├─ configure_gcm()
            ├─ configure_git_defaults()
            ├─ clone_dropwsl_repo()
            └─ validate_all()

dropwsl.cmd (proxy, no Admin)
  └─ powershell Bypass dropwsl.ps1
       └─ wsl.exe -d <distro> -- dropwsl $args
```

## Config-Driven

`dropwsl.sh` iterates over `ENABLED_CORE` from `config.yaml`, calling `install_${tool}()` dynamically. Adding/removing tools is just a YAML edit:

```yaml
core:
  docker:
    enabled: true
  kubectl:
    enabled: true
    version: "1.34"
  azure-cli:
    enabled: false    # ← disabled, won't be installed
```

### Default Layers (`defaults.layers`)

Layers listed in `defaults.layers` are auto-applied on every `--new`:

```yaml
defaults:
  layers:
    - gitleaks
    - trivy
```

| Rule | Description |
|------|-------------|
| Auto merge | Default layers merge with `--with` before execution |
| `--no-defaults` | Bypass completely: `--new my-api python --no-defaults` |
| Deduplication | If user already listed `--with gitleaks,trivy`, no duplicates |
| Language-agnostic | Only cross-language layers: `gitleaks`, `trivy`, etc. |

## Layer System Design Rules

| Rule | Description |
|------|-------------|
| No-clobber | `--scaffold` never overwrites existing files |
| Idempotent | Safe to re-run — check-before-install with early return |
| Mutual exclusions | `streamlit` ↔ `fastapi`, `biome` ↔ `eslint+prettier`, etc. |
| Phase ordering | Layers declare `_LAYER_PHASE` for execution order |
| Conflict detection | `_LAYER_CONFLICTS` validated before any layer runs |
| Dependency tracking | `_LAYER_REQUIRES` checked before execution |

## Design Decisions — Infrastructure Layers

### postgres — SQLAlchemy 2.0 + Service Layer

**ORM:** SQLAlchemy 2.0 with `Mapped[T]` + `mapped_column()` (type-safe, mypy-aligned). Driver: psycopg3.

**Pattern: Service Layer** (not Repository). SQLAlchemy Session **already is** Repository + Unit of Work. The Python ecosystem (FastAPI, Starlette, Litestar) converged on pure functions with Session injected: `create_user(session, data)`.

**Schema:** `create_all()` in lifespan (additive, idempotent). Alembic fits as a future layer without refactoring.

### compose — Local Declarative Infrastructure

`compose.yaml` v2 (no `version:`), named volumes, health checks on every service, isolated network, non-root, credentials in `.env` (never hardcoded), ports on `127.0.0.1` only.

### testcontainers — Tests with Real Databases

"Don't mock what you don't own." Testcontainers spins up real PostgreSQL in an ephemeral container (~3s startup). Pattern: Transaction Rollback — each test runs in an isolated transaction (begin → yield → rollback).

### Topology-Agnostic

Generated code is **topology-agnostic**. `DATABASE_URL` is the only knob — works the same in a local container, VM, Azure Database, or AWS RDS. No `if env == 'prod'`, no per-environment config files.

## VS Code Extensions

### Host-side (Windows — `install.ps1`)

Configured in `config.yaml` → `vscode.extensions`. Installed via `code --install-extension`.

| Extension | ID |
|-----------|-----|
| Remote WSL | `ms-vscode-remote.remote-wsl` |
| Dev Containers | `ms-vscode-remote.remote-containers` |
| Docker | `ms-azuretools.vscode-docker` |

### Base (every template — `devcontainer.json`)

| Extension | ID |
|-----------|-----|
| Copilot Chat | `GitHub.copilot-chat` |
| EditorConfig | `EditorConfig.EditorConfig` |
| GitLens | `eamodio.gitlens` |
| Docker | `ms-azuretools.vscode-docker` |

### Per Template

| Template | Extensions | IDs |
|----------|-----------|-----|
| `python` | Python, Pylance, Ruff | `ms-python.python`, `ms-python.vscode-pylance`, `charliermarsh.ruff` |

### Injected by Layer

| Layer | Extension | ID |
|-------|-----------|-----|
| `mypy` | Mypy Type Checker | `ms-python.mypy-type-checker` |
| `trivy` | Trivy Vulnerability Scanner | `AquaSecurityOfficial.trivy-vulnerability-scanner` |
