# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-05-30

### Added

- Core tools `nodejs`, `bun`, `dotnet`, `pac-cli` as opt-in installers (toggled in `config.yaml`).
- Core packages `unzip` and `bind9-dnsutils` in `apt_base`.
- Docker daemon `default-address-pools` (default `10.200.0.0/16`, `/24` subnets) to avoid VPN/LAN conflicts. Configurable via `core.docker.address_pool_base` and `address_pool_size`.
- Python layer `streamlit-auth`: form-based auth via `streamlit-authenticator`, self-contained `users/` package with bcrypt + cookie HMAC and `python -m pkg.users` CLI (`add`, `passwd`, `remove`, `list`, `gen-cookie-key`, `verify`).
- Python layer `pydantic-settings`: typed config via `Settings(BaseSettings)`, self-contained `config/` package with `@lru_cache` factory and `python -m pkg.config` CLI inspector (`show`, `validate`, `dump-env`, `schema`).
- Python layer `azure-keyvault`: self-contained `keyvault/` package with opt-in FastAPI router and Streamlit panel. Reuses the `azure-identity` credential.
- Python layer `geopandas`: self-contained `geo/vector/` package with a `brasil_regioes` GeoJSON fixture.
- Python base `pyproject.toml`: ignores `T20` for `**/__main__.py` and `**/cli.py`.
- Python base `requirements.txt`: pins `pydantic>=2.7,<3.0`.
- Python layer `streamlit`: `.streamlit/secrets.toml` added to `.gitignore`.

### Changed

- **Breaking**: `azure-identity`, `azure-ai-foundry`, `azure-ai-chat` no longer modify the user's `main.py`. Each ships its own package (`auth/`, `foundry/`, `chat/`) with opt-in `router.py` (FastAPI) and `ui.py` (Streamlit). Migration: copy the `app.include_router(...)` snippet from the layer README. `azure-ai-chat` phase moved from `infra-inject` to `infra`.
- `dotnet` and `pac-cli` default to `enabled: false`.
- Python layer `streamlit` `.streamlit/config.toml`: sets `fileWatcherType = "auto"` and `[theme.sidebar]` to silence Streamlit >= 1.50 warnings.
- Defender exclusions list clarified as superset of install, uninstall and legacy entries.

### Fixed

- Python base `Dockerfile`: `USER $USERNAME` set before `python -m venv`; pip cache mount user-owned (`uid=1000,gid=1000`). Avoids root-created venv files that made subsequent `pip install` fall back to `~/.local`.
- `install_vscode_extensions()` passes `--force` so installed extensions actually upgrade.
- `install_wsl-vpnkit` restores the previous default WSL distro after `wsl.exe --import`.
- Python layer `streamlit-auth` templates: `<pkg>` placeholder substituted correctly (templates use `{{PKG_PREFIX}}`, layer passes it to all 5 affected render/inject calls). Regression test in `tests/unit/test_layer_hygiene.bats`.
- Python layer `streamlit-auth` templates: pass `mypy --strict` and `ruff` (`SIM105`, `S110`).
- Python layer `pydantic-settings` test fixture `_clear_settings_cache`: returns `Iterator[None]` (was `None` despite `yield`).
- Python layer `postgres` `db/engine.py`: skips `pool_size` / `max_overflow` for SQLite URLs (was crashing pytest at import).
- Python layer `streamlit` test `AppTest.run(timeout=30)` (was `10`, flaky on cold start).
- Shared layer `compose`: `initializeCommand` uses `docker network create ... 2>/dev/null || true` (was `docker compose up --no-build --pull never`, which silently failed without local images and left the dev container with no network).
- Test fixes: anchored line match for `return health_status`, exact dependency-line count for re-apply dedup, `grep -e` to escape `->`.

## [0.1.0] - 2026-04-01

### Added

- `dropwsl install` for provisioning a WSL development environment with Docker, kubectl, kind, helm, Azure CLI, GitHub CLI, Git + GCM, systemd, and VS Code integration.
- `dropwsl new` for creating containerized projects from language templates, with Python as the first supported language.
- Workspace mode via `dropwsl new <workspace> --service <svc> <lang>` for multi-service repositories with a shared `compose.yaml` and per-service Dev Containers.
- The `compose` layer for generating local service orchestration files for new projects.
- The `postgres` and `redis` layers for injecting infrastructure services into generated development environments.
- Python layers `src`, `fastapi`, `streamlit`, `streamlit-chat`, `mypy`, `uv`, `postgres`, `redis`, `azure-identity`, `azure-ai-foundry`, `azure-ai-chat`, `testcontainers`, and `locust`.
- AI agent layers `agent-developer`, `agent-po`, `agent-qa`, and `agent-tech-lead`, including prompts, instructions, and knowledge files.
- `dropwsl validate`, `dropwsl doctor`, and `dropwsl uninstall` for validation, diagnostics, and removal workflows.
- Declarative configuration through `config.yaml`, including `.wslconfig` generation and idempotent installation behavior.

[0.1.1]: https://github.com/yurifranconeri/dropwsl/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/yurifranconeri/dropwsl/releases/tag/v0.1.0
