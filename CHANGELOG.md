# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/yurifranconeri/dropwsl/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yurifranconeri/dropwsl/releases/tag/v0.1.0
